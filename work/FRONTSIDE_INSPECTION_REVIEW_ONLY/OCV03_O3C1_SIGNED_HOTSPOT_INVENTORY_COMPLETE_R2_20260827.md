# OCV-03 O3C1 Signed Hotspot Inventory Complete R2 — 2026-08-27

Disposition: `PENDING_GATE`

This R2 supersedes the provisional pre-audit checkpoint with the same signed
terminal and inventory evidence. The mandatory checkpoint-promotion
zero-recurrence audit passed as
`PASS_ARGOS_ZERO_RECURRENCE_PREACTION`. Its exact contract is
`work/OPENCV_EDGE_NOTCH_O3C1/PREACTION_O3C1_SIGNED_INVENTORY_CHECKPOINT.json`,
SHA-256
`AA04690AE781D03FCFE1D9BD2F2653089FE548D487AADBD47819DB71D09953FB`.

The exact one-shot request `REQ_20260827T141000111Z_62629419C3A1` was
published once through persistent `U:` after clean matching branch tips and all
publisher gates passed. It was not retried. Gateway acceptance was not treated
as execution evidence. Matching response
`R_96293D05BC45_20260827143055769_eb895d3c` returned terminal
`PASS_MAINTENANCE_PATCH` and passed exact request correlation, JBOD source-role,
signed-file, and signer verification. Response ZIP SHA-256 is
`7CFD6195E3BBD0369C1A6468102E27A9654BFE520C8D18680A20B560CAC63C83`;
the exact collection gate SHA-256 is
`8BC123F670CB4154C737CE714086F238916820C11789925F4DB024120299DDCC`.

## Concrete hotspot result

The installed, qualified metadata provider executed successfully against
`PatternedFront/Lot_62629-419_NotchBad_Hotspot`. Inventory disposition is
`COMPLETE`: 131 directories, 40 BMP leaves, and 162 other leaves were observed,
with zero skipped paths, zero access errors, and no truncation. The exact lot
contains one acquisition run, `62629-419_20260824112405`, and ten slots:
Slot16 through Slot25.

Every slot contains exactly four 475,379,874-byte BMP leaves: BF backside, BF
frontside, DF backside, and DF frontside. OCV-03 therefore has ten complete
paired frontside BF/DF members (20 exact source leaves). All 40 canonical BMP
paths require a short alias for I/O; their maximum canonical effective length
is 227, while the qualified `F:` alias maximum is 169. No image bytes were read
and no source hash or pixel outcome was exposed.

The machine assessment is
`work/OPENCV_EDGE_NOTCH_O3C1/O3C1_HOTSPOT_INVENTORY_ASSESSMENT.json`, SHA-256
`8C6BD56577302550F7CEB317F1D79C6A1DC795C1D823B4129764E6541AB277FA`.
It freezes exact physical identities, BF/DF relative paths, alias read paths,
byte counts, and the hotspot development/permanent-regression role for all ten
members. The previously frozen POST2 cohort remains the existing regression
cohort, including the operator-confirmed Slot01 notch-adjacent chipout. Its
cohort SHA-256 is
`4647FC5B7EC146FC4AFBF4DF15CCE9154CA26DB98A67E8483674A3351A915345`.
The separate fresh independent paired BF/DF validation cohort remains pending
and uninspected.

## Existing OCV-03 detector evidence

The unchanged structural OpenCV V1 starting point remains diagnostic-only. On
the frozen POST2 development/regression cohort it qualified each BF and DF
perimeter independently but returned 48, 51, and 56 matched physical
indentation candidates for Slot01, Slot03, and Slot17. All three failed closed
at `FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_PHYSICAL_INDENTATIONS`; it emitted
no rotation, did not average BF/DF pose, and did not select the known Slot01
chipout as the notch. This is concrete failure-isolation evidence, not a
qualified detector.

## Exact next action

Create one bounded review-only O3C2 source-freeze capability for exactly the 20
frontside leaves pinned by the O3C1 assessment. It must read through the
qualified short alias, compute exact SHA-256 and acquisition fingerprints only,
and freeze the hotspot development/permanent-regression partition before any
hotspot image decode or pixel outcome. It must not process backside leaves,
decode images, score pixels, select a notch, emit rotation, mutate sources,
activate the provider, or touch any task/process/wafer/hold. After that freeze,
continue V2 detector development only on frozen development and known-failure
evidence, then run a separately frozen independent paired BF/DF validation
without tuning.

The live provider remains disabled and the protected processor remains
untouched. `SCRIBE_REFERENCE_COVERAGE_HOLD`, the OCV-02 four-of-four
ambiguity/reference/localization/identity hold, Slot25 metadata-disclosed
qualification, `lot62631586FrontGuiRecovery` `PENDING_GATE`, every
map/pose/fiducial/alignment prerequisite, O2D14 withdrawal, and DFLY3005
exclusion remain unchanged. Authority remains review-only, training-ineligible,
XML-ineligible, and production-ineligible.
