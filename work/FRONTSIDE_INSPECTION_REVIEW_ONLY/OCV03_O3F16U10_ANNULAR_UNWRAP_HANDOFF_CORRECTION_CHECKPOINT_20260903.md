# OCV-03 O3F16 U10 annular edge-unwrapping handoff correction checkpoint — 2026-09-03

Disposition: `PENDING_GATE`

The prior rollover handoff was incorrect. It selected the later O3F8 R13 T5
notch/topology checkpoint, while the operator's unfinished stream was O3F16
annular edge unwrapping. The active annular files were present under
`work/O3F8`, but the repository's `/work/*` ignore rule kept those untracked
files out of the rollover commit. T5 evidence remains preserved as separate
diagnostic history, but it is not the active stream and does not authorize the
978-pair frontside corpus.

## Exact preserved detector state

The corrected annular core is
`work/O3F8/AnnularUnwrapDiagnosticOpenCvR1.py`, SHA-256
`6B28925E04839D411838CB3D6C7D39E523AFC3AE89EDBAC83034351D27ED814C`.
It was transferred to JBOD under the installed name
`AnnularUnwrapDiagnosticOpenCvR10.py`. Its thin loader is
`work/O3F8/AnnularUnwrapDiagnosticOpenCvR11.py`, SHA-256
`DE8BD27DC9731AEE4739531F58F18B365FA1423A861DB4B90CD21A68C361C4FE`.
The exact installation record and compact result projection are pinned under
`work/OPENCV_EDGE_UNWRAP_O3F16U10`.

The correction computes adaptive maxima, normalization, and support
eligibility from the same plus-or-minus-12-pixel radial lane the tracker may
select. It also reports rescued columns and explicit angular gap ranges. No
numeric threshold, holder rule, notch selector, smoothing rule, or evidence
eligibility was relaxed.

## Existing real-image evidence

U8 completed the frozen current-recipe four-wafer cohort at native pitch:
Slot16, Slot17, Slot18, and Slot20 from
`PatternedFront/Lot_62629-419_NotchBad_Hotspot/62629-419_20260824112405`.
Its existing `D:/O3F16U8/SUMMARY.json` hash is
`BD2D48C793F1AC8A15FBA80A5CC679A469CB3942B1F0F12F2530293B906CF7DE`;
4/4 cases, 8/8 channels, and 48 review assets were previously hash-verified.
Two BF references had excluded/interpolated arcs of 3,692 and 2,093 native
pixels, requiring visual review rather than automatic acceptance.

The R10/R11 successor then completed the same four cases into the existing
`D:/O3F16U10` result root. It rescued 28-40 BF columns per wafer but did not
erase the large gap sectors. Previously observed gap locations were structured:
cases 2-4 clustered near 90 degrees in both channels, while case 1 spanned
approximately 179-220 degrees in BF with DF centered near 205.8 degrees;
additional DF gaps clustered near 0 and 180 degrees. The U10 summary and review
assets were not copied into the repository before rollover, so those existing
artifacts must be directly recollected and hash-pinned before their visual
interpretation becomes the next detector decision. Do not rerun U10.

Machine-readable handoff gate:
`work/OPENCV_EDGE_UNWRAP_O3F16U10/O3F16U10_HANDOFF_CORRECTION_GATE.json`.

## Next action

Classify the next step as `OBSERVE`. Resume from the existing
`D:/O3F16U10` output. Use the unchanged recorded route once to return and
hash-pin its `SUMMARY.json` and existing narrow annular clean/mask/overlay
assets. Inspect every BF/DF strip for actual straightened edge geometry, enough
radial width to retain chipout evidence, notch and stitch discontinuities, and
rear-holder contamination. Only after this visual gate may detector-only work
continue. Do not return to T5 or authorize the 978 frontside corpus yet.

Scribe remains owned by the separate worktree. Review-only remains true;
training, XML, production, provider activation, source mutation/deletion,
existing task/process action, automatic hold clearance, and retry remain false.
