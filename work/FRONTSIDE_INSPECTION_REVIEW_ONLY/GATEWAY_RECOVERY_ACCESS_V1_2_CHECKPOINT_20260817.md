# Gateway response-publication repair and constrained access V1.2

Status: `RELEASED_REVIEW_ONLY`, pending one gateway-local bootstrap launch.

## Why V1.2 exists

The live V1.1 apply stopped after creating `C:\APR\S`. Windows PowerShell 5.1
reported the exact UNC symbolic-link target as `UNC\shm-cifs\...`, while the
repair compared it only with `\\shm-cifs\...`. The same representation bug
then blocked V1.1 rollback. Evidence places the failure before either installed
gateway file was replaced: the predecessor bridge/share configuration remain
installed, the response receiver is unchanged, the share task is stopped, and
the exact intended alias plus V1.1 `prior`/`stage` audit structure remain.

V1.2 recognizes only that pinned interrupted-after-alias state or the exact
fresh predecessor state. It canonicalizes the Windows PowerShell 5.1 UNC link
representations, verifies the exact audit contents and predecessor hashes,
probes create/read/delete through the alias, installs only the replacement
bridge and share configuration, restarts only the share task, and requires a
fresh task-context alias proof. Unexpected audit content, link target, task
definition, installed hash, or receiver hash fails before mutation.

## Durable direct-access bootstrap

The same one-launch package installs `ArgosGatewayMaintenance`, a constrained
JEA endpoint for only `AMER\joshua.conn`, with TCP 5985 allowed only from
`10.66.0.0/16`. It does not add any account to local Administrators, change the
default endpoint ACL, or grant a general remote shell. Its visible surface is
five Argos functions: bounded status, signed ZIP receive, signed maintenance
execution, bounded signed-response read, and bounded response-chunk read.

Every mutation after bootstrap requires an unexpired review-only
`GATEWAY/MAINTENANCE_PATCH` request signed by the existing non-exportable laptop
signer. Uploads are bounded, contained, reparse-point-free, hash verified, and
RSA signature verified. Responses are signed by a new non-exportable gateway
result key. Production routing remains disabled.

## Exact package and gates

- ZIP: `work/ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_AND_ACCESS_V1_2.zip`
- bytes: `65014`
- SHA-256: `57414E74EDDBAE9C352084FEE149B372A05911715CAC42ED67DED3916E903BE4`
- package manifest SHA-256:
  `DF1437F1DF4D0578E0D069A8051B7659C65B9338ECA2CA21725AA3AECF2C9D37`
- final package gate:
  `work/ARGOS_GATEWAY_RECOVERY_ACCESS_V1_2.GATE_PASS.json`
- final package gate SHA-256:
  `EA7AE4AE52582E6E80C17E782C94054D882DBB85A5E78D53EF0A491B00F1478B`

The ZIP and short-named final gate were copied create-new to the operator's
`InspectionRevs` root through a path-gated short mapping. A bounded
create/read/delete alias probe passed first, and both mapped-path and direct-UNC
hashes match the local sources. The mapping was removed after publication.

The resealed exact ZIP passed byte-for-byte extraction, the wrapper gate, 7/7
access controls, 11/11 repair controls, and 9/9 launcher controls under Windows
PowerShell 5.1. The repair gate includes the live-type UNC symbolic link, exact
interrupted continuation, contaminated-audit refusal, task-context write proof,
unapproved predecessor refusal, idempotency, and injected rollback.

The exact extracted endpoint passed a live authenticated JEA gate: all five
Argos functions were visible; `Get-Process`, general file mutation, shell
executables, and other general commands were unavailable; wrong transport hash
and signed-payload tampering were refused; a harmless signed maintenance patch
executed; its response signature and bounded chunk were verified; and the test
endpoint, certificate, module, fixture, and service state were exactly cleaned.
The live gate result SHA-256 is
`8FF9A9F1E363E0877872AD179DB45C9F2D68676B69024648A33D8B27A6D486FC`.

This workstation's domain GPO listener is IPv4-only while its own hostname also
publishes AAAA, so the local live gate used authenticated loopback Negotiate and
records that limitation explicitly. The gateway hostname resolves to only the
audited A address `10.66.81.84`; the actual laptop-to-gateway Kerberos session
is mandatory immediately after installation and cannot be claimed in advance.

## Operator and continuation action

On exact gateway `TXSH-DPMZ0295HR`, extract only the published V1.2 ZIP to a
fresh short local folder such as `C:\GWR12`, then run only
`RUN_ON_GATEWAY.cmd` as Administrator. Both preflights run before any mutation;
the constrained endpoint installs first, then the exact interrupted repair
continues automatically. The persistent log is beneath `C:\GWR12_LAUNCH`, and
the window remains open on success or failure.

If endpoint installation passes but repair fails, do not rerun the package.
The endpoint remains available so Codex can inspect and recover the exact state
directly. After complete PASS, Codex must prove the actual Kerberos endpoint,
retrieve bounded status, rerun the complete response-publication route gate,
and only then authorize the pending 41-file FM7P24A result pull.

No detector, alignment, composite, defect, Normal, mask, reviewer, XML,
training, or production authority changes in this checkpoint.
