# PFC004 bin-32 navigation and explicit-corner native-edge review gate

Date: 2026-08-18

Revision: `PFC004_LOT_TRANSFER_TARGETS_V1`

Disposition: `PENDING_GATE`

## Operator bin correction

Operator feedback `PFC004_OP12` is locked at
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP12/OPERATOR_FEEDBACK.json`,
SHA-256
`586FEC3DC3F888C5F8DA72757FCE02C12BF9C3B5F50096125069A6119EAAC361`.
Bin 1 is the general production-die population and has no useful fiducial
meaning. Bins 34 and 36 are broad neighborhood landmarks only. The intended
robust theta structure is sought in a bin-32/null-die neighborhood, but the
complete operator-designated crosshair topology still establishes identity.

The machine-readable bin-32 audit is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_BIN32_CLUSTER_AUDIT_V1/AUDIT.json`,
SHA-256
`92E1EA962242274F8BE54C895F748DCEC1B18BD01ECC65710DA498F7EF365E70`.
The map has 3,587 bin-32 coordinates. Four-neighbor connectivity yields one
3,265-die wafer-edge component, two additional extent-touching singletons,
and 96 internal components: 32 each of size seven, two, and one. These form 32
repeating internal neighborhoods around bin-36/bin-34 pairs.

Twenty-nine notch-projected bin-32 centers and three special neighborhoods
fall inside the locked 3600 by 2600 crop. The exact operator crosshair remains
about 449.883 pixels from the nearest projected bin-32 center, so the map is
not promoted to exact topology binding. It nominates the broad region only.

## Exact corner exclusion

The locked mask is
`work/PATTERNED_FIDUCIAL_INVENTORY/review/PFC004_EDGE_V5_CORNER_MASK_V1/CORNER_MASK.json`,
SHA-256
`B132AAAAA09792F4AF9C2D4ABF9F852194CD9EE8026C607D4BA6D8B1225211E9`.
It binds all 12 unique vertices of the confirmed 12-line inventory, including
the four inner corners and all outer arrow corners. The scorer uses nominal
line endpoints; an endpoint trim is not accepted as corner proof.

For every candidate pose, the complete profile from 2.5 pixels outside to 4.5
pixels inside, including the conservative bilinear interpolation footprint,
must miss every model-space corner mask. A fixed 74-pixel native mask is also
derived from the exact operator nomination. Any sample whose bilinear source
footprint touches one of those pixels is rejected before any pixel value is
read. Masked samples do not become unsupported gaps.

The V5 source is
`work/PATTERNED_FIDUCIAL_INVENTORY/tools/Pfc004EdgesV5.cs`, SHA-256
`A025F0DB4266E339FE0717C36E8F87EC5A38D0CD8644B40D0D5DB21D9C09F5FE`.
The compiled executable SHA-256 is
`A5AD3054A8045D7776D4636BA10474B3A7FF4EF38B8D4315D532947EFC488C95`.
Input `PFC004_EDEV5_MASKED.json` has SHA-256
`60FB5487D03B6415BD3894E4305A124623597AE76BD982F91252BCAA38D38504`.

## Exact native result

