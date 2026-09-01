# OCV-03 O3B21 R25NA1 partial 17 / missing 7 resume checkpoint — 2026-09-01

Disposition: `PENDING_GATE`

Fresh exact-host, nonce-bound, non-truncated metadata observation proves the
timed-out R25NA1 output root exists with 17 complete job/result pairs at
ordinals `00` through `16`, zero partial pairs, and seven wholly absent pairs at
ordinals `17` through `23`. No image bytes were read and no target state was
changed. The earlier combined-path and verbose-truncated observations are
withdrawn and cannot support absence inference.

The signed 900-second timeout is therefore a bounded runtime exhaustion, not
evidence of scribe-path contention. Preserve the 17 completed outputs. The
minimal successor may reuse the unchanged frozen R25/R13 detector, 24-case
ordering, source hashes, and eligibility rule; verify the 17 completed results,
execute only missing ordinals `17` through `23`, and aggregate all results
without post-result selector relaxation. It must use a fresh namespace, remain
review-only, and leave the original output root unchanged except for explicitly
authorized create-new successor evidence.

R25NA1 is not yet a selector pass. O23 remains independently held. Fresh 953,
frontside, scribe, combined outputs, fiducial/alignment, training, XML, and
production remain unauthorized until their recorded prerequisites pass.

Observation gate:
`work/O3B21/R25NA1_POSTFAIL_OBS4_RESULT_GATE.json`, SHA-256
`CF3441EDBDE76DF7C40B1B1FF54828F1D9CC89C5D3064A36C57436C37A6BFD71`.
