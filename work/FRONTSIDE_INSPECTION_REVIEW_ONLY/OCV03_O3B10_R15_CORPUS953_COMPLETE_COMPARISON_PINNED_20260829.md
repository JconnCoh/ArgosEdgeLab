# OCV-03 O3B10 R15 corpus-953 complete / R14-R15 comparison pinned

Date: 2026-08-29
Disposition: `PENDING_GATE`
Authority: review-only; not training, XML, or production eligible

## Terminal R15 corpus result

The single previously launched R15 backside-only worker completed its frozen
inventory at `D:/KLARFExport/_ArgosReview/C15RUN2`. The launch-time estimate
of 943 was stale; the worker's own frozen inventory and terminal outputs
contain 953 unique BACK BF/DF identities. The signed final pull proves:

- terminal `complete: true`;
- 953/953 result rows;
- 898 `PASS_REVIEW_ONLY_UNIQUE_BACK_BF_DF_NOTCH`;
- 55 explicit holds: 45 no-pair, 9 channel-analysis, and 1 multiple-pair;
- zero source problems;
- summary SHA-256
  `15179E7665FFC5B1E520E6AAC479F86EEC84492A9FB1A723DC9E25CEAE67362C`;
- results CSV SHA-256
  `A578D11DB74F404B97E378AEE7CA22C87D29E0A54B482956DD755728E3004A90`;
- failures JSON SHA-256
  `8ADD26F9CD3C3F50B63071FB5B3A6BD9F53399BCB33882F7783BB0214EE56CA1`.

The exact final comparison pull was request
`REQ_20260829T182353208Z_C55F5771E181`, response
`R_332FE946CE5F_20260829182358179_d35b4f50`, response ZIP SHA-256
`0D5D62EBEBD632629B87F03A9B03725496A1C0CF0FBD383E9E823BB095F9EBF4`.
JBOD endpoint signature and request correlation passed.

## Mechanical R14/R15 comparison

The create-new comparison output is
`work/OPENCV_BACKSIDE_NOTCH_O3B10/comparison_r14_r15_complete_20260829`.
Its inputs are the signed complete R14 and R15 CSVs. The comparison proves:

- R14 rows: 943; R15 rows: 953;
- common identities: 943; R14-only identities: zero;
- R15-only identities: 10, all ten unique-notch passes;
- 801 common identities remained passes;
- 87 R14 holds became R15 passes;
- 53 common identities remained explicit holds;
- exactly two R14 passes regressed under R15;
- zero common holds changed to a different hold class;
- for the 801 common pass/pass rows, median, p90, p95, and p99 angle change
  are exactly zero; maximum change is 0.344281 degrees.

The two regressions are exact and already inspected:

1. `Coherent_W2W/Lot_62627-127/62627-127_20260729061029/Slot18|BACK`:
   R14 passed at 179.778357 degrees; R15 held no-pair. BF remains a valid
   2.4-degree candidate and the same-angle DF response is centered within
   0.067 degrees, but R15's 0.8-degree DF gap fill expands the measured DF
   width to 3.5 degrees, just above the unchanged 3.2-degree manufactured
   limit.
2. `Coherent_W2W/Lot_62627-195/62627-195_20260728145720/Slot20|BACK`:
   the physical BF/DF notch pair remains at 179.7 degrees with 0.001061-degree
   disagreement. A second fixture-contact pair near 224 degrees causes the
   safe multiple-pair hold. Selecting the deepest pair would select the
   fixture and is forbidden.

Comparison artifacts:

- `COMPARISON.json` SHA-256
  `F2B44A1BB76484891B0EA336D7FC280D40FEF7EBECD80224BE48F13920F942D5`;
- `TRANSITIONS.csv` SHA-256
  `4FC161BF8EBAF871D8B11FA41BB3DDCF4A464330192269CD1CFF41347BF59AC2`;
- `R15_HOLDS.csv` SHA-256
  `8467FE780F5F9503445BE80BA22437E24FC2F71111FF7A50FB7AC3B546E2C847`;
- `R15_NEW_IDENTITIES.csv` SHA-256
  `786BE5EBB076FA32083784467E5F00AB95B6EA7EACE8A6F6CEC1351F94DEAABC`;
- generator SHA-256
  `F4F70DA2DEBA82653CA3DA2F315654871DFC66E907EE98B422DE4FDB536C95BD`.

## Residual evidence already inspected

Pattern suppression remains the full-360 outermost dark exterior boundary.
The inspected traces stay on the wafer perimeter; no interior wafer pattern
was selected as the notch edge. The residual families are channel appearance
and fixture-contact discrimination problems, not missing pattern suppression.

- The eight inspected 62624-803 BowComp no-pair wafers all contain a valid DF
  notch at 89.60-90.44 degrees and width 2.4-2.5 degrees. BF either emits no
  thresholded candidate or a 0.5-0.7-degree fragment below its minimum.
- Some of those wafers also contain manufactured-looking DF fixture responses
  near 133.5 degrees. A DF-only best-candidate rule is therefore unsafe.
- Four inspected PatternedFront channel holds contain correct BF/DF notch pairs
  near 90 degrees with 0.011-0.106-degree disagreement; the hold is solely the
  channel trace-fit gate.
- Two inspected ProcessJob11 channel holds have a visible same-angle notch;
  one channel is broadened while the other remains a valid manufactured
  candidate.
- Broad DF responses at the correct BF angle, DF symmetry-boundary misses,
  and the damaged-wafer negative control remain explicit residual families.

No global threshold relaxation, angle prior, hard-coded notch location,
source mutation/deletion, existing task/process action, protected-processor
action, retry, or hold clearance occurred.

## Next action

Pull all 55 terminal R15 `RESULT.json` files in one qualified signed read-only
request and mechanically classify the whole residual set. Then make only the
smallest fresh detector correction that:

1. suppresses fixture-contact candidates using image-local exterior context,
   not a fixed angle or deepest-candidate choice;
2. preserves the R15 split-DF and coverage rescues while preventing filled-gap
   width inflation from vetoing the manufactured core;
3. permits a unique valid channel-local notch to be confirmed by the other
   channel's same-angle boundary evidence when its thresholded candidate is
   absent, too narrow, or appearance-broadened;
4. keeps ambiguous, chipout, damaged-wafer, and true no-notch cases held.

Run the correction first against the frozen regression evidence, then in one
fresh full-corpus successor. Do not modify the completed R14/R15 roots. After
backside closure, resume the broader all-KlarfExport front/back/scribe audit;
fiducial OpenCV work remains later and all prior prerequisites remain ordered.
