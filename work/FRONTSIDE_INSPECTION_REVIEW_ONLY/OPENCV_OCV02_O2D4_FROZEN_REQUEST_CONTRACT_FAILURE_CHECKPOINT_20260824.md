# OCV-02 O2D4 frozen-request contract failure checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

## Outcome

`REQ_O2D4` is not merely waiting on source data. The frozen, signed, and
published request contains deterministic contract defects that make an exact
live pass impossible even though the Slot16 source paths and source-byte
hashes remain fully pinned.

The machine-readable diagnosis is
`work/OPENCV_SCRIBE_O2D4/O2D4_FROZEN_REQUEST_CONTRACT_FAILURE_20260824T235744Z.json`,
SHA-256
`C2F1E971063226C7B7C76664B5F9CF0B0CF4D199DE49BE5439C95BDC43BAE5E4`.

## Deterministic request defects

1. The signed request manifest requires
   `PASS_O2D4_ENTRYPOINT_TEST_GATE`, which is a test-harness/rehearsal marker.
   The exact normal entrypoint emits
   `PASS_O2D4_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED`. The exact installed worker
   checks the request's `rehearsal.requiredState` against normal no-argument
   stdout. Therefore an otherwise successful live run must still become
   terminal `FAILED` with a required-state mismatch.
2. The exact installed worker SHA-256
   `64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`
   has a 900-second child timeout. The exact O2D4 entrypoint SHA-256
   `7FB8B54B18D4D446F4C7AC2FFCB3898721222B93FE4B17E69B681B6E6F85C8C2`
   allows its OpenCV child 1,800 seconds. The parent can forcibly terminate the
   entrypoint before its own bound and before `finally` removes temporary
   `X:`.
3. The live request ID is the static `REQ_O2D4`, not a high-entropy
   timestamp/GUID namespace. The inaccessible JBOD ledger namespace was not
   proved absent before signature.

All three failures were already represented in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. The O2D4 pre-action contract
nevertheless asserted that resident consumers were inventoried and that the
declared action matched implementation. The build gates tested the entrypoint
directly but did not mechanically compare it with the exact installed worker's
normal required-state and timeout behavior. O2D4 and its builder, definition,
and entrypoint are non-reusable and cannot parent a successor.

## Exact response observation

At `2026-08-24T23:53:17.4129840Z`, all 329 response ZIPs in the authorized
engineering-share response root were correlated by the request ID inside each
`PORTAL_RESPONSE_MANIFEST.json`. All 329 manifests were read successfully;
zero matched `REQ_O2D4`. The exact response prefix derived by the installed
worker is `R_A2A87054A416_`; it also had zero matches at
`2026-08-24T23:56:28.0073474Z`.

The gateway-processed request remains the exact 14,825,404-byte ZIP with
SHA-256
`D2411AE50ED33AEE4B6EC8DF1D8B771E228C082C21338B6A4373289EB744C994`.
Its share creation time was `2026-08-24T22:58:34.5320560Z`. The immediately
preceding `REQ_OLS5` timeout control returned to the same share in 910.29
seconds after gateway consumption. O2D4 was already past that outer-timeout
round-trip boundary when the comprehensive response scan completed. Long
source processing no longer explains the absent signed terminal response.

The response's exact broken hop remains unknown. The authorized engineering
share proves gateway intake and response-share absence only; it cannot expose
the JBOD pending/processed package, exact ledger, response outbox, O2D4
`D:\A2` work/output roots, or `X:` mapping. The laptop
`TXSH-LUPW0JLTPR` has no JBOD-specific route and no configured WinRM target.

## Source authority remains intact

The exact Slot16 BF and DF identities remain:

- BF SHA-256
  `CE5502F33D54A12FEF1A082A0B18C1635169B2F5D0BE98C402EA8238D86C2E53`,
  475,379,874 bytes;
- DF SHA-256
  `6FAC812536C19F07D1C3DAD5263741350E94460A07867F2AEE0D2EEEA8C19ED9`,
  475,379,874 bytes.

No evidence supports a missing-source diagnosis. The failure is in the
request/worker execution contract and the unresolved return path.

## Preserved authority and next action

The recovery classification remains `OBSERVE`. The healthy processor was not
restarted or changed. The live OpenCV provider remains disabled. Slot16 is not
frozen, Slot17 has not started, and Slots22-25 remain unseen.
`SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold remain unchanged.
Training, XML, production, and production routing remain disabled.

Continue collecting the exact response prefix and require the matching signed
terminal response. In parallel, the exact JBOD pending/processed/ledger,
response-outbox, O2D4 work/output, and `X:` state require a qualified direct
read-only observation. The currently authorized engineering-share route lacks
those capabilities. Do not retry `REQ_O2D4`, publish a portal successor, reuse
its static namespace, or mutate any task/process/queue/ledger/source/wafer
state while the terminal response and direct endpoint state remain unresolved.

The checkpoint pre-action contract is
`work/OPENCV_SCRIBE_O2D4/PREACTION_O2D4_CONTRACT_FAILURE_CHECKPOINT.json`,
SHA-256
`572B391B4E901D7AF534381644EC09F2E188A1DF55E28289425EFC26C989C79E`.
Its zero-recurrence preflight passed all 90 current history issues.
