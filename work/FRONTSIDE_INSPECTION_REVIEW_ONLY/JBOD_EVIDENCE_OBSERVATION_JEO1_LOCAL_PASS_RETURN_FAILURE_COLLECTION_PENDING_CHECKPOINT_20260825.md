# Argos checkpoint — JEO1 local observation passed; return path failed; exact ZIP collection pending

Date: 2026-08-25

Revision: `JBOD_EVIDENCE_OBSERVATION_JEO1_LOCAL_PASS_RETURN_FAILURE_20260825`

Disposition: `PENDING_GATE`

## Outcome

The operator ran frozen JEO1 once on JBOD `A1025645101`. The exact live
preflight passed, the bounded read-only observation completed, and the local
result was reported preserved at `D:\A2\x\JEO1R_LOCAL.zip`. The subsequent
direct copy to the engineering share failed closed because JBOD could not reach
the `\\shm-cifs` network path. JEO1 must not be rerun.

File-backed operator-console record:

- path:
  `work/JBOD_EVIDENCE_OBSERVATION_JEO1/JEO1_OPERATOR_CONSOLE_RESULT_20260825T184718Z.json`
- SHA-256:
  `9F758D4A24562165E26164F8A06A99A9E13386C8F434DEE07D92BC1DCDEC6D59`
- verification state: `PENDING_EXACT_JEO1R_LOCAL_ZIP_COLLECTION`

The exact local result ZIP hash and contents are not yet known. Therefore the
observation claims are not promoted beyond operator-console evidence.

## Reported live result

The pasted console output reports:

- preflight state: `PASS_JEO1_DIRECT_ADMIN_READ_ONLY_PREFLIGHT`
- observation state: `PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION`
- copied evidence: 4
- retired trees observed: 3
- tasks observed: 4
- processes observed: 3
- target mutations performed: `false`
- local result: `D:\A2\x\JEO1R_LOCAL.zip`
- return failure: `Test-Path: The network path was not found`
- launcher exit code: 1

The frozen package itself remains immutable and non-reusable after execution.
A return-only failure does not authorize patching or rerunning JEO1.

## Direct route observation

After the reported failure, the engineering laptop observed no reachable
direct JBOD SMB, WinRM, HTTPS WinRM, or RDP port at `A1025645101`; exact
`\\A1025645101\D$\A2\x\JEO1R_LOCAL.zip` was not reachable. The engineering
share still contains no `JEO1R.zip`. The qualified gateway JEA endpoint exposes
gateway status and signed gateway-maintenance functions only; it has no
arbitrary JBOD-file retrieval capability.

The already-open reverse RDP path is therefore the only currently qualified
way to move this exact file without a new endpoint mutation:

`JBOD -> Argos RDP clipboard/redirected drive -> gateway RDP clipboard/redirected drive -> InspectionRevs`

## New failure memory

`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md` now records that share reachability
must be proven from the exact host performing the return. Its current SHA-256
is `55C6BA51D392746E1A90C65BAE7F8AF07E1CF434FC58A29F8493D2EFD58E2007`.
Future direct-admin collectors must commit local D-side evidence independently
and must treat an unreachable optional share copy as a separately reported
return failure.

## Preserved authority and holds

- Review-only authority remains unchanged.
- No JEO1 target mutation, task action, process action, image-byte read,
  source deletion, or wafer action is reported.
- The healthy processor must remain untouched.
- The live OpenCV provider remains disabled.
- Slot16 remains unfrozen; Slot17 remains blocked; Slots22-25 remain unseen.
- `SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold remain.
- CDM1 must not be rerun; CDO1 and O2A2 must not run.
- `REQ_O2D4` is non-reusable and must not be retried.
- DFLY3005 remains excluded.

## Exact next action

Using the already-open nested RDP sessions, copy only
`D:\A2\x\JEO1R_LOCAL.zip` outward and place it in `InspectionRevs` with the
exact name `JEO1R.zip`, or attach that exact ZIP to this task after bringing it
to the engineering laptop. Do not open, modify, recompress, rename internally,
or rerun JEO1.

Codex then hashes, extracts, and verifies the exact result, pins the observed
CDM1 and O2D4 state, builds the durable host-authentic signed read-only JBOD
evidence channel, and continues the inspection sequence.
