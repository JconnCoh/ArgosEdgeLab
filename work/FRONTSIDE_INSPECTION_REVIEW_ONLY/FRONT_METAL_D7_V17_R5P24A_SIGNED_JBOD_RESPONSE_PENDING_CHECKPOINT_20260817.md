# Front-metal D7 V17 R5P24A signed-JBOD response pending checkpoint — 2026-08-17

Disposition: `PENDING_GATE`

Request: `REQ_20260817T153923252Z_2EB5616C2942`

The exact final signed request ZIP was published create-new at
2026-08-17T15:42:24Z through a verified short mapping to the approved
`InspectionRevs\ProjectPortalRO\requests` share. The published file was 105366
bytes and hash-matched SHA-256
`FED45D387EC45BC3ADD2ECEC4783FF0904CAFAC60C3F7B393B8542D1014F44D0`.
The publish gate is
`work/FM7P24A/portal_request/FM7P24A_PORTAL_PUBLISH_GATE.json`, SHA-256
`614B7D3B22FD2BB91F91705CD78F30D12CFA417931C92E1579F1B3561A4D07AA`.

The gateway consumed the request from the share. As of
2026-08-17T16:09:31Z, no signed response ZIP for this request and no new
response ZIP of any kind had appeared on the shared response channel. The
channel's newest file remained the prior 2026-08-16 response. This is a
response-transport pending state, not an FM7P24 PASS or failure and not proof
that the JBOD child completed.

The generic bulk receiver was not retried after it attempted to extract an
unrelated old deep-path archive before applying its expected-request filter.
Future receipt must identify the exact response by bounded
`PORTAL_RESPONSE_MANIFEST.json` lookup through the ZIP central directory,
extract only that ZIP to a fresh short root, and verify its endpoint signature
and declared hashes.

Do not resend, edit, or replay the accepted R5P24A request. Only a signed
response containing
`PASS_FM7P24_T16_T17_ZERO_BLANK_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`
may authorize the bounded result pull. No defect, Normal, reviewer, XML,
training, or production authority is granted while the response is pending.

The patterned-fiducial request `REQ_20260816T033053168Z_802B9D0EC0B4`
remains independently accepted and unanswered; it also must not be duplicated.
