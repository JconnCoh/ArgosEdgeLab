# Front-metal D7 V17 R5P18 JBOD peer-qualification handoff

Revision: `FM7V17R5P18_HANDOFF`

Disposition: `PENDING_GATE`

Date: 2026-08-15

## Authority and reason for this checkpoint

The operator authorized the next bounded step: qualify additional POST2 wafers
in place on the JBOD, then use their clean regions to enlarge the
target-excluded BF and DF reference envelopes. The operator identified the
candidate slots as `25,24,23,22,21,20,19,18,16,14,02` and separately stated
that a bad perimeter region may form a crescent extending about five die rows
inward. Such a regional anomaly must not reject an otherwise useful peer, but
its pixels must not be absorbed into the normal reference.

The active Codex task reached the mandatory 256 MiB rotation threshold before
the package was built. This file is a text-only handoff. No JBOD job was
published or run, and no image, detector, mask, threshold, classifier, M3,
reviewer, XML, production route, or V16 artifact changed.

## Locked parent and sensitivity authority

- Parent checkpoint:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FRONT_METAL_D7_V17_R5P17_DEADBAND_CHECKPOINT_20260815.md`
- Parent SHA-256:
  `8F09902651D6B65779BEEF7501C179EB4FFC638F17316C32FCED8CAA68769EDB`
- Patterned-wafer registration baseline:
  `work/ARGOS_PATTERNED_WAFER_REGISTRATION_BEST_PRACTICE.json`
- Registration baseline SHA-256:
  `FE436D5BEC5D2497B2D5AB06B5180FF371C20A330493A3AF476EDA204381183A`
- Exact previously recovered POST2 source paths and hashes:
  `work/PROJECT_PORTAL_REVIEW_ONLY/requests/POST2_NATIVE_RECOVERY_20260811T204207Z/RECOVERY_REQUEST_LEDGER.json`
- Recovery-ledger SHA-256:
  `12BD9CF377B148001DB855264027E5D77451361F78B3D6C51D8D572FB62290B0`
- Accepted registration implementation source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17QualifiedCompositeAuditV1.cs`
- Source SHA-256:
  `F303DD8B2E6DB08A6E0D315917AE3FF1065B32C298BE26B6AC2C158533C77FE7`
- Current target is Slot02. It is excluded from every reference used to score
  itself. Slot02 may be read as the unchanged target but is never a peer for
  its own composite.
- Preserve all 216 saved real components and all 57 saved missed-defect
  strokes as the sensitivity gate. Preserve 21 saved false components and 29
  false-removal strokes as negative controls. Unresolved findings stay holds.

## Required next run

Build a short-path, portable, review-only JBOD package. Before the first write
or launch, run the path-budget checker against the exact package source and
longest possible output path, and run the wrapper checker against the exact
PowerShell script, CMD wrapper, and bounded UTF-8 JSON manifest. The wrapper
must expose a non-mutating `-Preflight` path and use Windows PowerShell 5.1
with `-NoProfile -ExecutionPolicy Bypass` and one quoted manifest scalar.

The quickest first run is peer qualification, not a full detector rerun:

1. Read the lossless BF and DF BMPs directly on the JBOD and verify the exact
   source hashes from the recovery ledger.
2. Load source data once and use the JBOD's 128 GiB RAM; start with eight
   bounded workers only if the implementation actually benefits from worker
   parallelism.
3. For BF and DF independently, use the approved notch macro pose and the
   accepted nonrepeating dark fiducial plus straight horizontal and vertical
   first-transition edges. Require a no-scale rigid XY/theta result at
   distributed sites and reject a whole-die or PM-period alias.
4. Produce per-slot alignment metrics and small file-backed verification
   sheets. Do not embed image bytes in the task or transfer full wafers back.
5. Measure spatial appearance/topology disagreement after registration. A
   coherent perimeter crescent, provisionally up to about five die rows, is a
   candidate exclusion region, not proof that the whole peer is invalid.
   Interior mismatch, wrong PM/scribe phase, broad color-family mismatch, or
   insufficient fiducial evidence holds the affected peer or region.
6. Build BF and DF contribution masks independently. A pixel may enter a
   target reference only when that peer is aligned, topology-qualified, and
   locally normal there. Do not fill excluded regions and do not treat absent
   contribution as Normal.
7. Require at least three locally eligible target-excluded peers at every
   scored pixel; otherwise emit a coverage hold. Use a robust per-pixel
   bounded normal envelope or quantiles, not merely a larger median.
8. Return only compact JSON/CSV metrics plus bounded T16/T17 and representative
   perimeter/interior sheets. Stop for operator feedback before a full-wafer
   V17 rerun or any detector promotion.

## Slot handling

- Operator-confirmed JBOD lot root:
  `D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2`.
  Use this exact local-JBOD root as the primary source location. Resolve each
  slot's BF/DF BMP below it and verify the expected hashes from the recovery
  ledger; do not discover an alternate copy by a broad drive scan.
- Requested candidate pool: `S14,S16,S18,S19,S20,S21,S22,S23,S24,S25`.
- Existing `S03,S13,S18` remain useful controls for replay comparison; only
  qualified local pixels may contribute.
- `S25` previously showed a possible whole-die/PM-phase error and begins held
  until the new distributed fiducial gate disproves the alias.
- `S20` and `S21` lacked complete local raw-tile recovery, so inspect their
  full JBOD BMPs directly rather than inferring eligibility from local data.
- Do not exclude an entire wafer solely because one perimeter crescent is
  discolored. Do not absorb that crescent into the composite merely because it
  occurs on several edge die.

## Execution boundary

The fresh task must resume from this checkpoint and the mandatory continuity
files, then build and preflight the portable package. If direct remote launch
is unavailable, finish the verified package and provide one bounded manual
JBOD command; do not widen the portal or publish a maintenance hotfix merely
to avoid that explicit launch step. Any future portal/hotfix publication must
pass the exact packaged Windows PowerShell 5.1 predecessor/rehearsal gate.
