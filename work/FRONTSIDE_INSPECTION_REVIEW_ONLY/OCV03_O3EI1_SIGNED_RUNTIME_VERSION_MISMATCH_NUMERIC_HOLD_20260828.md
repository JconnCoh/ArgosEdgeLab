# OCV-03 O3EI1 signed runtime-version mismatch — numeric hold

Date: 2026-08-28

Disposition: `PENDING_GATE`

Active phase: `OCV03_O3EI1_SIGNED_RUNTIME_VERSION_MISMATCH_NUMERIC_HOLD`

## Terminal outcome

The one authorized O3EI1 request was published exactly once and returned a
matching JBOD-signed terminal response. The endpoint transaction itself passed,
and the timeout-isolated helper returned exact runtime evidence without a
timeout:

- Python executable: `D:\AFCV1\rt\python.exe`
- executable SHA-256:
  `7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1`
- installation SHA-256:
  `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`
- Python version: `3.13.2`
- OpenCV version: `5.0.0`
- NumPy version: `2.5.2`
- frozen expected OpenCV: `5.0.0`
- frozen expected NumPy: `2.5.1`

Therefore the exact disposition is
`HOLD_O3EI1_RUNTIME_VERSION_MISMATCH` and `runtimePremisePass=false`.
The observed NumPy `2.5.2` is evidence, not an accepted replacement for the
frozen `2.5.1` premise. No Slot16 numeric successor is authorized.

Request: `REQ_20260828T143500111Z_O3EI1R01`.

Response: `R_43E71FD9A091_20260828144836355_489915ba`.

Response ZIP SHA-256:
`5867DF273446D5CE564466F2696DD8610D359B13F276E3A59B848A09D57BBE26`,
2,945 bytes.

Exact signed response collection gate SHA-256:
`A8437E04071F4429734BC791F23E1D537FB0CD6DB36ADD9399830ED83D924756`.

The signed response manifest SHA-256 is
`BB3F108CA63304AA939D46C73D1BA4F8CDCD161D99BF3FF4EC43CD6BA6F42A11`.
The exact signed stdout SHA-256 is
`C53EFBFA100D6A4D6D286D4218F23D1F6F300B0800A9B013F8AF70192427D456`.
The JBOD signer thumbprint is
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

The helper-owned child PID was 32956. It exited 0, did not time out, and was not
killed. No existing process or scheduled task was queried or acted on. No image
bytes or source images were read or hashed; no source was mutated or deleted;
the protected processor was untouched; no live image provider was activated.
The endpoint output is
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_O3EI1_RUNTIME_STATUS.json`,
SHA-256 `06AAC74522D04B9BABACF53BB4F515A5FD2046B592A2372692F0E691C0E4BD0A`,
3,078 bytes.

O3EI1 has consumed its one publication and may not be retried. The installed
read-only helper and output remain untouched; no cleanup or second endpoint
transaction is authorized.

## Preserved prerequisite order and holds

1. The frozen NumPy `2.5.1` runtime premise did not pass. Stop numeric
   publication. Do not relabel `2.5.2` as accepted, change the expected version,
   rebuild the runtime, or create a successor without a separately reviewed and
   explicitly authorized premise decision.
2. No fresh independent Slot16 numeric successor may run. The locked BF/DF
   hashes and unchanged O3P8 detector/config remain available only after a
   future exact runtime-premise gate passes.
3. BF Slot16 coverage remains partial and frontside independent numeric
   validation remains incomplete.
4. Backside remains unconsumed and requires a separate appearance-regime intent
   only after frontside closure.
5. Every fiducial designation, map, pose, registration, coverage, sensitivity,
   and independent alignment-transfer gate remains pending.
6. XML, training, production eligibility, and production routing remain held.

O3N1/O3P7/O3Q1/O3TR1/O3TR2/O3RO1/O3RO2/O3RO3/O3SO1/O3SO2/O3SO3 remain
withdrawn/no-retry/non-parent. O3EI1 is terminal/no-retry and is not a numeric
successor parent. Every stranded console and unknown process remains untouched.
No threshold, detector algorithm, source, or hold changed.

## Exact next action

Stop at this signed runtime-version mismatch hold. Do not retry O3EI1 or build,
publish, or execute a Slot16 numeric successor. Continue only after a separate
file-backed review explicitly decides how the frozen NumPy `2.5.1` premise is
to be restored or superseded, with unchanged review-only authority and every
existing prerequisite and hold preserved.
