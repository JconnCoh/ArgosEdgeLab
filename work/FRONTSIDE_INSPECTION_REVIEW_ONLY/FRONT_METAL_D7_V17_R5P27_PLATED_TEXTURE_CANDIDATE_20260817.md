# Front-metal D7 V17 R5P27 plated-texture candidate checkpoint

Reviewer status: `RELEASED_REVIEW_ONLY`

Candidate status: `DIAGNOSTIC_ONLY_OPERATOR_REVIEW_PENDING`

The operator reviewed the exact signed R5P26 residual and reported that the real defects are displayed very clearly, including the formerly difficult faint feature. The widespread tiny patterned-interior snow is false/noise. The speckled physical edge-die response is real and must remain detectable. The operator's likely explanation is normal bright/dark microspeckle in electroplated metal combined with a slightly too-strict pixel acceptance range; this is preserved as a causal hypothesis, not independently established material identity.

The three exact screenshots and bounded semantic records are preserved under `work/FM7P26/feedback/OP1` and `work/FM7P26/feedback/OP2`. Their markup is qualitative rather than pixel-exact and does not become full-lot negative truth.

## Native component inventory and sweep

The unchanged 1,192,372-pixel R5P26 residual contains 393,673 eight-connected components. T16 alone contains 133,143 residual pixels in 59,101 components. This confirms that the original output is dominated numerically by microspeckle-scale component fragmentation even though the true defect structures remain visible.

The frozen sweep at `work/FM7P26/audit/SNOW_EDGE_D2/SWEEP.json`, SHA-256 `3FE18F4F9EB712BDDA8AC8E7D415A7B25B174E5EEFF2030372025AD18D7463E7`, tested 26 small residual-margin and spatial-support variants. Every candidate retained complete components touching a 384-pixel physical-edge measurement band; this is a sensitivity protection, not an edge suppressor.

The bounded candidate selected for operator review retains a complete current component when either:

- it reaches the protected physical-edge measurement band; or
- at least one BF/DF residual pixel in the component exceeds X24=36, approximately 1.5 DN beyond the existing peer envelope.

This is a component-seeded residual margin, not a global minimum-area filter. It does not trim retained component shapes. It uses no broad radial, perimeter, or edge-die suppression.

## Candidate gate

The exact candidate is `work/FM7P26/audit/SNOW_EDGE_C1`; `AUDIT.json` SHA-256 is `B34C99C249DA2BB713AFBA690A44F64BB9FF5463F972428408481B60D5DB5442`.

- Original residual: 1,192,372 pixels and 393,673 components.
- Candidate residual: 916,669 pixels and 178,634 components.
- Removed weak response: 275,703 pixels.
- T16: 35,289 of 133,143 residual pixels removed; 30,286 of 59,101 components retained.
- Protected edge response: 100,193/100,193 pixels retained.
- Saved V16 positives: 288/288 exact stroke hits retained.
- Positive-stroke residual pixels retained: 99.728941%.
- Positive strokes below 80% pixel retention: 0.
- Only two saved positives fall below 90% pixel retention; both are small Particle strokes, at 84.21% and 89.47%. The faint scratch evidence is not among them.
- Saved false strokes with an exact candidate hit fall from 21/29 in the original residual to 14/29.

These figures authorize visual review only. They do not prove that every removed pixel is Normal, do not make the electroplated-material hypothesis detector truth, and do not grant an automatic defect outcome.

## Canonical reviewer

The fresh canonical-derived reviewer is:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P27_20260817T2200Z`

`BUILD_RESULT.json` SHA-256 is `256A9E05D648AC6C92304652CA9125AF71D46D36910095F15898B40FED88DCFD`.

The magenta layer is the candidate. The yellow comparison contains only the weak response removed from the original R5P26 residual. Candidate and removed layers are separate from clean BF/DF and imported V16 feedback. Imported feedback is hidden by default. The physical scoring scope is unchanged.

Path, wrapper, launcher, canonical source/control, raster provenance, and real-browser gates pass. The browser exercised all five full-wafer views, all twelve native layer controls, both 11-field queues, and six representative 2400-by-2000 native fields with zero console errors. No screenshots or image bytes were emitted into the task.

The released R5P26 reviewer remains unchanged and is the source comparison. R5P27 is review-only, feedback-informed, training-ineligible, XML-ineligible, and production-ineligible. No defect or Normal result is emitted.

Next action: the operator visually compares T16 and the physical edge-die fields in R5P27. Approval must specifically confirm that the interior snow is sufficiently reduced, the real edge-die speckling remains, and the real faint/strong defect structures remain complete enough for inspection. Any later detector change requires a separately frozen successor and a new transfer gate.
