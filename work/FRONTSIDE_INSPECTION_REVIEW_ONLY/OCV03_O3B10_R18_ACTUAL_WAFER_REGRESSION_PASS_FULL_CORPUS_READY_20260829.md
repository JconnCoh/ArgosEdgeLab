# OCV-03 O3B10 R18 actual-wafer regression pass / full corpus ready

Date: 2026-08-29

Disposition: `PENDING_GATE`

## Result

R18 completed one signed ten-wafer review-only regression with nine unique
backside notch results and one deliberate damaged-wafer hold. The full-360
OpenCV perimeter implementation remains the frozen R15/R17 implementation;
R18 changes only image-local cross-channel confirmation and fixture-contact
suppression.

- Detector: `work/OPENCV_BACKSIDE_NOTCH_O3B10/Detect-BacksideNotchOpenCvR18.py`
  - SHA-256: `DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A`
- Configuration: `work/OPENCV_BACKSIDE_NOTCH_O3B10/BACKSIDE_NOTCH_CONFIG_R6.json`
  - SHA-256: `ACBD63E620349DD83A417F4DC29DCEDDC07765036D49D57DDB305F2C637BF2A0`
- Frozen R17 parent: `B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713`
- Frozen R15 perimeter base: `F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C`

## Signed R18 evidence

- Request: `REQ_20260829T192952433Z_F8139A1A0FC0`
- Response: `R_45A9294DF335_20260829193553114_7d55a44b`
- Response ZIP SHA-256: `4EB44AA51CF01DF5901F595654B77847994E4E1BAD6231DD0C1C55B94B4E63D1`
- Response manifest SHA-256: `2952EB7B231C5B67575BC1B2B213AEAE68D27D078C9543E61262636FCC34DB0C`
- Endpoint state: `PASS_MAINTENANCE_PATCH`
- Data state: `PASS_O3B10_R18_ACTUAL_WAFER_REGRESSION_EXECUTED`
- Existing Argos task/process action: false
- Source mutation/deletion: false

## Actual-wafer outcomes

| Case | Result | Angle | Confirmation |
|---|---:|---:|---|
| 62627-193 Slot01 chipout control | unique | 89.993 | strict BF+DF |
| 62607-215 Slot25 BowComp control | unique | 89.722 | strict BF+DF |
| 62627-127 Slot17 split control | unique | 179.700 | strict BF+DF |
| 62631-544 Slot06 coverage control | unique | 90.182 | strict BF+DF |
| 62627-127 Slot18 width regression | unique | 180.171 | strict BF / confirmed DF |
| 62627-195 Slot20 fixture ambiguity | unique | 179.701 | false 224-degree fixture pair suppressed |
| 62628-233 Slot20 05:27 broad channel | unique | 179.574 | strict BF / broad zero-exterior DF |
| 62628-233 Slot20 06:32 broad channel | unique | 178.088 | strict BF / broad zero-exterior DF |
| 62624-803 Slot02 patterned BowComp | unique | 89.652 | strict DF / confirmed BF |
| ProcessJob11 Slot19 damaged negative | hold, zero pairs | n/a | no defensible manufactured notch |

Returned BF/DF review images were visually inspected. The cyan trace follows
the physical perimeter. On the fixture case the green selected marker is on the
real left-edge notch while the upper-left chuck contact remains diagnostic-only.
Both broad-channel markers sit on the visible left-edge indentation. The
damaged wafer has no green selection.

## R16 terminal evidence retained

R16 is withdrawn and non-reusable. Its signed response
`R_89E795A5297A_20260829191311799_be2f0904` proved the fixture target had been
incorrectly asserted as a pre-proven control, causing diagnostic evidence to be
discarded. The prevention is recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. R17 used fresh roots and returned
all target metrics; R18 was derived only from that actual evidence.

## Preserved authority and holds

Review-only remains true. Training, XML, production routing, hold clearance,
source mutation/deletion, managed task/process action, and protected processor
action remain false. Frontside POST2 notch evidence remains independently
qualified and unchanged. The hotspot frontside issue remains backburnered and
is not generalized into this backside detector.

## Next action

Launch one fresh review-only full backside corpus successor with the exact R18
detector/configuration, unchanged corpus runner and unchanged source catalog.
Write only to a fresh JBOD `D:` output root, monitor its file-backed progress,
then mechanically compare every identity against the terminal R15 corpus.
Inspect every regression and every remaining hold before any further detector
change. Do not alter completed R14/R15 roots or touch an existing Argos task or
process.
