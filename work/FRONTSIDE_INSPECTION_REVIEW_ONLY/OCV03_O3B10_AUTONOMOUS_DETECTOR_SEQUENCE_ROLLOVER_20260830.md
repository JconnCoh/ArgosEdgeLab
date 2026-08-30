# OCV-03 O3B10 autonomous detector sequence rollover — 2026-08-30

Disposition: `PENDING_GATE`

This checkpoint carries the current review-only Argos OpenCV detector work to
one fresh Codex task without a transcript fork, heartbeat, scheduled monitor,
or rediscovery of recorded access, runtime, source, hash, and topology facts.
The operator authorized autonomous continuation through detector development,
real-image regression, failure analysis, and explicit hold recording.

## Current evidence

R20 completed the exact 953-pair backside corpus at
`D:/KLARFExport/_ArgosReview/C15RUN4`: 931 review-only unique-notch passes,
21 not-found holds, one DF channel-analysis hold, and zero source problems.
R20 has zero regressions and zero shared-pass angle drift against R18 and R15.
It remains valid regression evidence but is not an activation, publication, or
successor-package parent.

The activation gaps remain exact:

- no channel-local visible-holder mask is applied before perimeter and
  candidate formation;
- a sole paired holder-like candidate remains an untested false-pass risk;
- 13 Coherent rows expose a DF appearance/morphology gap;
- six BowComp rows expose a BF appearance/morphology gap;
- one ProcessJob11 Slot19 row has no eligible channel candidate;
- Break Resist Slot25 has multiple eligible pairs without a unique selection;
- ProcessJob11 Slot25 has a DF radial-qualification hold.

Frontside notch proof remains development-only: three POST2 members passed,
but the complete frontside corpus has not been proven. OCV-02 scribe proof is
also incomplete: Slot22-Slot25 produced zero automatically accepted identities
and retain localization, reference-coverage, ambiguity, reranking, and upstream
identity-confirmation holds. The rare frontside hotspot remains parked.

## Autonomous execution sequence

### 1. Finish backside perimeter and notch

Create one bounded local OpenCV successor from the useful R20 implementation.
Before perimeter and candidate formation, derive channel-local masks for
visible exterior-connected holder bodies and exclude only their local wafer
overlap. Do not use fixed holder angles, lot, slot, expected notch angle, Argos
pose, or another channel's pixels. A manufactured indentation beside empty dark
exterior or adjacent to a holder must remain eligible.

Correct the Coherent-DF and BowComp-BF appearance gaps independently. Preserve
R20 perimeter, full-360 search, physical-candidate pairing, fixture suppression,
and explicit ambiguity semantics unless actual image evidence disproves them.
Develop a separate rough-backside appearance regime for InP-like wafers. Image
appearance is the detector authority; completed MES history such as
`InP CAP REMOVAL / INP CAP ETCH` may select or corroborate the configured
regime but must not hard-code a lot or waive image gates.

Regress in this order: frozen ten R20 controls, all 22 R20 holds, new
sole-holder and notch-adjacent-holder controls, known chipout controls, and
representative normal, Coherent, BowComp, and rough-backside cohorts. Only
after those pass may one fresh complete 953-pair backside corpus run. Inspect
actual BF/DF evidence for every changed state and every angle outlier before
assigning cause or tuning again.

### 2. Complete frontside perimeter and notch

Preserve the current three POST2 results as development regression evidence,
not all-corpus proof. Process every applicable frontside BF/DF acquisition in
the bounded KlarfExport corpus. Search the full circumference and suppress
repeating die-pattern responses before candidate selection. Never select by a
fixed image angle, nearest prior, or deepest indentation. Keep BF and DF
physical-boundary evidence independent and distinguish manufactured notches,
physical chipouts, appearance-only pattern competitors, channel disagreement,
and incomplete coverage.

