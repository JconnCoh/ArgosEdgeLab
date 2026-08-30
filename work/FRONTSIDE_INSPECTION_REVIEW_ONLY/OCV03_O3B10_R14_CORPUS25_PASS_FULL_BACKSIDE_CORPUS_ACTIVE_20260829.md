# OCV-03 O3B10 R14 corpus-25 pass / full backside corpus active

Date: 2026-08-29

Disposition: `PENDING_GATE`

Authority remains review-only. Training, XML, production routing, source
mutation/deletion, existing task/process action, wafer action, and hold
clearance remain prohibited.

## Detector correction

R11 processed the first 25 exact backside BF/DF pairs with 24 unique-notch
passes and one explicit hold: lot `62625-956`, Slot22. Exact full-resolution
R13 diagnostics proved that both channels traced the physical wafer perimeter
and independently found the bottom notch:

- BF manufactured candidate: `89.500000` degrees;
- DF manufactured candidate: `89.4647248867` degrees;
- BF/DF mismatch: `0.0352751133` degrees;
- no other BF manufactured candidate had a qualifying DF match.

The BF raw circle RMS failure (`10.9390146133` px versus `4.0` px) was caused
by broad low-frequency wafer/camera shape while the traced boundary continued
to hug the physical wafer edge. DF fit RMS passed (`1.3913981399` px) and its
coverage was `61/72 = 0.8472222222`; the configured `0.85` boundary therefore
failed only because of 72-bin quantization.

R14 SHA-256 is
`E8627409BC4134AFD653603DDE1795861ACEF46C8ED240F69CACBAD90A14F10D`.
It changes backside trace qualification only:

- BF retains frozen inlier and angular-coverage requirements;
- BF uses the already-present local high-pass suppression for broad
  low-frequency shape instead of using raw circle RMS as a veto;
- coverage comparison receives exactly half of one 72-bin interval as
  quantization tolerance;
- manufactured-notch morphology, full-360 search, no notch prior, and unique
  BF/DF pairing remain unchanged.

## Four-pair regression

Signed request `REQ_20260829T151207900Z_536BD983F102` returned signed response
`R_369186312E0F_20260829151337292_db598a3b`, ZIP SHA-256
`E2942F966DA3E602104DA34C5997956401CA187C471A5EC6C7568D2984F09CD1`.

All four exact pairs returned one unique BF/DF notch:

| Case | Mean angle (deg) | BF/DF mismatch (deg) |
| --- | ---: | ---: |
| 62627-193 Slot01 chipout control | 89.993118473 | 0.013763054 |
| 62607-215 Slot25 | 89.721707658 | 0.043415317 |
| 62625-956 Slot17 | 89.760453267 | 0.079093467 |
| 62625-956 Slot22 | 89.482362443 | 0.035275113 |

The six R14 BF/DF review JPEGs for the three predecessor controls are
byte-for-byte identical to R11. Visual inspection of Slot22 R14 BF and DF
confirmed that the green P1 marker is centered on the physical bottom notch;
fixture responses remain red diagnostics.

## Twenty-five-pair regression

R14 corpus request `REQ_20260829T151948982Z_9A82EE35CACE` returned signed
launch response `R_AC1EC62812E9_20260829151854933_fad1b0ee`, ZIP SHA-256
`79A9CC70BBC422E3C9E84E1C36825DBF7C9491DA7A00DB7921708214AE561A5C`.
Output root was create-new `D:/KLARFExport/_ArgosReview/C14RUN1`.

The signed complete summary response
`R_09698EDE9329_20260829152340480_5c56e43b`, ZIP SHA-256
`E71AF11C45939A674B05E1664B55E25DEEAA3E95BD289FA6C1C8F67F269590A7`,
proved:

- pair count: 25;
- unique BF/DF notch passes: 25;
- source problems: 0;
- failures/holds: 0;
- complete: true.

Signed before/after result-table response
`R_5C16D09B2C69_20260829152544230_3170176e`, ZIP SHA-256
`B71A048DE943383626DAB03922047528E9D027FCD40B0B62D31EA891B9955EBF`,
proved 24 rows unchanged. Slot22 was the only changed row: generic channel hold
to unique BF/DF notch pass at `89.4823624433` degrees. R11 results CSV SHA-256
is `0CDED01481A5BEA6623BCA82DB205178607D57854CE62329652756289B601F84`;
R14 results CSV SHA-256 is
`A9AE18277CF92A35BACDEDE9BCA41970C51A4F4661E4146FFDAFDF6C2CEACB50`.

## Full backside corpus active

Full backside-only request `REQ_20260829T153027001Z_0C74C60A95A2` returned
signed launch response `R_C240BACC6B25_20260829152931471_d74658b4`, ZIP
SHA-256 `39CBD850B4EA6251F968E403106D870449E74C96E19AE826E9A14EF1ECB52C76`.

The create-new R14 worker is PID `36328`, creation time
`2026-08-29T15:29:28.3951014Z`, output root
`D:/KLARFExport/_ArgosReview/C15RUN1`, expected pair count `943`. It did not
touch an existing process or mutate a source image.

The first signed atomic summary response
`R_5C43E79C131C_20260829153143440_bf4e5c2a`, ZIP SHA-256
`940542605303C5DF479FCDEF3C4C7349B4915F9E617BB52B8A54F9256BF902C9`,
proved 22 processed pairs, 22 unique-notch passes, zero holds/failures, and zero
source problems. The full run remains active and incomplete.

## Holds and next action

Every pre-existing continuity hold remains in force, including all withdrawn
or no-retry/non-parent records, the protected processor, any stranded console
or process, frontside hotspot deferral, Post2/frontside evidence boundaries,
fiducial designation/alignment prerequisites, and backside/full-corpus review
authority limits. No prior hold is cleared by this checkpoint.

Next action: continue bounded signed file-backed observation of
`_ArgosReview/C15RUN1/SUMMARY.json`. On completion, inspect every failure or
hold from its exact result and overlays before any detector change. If all 943
pass, freeze the full R14 result set and proceed to the remaining frontside
scribe/notch corpus failures without altering the backside detector.
