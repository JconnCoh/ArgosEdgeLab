# Front-metal D7 V17 R5P29 near-zero-snow threshold candidate

Candidate status: `DIAGNOSTIC_ONLY`

Reviewer status: `RELEASED_REVIEW_ONLY`

The operator rejected R5P28 because substantial patterned-interior snow and
repeated internal structure-boundary signatures remained. The exact OP4 input
is locked at `work/FM7P26/feedback/OP4/OPERATOR_FEEDBACK.json`, SHA-256
`5DE4BA7543D4296D3CA8FF0C1C4055979B5A723EDF2636EA9411FF0823D12BEB`.
The submitted view does not show the physical wafer perimeter, so earlier
physical edge-die speckling remains real evidence and is not withdrawn.

## Short threshold fallback

The fresh diagnostic at
`work/FM7P26/audit/THRESHOLD_FALLBACK_C3_T240G0` retains only observed source
residual pixels above X24=240 outside the physical-edge band. Physical-edge
protection is pixel-local for independent boundary distance at most 384 pixels;
it never expands through a connected component. No geodesic growth or global
minimum-area filter is used.

- Original residual pixels: 1,192,372.
- Candidate pixels: 187,023; removed pixels: 1,005,349.
- Pixel-local physical-edge pixels retained: 98,001/98,001.
- Non-edge candidate pixels: 89,022.
- T16 candidate pixels: 25,414, including 20,860 local edge pixels and only
  4,554 non-edge pixels.
- Saved false controls with an exact candidate hit: 2/29.
- Saved positive locations retained: 287/288.
- The lost location is the previously measured eight-pixel T22 Residue mark;
  its maximum either-channel response is X24=65.
- Positive-stroke residual-pixel retention is 83.598671%; 184 strokes, including
  98 Scratch strokes, retain less than 80% of their prior drawn shape.

The candidate therefore fails its sensitivity gate. The thinner shape metric
partly reflects thick operator strokes around a narrower residual core, but the
lost T22 mark is an exact detector miss and cannot be waived. No lost or thinned
pixel is Normal truth.

## Canonical reviewer release

The fresh canonical-derived reviewer is released review-only at
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P29_20260818T0930Z`.
Its `BUILD_RESULT.json` SHA-256 is
`D2BBDC3A379E6433EB05076C529D2D392CBF639EFE648405F195A2F0572F593D`.
Magenta is the 187,023-pixel candidate; yellow separately shows the 1,005,349
removed pixels. Imported V16 feedback is hidden by default.

Exact path, wrapper, launcher, canonical UI/control, raster-provenance, and
real-browser gates pass. The rendered gate exercised five full-wafer views,
twelve native evidence layers, five native view modes, both eleven-tile queues,
and T02/T16/T17/T21/T22/T29 with zero browser-console errors. Raster provenance
verified 50 entries, 24 clean bases, 26 current heatmaps, 70 masks, and the
bound rendered audit.

Next action is operator visual review of whether T16/T17 now meet the practical
near-zero-snow requirement while strong/faint defect cores and physical-edge
speckling remain useful. T22 must be inspected explicitly because its eight-pixel
Residue mark is absent from the candidate. R5P29 cannot be promoted while that
sensitivity failure remains. No defect, Normal, training, XML, or production
authority is granted.
