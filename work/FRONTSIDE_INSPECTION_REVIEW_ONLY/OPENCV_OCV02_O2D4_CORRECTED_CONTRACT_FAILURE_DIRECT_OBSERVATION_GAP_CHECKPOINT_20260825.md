# OCV-02 O2D4 corrected contract failure and direct-observation gap checkpoint — 2026-08-25

Disposition: `PENDING_GATE`

State: `STOP_RECOVERY_OBSERVATION_CAPABILITY_GAP`

## Corrected outcome

The Slot16 source identity is intact, but the exact frozen `REQ_O2D4` cannot
produce a valid live pass. The corrected machine diagnosis is
`work/OPENCV_SCRIBE_O2D4/O2D4_FROZEN_REQUEST_CONTRACT_FAILURE_R2_20260825T000937Z.json`,
SHA-256
`9BB226016EB5251F037BC996631E434AE375FEBA9360CE82C9E87FBA47FC8AC9`.

The prior diagnostic and its checkpoint are withdrawn as current authority.
They compared O2D4 against older endpoint worker hash
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`
instead of the exact current worker pinned by the O2D4 route gate. No external
action was taken from that error. This revision mechanically compares only
`work/OPENCV_OLS3/pkg/payload/W.ps1`, SHA-256
`CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250`,
which matches the exact current worker declared by
`work/OPENCV_SCRIBE_O2D4/O2D4_COMPLETE_ROUTE_GATE.json`, SHA-256
`AFE9A1306D90C5B54042388901F6FD6902DD8C1637A99714B451EF1F14F8CA34`.

## Defects confirmed against the exact current worker

1. The request manifest requires rehearsal-only marker
   `PASS_O2D4_ENTRYPOINT_TEST_GATE`. The normal no-argument entrypoint emits
   `PASS_O2D4_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED`. The current worker invokes
   that exact no-argument path and checks normal stdout for the manifest's
   rehearsal marker. It must therefore roll back and return `FAILED` even if
   the provider succeeds.
2. The current worker's maintenance child call uses its default 900-second
   timeout. O2D4 permits the inner OpenCV child 1,800 seconds. The worker can
   kill the entrypoint before its own bounded provider timeout and before its
   `finally` removes temporary `X:`.
3. The live request uses prohibited static ID `REQ_O2D4`. The current worker
   searches both response-outbox `pending` and sibling `sent` for an existing
   signed response with that request ID. A match archives the incoming request
   as replayed and creates no fresh response. The inaccessible endpoint
   ledger/response namespace was not proved absent before signature.

These are known failure-memory recurrences. O2D4, its request namespace,
builder, definition, and entrypoint are non-reusable and cannot parent a
successor.

## Exact response watch and share-route exclusion

All 329 returned response manifests were correlated with zero read errors and
zero O2D4 matches at `2026-08-24T23:53:17.4129840Z`. A further exact-prefix
watch for `R_A2A87054A416_` ran for 600 seconds and completed
`NO_MATCH_WITHIN_MONITOR_WINDOW` at
`2026-08-25T00:08:33.8546944Z`.

A bounded recursive filename check of the authorized Project Portal share
found one O2D4 artifact only: the exact processed request
`ProjectPortalRO/requests/processed/REQ_O2D4.ready.zip`. There is no matching
request or response in another share-visible staging, quarantine,
maintenance, or response path. The response-root directory has not changed
since `2026-08-24T21:37:06.6874070Z`, before O2D4 gateway consumption.

Therefore the response is not merely late and source absence does not explain
it. The unresolved state is within gateway-to-Argos delivery, Argos-to-JBOD
delivery, endpoint pending/processed/ledger/work handling, or the JBOD/Argos/
gateway response-return chain.

## Source authority and preserved holds

The exact Slot16 source identities remain:

- BF: 475,379,874 bytes, SHA-256
  `CE5502F33D54A12FEF1A082A0B18C1635169B2F5D0BE98C402EA8238D86C2E53`;
- DF: 475,379,874 bytes, SHA-256
  `6FAC812536C19F07D1C3DAD5263741350E94460A07867F2AEE0D2EEEA8C19ED9`.

No evidence supports a missing-source diagnosis. The healthy processor was
not restarted or changed. The live OpenCV provider remains disabled. Slot16
is not frozen, Slot17 has not started, Slots22-25 remain unseen,
`SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold remain unchanged,
and training, XML, production, and production routing remain disabled.

## Required next evidence

Recovery remains `OBSERVE`. Exact direct read-only observation is required for
the following current JBOD fields:

- endpoint pending/processed `REQ_O2D4.ready` state;
- `endpoint_jbod/state/ledger/REQ_O2D4.json`;
- `endpoint_jbod/state/work/J_A2A87054A416_*`;
- `to_argos/pending` and `to_argos/sent` response prefix
  `R_A2A87054A416_*`;
- `D:\A2\w\ocv\O2D4*` and `D:\A2\o\ocv\O2D4*`;
- current `X:` alias existence and target.

The engineering-share route cannot expose these fields, the laptop has no
JBOD route, and no qualified `DIRECT_ADMIN_READ_ONLY` authorization gate is
present. Under the recovery policy this is
`STOP_RECOVERY_OBSERVATION_CAPABILITY_GAP`. Obtain authority for one bounded
direct-admin read-only observation capability; it must install nothing,
change no task or process, mutate no queue or ledger, read no image bytes, and
perform no source or wafer action. Continue passive exact-response collection.
Do not retry O2D4, publish a portal successor, or mutate JBOD while unresolved.

The checkpoint pre-action contract is
`work/OPENCV_SCRIBE_O2D4/PREACTION_O2D4_CONTRACT_FAILURE_R2_CHECKPOINT.json`,
SHA-256
`0471521E8C0E2BF0A395746808A33EA3D2AC03FC9C9DB6167D5A67388B0696C6`.
Its zero-recurrence preflight passed all 90 current history issues at
`2026-08-25T00:11:01.7528255Z`.
