# OCV-03 O3B10 R15 corpus 436 / hold evidence pinned / running

Date: 2026-08-29
Classification: `PENDING_GATE`
Authority: review-only; no training, XML, production, provider activation,
source mutation/deletion, existing task/process action, protected-processor
action, threshold change, algorithm change, retry, or hold clearance.

## Signed progress

The single R15 backside-only worker remains the only launched worker at
`D:/KLARFExport/_ArgosReview/C15RUN2`. The latest signed read-only observation
used request `REQ_20260829T173909765Z_3911DE86BC69` and matching response
`R_DB6D76B78FC6_20260829173943067_0a17ca23`.

- response ZIP SHA-256: `AC88C9B8ACA7A9FFB90036E4E52EFBAEA3ACF3007FED0DC3649A70FD17D928FD`
- summary SHA-256: `070947227151EA2021C62FB127866A7BFEC215DAF99D67E453B155D39968F340`
- observed pairs: `436` of `943`
- unique BF/DF notch passes: `400`
- explicit holds: `36`
- no-pair holds: `35`
- multiple-pair holds: `1`
- source problems: `0`
- terminal complete field: absent; run remains active

## Actual hold evidence inspected

Representative current holds were pulled through signed read-only DATA_PULL
requests before any detector/configuration change.

- current-hold image evidence response:
  `R_EE0ED153BE02_20260829172632667_8ef85574`, response ZIP SHA-256
  `2C7F0BFE161A97665D24B87C8C2119847F41E59E1B63A379854F2BB480FC51B0`
- exact engine-result response:
  `R_81E2CE497AD6_20260829172906725_f8f4d91a`, response ZIP SHA-256
  `A87FD9605022EE7FD9B1886335FE940521A14E98F22C365B1545F751A6098C03`
- new-family evidence response:
  `R_3D386CAF2BAF_20260829173626990_5041c554`, response ZIP SHA-256
  `F9BC7CE99D0F7D5E2FABB650EE572E37D69FDF878C60DDBCD53EFECCB39769BD`
- 62546 evidence response:
  `R_78666D3AA95F_20260829174126902_73a3a602`, response ZIP SHA-256
  `309552D8C80134682F54C4B4884FE01CEC14361B5F080A0C99D3D4897DACAA77`

The inspected true notch is physically visible and correctly centered by both
channels in each normal case. The measured residual families are:

1. DF width expansion: BF supplies a manufactured 2.3--2.7 degree candidate,
   while the same-angle DF response expands to 6.9--17.9 degrees.
2. DF morphology boundary: same-angle normal-width DF candidates fail by a
   narrow width or symmetry margin, including width 3.3 versus maximum 3.2,
   symmetry 0.712 versus minimum 0.720, and one lower-symmetry 2.5-degree DF
   response.
3. Fixture contamination: one case contains the correct 179.70-degree pair
   plus a second BF/DF pair at an external fixture contact near 224 degrees.
   The detector correctly held ambiguity and did not choose the fixture.
4. The severely damaged 62617-215D negative control remains held.

Pattern suppression remains full-360 outermost dark-exterior boundary in both
channels. No known notch angle or location prior was consumed. No threshold or
algorithm has been changed from these observations.

## Preserved prerequisites and holds

Every prior withdrawal/no-retry/non-parent record remains preserved. The
frontside hotspot issue remains deferred. No Argos rotation/orientation/
location prior is granted. Fiducial designation, alignment transfer, map,
pose, coverage, and sensitivity prerequisites remain ordered before patterned
production scoring. BF Slot16 partial coverage remains explicit. Inspection-
held wafers must later remain visible in the dashboard with their exact held
reason. XML, training, and production routing remain ineligible.

## Exact next action

Continue observing only `C15RUN2/SUMMARY.json` through fresh qualified signed
read-only requests until all `943` rows are terminal. Do not retry or relaunch
R15 and do not touch its owned worker or any existing task/process. At
completion, pull both R14/R15 summaries, failures, and all-row results CSVs;
freeze the exact identity comparison; inspect every remaining residual family;
then design the smallest fixture-suppression and DF-appearance correction with
independent positive and negative regression cases.
