# OCV-03 O3J1 signed JSON collection and Slots16-Slot18 no-tuning diagnosis

Date: 2026-08-27

Disposition: `PENDING_GATE`

Authority: review-only true; training/XML/production false

## Exact publication and terminal response

Request `REQ_20260827T185500111Z_62629419O3J1` was published exactly once
through the persistent `U:` mapping. The publisher ran from clean matching
local/remote commit `9290a536ba170768af0894a4f07902122c6ec59b` after continuity,
metadata-only session safety, recovery, wrapper, harness, zero-recurrence, and
exact Windows PowerShell 5.1 preflight passed. The request ZIP remained
SHA-256
`71E3BA51EF387C91D8F1425CD7703B3F3606B4C6043166E1907069F4A803DF94`.
Publication gate SHA-256 is
`4CB3D072893470744C49E79C160E4452E93CC38DF2DAB909459811F609721828`.
No retry occurred or is authorized.

The single matching terminal response is
`R_7AF93A801F21_20260827192418120_a88bd396`. Response ZIP SHA-256 is
`702932F08C741610CC8E2950E8D7A2CFE963CD16A8E75E831B0BDDFE6A348130`
and byte count is `41491`. The signed manifest correlates the exact request,
reports source role `JBOD` and state `PASS_MAINTENANCE_PATCH`, and verifies
against signer thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.
Collection gate SHA-256 is
`4C277E2F92BC33D61F29BBF41E0E79D3371A8258365522B100DC606C02EB2748`.

## Exact 13 JSON files

The signed endpoint result state is
`PASS_O3J1_EXACT_RESULT_JSON_CAPABILITY`. Exactly 13 bounded UTF-8 JSON files
were reconstituted under `work/O3J1R/files`; every byte count and SHA-256
matches the signed endpoint output. The source-to-return mapping SHA-256 is
`F5A148CC5CDE765A0A86B7046D2665B65389D48BC3775A315B52FFA87393FFA3`.
The files are `SUMMARY.json`, `RUN_GATE.json`, `EXECUTION.json`, and short
returned names `S16.json` through `S25.json` mapped to the ten exact native
result paths. No image bytes or source-image bytes were read by the collector,
no source hashing was performed by the collector, and O3D3R4 was not rerun.

The live provider remained disabled. The protected processor, tasks,
processes, sources, wafers, queues other than the authorized request round
trip, training, XML, production routing, and every hold were untouched.

## Slots16-Slot18 JSON-only diagnosis

Diagnosis gate SHA-256 is
`4FF05A8614171205B5A2C70E772AFE3FB58DE8AE797128BEE87D3C5A3A0804B9`.
It pins frozen R6 engine SHA-256
`90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30`
and frozen O3D3R4 job SHA-256
`F7DB6FE811D58DAA3F410C5AD8E4F063BBD6E961004BDAF1BF2470BB74392717`.

The unchanged manufactured-notch gates are width `0.9..3.2` degrees,
symmetry at least `0.72`, tip offset at most `0.70`, slope consistency at
least `0.55`, and cross-channel overlap at least `0.10`.

- Slot16: BF, DF, and channel comparison qualify. The only paired physical
  candidate has width `0.5` degrees and fails only
  `WIDTH_BELOW_MINIMUM`, by `0.4` degrees. Its detector hold remains.
- Slot17: BF, DF, and channel comparison qualify. Two paired physical
  candidates remain. Candidate 1 has width `3.4` degrees and fails only
  `WIDTH_ABOVE_MAXIMUM`, by `0.2` degrees. Candidate 2 has tip offset
  `0.72413793103448276` and fails only `TIP_OFFSET_ABOVE_MAXIMUM`, by
  `0.024137931034482807`. Loosening both boundaries would admit two distinct
  candidates; no current evidence identifies either as the manufactured
  notch. The detector hold remains.
- Slot18: BF, DF, and channel comparison qualify. Exactly one paired physical
  candidate passes every frozen morphology gate: width `1.1`, symmetry
  `0.96175751125053677`, tip offset `0`, slope consistency `1`, and overlap
  `0.82968384663910366`. Its detector state remains
  `PASS_REVIEW_ONLY_MANUFACTURED_NOTCH_CANDIDATE`.

Slot18 differs from the Slots19-Slot25 selected-angle median by
`6.204958676650719` degrees, but selected angle is not a morphology input and
the detector consumed no known location, angle prior, fixed window, or
regression label. The difference remains post-freeze cohort context, not a
detector failure or rotation authority.

Current evidence supports no threshold change, algorithm change, fresh
hotspot successor, hold clearance, or production action. No frozen POST2
rerun was performed because no successor is authorized. The unchanged frozen
POST2 R6 regression remains mandatory immediately before any future fresh
hotspot successor.

Checkpoint-promotion zero-recurrence preaction SHA-256 is
`EF4C83D3357F57A1DEBB706B570EB9623C44961E57B0CBCCAF9BBF36561BE973`.

## Preserved holds and exact next action

Preserve Slots16-Slot17 morphology holds, Slot18 review-only/no-rotation
state, the OCV-02 four-of-four ambiguity/reference/localization/identity hold,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, Slot25's metadata-disclosed history,
`lot62631586FrontGuiRecovery PENDING_GATE`, every map/pose/fiducial/alignment
prerequisite, O2D14 withdrawn, DFLY3005 excluded, and the uninspected fresh
independent paired BF/DF validation cohort.

Exact next action: do not build or publish a fresh hotspot successor and do
not alter R6 thresholds or code. Obtain independent, non-tuning evidence that
can establish candidate truth for Slots16-Slot17, or hold. If a later
evidence-supported successor is explicitly authorized, rerun the exact frozen
POST2 R6 regression first and require its unchanged terminal pass before any
successor build or hotspot execution. Live provider activation, protected
processor action, training, XML, production, rotation, or hold clearance
remain unauthorized.
