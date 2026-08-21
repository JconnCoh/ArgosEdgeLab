# Argos Phase 1 / Phase 2 Operational Roadmap

Status: implementation contract and staged roadmap. It does not authorize a
production run, production XML routing, a full-lot run, detector training, or
overwriting any existing artifact.

## Outcome

Argos will use the human-verified wafer scribe as the primary wafer identity,
attach the current MES visual/process state to that identity, choose the Bare
or BowComp backside inspection domain from exact MES history, preserve the KLA
record, and validate XML coordinates and defect sizes in a bounded test lane.

The canonical metadata shape is defined by:

- `work/MES_INSITE_READ_ONLY/ARGOS_WAFER_METADATA_SCHEMA_V1.json`;
- `work/MES_INSITE_READ_ONLY/FRONTSIDE_VISUAL_STATE_AND_BOWCOMP_CONTRACT.md`.

## Identity and source boundaries

- Primary wafer ID: confirmed 12-character scribe.
- MES-linked wafer ID: issued wafer/container found from the scribe lineage.
- Argos lot, tool, physical slot, image folder, and acquisition time:
  observational metadata only. Preserve them because tool/slot damage
  correlations are important, but never use slot as the MES identity key.
- JBOD discovery must run on the Argos/JBOD computer or an approved gateway
  that can see that storage. The laptop's `D:` drive is a different computer
  and is never a substitute for the Argos JBOD tree.
- Every file is tracked by full path, size, last-write time, and hash. A run
  manifest prevents a moved, renamed, or duplicated folder from being
  silently inspected twice.

## Frontside visual-state key

Frontside reference images and comparisons are segregated by this exact
seven-field tuple:

1. Device Workflow;
2. ProdFamily;
3. Product, including revision;
4. Process Block Workflow;
5. Process Block;
6. Step;
7. Status Semantic: `In Process` or `In Queue`.

Raw MES values are preserved. A normalized, versioned key is derived only for
indexing. A missing field creates `VISUAL_STATE_HOLD_INCOMPLETE_MES_STATE`;
it is not replaced with an empty string or grouped with a different state.

`In Process` and `In Queue` are deliberately separate because a wafer that
has moved into a process may have a different visible surface than a wafer
waiting at the same step.

## Phase 1 - initial implementation

### P1.1 Discover uninspected image folders

An Argos-side inventory adapter scans only configured JBOD acquisition roots.
It writes a timestamped, refusal-on-overwrite discovery manifest containing:

- acquisition folder and lot-folder labels;
- BF/DF/front/back source paths;
- source dimensions, byte lengths, hashes, and timestamps;
- Argos tool and physical slot;
- evidence that the folder has or has not already been inspected;
- discovery and eligibility state with a reason.

Discovery does not execute a detector. Ambiguous folder identity, incomplete
BF/DF pairs, non-lossless detector inputs, or a duplicate manifest entry are
holds.

Discovery also opens or resumes a durable lot visit. The sealed Argos
acquisition-session ID, not folder existence or physical slot, is the repeat
key. Every wafer and side in one session shares one immutable visit ordinal:
the first distinct lot visit is Pre and the second is Post. Retries of an
already sealed session are idempotent. Later distinct visits remain unique
Post runs and may not overwrite the first Post result. The governing contract
is `work/ARGOS_PROGRAM_INTEGRATION_REVIEW/ARGOS_RUN_LEDGER_AND_PRE_POST_CONTRACT.md`.

### P1.2 Read and confirm the frontside scribe

The scribe reader localizes the frontside scribe, preserves its tight crop,
per-character scores, image-first string, checksum result, and alternatives.
The confirmed scribe becomes the canonical wafer identity. Low-confidence,
checksum-conflicting, or MES-conflicting reads require a bounded confirmation
card rather than a silent substitution.

### P1.3 Resolve MES lineage and backside domain

The read-only lookup follows:

```text
confirmed scribe
  -> EPI/source wafer
  -> issued wafer/container
  -> MES state container and historical base lot
```

BowComp is proven only by an exact historical event on the linked base lot:

```text
Workflow step     = SPUTTER BOW COMP DEP
TxnServiceName    = MoveIn
TxnType           = 2650
```

The summary text is retained as audit evidence but is not parsed as the
primary rule. The verified event means the wafer has entered the deposition
step and selects the isolated BowComp backside inspection domain.

Outcomes:

- `BACKSIDE_REGIME_BOWCOMP`: qualifying exact MoveIn exists;
- `BACKSIDE_REGIME_BARE`: relevant history is complete and no qualifying
  MoveIn exists;
