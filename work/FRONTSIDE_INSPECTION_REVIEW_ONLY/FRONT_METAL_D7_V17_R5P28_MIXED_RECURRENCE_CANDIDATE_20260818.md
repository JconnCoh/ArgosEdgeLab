# Front-metal D7 V17 R5P28 mixed-recurrence candidate checkpoint

Candidate status: `DIAGNOSTIC_ONLY`

Reviewer status: `RELEASED_REVIEW_ONLY`

The operator clarified that the nuisance response remaining in R5P27 is not
confined to repeated metal boundaries. It also occurs inside emitters, inside
die rivers, and on null-die structures. The exact qualitative evidence and
limits are locked under `work/FM7P26/feedback/OP3`; `OPERATOR_FEEDBACK.json`
SHA-256 is
`82D0FE0ECF51707AC2DB0D1858BFF87FC36B866DE0A83AA32C02D4C5ED63599D`.

## Bounded feasibility result

T16 contains a strongly measurable image-space lattice. Gradient correlation
is 0.877481 at translation `(121,121)` and 0.800002 at `(94,-94)`. The first
recurrence-only sweep nevertheless showed no material advantage over a uniform
threshold at the same saved-positive gate. The frozen feasibility artifacts
are:

- `DIE_TEXTURE_D1/FEASIBILITY.json`, SHA-256
  `3D4392BAD906CB65268208643F7B012E537C145CD0769987C05D9564E10EFDE1`;
- `DIE_TEXTURE_D2/THRESHOLD_SWEEP.json`, SHA-256
  `45CD674B774FF77026B8A4A18BD92BDDC07CF47DF60FC3CCCF3EA8013582D53B`;
- `DIE_TEXTURE_D3/MIXED_SWEEP.json`, SHA-256
  `148F39AB991574B5B5038D67966FFFE1B114B714E9D9D14420EF5CBEFCFDDABB`.

A uniform X24=144 seed plus eight-pixel geodesic growth reduced the complete
eleven-field residual from 1,192,372 to 417,414 pixels, but it lost one locked
eight-pixel T22 residue stroke. X24=120 still lost that same stroke. Their
audit SHA-256 values are respectively
`59E734D8B40A36EA843423E0DCA091DF0A378F69D85877E065E6175FB7F3ED8A`
and
`5A39AC3279E0CDA9F1624750E18C4CBBFE5E59609CE5F574C7FE725343DD9848`.
Both candidates are stopped and remain diagnostic only.

The scalar signature audit at
`work/FM7P26/audit/WEAK_POSITIVE_D1/AUDIT.json`, SHA-256
`232460DD448B5053844D6E6A24B8096E9C8D8FB7BDF44088A9A86220DA4AC3AC`,
shows why a uniform threshold cannot solve the problem: the locked T22 residue
peaks at only BF X24=40 and DF X24=65, with zero pixels nonzero in both
channels. Raising one global threshold above X24=65 necessarily loses the
complete stroke.

## Mixed sparse/recurrent candidate

The current bounded candidate is
`work/FM7P26/audit/MIXED_RECURRENCE_C1`; `AUDIT.json` SHA-256 is
`A49B895EF79E52A255B1B5276F51639A1B6D0F6090597D0F0E8C584AB10E903A`.
It preserves every complete source-residual component reaching the 384-pixel
physical-edge measurement band. Elsewhere it uses the frozen T16 lattice to
measure equivalent-position residual recurrence. Sparse locations retain the
R5P27 X24=36 seed threshold; recurrent texture locations require X24=240.
Seeds recover at most eight pixels geodesically through the observed signed
residual mask.

- Candidate pixels: 529,374; removed pixels: 662,998.
- T16 candidate pixels: 66,878, down from 97,854 in R5P27.
- Protected physical-edge pixels: 100,193/100,193 retained.
- Saved positives: 288/288 exact stroke hits retained.
- Positive-stroke residual pixels retained: 99.579026%.
- Scratch strokes below 80% retention: 0; minimum Scratch retention is
  87.084871%.
- Three small Particle/Residue strokes fall below the prior 80% shape-retention
  gate; the minimum is 72.222222%. They remain exact hits and are not Normal.
- Saved false strokes with an exact candidate hit: 12/29.

The mixed candidate therefore remains `DIAGNOSTIC_ONLY` and has not passed the
prior shape-retention gate. It emits no defect or Normal outcome and is
training-, XML-, and production-ineligible.

## Canonical reviewer release gate

The fresh canonical-derived reviewer is released review-only at
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7P28_20260818T0900Z`.
Its `BUILD_RESULT.json` SHA-256 is
`BCF1A9D033973532202CE8FA2AA5099B8AF2B3CF59BF2282C1DC72D34C54E465`.
The reviewer preserves the locked clean BF/DF bases, presents the 529,374-pixel
mixed candidate in magenta, and keeps the 662,998 removed-response pixels in a
separate yellow comparison layer. Imported feedback is hidden by default.

The exact path, PowerShell-wrapper, launcher, canonical UI/control, raster
provenance, and real-browser gates pass. The rendered audit exercised all five
full-wafer views, all twelve native evidence layers, all five native view
modes, both eleven-tile queues, and the representative T02, T16, T17, T21,
T22, and T29 fields with zero browser-console errors. The raster release gate
verified 50 entries, 24 clean bases, 26 current heatmaps, 70 current masks, and
the bound rendered audit.

Reviewer release does not promote the candidate and does not replace R5P27 as
inspection authority. Next action is operator comparison of the remaining
die-interior snow, the separately yellow removed response, the faint/strong
defects, the three partially retained small Particle/Residue marks (especially
T22), and the physical edge-die speckling. No defect, Normal, training, XML,
or production authority is granted.
