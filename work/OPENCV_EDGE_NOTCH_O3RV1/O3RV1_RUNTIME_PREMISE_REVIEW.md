# OCV-03 O3RV1 file-backed JBOD runtime-premise review

Date: 2026-08-28

Disposition: `LOCKED_INPUT`

State: `PASS_O3RV1_FILE_BACKED_JBOD_RUNTIME_PREMISE`

## Finding

The JBOD runtime did not change. O3Q2 copied NumPy `2.5.1` from the laptop's
`C:\A3P2R` CPython 3.14 rehearsal into a gate for the different
`D:\AFCV1\rt` CPython 3.13 JBOD runtime. The defective target gate also retained
the local-only state token `PASS_O3P2_LOCAL_RUNTIME_INSTALLED`.

The original qualified portable bundle, the exact FOI1 installer, the signed
FOI1 installation response, and the exact signed O3EI1 observation agree on
the JBOD premise:

- Python `3.13.2`;
- OpenCV `5.0.0`;
- NumPy `2.5.2`;
- Python executable SHA-256
  `7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`;
- installation manifest SHA-256
  `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`.

The executable and installation hashes observed by O3EI1 are exactly the ones
installed by FOI1. This proves a stale cross-runtime contract premise, not an
unreviewed runtime mutation. The correction is remedy `B`: remove the invalid
precondition while preserving installed bytes and every detector/config value.

## Successor boundary

O3Q2 remains withdrawn/no-retry and O3EI1 remains terminal/no-retry. Neither is
an execution parent. The conditional authority already recorded in the O3SO3
checkpoint now has its exact runtime-evidence condition satisfied. At most one
fresh independent Slot16 numeric successor may use the locked BF/DF hashes,
unchanged O3P8 detector/config, and corrected target-runtime premise NumPy
`2.5.2`.

No runtime reinstall, runtime mutation, task or existing-process action,
provider activation, threshold/algorithm change, source mutation/deletion,
backside consumption, hold clearance, XML, training, or production routing is
authorized.

Machine gate:
`work/OPENCV_EDGE_NOTCH_O3RV1/O3RV1_RUNTIME_PREMISE_REVIEW.json`.
