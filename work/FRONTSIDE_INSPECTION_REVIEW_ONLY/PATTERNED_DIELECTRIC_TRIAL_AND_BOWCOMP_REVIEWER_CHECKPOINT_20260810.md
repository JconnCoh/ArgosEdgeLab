# Patterned dielectric trial and BowComp reviewer checkpoint — 2026-08-10

## Authority

- Review-only.
- Training, XML, production, and production routing remain disabled.
- Native lossless BF/DF inputs are scored at `scaleX=1`, `scaleY=1`.
- Frontside scribe and tool hardware are excluded before candidate formation and are never defects.
- Frontside edge/notch/microdamage/bevel decisions remain held unless separately qualified.

## Backside queue audit

The recovered main processor continues to process qualified Bare and BowComp backside jobs. The late-run backside rows that are not route-ready are exact-acquisition scribe confirmation holds; no additional unexplained backside rejection gate was found. Completed backside outputs are preserved and are not to be rerun merely because the portal endpoint is blocked.

## Patterned dielectric trial inventory

The isolated trial contains ten exact, human-confirmed, native BF/DF frontside acquisitions:

- `62628-318` scan `20260810T152358`, Slots 01, 02, 04, 05; family `PDI_V1_1480861_TRENCH_NITRIDE_INSPECT`.
- `62620-548` scan `20260810T154124`, Slots 02, 03, 04; family `PDI_V1_1477419_NITRIDE_DEP3_NO_RESIST`.
- `62626-043` scan `20260810T160500`, Slots 02, 03, 04; family `PDI_V1_1477419_NITRIDE_DEP3_NO_RESIST`.

Trial root on the JBOD:

`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\outputs\review_only\PATTERNED_DIELECTRIC_TRIAL_20260810_V1`

The first revision repeatedly recomputed native notch qualification for the target and all peers. The review-only pose-reuse recovery instead consumes the exact same-acquisition, human-confirmed scribe proposal and its matching native-notch audit. It requires one physical manufactured/pattern-interrupted notch within 0.25 degrees and otherwise emits `FRONTSIDE_NOTCH_ALIGNMENT_HOLD`. It does not select the deepest indentation, use a fixed angle, erase a physical competitor, or create a frontside holder mask.

Signed portal request:

`REQ_20260811T031601494Z_B6B0A39D64F1`

The signed request reached the Gateway processed archive, but no response had
returned as of the latest recovery check because the JBOD endpoint was still
occupied by the preceding diagnostic request. Restart only
`ArgosProjectPortal.JBOD.Endpoint.RO`; detector, scribe, Insite, and monitor
tasks remain untouched. The hash-locked recurrence-prevention package is
`work/PROJECT_PORTAL_REVIEW_ONLY/candidates/PORTAL_ENDPOINT_TIMEOUT_HARDENING_V1`.
It adds a bounded 900-second maintenance-child timeout, preserves redirected
stdout/stderr, terminates only the timed-out child, and refuses any installed
endpoint other than the exact deployed predecessor.

Packaged copy placed on the shared InspectionRevs drive:

`ARGOS_PROJECT_PORTAL_ENDPOINT_TIMEOUT_HARDENING_V1_20260811T035500Z.zip`

Package SHA-256:

`C2C8B75F3D376D03DFD4056FE2418E268C2D7ECD1578F84510B218A09DDA791C`

The endpoint implementation passed the hash-locked maintenance round-trip,
signed-response verification, unapproved-predecessor refusal, and
unchanged-after-refusal regression.

The request reached the Gateway processed queue. At checkpoint time no response had returned because an older diagnostic invocation occupied the JBOD portal endpoint. Restarting only `ArgosProjectPortal.JBOD.Endpoint.RO` is the safe recovery; detector, scribe, Insite, and monitor tasks must not be stopped.

## Proven annotation interaction

Do not build a new frontside feedback interaction. Reuse the BowComp four-action contract:

1. `ADD_MISSED_DEFECT` — miss / underkill.
2. `REMOVE_FALSE_DETECTION` — false / noise / overkill.
3. `RECLASSIFY_REAL_DEFECT` — real evidence with the wrong proposed class.
4. `DISPLAY_ALIGNMENT_ISSUE` — display or registration problem, not detector truth.

Every stroke preserves overview and native coordinates, action, class or nuisance reason, brush width, source view, and optional comment. Feedback remains guidance rather than pixel truth.

Reusable builder:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-BowCompContractAcquisitionReviewerV1.ps1`

Builder SHA-256:

`335594D826A471D8A996742A945DB66D1BA88A79217D4B5DB16347F53A2707AF`

The smoke test passed with all four actions, overview/native coordinate storage, local partial-save support, JSON export, and zero embedded image/data-URL payloads.

## Front-metal review page

The current front-metal page already uses this contract:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_BOWCOMP_CONTRACT_REVIEW_V3_20260810T213900Z/FRONT_METAL_BOWCOMP_CONTRACT_REVIEW.html`

It is the page to show for front-metal feedback. Do not substitute the older bounding-box or residual-only gallery.
