# Gateway request-share alias V1 failed safely

Date: 2026-08-17  
Revision: `GATEWAY_REQUEST_SHARE_ALIAS_V1`  
Disposition: `WITHDRAWN`

Direct signed gateway maintenance request
`REQ_20260817T194356363Z_6FE3643257D7` was accepted through the constrained
Kerberos JEA endpoint. Its signed terminal response is
`R_6B9D83BC6FF3_20260817194529902_e4f186b5`, response-manifest SHA-256
`44B83F7FD0A99B2177928A6F6FC5CE5370BE44DA951F9E2403A3473A0E3F8A7F`.

The verifier failed before restarting the gateway share task because the JEA
virtual administrator could not write a probe beneath
`C:\APR\S\requests`. That identity does not reproduce the SMB credentials or
share ACL of the actual interactive `AMER\fab.op` scheduled task. The probe
was therefore invalid task-context evidence.

The maintenance handler returned a signed `FAILED` response and restored the
exact V1.2 predecessor configuration. Independent bounded status confirmed:

- gateway share task: `Running`;
- gateway response receiver: `Running`;
- installed share-config SHA-256:
  `24102B5ABDB155D3BD2A44CA3A3215ED67353C68824370BB3447909171B939D9`.

V1 must not be replayed. The replacement must omit the cross-identity share
write probe, preserve the config/task/alias/path/rollback checks, and use a
fresh signed request. Actual request and response access must be proven by a
small signed STATUS round trip processed by the `fab.op` task.

No detector, inspection, production, XML, training, or reviewer authority
changed.
