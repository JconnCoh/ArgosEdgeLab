# OCV-03 O3F16 U10 operator review supersedes visual pass / R12 draft next — 2026-09-04

Disposition: `PENDING_GATE`

The prior AI-only U10 visual conclusion is superseded. Its signed acquisition
and byte provenance remain valid diagnostic evidence, but its conclusion that
the annular unwrap passed and required no tuning is not reusable. Operator
review identified stitch-like presentation, unstable lines in dark sectors,
and no visible or identified notch. Direct measurement of the returned U10
assets confirms unsupported spans as long as 3,692 columns and cyclic path
jumps as large as 18 radial pixels. U10 is not approved for broader use.

The 2,048-column review-sheet cuts contribute a presentation artifact: the
measured path changes by at most one pixel at those display boundaries. That
does not excuse the separate detector behavior in dark sectors. The existing
path-centered view also cannot prove correct straightening because it centers
the strip on the path being judged.

The operator-provided Argos examples are exact 45-by-5,994-pixel strips. The
processed image is byte-exact OpenCV global min/max normalization of the
unprocessed geometry. It performs no geometric resampling. A V-shaped notch is
visible at columns 3,082 through 3,118, centered near column 3,100. This is a
display and diagnostic reference only; it is not site truth for the four U10
wafers.

Fresh review-only successor draft
`work/O3F8/AnnularUnwrapDiagnosticOpenCvR12.py`, SHA-256
`1696DBE407E4461B351C6B939C591A4E652E558DF15BF4AC5CEFB369950FF7F6`,
is preserved at commit `65f71d73707fac8395ca428bd6b4f18326824399`.
It leaves frozen R10 unchanged, uses global min/max enhancement rather than
CLAHE for the annular tracking/review input, limits the cyclic reference to one
radial pixel per tangential column, removes continuity-adjusted columns from
measured evidence, and emits unsegmented native-width raw/enhanced/full-band
assets. Its full evidence band is 236 radial pixels rather than the narrow
49-row reference core. R12 has passed Python syntax compilation and bounded
reconstruction analysis against the returned U10 strips; it has not executed
on JBOD and is not an approved detector.

Machine decision gate:
`work/OPENCV_EDGE_UNWRAP_O3F16U12/O3F16U10_OPERATOR_REVIEW_SUPERSESSION_GATE.json`,
SHA-256
`E70FF601E348BAA19086CFF3FF163C26BFDB4BB346EE8D51ACC352709CDE571C`.
The checkpoint-supersession preaction passed at
`work/OPENCV_EDGE_UNWRAP_O3F16U12/PREACTION_O3F16U10_OPERATOR_REVIEW_SUPERSESSION_GATE.json`,
SHA-256
`62E982A9D828435ED08732F110C7798E44D7CB6BFF6B619B3EC521F6649521C6`.

## Next action

Finish the exact R12 local detector gate, then use the unchanged recorded route
at most once to transfer that exact draft and execute the same four cases under
a fresh JBOD D: result root. Do not rerun or modify U10. Stop immediately if
the unchanged route fails. Return and inspect every native-width BF/DF raw,
globally enhanced, and full-band overlay. Require numeric 0/360 continuity,
no false measured path through held dark sectors, no review-layer stitch, and
unclipped notch/chipout/holder geometry.

Only after that strip gate passes, rerun the frozen POST2 Slots01/03/17
regression so the known Slot01 large chipout is not selected as the notch. The
operator-requested genuine microchipout lot is the next positive transfer
cohort after POST2 and before any targeted-11 or 978-pair expansion. Current
file-backed records do not contain its exact lot identity, so its exact
operator-named subtree must be frozen before source acquisition.

T5, the targeted 11, full 978, scribe, provider activation, source mutation or
deletion, existing task/process action, automatic hold clearance, training,
XML, and production remain unauthorized. Every existing hold remains.