POST2 is a known mechanical-wafer challenge cohort, not a selector or the only
possible unusual-scribe/notch family. Require zero chipout-as-notch selections,
zero pattern-as-notch selections, accurate local edge-hugging evidence, and
explicit holds when more than one physical candidate remains plausible. Leave
the rare hotspot parked for a later specialized regime if the normal method
cannot resolve it safely.

### 3. Decipher the complete scribe corpus

Decode BF and DF once per acquisition in OpenCV. Fit the wafer perimeter and
search a configurable edge-relative radial annulus over the full 360 degrees.
The notch-relative location is a priority only, never an exclusion. Begin with
a generous radial range, record every credible scribe's normalized distance
from the fitted edge, and freeze evidence-based inner and outer bounds with a
safety margin. POST2 is a known nonstandard angular-position cohort but must
not be hard-coded.

After localization, transform only the native-pixel scribe ROI and run the
fixed enhancement bank independently on BF and DF. Preserve every enhancement
that uniquely recovers any product/process appearance. Record localization,
segmentation, enhancement ID, image-first string, alternatives, per-character
scores, BF/DF agreement, SEMI M12 checksum state, source hashes, and crop
transform. Checksum and MES may corroborate image-supported candidates but may
not invent or silently replace characters.

Failure states must distinguish localization failure, segmentation failure,
ambiguous image read, missing glyph-reference coverage, checksum failure,
multiple checksum-valid alternatives, BF/DF disagreement, MES unavailable,
MES identity absent, and MES conflict. Complete the first corpus pass before
pruning enhancements. Remove only demonstrated redundancies, freeze the
reduced bank, rerun the entire corpus, and restore any variant whose removal
causes a lost or less-stable read.

### 4. Combined regression and later work

After backside, frontside, and scribe stages pass independently, use one
deterministic corpus runner to execute all three across the complete bounded
corpus. Write atomic file-backed progress plus terminal `SUMMARY`, `RESULTS`,
`FAILURES`, measurements, hold reasons, and diagnostic-overlay paths. Compare
against frozen Python and OpenCV predecessor outputs as regression evidence;
inspect the actual BF/DF evidence for every mismatch rather than assuming the
predecessor is truth.

Only after notch/pose and scribe identity are complete may OCV-04 fiducial work
resume. Port the useful old Python fiducial methodology into the current
configuration-selected OpenCV design while retaining recent geometric
improvements and all operator-designated-site requirements.

## Autonomous stop-loss

- No heartbeat or recurring automation will be created.
- Use only the existing recorded detector-results route and frozen facts.
- A route failure ends that attempt after one exact report; do not retry,
  create consoles, or debug infrastructure.
- A long run is observed only through atomic file-backed progress; do not
  inspect, stop, restart, or otherwise manage the worker or any existing task
  or process.
- Every iteration must produce real-image detector measurements/overlays or an
  exact blocker. Support scripts, schemas, transport investigations, and
  monitoring loops are not detector progress.
- Inspect actual BF/DF evidence before diagnosing or tuning a failure.
- Human-only ambiguity becomes an explicit hold and does not stop the remaining
  corpus.
- Inspection-held wafers remain dashboard-visible with their exact held reason
  when GUI integration is later performed.

## Preserved authority and holds

Review-only remains true. Training, XML, production routing, provider
activation, protected-processor action, source-image mutation/deletion, wafer
action, existing-task/process action, retry, automatic hold clearance, and
hotspot extrapolation remain unauthorized. Preserve all existing withdrawals,
no-retry/non-parent states, stranded-console/process restrictions, map/pose/
fiducial/registration/coverage/sensitivity prerequisites, BF Slot16 partial
coverage, and every explicit inspection and identity hold.

Exact next action in the fresh task: edit only the bounded OpenCV backside
notch detector/configuration to add channel-local image-derived local holder
exclusion before perimeter/candidate formation and correct the Coherent-DF and
BowComp-BF appearance gaps. Produce real-image results first on the frozen ten
controls, all 22 holds, and new sole-holder/notch-adjacent controls. Do not
begin frontside, scribe, fiducial, full-corpus, infrastructure, publication, or
activation work until this targeted backside gate passes.
