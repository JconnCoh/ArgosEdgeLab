# OCV-03 O3F16 R46/C13 dual-appearance and multiprocessing handoff — 2026-09-12

Disposition: `PENDING_GATE`

This checkpoint exists only because the current Codex task crossed the mandatory
session-size hard stop and the operator explicitly authorized one robust new-task
handoff. It is not a detector release, package authorization, production gate, or
permission to create another rollover. No detector bytes, source images, JBOD
state, portal queue, task, process, provider, XML, training, or production state
were changed while authoring this handoff.

## Acceptance boundary

The successor must run directly in the saved local project
`C:/Users/joshua.conn/Desktop/ArgosDev/ArgosEdgeLab`, not in the detached
`c7f5` generated worktree. It must use the exact local project returned by Codex
Desktop as `Ai AVI Image processing`, project ID
`0e4b841f-d116-45fc-b11e-0826f55acd41`, and local host `local`.

Before any edit, detector execution, result-root creation, image read, or JBOD
contact, the successor must:

1. Read the governing sequence required by `AGENTS.md` and both applicable
   skills: `argos-opencv-migration` and `argos-jbod-direct-control`.
2. Fetch `origin/codex/fiducial-opencv-d-drive` and require the branch, local
   `HEAD`, and fetched origin tip to equal the exact containing commit supplied
   in the creation prompt.
3. Verify this checkpoint, its machine-readable manifest, its verification gate,
   the current continuity file, and every dependency it will consume by bytes and
   SHA-256.
4. Confirm all required active R46-chain and C13-evidence files are tracked in
   `HEAD`; none may be reconstructed from chat, cache, a package, or a result
   filename.
5. Return a read-only `ACCEPTED_AWAITING_RELEASE` attestation to the source task.
   It must state exact root/project/branch/tips/hashes, zero dependency mismatch,
   the detector and multiprocessing contracts below, every hold, and
   `writesPerformed=false`, `implementationStarted=false`.
6. Wait for the source task to validate that attestation and explicitly release
   implementation.

The handoff transfers all authoritative facts, decisions, unresolved questions,
paths, hashes, holds, scope limits, and next actions. Private model reasoning,
open tool handles, and transient process memory cannot be transferred between
tasks and are not claimed as authority.

## Repository state being handed off

- Required branch: `codex/fiducial-opencv-d-drive`.
- Tip before preservation: `f8d7f977ac95320ff1f3fbc856577081251f08ce`.
- Preservation commit: `29dacf534f8c1d2b5067e40918f981f99b1618c4`.
- The final containing commit is intentionally supplied externally in the task
  creation prompt because a tracked file cannot safely contain the hash of the
  commit that contains itself.
- The preservation commit captured 132 existing project paths without rewriting
  their content: six tracked modifications, two staged detector adapters, 97
  non-ignored project artifacts, the previously ignored active detector chain,
  and the previously ignored C13 action evidence.
- The repository contains a very large ignored area (audit: 184,563 files,
  183,692,309,824 bytes). It is dominated by source images, result trees, build
  staging, and caches. It remains physically in the same saved project and was
  not copied, deleted, staged, or made a dependency. The successor must not scan
  it recursively. It may consume an ignored byte only after adding its exact path,
  size, purpose, and hash to a fresh bounded evidence record.

## Current objective

Improve frontside notch identification without breaking already correct notches
or turning chipouts/damage into notches, while also introducing bounded
whole-wafer multiprocessing for speed. The experiment is deliberately diagnostic
and must retain both appearance lanes; it must not prematurely optimize by
accepting the first lane that looks successful.

The current implementation is R46. R46 is a runtime-stall/corridor-cache fix over
R45. Its exact transformed-corridor equivalence self-check passed 396 cases. R46
does not introduce the requested interior-first tracing or dual-population
semantics.

The exact implementation seam is:

- R18 currently builds a transition map using enhanced-contrast thresholding
  together with raw-contrast polarity.
- R27 emits one unified `candidateTraces` population.
- R41 `analyze_native_strip()` and `pair_after_channel_contours()` select and pair
  that population.
- The successor must fork the two appearance populations before R27 unifies them
  and before R41 selects or pairs them.

## Frozen C13 result and review outcome

The completed review-only result is
`U:/ProjectPortalRO/responses/F34F24C13`. Its three top-level machine files are
hash-pinned in the companion manifest. Do not read its PNG/image bytes during
handoff acceptance.

Machine outcome:

- 24 cases scheduled and 24 completed; 48 BF/DF source leaves validated.
- 11 cases had a correct unique BF/DF pair: C0007, C0010–C0016, C0020,
  C0023, and C0024.