The exact run audit is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EDEV5_MASKED/AUDIT.json`,
SHA-256
`C9138B3925F39DBDB62CC6A08D79E52237DD8095C261094B4C57261024683149`.
The unchanged locked BF/DF inputs remain 3600 by 2600 at one source pixel per
scored pixel. Neither channel is rotated or resampled for scoring, and BF/DF
poses are independently fit.

- BF passes 12/12 lines, with 61 masked samples, 75/75 accepted eligible
  samples, minimum support 1.0, maximum gap 0, maximum P90 residual 0.229 px,
  and maximum P90 response width 1.75 px. Its pose is
  `(993.642354,1417.927980,43.70 degrees image)`.
- DF passes 12/12 lines, with 61 masked samples, 74/74 accepted eligible
  samples, minimum support 1.0, maximum gap 0, maximum P90 residual 0.158 px,
  and maximum P90 response width 1.65 px. Its pose is
  `(993.642354,1418.177980,43.90 degrees image)`.

The complete BF and DF searches were independently repeated after replacing
all 74 fixed ignored native pixels with 0 and again with 255. Pose and every
recorded line metric remained byte-identical under both mutations. This is an
ignored-pixel invariance pass, not a same-wafer holdout or alignment pass.

## Three-color review

The exact recovered historical convention is preserved:

- magenta: direct accepted native edge runs;
- green: fitted rigid line solution;
- cyan: prior operator-nominated pose;
- yellow: the enforced inner/outer native corner-ignore pixels.

The file-backed 4X BF/DF review is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EDEV5_MASKED_REVIEW_V1/THREE_COLOR_PAIR_4X.png`,
SHA-256
`E2CA4621BC758B1081757BAF4BADAB77536278AA10EA518CA922D3435D129440`.
Its package audit SHA-256 is
`7C306026ECC34697A64AADA4165F4556FD672095AA906D81296177F1673FFA2F`.
The raster manifest SHA-256 is
`EB00441705FB84DF4B291F91D1E87E139B204ED4B215C57AD66E10B923FDE23F`.
Raster-provenance preflight passes one byte-identical clean display base, one
current three-color display layer, one exact current display mask, and zero
changed pixels outside that mask. No image bytes entered task history.

## OP13 color-order clarification and separated review

