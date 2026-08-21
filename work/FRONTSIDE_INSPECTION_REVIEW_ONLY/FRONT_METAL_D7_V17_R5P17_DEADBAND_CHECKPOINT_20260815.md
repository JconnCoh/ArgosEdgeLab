# Front metal D7 V17 R5P17 residual deadband checkpoint

- Revision: `FM7V17R5P17`
- Revision class: `DIAGNOSTIC_ONLY`
- Phase: `FRONT_METAL_D7_V17_R5P17_DEADBAND_AND_PEER_ENVELOPE_REVIEW_PENDING`
- Date: 2026-08-15
- Parent: `FM7V17R5P16` (`DIAGNOSTIC_ONLY`)

## Operator input

The operator found both T16 and T17 defects extremely visible, questioned the dense red/blue signed-residual speckle despite excellent registration, and proposed that three composites may not encompass the range of normal variation. The operator authorized quick checks first.

## Bounded diagnostic

R5P17 reuses the exact locked R5P16 alignment, photometric normalization, three-peer sources, and target crops. It recomputes no pose and changes no composite or detector. It renders fixed raw signed-residual deadbands at `2`, `4`, and `8` target-gray levels and separately measures where the target lies beyond the minimum/maximum values of all three current aligned peers by the same absolute amount.

The three-peer min/max envelope is diagnostic only. It is not a qualified estimate of full-wafer or production normal variation.

## Result

Outside the operator boxes:

- T16 BF residual exposure falls from `28.45%` at 2 DN to `12.04%` at 4 DN and `1.71%` at 8 DN.
- T16 DF residual exposure falls from `46.00%` at 2 DN to `27.31%` at 4 DN and `10.74%` at 8 DN.
- T17 BF residual exposure falls from `21.81%` at 2 DN to `4.93%` at 4 DN and `0.71%` at 8 DN.
- T17 DF residual exposure falls from `45.46%` at 2 DN to `20.60%` at 4 DN and `4.21%` at 8 DN.

The 4-DN target-outside-current-three-peer-envelope exposure remains `6.63% BF / 14.13% DF` for T16 and `2.41% BF / 9.35% DF` for T17. At 8 DN it falls to `0.50% / 5.17%` for T16 and `0.54% / 2.11%` for T17.

This rules out gross rigid or whole-die misregistration as the main source of the pepper. Much of the BF pepper is low-amplitude display exposure. DF retains substantially more real target-to-peer and peer-envelope variation, so the operator's three-peer coverage concern is supported. This does not yet determine whether the additional DF variation comes from ordinary population variation, illumination/acquisition variation, local edge-profile variation, or the separate unevaluated stitch concern.

## Locked artifacts

- Operator feedback: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FM7V17_R5P16_OPERATOR_FEEDBACK_20260815.md`, SHA-256 `A947D38FF6712BFC5C1B3EB8CC159432F71D47518D146D9A8A25B1EAADCB9717`.
- Input: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P17_INPUT.json`, SHA-256 `CDB294AB8DB1EBE8E3B22F5EC01BFA2074152C0B80D58B89D794D97DB16FC85B`.
- Source: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17ResidualDeadbandAuditV1.cs`, SHA-256 `706F73C61AC8E11897202ED91FFBDB683CE93AECB35B665BFB46279E5D4B9AB6`.
- Executable: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17ResidualDeadbandAuditV1.exe`, SHA-256 `AA1D144C1914AF1BB1ACE4D73F311F8CA87AFDB6F4E51D3976D87EC27F92A815`.
- Audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P17/AUDIT.json`, SHA-256 `200C783558EB9F52161EC23914ACBA6E43FBAACED2DB1060B8761151557A96F1`.
- T16 sheet: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P17/T16_DEADBAND.png`, SHA-256 `BB0DE5F34805EBAC841C1A3A54C17F2813E8FB79757BE6053BCC772FE5B1DA51`, dimensions `2120 x 1308`.
- T17 sheet: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P17/T17_DEADBAND.png`, SHA-256 `2817E9C54E07BF3B1812CA9D86D231CBFB369D7539CD3BD1C4AAC27E85F2A1D5`, dimensions `2120 x 1308`.

## Next action

Pause for operator review of the fixed-scale T16 and T17 sheets. In particular, check whether both defects remain coherent at 4 and 8 DN and whether the final 4-DN envelope panels remove most of the random pepper while preserving the defects.

Do not add peers or change the composite until this quick visual result is reviewed. If additional peers are later authorized, use them to estimate a robust per-pixel normal distribution or bounded quantile envelope; do not assume that merely changing a three-peer median to a larger median is sufficient.

Do not change alignment, source images, masks, detector thresholds, classifier/M3, V16, XML, JBOD, production, stitch state, deferred stroke 278, or the strict chipout sibling.
