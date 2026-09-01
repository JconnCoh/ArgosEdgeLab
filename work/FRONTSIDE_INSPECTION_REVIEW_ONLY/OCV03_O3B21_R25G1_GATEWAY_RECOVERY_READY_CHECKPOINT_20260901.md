# OCV-03 O3B21 R25G1 gateway recovery ready — 2026-09-01

Disposition: `PENDING_GATE`

The operator explicitly authorized portal recovery after R25NA1 remained at
the engineering-share request root. Fresh direct read-only JEA observation
proved gateway `TXSH-DPMZ0295HR`, caller `AMER\joshua.conn`, exact qualified
GWQ2 bridge/config hashes, `ArgosProjectPortal.Gateway.ShareBridge.RO` state
`Ready`, and the separate response receiver state `Running`. The exact
45,761-byte R25NA1 ZIP remains pending with SHA-256
`A96E29988C4DC9DE3FF4495823409BA14A54E6138616A2D9E873A4EBB0461D0D`;
no processed copy or matching response manifest exists.

One fresh direct gateway recovery package, R25G1 request
`REQ_20260901T161846627Z_6B71EECCA831`, is frozen but not yet uploaded or
invoked. Its ZIP is 3,991 bytes with SHA-256
`F08FE0DD6E2A4ED7C54132239ED411D5F3F5D0445BB8C29B63AA04C3193A6F2B`.
Windows PowerShell 5.1 signature, extraction, payload-hash, clone-literal,
path-budget, recovery-intent, zero-recurrence, and extracted-entrypoint
rehearsal gates pass.

The entrypoint verifies the exact gateway hostname, interactive `fab.op`
principal, qualified bridge/config hashes, pending R25NA1 request ID/hash, and
absence of the processed copy before its only task action. It may restart only
`ArgosProjectPortal.Gateway.ShareBridge.RO`. It cannot restart the response
receiver or any detector, scribe, Insite, monitor, inspection, or JBOD task; it
cannot republish/retry R25NA1, change provider authority, read image bytes,
mutate sources, or clear holds.

Exact next action: after a clean commit/push with matching local and origin
branch tips, upload and invoke R25G1 exactly once through the existing
`ArgosGatewayMaintenance` Kerberos JEA endpoint. Collect its exact signed
terminal response. Then observe whether the unchanged bridge consumes the
already-published R25NA1 request and collect only R25NA1's matching signed
terminal response. Do not republish or retry either request.

NA1, ordinal 23, the fresh 953 corpus, frontside, scribe, combined outputs,
fiducial/alignment, training, XML, production, source deletion, and all prior
holds remain unchanged and unauthorized.
