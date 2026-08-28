# OCV-03 O3Q5 local runtime-gate consumer contract repair pass — 2026-08-28

Disposition: `PENDING_GATE`

Active phase: `OCV03_O3Q5_LOCAL_RUNTIME_GATE_CONSUMER_CONTRACT_REPAIR_PASS`

Authority remains review-only. Training, XML, and production are ineligible.

## Authoritative outcome

The runtime premise is closed and was not observed again. Existing exact
file-backed evidence remains Python `3.13.2`, OpenCV `5.0.0`, and NumPy
`2.5.2`.

The exact O3Q4 runtime-gate bytes, SHA-256
`09DEEF0BC1C0DC9464F5BF5CE93EF590F2780F3123BB13AB6080358E562C68C4`,
mechanically reproduce the frozen O3P8 consumer failure
`O3P8 runtime gate is not PASS.` with zero image reads.

Fresh O3Q5 adapter
`work/OPENCV_EDGE_NOTCH_O3Q5/Detect-O3Q5FrontSplitNotches.py`, SHA-256
`4A641397B787767ECCAABF3345499AF0E9E5F0C26F7EE8498CF58319E07D85F3`,
replaces only the runtime-gate `load_job` boundary. It requires the job-pinned
gate schema, PASS state, JBOD target role, Python/OpenCV/NumPy versions,
runtime executable hash, installation hash, and review-only authority flags.
All detector behavior delegates to the unchanged frozen O3P8 engine SHA-256
`41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36`.

The same byte-exact O3Q4 gate passes the repaired consumer. Wrong gate hash,
wrong job-pinned state, failed gate state, and wrong gate NumPy version all
fail closed before image access. The exact test gate is
`work/OPENCV_EDGE_NOTCH_O3Q5/O3Q5_RUNTIME_GATE_CONSUMER_TEST_GATE.json`,
SHA-256 `8CA026CCE68BC7FC243EA4386FB8C59F11993C366BD97B7AAC0207CEB3E17EC0`.

## Stop-loss review and operating correction

The incident-bound recovery-intent preflight passes and the two-signed-failure
mutation stop-loss is cleared only for this one local contract repair:

- workflow review clearance SHA-256
  `973227E7612C7D0F9668DCDBA4B4388D679EEB43E62C12BAFDAA78B30BC0A40B`;
- post-failure observation SHA-256
  `FAE1CC1AEAEB652DF3DB1D867B06D6DB69A99919B1E27A1138F77C3F2257F849`;
- recovery intent SHA-256
  `8438094E4E9D5402CCFB3A9F7D8B84647B03014C7CBF131ABD60E488DD3DEF86`;
- checkpoint preaction:
  `work/OPENCV_EDGE_NOTCH_O3Q5/PREACTION_O3Q5_LOCAL_CONTRACT_REPAIR_CHECKPOINT.json`,
  which passed `PASS_ARGOS_ZERO_RECURRENCE_PREACTION`.

The durable operating boundary for this incident is now mechanical:

- runtime discovery is closed and must not recur;
- substitute or semantically similar runtime-gate fixtures are forbidden;
- the byte-exact captured live gate must pass the final consumer;
- acceptance failures stop the attempt rather than creating an improvised
  observer, schema, or retry;
- no live action may precede the exact final-package consumer test;
- a local consumer pass is not a live numeric result or publication authority.

## Preserved holds and authority

No live request, retry, runtime observation, image read, source mutation or
deletion, task/process action, provider activation, protected-processor action,
threshold/algorithm change, wafer action, or hold clearance occurred.

O3Q2 and O3Q4 remain withdrawn, no-retry, and non-parent. All earlier
withdrawals and stranded console/process holds remain unchanged. Backside is
unconsumed, BF Slot16 coverage remains partial, and every fiducial designation,
map, pose, registration, coverage, sensitivity, independent alignment, XML,
training, and production prerequisite remains in force.

## Exact next action

Do not inspect runtime again and do not retry O3Q4. Use this verified adapter
only in a fresh O3Q5 local endpoint/job integration that supplies the exact
job-pinned runtime-gate contract fields. Before any package or live action,
the exact packaged final consumer must repeat the byte-exact positive and all
bounded negative cases. No live request is authorized by this checkpoint.