Operator feedback `PFC004_OP13` is locked at
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP13/OPERATOR_FEEDBACK.json`,
SHA-256
`0E2CC3F1DFC1AE0F879B85619106F98E453E1FB15E01A73B8D4D686168428784`.
The operator correctly observed that cyan and green exchange apparent
inner/outer order around the structure.

The signed cyan-to-green displacement was measured at every one of the 12
lines along that line's final outward normal. BF spans -0.7211 to +0.7212
native pixel and DF spans -0.5787 to +0.5788 native pixel. Both signs occur in
both channels. Cyan is the operator-nominated pose and green is the searched
pose; their crossing is the expected effect of pose translation and rotation.
Neither color represents inner or outer edge polarity. Magenta remains the
direct accepted native edge evidence.

The combined `PFC004_EDEV5_MASKED_REVIEW_V1` presentation is withdrawn from
current review because its overlaid pose lines can visually imply an
inner/outer edge meaning they do not have. Its rasters and audit remain
preserved and its detector result is unchanged. The first separated package,
`PFC004_EDEV5_SEMANTIC_REVIEW_V2`, is also withdrawn from presentation because
its raster manifest omitted the mandatory `sourceRevisionId`; exact audit
SHA-256
`053D89EEE2195A4958D61BF1FAD6906A7D468EC16756ED7D3B54405D0CFBC23E`.
It was never presented.

The fresh V3 primary edge-evidence review is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EDEV5_SEMANTIC_REVIEW_V3/EDGE_EVIDENCE_PAIR_4X.png`,
SHA-256
`03B5AD9A4D96E367622831F9DA43484340CB5950CA564F638F5EFF61DA67A9C3`.
It contains 1,664 exact magenta pixels and 2,368 exact yellow pixels, with zero
cyan or green pixels. The separate secondary pose-comparison review is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_EDEV5_SEMANTIC_REVIEW_V3/POSE_COMPARISON_PAIR_4X.png`,
SHA-256
`B79CA0B955DEFC72FE65276102CD88F68745E193A045C5E5BA72DFD8E45B0A8E`.
It contains zero magenta pixels and explicitly labels cyan/green as pose-only
diagnostics whose order may reverse.

V3 did not rerun the detector, change detector parameters, or change native
edge evidence. Its audit SHA-256 is
`2A9B5AD332E8C7924D56A1B020CC0A24BACCF171C835F89902F0E6DF1A0427F2`;
its raster-manifest SHA-256 is
`713BC0A5245894970A1058F41FCB377B63ABF71A135BF8279220A0C193378203`.
Raster-provenance preflight passes one byte-identical clean base, two current
display layers, two exact masks, and zero changed pixels outside either mask.

## Gate and next action

The OP13 interpretation and the V3 presentation action above are superseded by
the OP14 correction and frozen-model verification below. Do not present V3 or
any replacement raster from the V5 pose result.

## OP14 correction: the cyan/green swap was a solver defect

Operator feedback `PFC004_OP14` is locked at
`work/PATTERNED_FIDUCIAL_INVENTORY/feedback/PFC004_OP14/OPERATOR_FEEDBACK.json`,
SHA-256
`546FF952FF0592CD844791FC1365010539464F68ECA1210F081BF001B77E802C`.
The operator rejected the prior explanation that the reversing cyan/green
order was harmless pose crossing and required the error to be found and
verified before another judgment image is shown.

The V5 green result is withdrawn as a rigid-pose conclusion. Its candidate
search independently refit an intercept and slope for every line at every
candidate X/Y/theta pose. Those 24 local degrees of freedom absorbed global
pose changes, so the reported global solution was non-identifiable. Six BF and
six DF fitted intercepts also reached the positive two-pixel profile boundary.
After the profile was widened for diagnosis, DF sometimes selected a farther
transition with the opposite signed gradient instead of the intended
near-seed transition. That edge-family switch is the direct cyan/green swap
mechanism. The magenta V5 response remains diagnostic evidence only; it is not
a frozen pose or alignment result. `PFC004_EDEV5_SEMANTIC_REVIEW_V3` is
withdrawn from presentation and was not accepted by the operator.

## Corrected frozen rigid-edge contract

The corrected model freezes channel-local signed polarity and channel-local
line intercept/slope geometry before candidate solving. Signed polarity is
established from the strongest response within 0.5 native pixel of the V5 seed,
not from a brittle exact-seed sample. Development geometry is iterated to a
fixed point three times. Candidate solving has exactly three unknowns:
`GLOBAL_X`, `GLOBAL_Y`, and `GLOBAL_THETA`; it cannot refit any line intercept
or slope. Nominal model length fixes sample count and along-line coordinates,
so transformed floating-point length cannot add or remove a sample.

Every line excludes 2.25 native pixels at both endpoints, and the full profile
plus interpolation footprint must also miss the locked 12-corner mask before a
pixel is read. A one-pixel outside guard and a maximum three-pixel association
distance prevent profile-limit and unrelated-transition acceptance. All V5
detection thresholds remain unchanged except the PFC004 P90 response-width
gate, which moves from 2.0 to 2.25 native pixels because one valid development
BF L11 response is exactly 2.25 pixels wide.

## Sealed V17R2 verification

The authoritative file-backed verification is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_RIGID_EDGE_VERIFY_V17R2/AUDIT.json`,
SHA-256
`9A4539BDE7EE605A4226FFBC43D4FC0EEAEF0473A8E80B26B23B7C580E20BD96`.
Its sealed source, input, and executable are:

- `work/PATTERNED_FIDUCIAL_INVENTORY/tools/Pfc004RigidEdgeVerifyV17R2.cs`,
  SHA-256
  `28207A5F967F1413A1FDC8EC01498D435E8C125F01A17EEFF3DB2CAAA81EB3E9`;
- `work/PATTERNED_FIDUCIAL_INVENTORY/inputs/PFC004_RIGID_EDGE_VERIFY_V17R2.json`,
  SHA-256
  `335108B9B23C2B1C09B6C0ABD36F2E06BCDF30B8D789CF033FA40120F69006C0`;
- `work/PATTERNED_FIDUCIAL_INVENTORY/bin/Pfc004RigidEdgeVerifyV17R2.exe`,
  SHA-256
  `7EFBC8CC616C05581CC29A62913EEE7DEA639CA388538654DC2D347809A80415`.

The unchanged 3600 by 2600 AVI-0 PFC004 crop passes 12/12 BF and 12/12 DF
lines. Both channels have minimum support 1.0 and zero unsupported gaps. BF
maximum width is 2.10 pixels with rigid RMS 0.1341 pixel; DF maximum width is
1.85 pixels with rigid RMS 0.1863 pixel. All accepted BF and DF development
responses match their frozen signed polarity: violation count is zero in both
channels. Both alternating-sample cross-validations pass.

