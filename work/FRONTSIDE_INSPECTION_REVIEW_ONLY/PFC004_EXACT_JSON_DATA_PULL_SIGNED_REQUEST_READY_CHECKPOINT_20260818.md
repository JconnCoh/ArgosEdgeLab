# PFC004 exact JSON DATA_PULL signed-request-ready checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_EXACT_JSON_DATA_PULL_V1`  
Disposition: `PENDING_GATE`

Signed JBOD `DATA_PULL` request `REQ_20260818T214318942Z_D7E63788675A`
is ready but not yet published. Its exact 1,350-byte ZIP SHA-256 is
`02242DBA942E5D402EA0E24E263D9DF9C3C2BA76FD2E85F06499C86C0AB1B081`.
Request-manifest and signature SHA-256 values are
`05EF0A8F3CE77E1ED5E81B4917041F603BBB9F86CBB7E2D3DDC3CA135B0E13CE`
and
`BF8EB894081F7BC678BE10831D96E24DC67F500A74BF535EBD3E31B38318C36C`.

The request declares exactly 38 leaves under approved root
`JBOD_PROCESSOR_REVIEW`: `F000.json` through `F035.json`,
`SOURCE_TO_RETURN_MAPPING.json`, and `EXPORT_AUDIT.json`. The 114-path
complete round trip enumerates every source leaf, every portal and response
hop, and every laptop payload-extraction leaf. All rows pass individually with
32-character suffix reserve; maximum effective length is 187 and maximum
component length is 51. Pre-sign and final route-gate SHA-256 values are
`DE5A3C5060EC684DB2D1492FC0C8BD864061D5ADB6034DF9EA7A027405918D8A`
and
`FF42505C8E2915BD5E22D89C578C9EF5092F2C97B6C9EF6E4999E0A9BB635D4C`.

The exact extracted signed request passed an isolated Windows PowerShell 5.1
round trip through the exact queue-safe endpoint worker SHA-256
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`.
The endpoint emitted signed `PASS_DATA_PULL`; all 38 declared entries were
returned at their preserved ZIP paths and all 38 hashes matched their exact
fixture sources. Exact round-trip gate SHA-256 is
`9493642BD8DB2E49FB62FB9E64B56CFCBB5569949D07197B6A931BEB3D9546ED`.
The signed final-ZIP gate SHA-256 is
`C1836F191F1D8CFFD134A64A76EAC30E23A29BCE0607A4DC8EE2FDE20BD6E140`.

Run continuity and session-safety checks, prove zero earlier pending request
ZIPs, then publish this exact ZIP create-new. Require its matching signed
terminal response and verify the returned `DATA_PULL_PAYLOAD.zip`, `RESULT.json`,
all 38 entry paths, every returned hash, the expected mapping hash
`EF6D8555882943C2E0E9014495A7068F94A2F505AEA11017F9E994970B6A9BD8`,
and the expected export-audit hash
`2B1D1B6B7200E4DE2DD262BA7D1A0890A884AB13A85CFFF16D7C6DC6FA670471`
before per-wafer diagnosis.

No detector tuning, judgment raster, alignment transfer, training/XML
promotion, or production scoring is authorized. The reusable fiducial
workflow, V17R5 contract, wet-strip separation, other pending gates, and R5P30
remain unchanged.
