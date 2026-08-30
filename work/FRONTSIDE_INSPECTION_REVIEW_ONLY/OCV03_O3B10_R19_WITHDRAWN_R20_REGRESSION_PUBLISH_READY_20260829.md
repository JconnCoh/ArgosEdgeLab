# OCV-03 O3B10 R19 withdrawn / R20 actual-wafer regression publish ready — 2026-08-29

Disposition: `PENDING_GATE`

R19 request `REQ_20260829T214436049Z_119F998247B5` received matching signed
terminal failure response `R_F48FFCBF7678_20260829214643684_e7636c9c` before
the detector ran. Mechanical comparison proves the package-local R19 case
manifest was malformed: one DF SHA-256 was truncated to 55 characters and the
two broad-channel paths were changed to unrelated `LotIDStringNotSet` leaves.
R19 is `WITHDRAWN`, no-retry, and a non-parent. The failure performed no image
decode, source mutation, existing task/process action, or detector execution.

Recovery observation
`work/OPENCV_BACKSIDE_NOTCH_O3B10/R19_PACKAGE_CONTRACT_OBSERVATION.json`
classifies this as a signed artifact-contract failure rather than a live-state
premise failure. Remedy B is mechanically bounded: R20 consumes the exact
successful frozen R18 ten-case manifest byte-for-byte and derives only fresh
output roots. Every BF/DF hash is required to be exactly 64 uppercase hex
characters before image access.

Fresh R20 detector/config drafts apply the already evidence-frozen,
position-independent paired exterior fixture-contact suppression. They contain
no lot, product, wafer, slot, angle, notch-position, hotspot, pattern, or
chipout exception. Python syntax, PowerShell harness safety, clone-literal
remediation, recovery intent, and zero-recurrence preaction all pass. R20 is
ready for one no-retry signed ten-wafer actual-image regression using the
unchanged chipout, damage, split-channel, broad-channel, patterned, and BowComp
controls. Require the matching signed terminal response and visually inspect
the returned BF/DF overlays before any full-corpus successor.

Authority and holds remain unchanged: review-only; training, XML, and
production ineligible; no source mutation/deletion; no existing task/process
action; protected processor untouched; no threshold or algorithm change after
this frozen R20 draft; no retry; no hold clearance; no stranded-console or
process action; backside is not consumed; all earlier O3 and fiducial
prerequisites remain in their recorded order.
