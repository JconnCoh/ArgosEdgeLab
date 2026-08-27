# OCV-03 O3D1 POST2 Diagnostic / Hotspot Operator Route Blocker — 2026-08-27

Disposition: `PENDING_GATE`

## Concrete OCV-03 development result

The frozen local review-only O3D1 job ran the unchanged structural OpenCV V1
starting point on three exact POST2 paired BF/DF sources: the operator-confirmed
Slot01 notch-adjacent chipout challenge and ordinary parity controls Slot03 and
Slot17. Cohort SHA-256 is
`4647FC5B7EC146FC4AFBF4DF15CCE9154CA26DB98A67E8483674A3351A915345`;
job SHA-256 is
`6FA813AD02848C5A5EAC3114A0F9EDC6DFE7103DAF5A963B014D37B3DB291FA3`;
and run preaction SHA-256 is
`C63B482B4F8142A7680E03C8B71563D5FB42E63F7CA44C59B14D34E9ADC5B164`.

All three independent BF and DF perimeter fits qualified, with full reported
inlier and angular-coverage fractions. Every pair failed closed at
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_PHYSICAL_INDENTATIONS`. Matched
physical candidate counts were 48 for Slot01, 51 for Slot03, and 56 for
Slot17. No manufactured-notch authority was granted, BF/DF transforms were not
averaged, and no rotation was emitted. The Slot01 chipout was preserved as a
physical competitor and was not selected as the notch.

The exact result gate is
`work/OPENCV_EDGE_NOTCH_O3D1/O3D1_POST2_V1_RESULT_GATE.json`, SHA-256
`702E124815ABDFCB3037D18D917E8312D7902F7214AD1A0049A82DD31C5FAFFE`.
Its state is
`HOLD_O3D1_STRUCTURAL_STARTING_POINT_REAL_WAFER_NOT_QUALIFIED`.
The unchanged synthetic parameters are therefore not qualified for real-wafer
notch selection. No tuning was performed and no independent-validation source
was exposed.

## Exact hotspot blocker

`Lot_62629-419_NotchBad_Hotspot` is not present in the frozen local catalog or
workspace source staging, so its exact source paths must be inventoried on the
JBOD before hashing or pixel processing. Current observation policy forbids
installing a maintenance helper for this metadata-only step. The existing
qualified STATUS and DATA_PULL handlers cannot enumerate an unknown exact
subtree, so the already authorized direct admin/read-only route was selected.

The read-only transport inventory observed one matching RustDesk forward from
local port 15985 to Argos `10.20.70.241:5985`, owned by PID 32736 created
`2026-08-25T15:37:33.7925110-05:00`. One hostname-gated `Probe` was attempted.
It returned no nonce or hostname result before the bounded timeout. JBOD
identity was not verified, no retry was made, and zero exact probe processes
remained afterward. The exact blocker is
`work/OPENCV_EDGE_NOTCH_O3D1/O3I1_HOTSPOT_INVENTORY_OPERATOR_ROUTE_BLOCKER.json`,
SHA-256
`8FC78087B49F59CC282387ABF925F1154C41888ECE4FF7AB84AB619636870AD4`.

Operator action required: expose the existing RustDesk connection titled
`10.66.81.84` in verified 1920x1200 full-screen mode with the existing nested
RDP session already showing JBOD `A1025645101`, then report that the JBOD layer
is visible. Do not open a new session, change window geometry through
automation, or accept a paste dialog. After that external state change, run one
fresh hostname gate and, only if it returns `A1025645101`, execute the bounded
in-memory metadata-only inventory for exact subtree
`PatternedFront/Lot_62629-419_NotchBad_Hotspot`. Do not retry the timed-out
probe or publish a portal maintenance request as an observation workaround.

The live provider remains disabled and the protected processor remains
untouched. No source, task, process, queue, ledger, wafer, XML, training,
production, identity, or hold mutation occurred. The OCV-02 four-of-four
ambiguity/reference/localization/identity hold, Slot25 metadata-disclosed
qualification, `lot62631586FrontGuiRecovery` `PENDING_GATE`, every
map/pose/fiducial/alignment prerequisite, O2D14 withdrawal, and DFLY3005
exclusion remain unchanged.
