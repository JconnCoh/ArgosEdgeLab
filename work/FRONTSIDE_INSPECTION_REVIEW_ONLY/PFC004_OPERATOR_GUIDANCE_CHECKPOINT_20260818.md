# PFC004 operator guidance checkpoint — 2026-08-18

Revision: `PFC004_OP1`

Disposition: `LOCKED_INPUT`

## Operator direction

The operator selected `PFC004` as the first bounded patterned-wafer transfer
candidate:

- Product: `1470174/A00`
- Recipe profile: `VSC331`
- Process: `AVI-0 SCAN / AVI_0_SCAN / INSPECT_AUTO`
- Physical identity: `62619-451-PRE_20260717143452_Slot01`
- Category confirmed: `Patterned Frontmetal`
- Operator interpretation: at scan time this is roughly equivalent to an
  average front-metal plated wafer. This is process guidance, not exact layer
  truth.
- The recent `FM7P30_TRANSFER_BASELINE` detector response is the approved
  unchanged starting point for a fresh review-only PFC004 transfer diagnostic.
- The operator confirms that the originally referenced fiducial is present in
  the marked region.
- The review window is the same as before the requested UI changes. Window/UI
  changes are explicitly deferred to the next revision.

## File-backed evidence

- Feedback JSON:
  `work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP1/OPERATOR_FEEDBACK.json`
- Feedback JSON SHA-256:
  `5907FC8E7DCE282ADEEA2D0CA968520B6CB19EB5D93DABA63110ABCC9412C4D3`
- Evidence copy:
  `work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP1/SOURCE.png`
- Evidence/source SHA-256:
  `BBAD411B235DD2DAC2B9F701016C9490AB432DE7B2D2B0F2700827C855082143`
- Dimensions: 712 by 540 pixels
- Evidence semantics: qualitative marked screenshot only. It is not a native
  coordinate mask, detector truth, or pixel-exact fiducial geometry.

No image bytes were emitted by Codex or loaded through an image-returning
tool. The temporary source and durable copy hash-match exactly.

## Required designation hold

The operator has not yet named the marked fiducial `STRUCTURE_1` or
`STRUCTURE_2`. The record therefore remains
`HOLD_OPERATOR_STRUCTURE_LABEL_PENDING`. The screenshot markup must not be
used to infer that label.

A fresh alignment-transfer diagnostic may begin only after the exact structure
label is supplied. The diagnostic must use the locked native PFC004 BF/DF
sources and the unchanged patterned-wafer registration contract. It may use
R5P30 only as the starting detector-response baseline; R5P30 itself remains
immutable.

## Unresolved prerequisite order

The continuity state contains eleven exact `PENDING_GATE` records:
`latestDiagnostic`, `frontMetalV17Classifier`,
`frontMetalV17NativeMasterEdgeAudit`,
`frontMetalV17FullOrthogonalMasterEdgeAudit`,
`frontMetalV17L02LeaveoutGate`, `frontMetalV17AllWaferCompositePackage`,
`frontMetalV17AllWaferCompositePathAliasRecovery`,
`patternedWaferFiducialCatalogInventory`,
`patternedWaferFiducialNativeCropV1E`,
`patternedWaferFiducialClassifiedSourceIndex`, and
`patternedWaferFiducialPendingDesignationMatrix`.

The active PFC004 sequence is:

1. Confirm whether the marked fiducial is `STRUCTURE_1` or `STRUCTURE_2`.
2. Freeze a PFC004 designation record bound to the exact native BF/DF hashes.
3. Run the fresh PFC004 alignment-transfer diagnostic.
4. Preserve the other 30 category rows, 20 crop-ready designations, one map
   hold, and nine pose holds for later review.
5. Do not begin production-wafer defect scoring unless the applicable
   designation and fresh alignment transfer pass.

No alignment transfer has started. No defect, Normal, training, XML, or
production authority is granted.

## Exact next action

The operator states whether the marked PFC004 fiducial is `STRUCTURE_1` or
`STRUCTURE_2`. Then freeze the exact PFC004 designation and build the fresh
review-only alignment-transfer diagnostic from unchanged locked inputs.
