# Front-metal D7 V17 R5P23 signed-JBOD all-wafer result checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P23_RESULT`  
Parent: `FM7V17R5P23A`  
Disposition: `DIAGNOSTIC_ONLY`

The alias-corrected signed JBOD request completed with endpoint state
`PASS_MAINTENANCE_PATCH` and exact inspection state
`PASS_FM7P23_ALL_12_TARGETS_PROCESSED_WITH_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`.
The signed data pull completed with `PASS_DATA_PULL`, and the exact returned
output was copied create-new with all hashes matching to:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P23_20260816T012800Z`

Run integrity:

- 24/24 lossless native BF/DF sources verified at 14411 by 10995 and 1:1
  scored scale;
- 12/12 wafer targets processed and zero skipped;
- exactly 11 references per target and 132/132 target-reference rows;
- the target wafer is absent from every one of its own reference sets;
- 132/132 channel-paired photometric peer rows are eligible;
- all 12 target states are
  `PASS_TARGET_EXCLUDED_COMPOSITE_WITH_EXPLICIT_LOCAL_COVERAGE_HOLDS`;
- 24/24 T16/T17 target control composites, 12/12 coverage sheets, one
  all-wafer summary, one compact contribution-mask audit, the exact runtime
  invocation, and the path-alias audit were returned;
- 41 returned files, 15,925,152 bytes, all signed-response and create-new
  copy hashes verified;
- audit SHA-256:
  `566C5AEAE3C2E3FC1AC6C8381D1AB7B42C433D343B291188829659CDD6DC55C7`;
- return-gate:
  `work/FM7P23/result/FM7P23_20260816T012800Z/RETURN_GATE.json`, SHA-256
  `688EBFD71036AEF4D77CE69AF6F84C15BA1C208948DB5DF77CE7FB3F924F9629`.

Alignment and composite interpretation:

The unchanged R5P21 independent BF and DF transforms and exact R5P22
alignment-stability authority are retained for every wafer. No transform was
recomputed or adjusted, no site was selected or dropped by residual rank, no
sequential worst-site removal or five-edge fallback occurred, and target
native pixels were not resampled before scoring. The run therefore establishes
that the all-wafer target-excluded composite path works for all twelve wafers
without a skip or wafer-level alignment hold in this exposed review-only lot.

All twelve targets still contain explicit local coverage holds. These are not
alignment failures and do not prevent composite formation. Global ambiguity
is held locally under
`LOCAL_COVERAGE_HOLD_NOT_PEER_SPECIFIC_MISMATCH`; it is not charged against
each peer. BF globally ambiguous interior cells range from 476 to 635 per
target and DF from 412 to 498. Control-window coverage holds remain visible
and are never Normal truth. The result is consequently not a claim of complete
normal coverage or autonomous defect sensitivity.

The JBOD execution-path alias is independently documented. The canonical
source remained
`D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2`, the temporary
alias was `R:\`, the same first 1,048,576 bytes of the locked source hashed to
`F579FF46031B30B07FA17BD6A2129A258313D6D5C52F0A1B23DC899C57BC0E95`
through both paths, and `imageContentChanged=false`. The runtime invocation
and `PATH_ALIAS.json` were preserved with the result; the temporary invocation
and `subst` mapping were removed in `finally`.

The initial signed request remains `WITHDRAWN`. It failed before source
hashing or output creation at the mandatory short-alias path gate and produced
no inspection evidence. It was not edited, replayed, or republished.

The all-wafer result emits no defect mask or automatic defect outcome. It
remains exposed-data, review-only, training-ineligible for new alignment
authority, XML-ineligible, and production-ineligible. Later independent-lot
evidence remains required before transfer authority. No M3, V16, canonical
reviewer, detector threshold, strict-chipout sibling, deferred stroke, stitch,
XML, or production route changed.

The next bounded action is operator review of the returned file-backed summary,
T16/T17 controls, and coverage sheets. Any detector integration must preserve
the explicit coverage holds and await the separately required gates; the
composite result alone cannot emit Reject or Normal outcomes.