All five common-nominal-pose perturbation starts return to the channel-local
fixed points within the unchanged gates. Maximum center return error is 0.0239
pixel BF and 0.0323 pixel DF; maximum angle return error is 0.0528 degree BF
and 0.1498 degree DF. One of 200 correlation nominations is the development
fiducial. None is a separate complete instance. Three high-correlation
repeating-die lookalikes at approximately `(1963,435)`, `(2045,2464)`, and
`(3018,1480)` are correctly rejected because their frozen rigid line evidence
is incomplete. No threshold was loosened and no line was dropped to make them
pass.

The preserved V17R1 verifier audit is a failed diagnostic because its harness
incorrectly applied perturbation deltas to each channel-local return reference
instead of the common nominal development pose. All of its line, polarity,
support, width, residual, and cross-validation checks passed; no detector
threshold was changed for V17R2.

## Frozen different-process transfer diagnostic

The same frozen PFC004 model was transferred without calibration or tuning to
the paired PFC005 nitride crop. The sealed replay audit is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_FROZEN_TRANSFER_V18R1/AUDIT.json`,
SHA-256
`328667B1462A0A3C02A45DCD47663BF58F6D1D49E7B88220DDFD30CAA7A3FC4D`.
Its source, input, and executable SHA-256 values are respectively
`416BCCECFAAD5B4708801C1DC9A2334BAF3A771CCF34C1BE3AAB245D0762AF29`,
`B50BFF2F0F692ACEBB613A93A068074EC8AA03D3BE4392253E2219C4484C883C`,
and
`8F5F780C3450D555FB81FF85D4EB012BA5E5980EEE87E8E18755AFA4126CE82C`.
All four candidate correlations and pass/fail outcomes exactly repeat the
first diagnostic run. There is no complete transferred instance and no target
tuning. This is broad process-layer non-transfer, not a polarity-swap failure,
and it is not PFC004 validation truth.

## Current gate and ordered next action

`PFC004_RIGID_EDGE_VERIFY_V17R2` is `PENDING_GATE`. The specific swap error is
determined and the corrected model passes internal same-crop verification, but
the locked inventory contains only one complete AVI-0 PFC004 fiducial crop.
The next required evidence is a different native paired BF/DF AVI-0 PFC004
wafer or crop containing a complete operator-designated crosshair. Apply the
sealed model without tuning; only a complete BF/DF rigid pass may support a
new operator judgment raster. Repeating dies and the different-process PFC005
diagnostic cannot fill this gate.

Until that independent same-process positive passes, do not present another
cyan/green/magenta judgment raster, begin alignment transfer, fan out to
production wafers, or score defects. The current PFC004 gate plus the 11
pre-existing top-level `PENDING_GATE` objects, the other 30 category rows, 20
other crop-ready designations, one map hold, and nine pose holds remain in
order. R5P30 remains immutable. No template, alignment, defect, Normal,
training, XML, production, package, routing, or automatic-reject authority is
created.

## Same-lot source correction and available transfer targets

The statement that another PFC004 wafer or crop must first be obtained is
withdrawn. It incorrectly treated the prepared V1E gallery as the full raw
source inventory. The locked JBOD catalog contains eight distinct paired
frontside BF/DF wafers from lot `62619-451-PRE` at the same 2026-07-17
14:34:52 P-metal acquisition: Slots 01, 02, 04, 06, 07, 08, 09, and 10.
Slot01 is the development parent; the other seven are available frozen-model
transfer targets. Slot04 is 14413 by 10997 pixels; the other seven are 14411
by 10995. Each paired BF/DF header was cataloged stable. Their raw files remain
on JBOD `D:/KLARFExport` and are not mounted on the laptop.

The metadata-only lot audit is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_LOT_CANDIDATE_AUDIT_V1/AUDIT.json`,
SHA-256
`EC97634DCB92D845F6C516D81D0B1634E0E5709AF16554E41BF91B9402F3EA14`.
It is bound to `ALL_WAFER_CATALOG.json`, SHA-256
`AC689B5C60DDD467061FCE1A88603C44772A0BBCC709FBC8D357639DA295D715`.
The catalog also contains a later 2026-07-23 wet-strip acquisition of the same
eight slots; that later process state cannot substitute for the seven
same-stage transfer targets.

