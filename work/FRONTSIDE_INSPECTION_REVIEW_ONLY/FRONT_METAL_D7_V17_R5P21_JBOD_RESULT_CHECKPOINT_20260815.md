# Front-metal D7 V17 R5P21 returned expanded-alignment checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P21_JBOD_RESULT`  
Parent: `FM7V17R5P21`  
Disposition: `DIAGNOSTIC_ONLY`

## Returned artifact and integrity

Returned root:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P21_20260816T004657Z`

- `EXPANDED_ALIGNMENT.json`: 147916 bytes, SHA-256
  `CE1D926D1CA1A36DB8C854998D1D82A649C80914A9204D9EAF5F5ED96753C829`;
- `EXPANDED_ALIGNMENT_SUMMARY.png`: 38162 bytes, SHA-256
  `9B37F663D18443EB1AF735BB35FE83CFF6D44422E5862C512D73F21CB9F69546`;
- `TARGET_FIDUCIAL_GRID.png`: 32942 bytes, SHA-256
  `695436D628BE855928C234474F29689860428620F16DE0B6D977D3ECE75D3765`.

All 24 BF/DF source rows match the frozen package contract by slot, channel,
byte length, SHA-256, `14411 x 10995` dimensions, and 1:1 scale. Authority,
expanded-requirement, invocation, and returned-sheet hashes verify. No source,
mask, detector, T16/T17, reviewer, XML, or production mutation occurred.

## Expanded-search result

Slot02 qualified 23/28 new BF+DF candidates. The target-first deterministic
selection retained 12 additional sites plus the four locked originals, across
all four wafer quadrants. No peer outcome entered target selection.

R5P21's exact predeclared disposition is
`HOLD_FM7P21_EXPANDED_ALIGNMENT_SOME_WAFERS_UNQUALIFIED`: 7/11 peer poses pass
and S14, S16, S21, and S24 are held. S23, which was held by the previous
four-field engine, now passes 14 BF and 15 DF consensus sites across all four
quadrants.

The four remaining holds are:

| Wafer | BF | DF | Exact R5P21 hold |
| --- | --- | --- | --- |
| S14 | 16/16 sites, RMS 0.419049 px, max 1.276397 px, LOO 0.177052 px | 16/16, RMS 0.423630 px, max 1.267220 px, LOO 0.183954 px | post-refit maximum local residual |
| S16 | 16/16, RMS 0.559348 px, max 1.303556 px, LOO 0.116305 px | 16/16, RMS 0.561882 px, max 1.254838 px, LOO 0.110623 px | post-refit maximum local residual |
| S21 | 12/16, RMS 0.516198 px, max 0.740101 px, LOO 0.153953 px | 11/16, RMS 0.531718 px, max 0.830551 px, LOO 0.216807 px | DF fraction 68.75%, one site below the discrete 70% rule |
| S24 | 16/16, RMS 0.580040 px, max 1.248523 px, LOO 0.139597 px | 16/16, RMS 0.581209 px, max 1.252264 px, LOO 0.141302 px | DF post-refit maximum local residual by 0.002264 px |

Every failed local site on S20/S21/S23 retained strong identity and
`posePass=true`; the failures are line-support metrics at scattered sites,
not absent identities or failed pose solves.

## Stability diagnosis

The file-backed assessment is
`work/FM7P21/result/R5P21_RETURN_STABILITY_ASSESSMENT.json`, 22875 bytes,
SHA-256
`A1816ADD8B23DF4959057F1C53E277532DD23951C1EB843E29C416435F471522`.

Across all eleven peers and both independent channels:

- minimum consensus sites: 11;
- minimum consensus quadrants: 4;
- maximum rigid RMS: 0.696163854483 px;
- maximum leave-one-site whole-wafer/control mapping change:
  0.238931238378 px;
- maximum BF/DF whole-wafer mapping disagreement: 0.272432859978 px.

All eleven wafers therefore pass the already predeclared minimum-count,
spatial-distribution, rigid-RMS, and leave-one mapping-stability limits, plus
a conservative 0.35 px independent-channel whole-wafer agreement diagnostic.
The result does not support damaged/missing fiducials or an unstable global
pose on S14, S16, S21, or S24.

Three hold conditions expose a gate-semantics problem. A candidate pair first
classified all 16 sites inside the 1.25 px consensus band; the one final rigid
refit then moved one local residual slightly above 1.25 px, and R5P21 held the
entire wafer instead of distinguishing local field residual from global pose
stability. S21 exposes the discrete 70% fraction rule: 11 geographically
distributed, independently stable DF sites fail at 68.75% even though the
separate minimum-count, quadrant, RMS, and leave-one gates all pass.

This checkpoint records that diagnosis but does not silently override the
frozen R5P21 disposition. No sequential worst-site removal or five-edge
fallback was performed.

## Next bounded correction

Predeclare an R5P22 review-only alignment-stability gate that preserves target
selection, native site qualification, independent BF/DF solves, direct
consensus, minimum six sites, minimum three quadrants, maximum 1.25 px rigid
RMS, and maximum 0.35 px leave-one mapping change. Add maximum 0.35 px BF/DF
whole-wafer mapping agreement as a validation gate. Treat consensus fraction
and final-refit maximum single-site residual as local evidence diagnostics,
not independent wafer-level pose holds once all retained global stability
gates pass. Do not change the local site detector or choose/drop sites by
final residual rank. Because this correction is informed by the returned
wafer set, a later independent lot remains required for transfer authority.
