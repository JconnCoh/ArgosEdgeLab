# Frontside Patterned Registration V3.2 Checkpoint — 2026-08-07

## State

`HOLD_JBOD_EIGHT_WAFER_PATTERNED_REGISTRATION_RESULT_PENDING`

This checkpoint is review-only. It creates no defect mask, lot composite,
golden image, training data, XML, or production route.

## Exact context under test

- Product: `1491551/A00`
- Process block: `FIDUCIAL OVERLAY`
- Step: `MEASURE`
- Context authority: confirmed 12-character scribe plus the exact scan-time
  MES history. Recipe-folder names are not authority.
- JBOD inventory: 15 distinct physical wafers are available in this exact
  context. V3.2 freezes at most eight, providing seven independent
  target-excluded peers per target.

Repeated acquisitions of the same physical wafer do not increase the peer
count and are never treated as independent golden contributors.

## Local registration evidence

The bounded local probe used four acquisitions representing two independent
physical wafers in the exact context. Its result is
`work/FSPR1_20260807T0123Z/PATTERNED_REGISTRATION_PROBE_RESULT.json`.

- Same-physical repeated-scan global registration: 4/4 ordered pairs found a
  candidate.
- Cross-physical global registration: 0/8 ordered pairs found a candidate.
- Five-region periodic die-phase registration: 12/12 ordered pairs found a
  consensus candidate.
- Reciprocal closure: 6/6 passed.
- Triangle-cycle closure: 4/4 passed.

Therefore one whole-wafer global translation is not adequate across physical
wafers. Multi-region die-phase evidence is required before a patterned
frontside composite may be considered.

The deterministic repeat in `work/FSPR1_REPEAT_20260807T0142Z` reproduced six
core CSV files and eight pose-normalized display PNG files byte-for-byte.

The unpatterned control in
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/grid_diagnostics/FRONTSIDE_CONTACT_MULTI_REGION_PHASE_V1_20260806T191500Z`
produced only 2/30 candidate ordered pairs, 28 holds, and 0/20 passing cycles.
This supports the diagnostic's ability to distinguish a repeating patterned
surface from an unpatterned one; it is not detector or composite authority.

The local `1491551/A00 | CONTACT PRE FIDUCIAL PATTERN | INSPECT` context has
only two independent acquisitions and remains
`HOLD_INSUFFICIENT_EXACT_CONTEXT_ACQUISITIONS_FOR_PATTERNED_REGISTRATION_PROBE`.

## Physical-boundary, hardware, and scribe contract

- Frontside hardware is behind the wafer. It is never surface-defect evidence
  and must not establish a holder-exclusion mask.
- A future accepted defect mask must be intersected with the per-wafer
  qualified physical wafer boundary before any event is formed.
- Accepted hardware-overlap count must be zero.
- Accepted outside-qualified-wafer count must be zero.
- The scribe is `WAFER_IDENTITY` only. It is never a surface defect, yield
  item, KLA bin, XML bin, or golden contributor.
- Accepted scribe-overlap count must be zero.
- Compact observed surface evidence remains eligible through the physical
  edge. The hard boundary gate must not become a broad inward edge exclusion.
- Any plausible physical edge damage remains held until a separate frontside
  edge-geometry method is qualified.

## V3.2.2 JBOD diagnostic package

Package:
`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_2_2_PATTERNED_FRONTSIDE_REGISTRATION_DIAGNOSTIC_20260807T013500Z.zip`

SHA-256:
`F114995655DA7B8BF833EB5008326489D60BBA0702B36AD5E1D5ABCE10C53FF7`

The package was copied without overwrite to the approved
`InspectionRevs` network handoff folder. The superseded V3.2.1 network zip was
removed after V3.2.2 passed package hashes and the bounded selection test; its
local audit folder remains available.

Package checks:

- 11 manifest-listed files: 0 missing and 0 hash mismatches.
- PowerShell parse errors: 0.
- C# registration and periodic-phase sources compile successfully.
- Packaged bounded selection: 15 available, 8 selected, 8 unique physical
  identities.
- Hardware eligible as defect: false.
- Scribe eligible as defect: false.
- Accepted hardware, scribe, and outside-wafer hard-gate counts: 0.
- Composite created: false.
- XML, training, and production eligibility: false.

## Next gate

Run V3.2.2 on the JBOD and return the small
`PATTERNED_REGISTRATION_DIAGNOSTIC_RESULT.json` plus the bounded CSV evidence.
Only a passing, operator-reviewed eight-wafer registration result can open a
new target-excluded patterned composite diagnostic. Other exact
product/process/step contexts remain isolated and held pending their own
appearance and registration evidence.
