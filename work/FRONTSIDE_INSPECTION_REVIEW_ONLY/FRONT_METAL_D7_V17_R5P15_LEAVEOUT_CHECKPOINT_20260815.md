# Front metal D7 V17 R5P15 S13 L02 leaveout checkpoint

- Revision: `FM7V17R5P15`
- Revision class: `PENDING_GATE`
- Phase: `FRONT_METAL_D7_V17_R5P15_S13_L02_STABLE_COMPOSITE_AUTHORIZED`
- Date: 2026-08-15
- Parent: `FM7V17R5P14C` (`DIAGNOSTIC_ONLY`)

## Result

The operator judged the focused R5P14C S13 L02 panels acceptable and requested a quick sanity check before proceeding. R5P15 removed L02 completely from each of the three bounded 74/78 fits—S25 BF, S20 BF, and S25 DF—and recomputed each local native-pixel rigid line solution from the other five straight edges. It did not tune a threshold, fill a missing sample, or reinterpret the 74/78 fits as autonomous passes.

The leaveout result passes the frozen bounded stability limits:

- maximum local anchor change: `0.0849609375 px` (limit `0.35 px`);
- maximum local theta change: `0.015617091422660795 deg` (limit `0.10 deg`);
- maximum T16/T17 mapped-location change: `0.048211437726551287 px` (limit `0.35 px`);
- alternate S13 global rigid RMS: `0.054021753846824686 px BF` and `0.052492158900544782 px DF`.

Per control/channel mapped changes are `0.048211437726551287 px` T16 BF, `0.032740341043437912 px` T16 DF, `0.039053343653427365 px` T17 BF, and `0.016253239235442616 px` T17 DF.

The operator then directed: `if it looks that good then no need for me to verify, continue to the next step.` The three cases may therefore be retained only as bounded, non-autonomous exceptions for the fresh three-peer target-excluded composite. This does not alter the general line-support gate and does not authorize other peers or sites to use the exception.

## Locked artifacts

- Input: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P15_INPUT.json`, SHA-256 `3C6B12C9DB655CB15D6913E29B36FBFDCDC31C9C32288F17C882FC50819ADC41`.
- Source: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17L02LeaveoutAuditV1.cs`, SHA-256 `4251706A807301C2B052D9DBBA643B5BC91769331DA3328ED7565FFE783C2DBB`.
- Executable: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17L02LeaveoutAuditV1.exe`, SHA-256 `9B17E959FAC075AB6A40C515F33DFFF3EB553A5682F8614B9D793D0DF78DA291`.
- Audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P15/AUDIT.json`, SHA-256 `132596458CD3C68CEE26ADD89F983783E4F5A0442093ADEE7C6B1494F2884402`.
- Comparison sheet: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P15/S13_L02_LEAVEOUT.png`, SHA-256 `C38601548A979765A5BF84E5732AC5EF19BDB5912A246FE1882790CA5355B591`, dimensions `2160 x 2100`.
- Operator input: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FM7V17_R5P14C_OPERATOR_FEEDBACK_20260815.md`, SHA-256 `8F1C027411C4156482E4AE160475A74104818F17E5CE49567CB34652855FEFD0`.

## Next action

Build one fresh review-only three-peer composite using S03, S13, and S18. Keep BF and DF transforms and references independent, exclude the target from its own reference, resample only peer references into the unchanged native target frame, and stop at T16/T17 review sheets. Preserve the exact R5P15 leaveout audit as the authority for the three S13 exceptions.

Do not change source images, detector masks, detector thresholds, classifier/M3, V16, XML eligibility, production routing, deferred stroke 278, the strict chipout sibling, or the separate unevaluated possible Argos stitch fault.
