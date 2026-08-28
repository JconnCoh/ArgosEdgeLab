# OCV-03 O3Q2 direct runtime observation timeout / operator-console hold — 2026-08-28

Disposition: `PENDING_GATE`

The operator authorized the bounded repair of the existing JBOD/Argos access
path and directed that the working access method not be replaced.  The local
transport inventory was therefore changed only to add a strictly non-mutating
preflight and remove the known conditional-assignment scalarization hazard.
The established RustDesk/RDP direct runner, the O3Q2 runtime observation
source, and all target-side bytes remained unchanged.

## Existing transport inventory repair

- rejected inventory SHA-256:
  `853776763BF5449E582CE5E1E163E7D44EED511ED43CD34A90A23ACD3C00720B`
- fresh qualified inventory SHA-256:
  `D582B80A7CF9AC4AB21FE2D228B875D8ED1503ACB50FB750EC008EEBFADED538`
- repair authorization gate:
  `work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_TRANSPORT_CAPABILITY_REPAIR_AUTHORIZATION_GATE.json`,
  SHA-256
  `DD64E94D06DDE1F8D475F8E4B6326D0CE5B30005332F619EB480759D1A6AE38F`
- repair terminal gate:
  `work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_TRANSPORT_CAPABILITY_REPAIR_GATE.json`,
  SHA-256
  `A32323790736A2EBA62FB68D38C4D211129EF682B7267BF810A8B098C679A7D0`

The exact script passed Windows PowerShell 5.1 parsing, the harness-safety
guard, the wrapper guard, its own non-mutating preflight, and the path budget.
Its operational schema, gateway peer `10.66.81.84`, target
`10.20.70.241:5985`, and `ValidateWinRm` behavior were preserved.  No new
transport implementation was introduced.

The first operational inventory returned
`OBSERVED_NO_MATCHING_ARGOS_FORWARD`, zero matching forwards, one RustDesk
listener candidate on local port `21118`, zero errors, and zero mutations.
WinRM was not requested and is not used by the established GUI observation
route.  Exact inventory gate:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_DIRECT_TRANSPORT_INVENTORY_R2.json`,
SHA-256
`357419E593DACB5886B98F51A41925727FB51C1DB204C81B1E88371978A8B409`.

## One direct observation attempt and terminal timeout

The refreshed recovery intent, observation source, direct runner, wrapper,
harness, path, continuity, session, and zero-recurrence gates passed.  The
unchanged source
`work/OPENCV_EDGE_NOTCH_O3Q2/Observe-O3Q2RuntimeVersions.ps1`, SHA-256
`9DED5B3AC1B1EE64CA771D34D8B07D291D7662B013E7E0DA2D46074874C78B8A`,
is 1,826 characters.  It was sent exactly once through unchanged runner
`Invoke-ArgosJbodDirect.ps1`, SHA-256
`CE10569FEAC2FF03C04BC0603011AD92A6DABB6C911A80F5E0546A785D232C3D`,
with exact expected hostname `A1025645101`, a 4,096-character result cap, and
a 45-second timeout.

No nonce-bound result, command hash, terminal state, or runtime version
returned.  The exact terminal error was `Timed out waiting for the exact JBOD
clipboard response after 45 seconds.`  Target execution is unconfirmed; no
runtime version, target mutation, or success is inferred.  The attempt was not
retried.  Terminal timeout gate:
`work/OPENCV_EDGE_NOTCH_O3Q2/O3Q2_DIRECT_RUNTIME_OBSERVATION_TIMEOUT_GATE.json`.
Its SHA-256 is
`DF16C06EBDD822E28135220E22E23D70C90D4D345CCEDE9A0C1D73C74B909E7F`.

This is a recurrence of the already documented long encoded-paste class.  The
unchanged runner still waits only 500 milliseconds between paste and Enter.
The O3Q2 safety/preaction evidence did not mechanically require the existing
rule's deterministic complete-pasted-length calculation and equal-or-greater-
length fixed-scalar terminal rehearsal.  The preaction PASS therefore did not
qualify the substantive clipboard class.

## Exact next action

Do not rerun the observation, press Enter, clear the remote console, click
blindly, or infer that the target command executed.  The operator must first
report the exact current JBOD console state while leaving every visible console
untouched:

1. whether the long `powershell.exe -EncodedCommand ...;exit` text is still in
   the input buffer with the cursor at its end;
2. whether a parse/runtime error is visibly present;
3. whether a normal prompt returned; or
4. whether another exact state is visible.

`CaptureConsoleText` is eligible only if a parse/runtime error is visibly
present.  Otherwise preserve the stranded console unchanged.  Any fresh
rehearsal and runtime observation require fresh namespaces, a runner preflight
that emits the deterministic complete pasted length and paste-to-Enter delay,
and one equal-or-greater-length fixed-scalar rehearsal returning its exact
nonce, command hash, PASS state, and non-truncated scalar.  If that rehearsal
does not pass, direct transport remains a capability gap.

The operator's current approval authorizes the bounded existing-runner
capability correction and, only after the post-failure observation succeeds,
a fresh numeric successor namespace.  It does not authorize replay or retry of
O3Q2, threshold or detector changes, or bypass of the exact-length rehearsal.

## Preserved prerequisite order and holds

O3Q2 remains a single published request with one authentic signed NumPy-
premise failure and no retry.  The active NumPy/OpenCV versions remain unknown.
Frontside independent hotspot validation is incomplete.  Backside remains
unconsumed and cannot start; fanout and fiducial resume remain pending after
frontside and backside completion.

O3N1, O3P7, and O3Q1 remain withdrawn and non-parent.  BF Slot16 partial
coverage remains unresolved.  The live provider remains disabled and the
protected processor is untouched.  No source-image mutation/deletion, managed
task/process action, queue/ledger mutation, threshold/algorithm change, hold
clearance, training, XML, production eligibility, or production routing
occurred.  Every fiducial designation, map, pose, registration, coverage,
sensitivity, and independent alignment-transfer gate remains pending.
