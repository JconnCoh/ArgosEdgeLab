# PFC004 exact JSON DATA_PULL request-published checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_EXACT_JSON_DATA_PULL_V1`  
Disposition: `PENDING_GATE`

After continuity and session-safety verification, exact publish preflight
proved zero earlier pending request ZIPs. Signed request
`REQ_20260818T214318942Z_D7E63788675A` was published create-new as the exact
1,350-byte ZIP with SHA-256
`02242DBA942E5D402EA0E24E263D9DF9C3C2BA76FD2E85F06499C86C0AB1B081`.
Publication-gate SHA-256 is
`85DA3DB0CA363788A11EC2D2A4EA365CD884CBF7652B693CB22717C60AB65C5F`.

The request was consumed from the share. That proves only gateway import, not
endpoint execution or return-container correctness. Do not publish a later
request first. Require the matching signed terminal response, then verify
`DATA_PULL_PAYLOAD.zip`, `RESULT.json`, all 38 entry paths and hashes, and the
expected mapping/export-audit hashes before per-wafer diagnosis. No tuning,
raster, alignment transfer, or production scoring is authorized; all other
gates and R5P30 remain unchanged.