- 8 cases had correct DF with BF held: C0004, C0006, C0008, C0009, C0018,
  C0019, C0021, and C0022.
- 5 cases had no selected notch: C0001, C0002, C0003, C0005, and C0017.
- No reviewed chipout, damage, or contact response was selected as a notch.
- Cyan fixed-circle and yellow 20-pixel-inward geometry remained stable.
- Candidate explosions occurred in C0001 (BF 223 / DF 401), C0002
  (BF 504 / DF 419), and C0003 (BF 380 / DF 477).
- C0005 had a good BF response near 269.692 degrees but no DF candidate and a
  circle mismatch.
- C0017 had valid-looking BF and DF responses, but BF circle coverage was 0.319
  against the frozen 0.35 gate.
- All notch ownership remains held. Registration, XML/KLARF export, and
  production routing remain unauthorized.

Operator visual review found the outside-facing trace jagged/noisy in failed
cases while the wafer-interior edge often appeared smoother. Contamination,
metal, or lighting inside the notch can dominate one enhancement. This motivates
the experiment below; it does not prove a production rule.

## Frozen dual-appearance detector contract

For every frozen input and for both BF and DF, development evaluation must run
both populations to terminal completion:

1. `RAW_DEFAULT`: native/default pixels without the existing enhancement.
2. `ENHANCED_ASSISTED`: the existing enhancement path, with exact parameters and
   provenance retained.

The following are mandatory:

- Neither population may accept, reject, short-circuit, suppress, overwrite, or
  replace the other.
- Preserve each population's complete candidates, holds, failures, measurements,
  masks, overlays, and pixel provenance separately.
- Associate the same physical response across populations only by native
  angle/coordinate interval after both populations are terminal. Association is
  diagnostic deduplication, not a winner or pixel transfer; both records and all
  lane-specific measurements remain present.
- No fusion, winner, early-exit, or production decision is allowed before the
  complete broad regression is frozen and reviewed by the operator.
- Freeze and hash both neutral populations before a separate evaluator opens any
  scorer label or operator truth.
- Every accepted coordinate must have a raw/native-pixel witness even when the
  enhanced lane proposed it.
- Apply the same evidence-bank idea to channel-local circle support without
  loosening the existing circle gate or silently substituting one lane for the
  other.

## Frozen interior-first tracing hypothesis

- Find the notch interval from the missing normal edge/green shoulder endpoints.
- Within that bounded interval, search from the wafer interior toward the outside
  and take the first sustained, shoulder-connected physical edge band.
- Trace an actual channel-local native brightness-supported path from shoulder to
  shoulder and through the apex.
- Measure apex, monotonic sides, circle return, curvature reversals, smoothness,
  branches, band switches, supported width, and depth before notch selection.
- Do not force an ideal curve, morph, interpolate across unsupported pixels, or
  copy pixels between BF and DF.
- Cyan remains the fixed outer circle. Yellow remains exactly 20 pixels inward.
- The brightness-supported third trace remains visible on circle-only and notch
  views.
- R6 is only post-contour secondary corroboration.
- Same-chuck cross-channel transfer is lawful only for angle/ownership interval
  and transfers zero pixels. BF and DF contours remain channel-local.

Expected relevance, not a promise of success:

- C0002 excess curvature reversals and C0003 multiple-apex behavior are direct
  targets of the interior-first trace.
- C0001 tests whether a complete BF path can be recovered without manufacturing
  one.
- C0005 tests the separate no-DF-candidate and circle-mismatch conditions.
- C0017 tests whether raw/default evidence legitimately improves BF circle
  coverage without weakening 0.35.

## Frozen multiprocessing contract

Parallelize only independent whole-wafer cases. Do not parallelize BF and DF
within one case and do not share the module-global BF/DF engine state between
workers.

- Use Python multiprocessing with `spawn`.
- Start at exactly 2 process workers because one decoded source image is roughly
  453 MiB. Benchmark and freeze a frontside-specific worker count; do not copy the
  Scribe default of 8 without memory evidence.
- Each worker owns one whole case and processes BF then DF serially.
- Each worker loads its own provider, detector modules, reference/cache state, and
  validates its own exact source/config hashes.
- Pin OpenCV to one internal thread per worker and disable OpenCL/GPU.
- Deterministically assign cases and reconstruct exact original inventory order in
  the parent.
- Workers write only disjoint per-case roots. The parent alone writes global
  status, aggregate/index files, and `COMPLETE`.
- No automatic retry. The first fatal error sets a shared stop event; the parent
  exits the receive loop, terminates and joins all remaining children, proves zero
  residual children, and never writes a false `COMPLETE`.
