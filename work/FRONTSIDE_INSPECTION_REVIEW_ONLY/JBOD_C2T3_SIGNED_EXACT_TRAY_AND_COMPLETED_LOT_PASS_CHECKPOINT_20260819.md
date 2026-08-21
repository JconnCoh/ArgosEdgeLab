# JBOD C2T3 signed exact-tray and Completed Lot pass — 2026-08-19

Disposition: `PENDING_GATE`

Matching signed response `R_0ADF9A72D35B_20260820014814111_01b4e6ce`
passed after C2T3 replaced task-state inference with exact tray-process proof.
The response signature and all three declared response files verify, and the
portal request queue is empty.

- response ZIP SHA-256:
  `1B507B203AB442B92A7936F1ECDAF277EAE03F64260077F986D61000F6397098`;
- response manifest SHA-256:
  `F16A7D61C27B62EB4F342A4F455E5D43DB02242BD1DA4A6055628CCC12E844A5`;
- response signature SHA-256:
  `10E72EB1BFF27DBA9DEF267A17CEED8330A66BB77CE20F40E1113F10187A409F`;
- response route gate SHA-256:
  `6C68701BC9C08A22F02EE05814EA85C06A89434FF8E9D186D639B738BC4F1B38`;
- terminal response gate SHA-256:
  `322AA0CA22A58D09ED3E85F075D1DD8030AF666B93BF9D788679A6E317D08B72`.

The exact installed tray task is unchanged, principal `lwm`, definition
SHA-256 `E3D78B9802BC4599CEC37BCC80F01BC8A0086B398CCABC25163DE4AEFC0C419F`,
and state `Running`. There was no exact tray process before the restart. One
fresh exact process, PID 19908, was created at
`2026-08-20T01:48:10.6421170Z` and remained stable. All 13 protected Argos task
definitions and principals remained unchanged.

The current Completed Lot launcher passed all three sealed probes. Viewer
SHA-256 is `39AEA256E4C08043A6F9AEFEADB32F4297217E878C8B71A4603D64FA570677A6`;
the live dashboard-manifest SHA-256 is
`309C5B2B6D8E344D55AB4BC652D13FC4311200EDF8ED07DD22D24313C93ACD34`.

The C2A D: paths and cooperative hold remain active. No inspection task was
changed, no C: source was deleted, no wafer was aborted, and production routing
remains disabled. C2B is now the next allowed action: clear only the cooperative
hold against the exact C2A config, reactivate review-only processing, then
validate newly run lot `62631-586` through the real D: output, dashboard, cache,
metadata, inspection-log, and Completed Lot consumers before considering any
C: duplicate recovery.