The corrected next action is to use the rehearsed JBOD route to notch-align,
crop, and hash Slots 02, 04, 06, 07, 08, 09, and 10 at native resolution, then
apply the sealed V17R2 model without tuning. Per-wafer dimensions must be
preserved rather than assuming one fixed size. A fresh judgment raster remains
prohibited until the frozen model passes independent same-stage BF/DF evidence.
All earlier production, alignment, training, XML, routing, and R5P30 holds
remain unchanged.

## Reusable fiducial-model workflow and PFC004 conformance seal

The reusable method is now locked in
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.md` and its machine-readable companion
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.json`, SHA-256 values
`E128BD58E6901D40DEC04B6DA55451B27F7EFC062B138C2940138145CA22C63F`
and
`C256838A8C9A8B8086D9AC2D77253FDFB6B750C3C0938EFB8B894A3B35600023`.
It requires, in order: provenance and evidence partition; operator topology
designation when a geometry is not already bound; native channel-local
automatic calibration of every required straight line with the complete
corner footprint excluded; model freeze; internal invariance and lookalike
tests; independent no-tuning BF/DF validation; and only then a judgment raster
and fresh alignment transfer. Geometry topology may be reused when the shape
is unchanged, but color/composition-dependent response polarity, widths, and
thresholds belong to a declared appearance regime and must be calibrated and
validated there.

The locked run template is
`work/templates/ARGOS_FIDUCIAL_MODEL_RUN.template.json`, SHA-256
`D8AEBC1CE2EAB0F06C32FEC46B28A7C8FBF91F45A2555C5471C25A008AEB6636`.
`AGENTS.md` makes the workflow mandatory. Its prohibited-method list preserves
the failed approaches from this study, including unproven XML-bin transport,
per-candidate line refits, far-transition edge switching, endpoint-only corner
trimming, transformed-length sample counts, BF/DF averaging, target tuning,
and treating a prepared gallery as the full lot inventory.

The final workflow-bound PFC004 internal verifier is
`PFC004_RIGID_EDGE_VERIFY_V17R5`. Its audit is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_RIGID_EDGE_VERIFY_V17R5/AUDIT.json`,
SHA-256
`B87D3880D97943A98699F02B82AA46EAB6BD42C8F28AEEF2AF9AB35EBE2978EC`.
Line-order invariance, all 12 one-line leave-outs in both channels, nominal
sample-cardinality invariance, ignored-corner mutation invariance, both
alternating-sample checks, all five common-nominal perturbations, frozen
polarity, and lookalike rejection pass. The one-line leave-out gate is measured
as maximum displacement of the complete frozen native line model, not as raw
theta alone. Its fixed bound is one 0.25-pixel profile sample; the maximum
observed BF and DF displacements are 0.068990 and 0.078931 pixel.

The earlier V17R3 raw-angle-only leave-out run is preserved as failed
diagnostic evidence. V17R4 proves the corrected geometry-space gate but binds
the predecessor workflow hash. V17R5 repeats the complete test against the
final workflow hash. No frozen line, polarity, response threshold, or native
input changed in those conformance revisions.

The instantiated model record is
`work/PATTERNED_FIDUCIAL_INVENTORY/models/PFC004_V17R2/FIDUCIAL_MODEL_RUN.json`,
SHA-256
`D838E681861A1D4FFA432DC88B0A0BC9C47A3282707E72F01BACDC2648F5DBFA`.
Its state is `PENDING_INDEPENDENT_FROZEN_VALIDATION`. The ordered next action
remains the native JBOD notch-align, crop, hash, and unchanged frozen-model run
on Slots 02, 04, 06, 07, 08, 09, and 10. No judgment raster, alignment
authority, defect scoring, training, XML, production routing, or automatic
reject is authorized before that independent gate passes. R5P30 remains
immutable.
