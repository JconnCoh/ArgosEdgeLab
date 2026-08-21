# JBOD C1D root refusal and C1F0 diagnostic ready — 2026-08-19

Classification: `PENDING_GATE`

## Signed C1D terminal failure

C1D request `REQ_C1D` advanced to signed terminal response
`R_90F9FB102714_20260819184434022_54dbca9e`, state `FAILED`. Response ZIP
SHA-256 is
`821EB82C89EA027B24185EB244F0C240A0A4A979816A641320AF04146170A60E`;
signed failure SHA-256 is
`94400F67B19DF0863FA6A3D08A5B7C77A6800684A30C2F2F4651685E69ACA861`.
The exact failure is:

`Maintenance destination is outside approved roots: C:\ProgramData\ArgosInsiteBridgeRO\Invoke-JbodAutomaticInsiteBridgeWorker.ps1`

The endpoint refused during destination preflight before changing any of the
five consumers. The C1D signed-response gate SHA-256 is
`4648538ECAD0EADEC440C878F1B5B742978E3F53F9C4BD6D63B730A826A041C9`.
No consumer file, scheduled task, cooperative hold, D: path, source tree, or
wafer changed.

The root cause is a rehearsal-contract error, not a random live mismatch. The
local C1D exact-endpoint harness supplied both the processor and Insite bridge
as approved maintenance roots. The installed JBOD endpoint config authorizes
only `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2`. The exact worker
bytes were tested, but the installed root set was broadened in the harness.
This failure and its mandatory installed-config preflight are now recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. C1D must not be retried unchanged.

## C1F0 exact installed-config diagnostic

The bounded follow-up is C1F0A, not a config mutation. It installs one short,
idempotent diagnostic helper at the already approved processor root and emits
the exact installed `endpoint_jbod.json` hash plus its parsed root contract.
The helper does not change the config, tasks, processor hold, D: paths, source
trees, or inspection state.

The first signed but unpublished `REQ_C1F0` is withdrawn because its
create-new change omitted target-hash idempotence. Replacement request
`REQ_C1F0A` explicitly permits only create-new or the exact target helper hash.
Its exact ZIP is 2,756 bytes, SHA-256
`16EFD0A5771CD66B61BCA8AED8D879F40EE70C5DDB2E69ACB80194F07985CFF5`.
Final-package-gate SHA-256 is
`48AE456E779B4C3CFFDAC452B06F554A9A92B3D3313B83934A3FF2CC9D856E74`.

C1F0A passed Windows PowerShell 5.1 helper behavior, exact signed endpoint
create-new, target-idempotent, and unapproved-predecessor refusal cases using
the literal installed approved-root set. Its complete route enumerates 94
leaves, including every response result leaf and the exact live config read,
at maximum effective length 187 and maximum component length 51. The current
16-case queue-safety gate is bound. C1F0A is ready but unpublished.

## Required sequence

1. Publish only exact `REQ_C1F0A` after zero pending requests and require its
   matching signed terminal response.
2. Retrieve the exact installed endpoint-config hash and complete parsed root
   contract from the signed stdout. Do not infer it from deployment source or
   the failed C1D message.
3. If the bridge root is still the sole missing root, build a separate atomic
   endpoint-config revision with exact predecessor hash, semantic-field
   preservation, rollback, installed-config, path, queue, and task-invariance
   gates. Require its signed terminal response.
4. Rebuild C1D under a new request ID and run its exact endpoint rehearsal
   against that pinned installed config before publication.
5. Preserve the cooperative hold and continue signed D2/D3 final-delta gates;
   do not cut over or delete C: source first.

The processor remains at the clean between-wafer hold with no active or
waiting wafer. D3, C2A, C2B, C: recovery, and resumed PFC004 work remain gated.
No detector, raster, alignment, XML, training, production eligibility, or
production-routing authority changes.