- `BACKSIDE_REGIME_HOLD_HISTORY_INCOMPLETE`: lineage or history coverage is
  incomplete or ambiguous.

Folder names, blue appearance, product family, slot, or a later process step
must never independently decide this state.

### P1.4 Snapshot metadata

At discovery and again immediately before inspection, save a read-only MES
snapshot with the seven visual-state fields plus lineage, current operation,
resource, rework, EPI resource, tool/slot, acquisition, and query provenance.
If the MES state changes between snapshots, preserve both and use the
pre-inspection state for visual grouping. Never silently rewrite a historical
inspection when MES advances later.

### P1.5 Inspect with a required-engine contract

Select either the Bare or isolated BowComp engine set from P1.3. Every
required engine must report `ENABLED`, `HOLD`, or `FAILED`; missing results
cannot be treated as a pass. Native lossless Argos pixels and existing
resolution/geometry guardrails remain mandatory.

Frontside visual references are compared only within the same complete
visual-state key. Until enough validated examples exist, a reference is a
review aid, not training truth or an autonomous golden-image authority.

### P1.6 Generate and preserve KLA, then convert a copied test input to XML

Preserve the KLA as the inspection/archive record. Use the confirmed scribe
to obtain the MES product/template lookup instead of deriving identity from
physical slot. The existing ChatGPT-era KLA-to-XML method remains the initial
conversion baseline, but Phase 1 validation must run only on copied inputs in
an isolated scratch/test route.

The converter must record:

- source KLA path and hash;
- confirmed scribe and MES-linked issued wafer;
- product/template and lookup provenance;
- converter version/config hash;
- unmapped-class holds and bin legend;
- output XML hash and test-only eligibility flags.

It must refuse overwrite and must not place Phase 1 test XML in a production
Outbox or ShermanData destination.

### P1.7 Validate defect size and location in test XML

Before any routing is considered, round-trip a small set of known synthetic
and observed defects through the copied KLA/XML path. Validate:

- one-pixel physical scale (`14.5 um`) and area scaling;
- width, height, area, and contour units;
- center/coordinate origin and handedness;
- frontside/backside mirror state;
- notch rotation and die-grid phase;
- correct die assignment near the center and perimeter;
- no unexpectedly large polygon, bounding box, or wafer region.

Acceptance requires numerical tolerances plus a visual overlay on the same
lossless wafer image. A size-scale or coordinate failure is
`XML_TEST_HOLD_GEOMETRY_OR_SCALE`, never a production file.

## Phase 2 - map learning from active testing

For each sufficiently populated visual/product state:

1. load the original product XML template without modifying it;
2. align its die grid to an approved frontside wafer transform;
3. preserve operator rotation, translation, pitch-display adjustment, phase,
   mirror state, source hashes, and approval;
4. identify physically inspected edge die missing or null in the original
   template;
5. generate a new versioned candidate template that adds only supported die;
6. compare the candidate against the original and separately validate it in
   the target Shermap test process.

Vendor/original templates are immutable. A candidate template must never be
promoted merely because it looks aligned on one wafer. Product and complete
visual-state coverage, repeated-wafer evidence, coordinate regression, and
Data Engineering/Shermap acceptance remain separate gates.

## Export boundary

The intended production topology is:

```text
Argos local staging -> gateway mover -> ShmData/ShermanData destination
```

Each hop is a separate, auditable component. The inspection process writes
only a timestamped local staging package. A mover verifies name, route,
hash, destination, and duplicate state before transfer. No detector or GUI
directly writes to the network destination.

The run ledger assigns `BACK_PRE`, `BACK_POST`, `FRONT_PRE`, or `FRONT_POST`
from the immutable lot-visit phase. It never reconstructs Pre/Post from output
folder contents. An identical source/session retry returns the existing export;
a different artifact at the same destination is a collision hold, not an
overwrite.

Until separately approved, all outputs from this roadmap remain local,
review-only, training-ineligible, XML-production-ineligible, unpackaged, and
unrouted.

## Initial bounded milestone

The first implementation milestone is complete only when one copied wafer
folder can produce, without overwriting anything:

1. a discovery manifest;
2. a confirmed-scribe identity record;
3. a MES visual-state and BowComp/Bare evidence snapshot;
4. a required-engine state manifest;
5. an archived test KLA;
6. a converted test XML plus bin legend;
7. a defect size/location round-trip report;
8. a local export-staging manifest with network transfer disabled.
