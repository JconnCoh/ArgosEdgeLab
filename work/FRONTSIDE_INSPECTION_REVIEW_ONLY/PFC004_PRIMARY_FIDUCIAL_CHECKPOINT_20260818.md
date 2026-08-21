# PFC004 primary robust fiducial checkpoint — 2026-08-18

Revision: `PFC004_OP2`

Disposition: `LOCKED_INPUT`

## Semantic designation

The operator designates the marked PFC004 topology as:

`PRIMARY_ROBUST_OPERATOR_FIDUCIAL`

The operator personally uses this structure as the primary fiducial and
considers it the most robust. The operator does not remember the legacy
1/2/3/4 numbering. `STRUCTURE_1` is only a guess and is explicitly not
authority.

The locked PFCP1E contract and generator record only that structures 1 and 2
were candidate model structures and 3 and 4 were line-array controls. They do
not bind a number to the operator-marked topology. The legacy numeric mapping
is therefore `UNRESOLVED_NON_AUTHORITATIVE` and must not be reconstructed from
memory or inferred from the screenshot.

This does not block semantic template construction. The approved patterned-
wafer registration contract requires one specific nonrepeating fiducial by its
full local topology; it does not require an arbitrary numeric label.

## Locked feedback

- Feedback:
  `work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP2/OPERATOR_FEEDBACK.json`
- Feedback SHA-256:
  `C4DE8F971C47906EDBFEBBCB3A5B346BA0FF7A1B13DCA4BE0C50BDD6A26546E6`
- Parent feedback SHA-256:
  `5907FC8E7DCE282ADEEA2D0CA968520B6CB19EB5D93DABA63110ABCC9412C4D3`
- Evidence SHA-256:
  `BBAD411B235DD2DAC2B9F701016C9490AB432DE7B2D2B0F2700827C855082143`
- Registration contract:
  `PATTERNED_WAFER_REGISTRATION_BP_V1`
- Registration contract SHA-256:
  `E32FAF9F0EC7735C2DE668C1B49E2E52597F69B77E54CA26FA774596898936DF`

## Exact PFC004 native binding

- Physical identity: `62619-451-PRE_20260717143452_Slot01`
- Native source dimensions: 14411 by 10995
- Crop rectangle: x=6092, y=4655, width=3600, height=2600
- BF source SHA-256:
  `8F1EE0BD3A4F5850D2F4DDA3424CD4C566A08CEE2F1A115D95B1A5441AE00861`
- DF source SHA-256:
  `72638854F889407D009A324761803D1D9216ADE666DC0738F467E5FD0BDEDB95`
- BF crop SHA-256:
  `4EBBD4FB322F3EF55414C92C5CB1A4741D6319648C7E167BF4D69486D230638D`
- DF crop SHA-256:
  `7F4785B389212B64B2A7EF5A1262A73430895071FC747EDDC2C930CFE663C831`

The operator screenshot is qualitative display evidence. It does not provide
a proven native-coordinate transform, so no native box or pixel mask is
inferred from it. Template construction must recover and verify the designated
full local topology directly in the locked native BF and DF sources.

## Active sequence

1. Build a bounded, file-backed PFC004 topology/template diagnostic from the
   exact native BF/DF hashes above.
2. Identify the smallest local model that uniquely represents the operator's
   primary robust topology. Curves/circles may be identity-only; pose weight
   requires sustained straight boundaries in both orthogonal directions.
3. Test the identity at distributed PFC004 sites to reject whole-die/PM phase
   aliases and preserve BF/DF-independent pose.
4. Only after that gate passes, run the fresh PFC004 alignment transfer with
   `FM7P30_TRANSFER_BASELINE` as the unchanged detector starting point.
5. Preserve the other 30 category rows, 20 crop-ready designations, one map
   hold, and nine pose holds for later review.

The continuity state retains eleven prior `PENDING_GATE` records. No
alignment transfer or production-wafer defect scoring has started. R5P30 is
immutable. No automatic defect, Normal, training, XML, or production authority
is granted.

## Exact next action

Build the fresh bounded PFC004 primary-topology/template diagnostic from the
locked native BF/DF crops. Do not require or invent a legacy numeric label.
