# PFC004 exact JSON exporter request-published checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_EXACT_JSON_RESULT_EXPORT_V1`  
Disposition: `PENDING_GATE`

After continuity and session-safety verification, the exact publish preflight
proved zero earlier pending request ZIPs. Signed request
`REQ_20260818T212606693Z_7EFD0668E6FB` was then copied create-new to the
approved Project Portal request share. The published 3,796-byte ZIP hash is
`0B0483D5FD2FD16841F7B6346B76A3830CE0D473497546FA0F2E3ABA43C122B4`,
matching the local signed final-ZIP gate. No overwrite occurred.

Publication-gate SHA-256 is
`00A04DA8888BEFF4EA21358BB674B215D11941BCDBBE313199E8C5D6E4369AAA`.
The request was subsequently absent from the share request inbox, proving only
that gateway import consumed it. It does not prove gateway-to-Argos delivery,
Argos-to-JBOD delivery, endpoint execution, result export, or response return.

Wait for the matching signed terminal response. Do not publish a later request
to this endpoint first. If and only if the exporter response is signed,
terminal, and successful, build a separate complete-route-gated DATA_PULL for
the short deterministic JSON names plus `SOURCE_TO_RETURN_MAPPING.json` and
`EXPORT_AUDIT.json`. Exact per-wafer diagnosis remains blocked until that
returned container verifies. No detector tuning, judgment raster, alignment
transfer, or production scoring is authorized; all other pending gates and
R5P30 remain unchanged.
