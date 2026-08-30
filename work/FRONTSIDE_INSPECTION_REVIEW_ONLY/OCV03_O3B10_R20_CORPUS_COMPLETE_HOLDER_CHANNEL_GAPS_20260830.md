# OCV-03 O3B10 R20 corpus complete / holder and channel gaps — 2026-08-30

Disposition: `PENDING_GATE`

R20 completed the exact 953-pair backside corpus at
`D:/KLARFExport/_ArgosReview/C15RUN4`: 931 review-only unique-pair passes,
21 not-found holds, one DF channel-analysis hold, and zero source problems.
The terminal table identities, states, and shared-pass angles still compare
mechanically with no regressions against frozen R18 and R15.

That comparison proves only that R20 did not lose predecessor passes. It does
not prove that every R20 pass is the physical notch, that a sole paired holder
cannot pass, or that the remaining holds are irreducible. The earlier
`OCV03_O3B10_R20_CORPUS953_931_PASS_22_HOLD_BASELINE` conclusion therefore is
superseded and withdrawn as an activation/publication parent. Its signed
terminal corpus evidence remains valid regression evidence.

## Exact hold analysis

The 22 saved `RESULT.json` records and all 44 BF/DF review rasters were
re-inspected from the file-backed terminal evidence.

- All 13 Coherent not-found holds contain one morphology-eligible BF candidate
  at the same angle as same-acquisition pass peers. DF contains a candidate
  within 0.14 to 1.47 degrees of that angle but rejects its morphology.
- All six BowComp not-found holds contain a morphology-eligible DF candidate
  within 0.01 to 0.69 degrees of same-acquisition pass peers. BF forms no
  eligible candidate; its nearest raw response is 20.10 to 25.60 degrees away.
- ProcessJob11 Slot19 has no eligible candidate in either channel, although DF
  has a raw response 1.51 degrees from its same-acquisition peer median.
- Break Resist Slot25 has one BF and two DF eligible candidates but no unique
  pair. It has no same-acquisition pass peer, so its cause remains unassigned
  pending image-first local diagnosis.
- ProcessJob11 Slot25 is the sole channel-analysis hold; DF radial
  qualification fails before pairing.

This is primarily a channel-local notch appearance/profile-formation gap, not
evidence that the physical notch is absent.

## Holder suppression gap

The operator's reminder about the earlier image-recognized holder exclusion is
directly applicable. Across the 21 not-found rows, the detector creates 117 BF
and 160 DF raw candidates. The same visible holder contacts recur near the
same image-relative positions; BF alone has 20 responses in the 225-degree
bin, 18 near 70, 18 near 295, 17 near 135, and 16 near 5 degrees.

R20 does not build a holder mask before perimeter fitting or candidate
formation. It classifies exterior fixture evidence only after BF/DF pairing,
and lines 62-65 of `Detect-BacksideNotchOpenCvR20.py` suppress a fixture-like
pair only when more than one paired candidate exists and a non-fixture
alternative remains. A sole paired holder-like candidate can therefore pass.
The ten-case R20 regression includes a holder beside a real notch, but no
sole-holder negative control, so that risk was not tested.

The qualified prior `BuildBowCompLocalHolderMask` mechanism in
`work/BARE_SURFACE_INSPECTION_REVIEW/src/NativePhysicalEligibilityReview.cs`
provides the correct design principle: recognize the exterior-connected
holder body from the image, qualify its local component, and exclude only its
local overlap before candidate formation. The OpenCV successor must port that
principle without fixed holder angles, lot/slot knowledge, or a known notch
position.

## Required bounded successor

One fresh local OpenCV detector revision may:

1. derive channel-local visible-holder masks from exterior-connected hardware
   bodies and exclude only their local wafer-overlap spans before perimeter
   fitting and candidate formation;
2. distinguish a holder from a notch by requiring a qualified hardware body
   that continues outward from the wafer, so an indentation beside empty dark
   exterior is never masked;
3. keep BF and DF enhancement/morphology channel-local and correct the
   Coherent-DF and BowComp-BF appearance gaps without consuming lot, slot,
   expected angle, Argos pose, or another channel's pixel values; and
4. emit the holder mask, excluded spans, raw/retained candidates, and explicit
   hold reason for regression diagnosis.

Validation order is the frozen ten-case R20 control, all 22 current holds,
new sole-holder and notch-adjacent-to-holder controls, then the full 953-pair
corpus. Every state change and every angle outlier must be visually inspected
before any baseline, promotion, or activation claim.

Machine analysis:
`work/OPENCV_BACKSIDE_NOTCH_O3B10/R20_HOLDER_CHANNEL_GAP_ANALYSIS_20260830.json`,
SHA-256 `555A7785F1ECDFDEF7156E657A4FC64F75ACC7F519B5B9051CD96C8C388F824F`.
Checkpoint pre-action contract:
`work/OPENCV_BACKSIDE_NOTCH_O3B10/PREACTION_O3B10_R20_HOLDER_CHANNEL_GAP_CHECKPOINT.json`,
SHA-256 `5C8C6302EC01A8E36A1A46FA34A7E60A95C468114D06020E2E9CD98417DA7A28`;
the exact zero-recurrence preflight passed.

No image, detector, configuration, source, task, process, provider, queue,
hold, XML, training, or production state was changed. The hotspot remains
parked. All previous withdrawals, no-retry restrictions, and authority holds
remain unchanged.
