# R18N published once; operator stop blocked by JBOD access token

Classification: `PENDING_GATE`

## Publication state

`REQ_R18N1` was published exactly once at `2026-09-04T12:59:51Z` from the
frozen 150135-byte ZIP with SHA-256
`198F365EF1B21739A9D6D7E67628F45751641ECE17112C01CE9A3F586431BEE4`.
The share importer moved the exact same bytes to `requests\processed`.
This proves share acceptance only. No matching signed terminal response has
yet appeared in `U:\ProjectPortalRO\responses`, and there is no retry authority.

The local publication gate is
`work/OPENCV_SCRIBE_R18N/R18N_PUBLISH_GATE.json`, SHA-256
`5696ED8317627214E999DCCF839B844B9C3C844A05058DE2B50F95F8F5CCD75F`.

## Direct launch evidence

After the operator reported visible result population, the exact JBOD route
returned `D:\A2\o\ocv\R18N1\LAUNCH.json`. It proves:

- computer `A1025645101`;
- state `PASS_R18J_CORPUS_WORKER_STARTED`;
- owned PID `32132`, start UTC `2026-09-04T12:59:45.3495262Z`;
- work root `D:\A2\w\ocv\R18N1`;
- output root `D:\A2\o\ocv\R18N1`;
- runner SHA-256
  `E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069`;
- review-only true, identity acceptance false, and source mutation false.

## Operator result observations and failure lead

The operator reported:

- `EED6B66B52679FAF`: crop correct;
- `333AFA446849C72F`: crop incorrect;
- `AF1ABF1870CF145E`: result not yet populated.

The frozen R18J crop sweep contains a generic hard-coded bounded search:
angles `-6/0/+6` degrees, normal offsets `0/+150/+300` pixels, a `2000x800`
window, at most eight discovered regions, and only two promoted regions. The
one-sided normal-offset sweep and top-two structure-based promotion are a
credible localization-failure mechanism. This is diagnostic only. No reader,
crop, worker, or reference byte was changed.

## Stop request and exact blocker

The operator ordered the run stopped. A first command-line-bound stop found no
match because the current token could not see the Python command line. The
subsequent exact `LAUNCH.json` observation bound PID `32132` to R18N. One
hostname-gated stop of that exact PID then failed terminally with:

`Cannot stop process "python (32132)" because of the following error: Access is denied`

No unrelated process or task was touched. Do not retry this direct-control
command. On JBOD `A1025645101`, an operator with an elevated token must stop
only PID `32132` (for example, elevated Task Manager or
`Stop-Process -Id 32132 -Force`). After the operator reports completion, one
read-only PID-presence verification is allowed. Do not analyze or change crop
code, publish another request, or touch unrelated processes while this hold is
open.

Machine evidence:
`work/OPENCV_SCRIBE_R18N/R18N_PUBLISHED_STOP_BLOCKED_GATE_20260904.json`.
