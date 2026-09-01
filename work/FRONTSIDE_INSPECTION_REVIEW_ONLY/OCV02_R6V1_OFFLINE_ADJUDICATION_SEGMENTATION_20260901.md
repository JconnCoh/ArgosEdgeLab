# OCV02 R6V1 offline adjudication and segmentation milestone

State: `DIAGNOSTIC_ONLY`

The frozen R6V1 request, endpoint, engine, batch, jobs, and signed ZIP were not changed or published. This milestone adds only an offline post-response adjudicator, its injected-failure test evidence, and diagnostic analysis of the already frozen fifteen-control scribe set.

## Frozen live revision

- Request: `REQ_20260901T160000111Z_7F77B8EFE092`
- ZIP SHA-256: `E4F62D6126F9FBEDD228CDDE8678136D7FDEFCF5CB2B3825BF1245E11BBF925D`
- Endpoint SHA-256: `F805E8336FF0A1847D0326ED8A77FFC39207128E8C69177559D0F6BE9E888A25`
- Batch SHA-256: `7F77B8EFE0926E4AD37A737F07C98E1A3DF2E8F1392D0B47B886E05F9F52143B`
- Published: `false`

## Post-response adjudication

The provider-local adjudicator verifies the exact four-case set, package/job hashes, result/output hashes, BF/DF source hashes and canonical paths, execution-to-batch-gate binding, localization geometry and duplicate-collapse counts, incomplete reference coverage, required holds, and `identityEligible = 0` authority.

The offline gate passed five cases: one exact valid four-case fixture plus injected identity widening, BF source-hash mismatch, duplicate geometry, and missing coverage-hold failures. Every injected failure returned a hold and no identity authority.

## Frozen fifteen-control segmentation evidence

- Exact R6 proposal: `15/15`
- Top-character correctness: `169/180`
- Truth in reported bounded candidates: `180/180`
- Duplicate physical-wafer agreement: `4/4`
- Minimum top-versus-runner-up margin: `0.004932`
- Median top-versus-runner-up margin: `0.387941`

The bounded OpenCV cell-expansion runner is prepared for `0, 2, 4, 6, 8, 12` pixels. It has not been executed because no pinned local OpenCV/NumPy runtime is present and the bundled dependency locator did not return in two bounded attempts. No runtime was installed, no threshold or expansion was selected, and no live revision was created.

## Holds and next action

All reference-coverage, automatic-localization, identity-confirmation, upstream notch, XML, training, production, and activation holds remain unchanged. Scribe publication remains serialized behind the exact matching signed R25NA1 terminal. After explicit lane clear, perform the current route/share-health observation, publish the frozen request exactly once, collect its signed terminal, and run the adjudicator on the four real-image results. No retry is authorized.
