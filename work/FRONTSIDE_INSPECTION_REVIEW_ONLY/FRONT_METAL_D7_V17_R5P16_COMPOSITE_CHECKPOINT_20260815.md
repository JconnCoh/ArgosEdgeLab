# Front metal D7 V17 R5P16 bounded composite checkpoint

- Revision: `FM7V17R5P16`
- Revision class: `DIAGNOSTIC_ONLY`
- Phase: `FRONT_METAL_D7_V17_R5P16_THREE_PEER_COMPOSITE_OPERATOR_REVIEW_PENDING`
- Date: 2026-08-15
- Parent: `FM7V17R5P15` (`PENDING_GATE`)

## Result

R5P16 built one fresh target-excluded three-peer composite from S03, S13, and S18. BF and DF registration, photometric normalization, and reference medians remain independent. The unchanged native target BF/DF pixels were not resampled; only the three peer references were sampled into the target frame. The target contributes zero pixels to its own reference.

S03 and S18 replayed as strict 4/4-site BF and DF peers. S13 replayed with only the exact R5P15-authorized, non-autonomous S25 BF L02, S20 BF L02, and S25 DF L02 74/78 exceptions. The general line-support gate was not relaxed and no missing sample was filled. All six peer/channel topology correlations remain above `0.9980`.

The class-neutral response uses an absolute target-excluded peer-control calibration rather than a fixed crop percentage. Frozen peer-control thresholds are q99 `1.989703803134564`, q99.5 `2.3049246141746078`, and q99.9 `3.2065915330367876`.

For T16 the q99/q99.5/q99.9 selected counts are `5305 / 3678 / 1342` in a `276 x 283` crop. For T17 they are `11420 / 8126 / 3982` in a `705 x 317` crop. These counts are diagnostic response exposure, not accepted defect pixels or production thresholds. The sheets also retain the former crop-relative top-2% overlay for comparison only.

## Locked artifacts

- Input: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P16_INPUT.json`, SHA-256 `56A5126BB6E45F080C9B607F33D5E5298C1AECD318FD01ED1D160E1259450918`.
- Source: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17BoundedCompositeAuditV1.cs`, SHA-256 `C8F9DB290A7C94EC2E7B08F01B7653A15CEAAFD98991433C696F19AFBE0245D6`.
- Executable: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17BoundedCompositeAuditV1.exe`, SHA-256 `78ADFCB9496C1BA241E37B0555613FF58F8316200BA7DD00D02472CCD614BCB0`.
- Audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P16/AUDIT.json`, SHA-256 `6562256430B54A8B58391A56C8115BF6650BFD218022F9FC4E7B4E4803DD6456`.
- T16 sheet: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P16/T16_COMPOSITE.png`, SHA-256 `DE5ADC596F1B531D529981723BA7550B726CBFD8B354442337FA8DEFD957EF26`, dimensions `2120 x 1308`.
- T17 sheet: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P16/T17_COMPOSITE.png`, SHA-256 `F673D7F15D0C26BC295641754B384AE2D02D883305973199038900280357AED4`, dimensions `2120 x 1308`.

## Review guide

Each sheet shows, left to right and top to bottom:

1. unchanged native BF and DF target crops;
2. independent three-peer BF and DF median references;
3. standard signed BF and DF residuals;
4. display-only low-amplitude signed BF and DF residuals;
5. the class-neutral normalized score and peer dispersion;
6. the former crop-relative top-2% overlay and the absolute peer-control q99 overlay.

Yellow is the operator-declared target box. Magenta is selected response. The preferred comparison is the absolute q99 panel at lower right; the top-2% panel is deliberately retained to expose how a crop-relative rule can overselect normal structure.

## Next action

Pause for operator review of the T16 and T17 sheets. Determine whether T16 retains the full strong scratch while materially reducing normal-edge/null-transition overkill, and whether T17 becomes visible in signed or low-amplitude residuals without treating display enhancement as detector truth. Do not tune from the sheets until the operator responds.

Do not change source images, detector masks, detector thresholds, classifier/M3, V16, XML eligibility, production routing, deferred stroke 278, the strict chipout sibling, or the separate unevaluated possible Argos stitch fault.