- A process-isolated solution to the current single-`Q:` per-case mapping is the
  only frontside-specific runtime seam. It must use deterministic, disjoint short
  aliases without copying source images. It may not redesign wrappers, transport,
  or endpoint infrastructure.

Qualification must prove:

- serial and parallel semantic projections are identical;
- serial and parallel raster hashes are identical for identical inputs;
- two parallel runs are deterministic;
- at least two worker PIDs and overlapping case intervals are observed;
- elapsed time, CPU, peak RSS, worker count, and per-case timing are recorded;
- all holds and all normal hypothesis semantics are unchanged;
- zero residual children and no false `COMPLETE` after injected failure.

The Scribe multiprocessing qualification records that define this pattern are
external read-only dependencies in the manifest. They authorize reuse of the
orchestration design, not reuse of OCR-specific worker counts or OCR code.

## Smallest authorized implementation after acceptance release

The successor must first measure its proposed diff. The maximum planned product
change is two new executable files and 600 net-new executable lines total:

1. one R47 detector adapter that inherits the exact R46 chain and adds only the
   dual-population/interior-first diagnostic behavior;
2. one bounded case coordinator that adds only process-isolated whole-case
   orchestration around the existing runner.

Do not modify any R46 or predecessor byte. Do not create a new package, endpoint
worker, portal runner, wrapper, launcher, recovery framework, schema family, or
general harness. Reuse existing tests and the recorded route. No more than one
small local non-image check root (under 50 MiB) and one fresh JBOD `D:` result root
may be created. Do not place image results or source copies on laptop `C:`.

If the projected change exceeds two executable files or 600 executable lines,
if support code becomes larger than the detector change, or if a third local
draft revision fails, stop and report exact counts. Do not silently expand.

## Regression sequence after release

1. Reverify every dependency actually consumed and the R46 396-case equivalence
   evidence.
2. Measure the exact two-file delta and hard-code scan. Lot, slot, source root,
   output root, review-only switch, or authority decisions must be configuration
   inputs, never detector constants.
3. Author the R47 detector adapter and the two-worker process coordinator.
4. Run only minimal source/import/non-image checks first.
5. Prove deterministic serial/parallel equivalence and failure cleanup on the
   smallest existing non-image or bounded fixture set.
6. Only then use the unchanged recorded JBOD detector-development route for one
   bounded full-resolution focal regression into one fresh short `D:` root. No
   package build or publication is part of this authority.
7. The focal cohort must include C0001, C0002, C0003, C0005, and C0017, correct
   C13 controls, the old chipout wafer, the prior hotspot, and old wafers that
   previously passed. A new algorithm may turn an old failure into a pass when it
   genuinely finds the notch; an old hold is not frozen as a permanent expected
   failure.
8. Freeze/hash both lane populations before any evaluator reads labels. Stop for
   operator visual review with side-by-side lane provenance and timing.

One unchanged-route execution failure stops that attempt. Do not retry, alter the
route, open another console, or convert detector work into infrastructure work.

## Preserved authority and holds

- Review-only detector development and bounded hash-locked real-image evaluation
  are authorized after the source task releases the accepted successor.
- No package build, signature, publication, installation, activation, or
  production routing is authorized by this handoff. Package attempt count remains
  unchanged; there is no automatic retry.
- U13 terminal-unknown/no-retry remains preserved.
- Every R21/R22/R23, cyan-geometry, BF-contour, notch-ownership, fiducial,
  registration, appearance-route, XML/KLARF, and production hold remains active.
- Do not touch T5, targeted 11, full 978, scribe/OCR work, source images, existing
  tasks/processes, providers, portal/RDP/transport infrastructure, queues,
  training, XML, or production.
- Do not alter or stop the separately owned R18ZW OCR worker.
- Do not create another rollover or handoff unless the operator explicitly asks.

## Exact next action

The successor's first turn is acceptance-only and read-only. After the source
task validates `ACCEPTED_AWAITING_RELEASE` and sends an explicit release, proceed
with the regression sequence above. The immediate implementation objective is
the smallest R47 fork before R27/R41 selection that preserves complete
`RAW_DEFAULT` and `ENHANCED_ASSISTED` populations, followed by a two-worker
whole-case coordinator derived from the qualified Scribe orchestration pattern.

Machine-readable companion:
`work/O3F8/O3F16R46_C13_DUAL_APPEARANCE_MULTIPROCESS_HANDOFF_20260912.json`.

Verification gate:
`work/O3F8/O3F16R46_C13_DUAL_APPEARANCE_MULTIPROCESS_HANDOFF_GATE_20260912.json`.

Their exact hashes, this checkpoint hash, the updated continuity hash, and the
final containing commit are supplied in the successor creation prompt and must
be recomputed before acceptance.
