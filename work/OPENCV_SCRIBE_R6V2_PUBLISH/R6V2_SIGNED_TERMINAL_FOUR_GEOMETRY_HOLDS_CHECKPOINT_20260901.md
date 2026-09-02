# OpenCV scribe R6V2 signed terminal four-geometry-hold checkpoint — 2026-09-01

Disposition: `PENDING_GATE`

## Signed terminal evidence

The exact matching response for request `REQ_20260901T220000222Z_5A348AE509A4` is cryptographically verified and collected create-new.

- Response ID: `R_71E7438B5A18_20260901234419542_54c4855d`
- Response ZIP SHA-256: `69C8BB46AD8453D1C38EA5A4AD6238398B0DB51BF9611C7A64B23FC2353BF841`
- Response ZIP bytes: `4017`
- Source role: `JBOD`
- Endpoint state: `PASS_MAINTENANCE_PATCH`
- Endpoint exit code: `0`
- Pinned signer thumbprint: `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Standard verifier state: `PASS_SIGNED_PORTAL_RESPONSE`
- Collection gate: `work/OPENCV_SCRIBE_R6V2_PUBLISH/R6V2_EXACT_SIGNED_RESPONSE_COLLECTION_GATE.json`
- Collection gate SHA-256: `8FFC71140229142F9C5E1353D14C305C97F47B5CEDEC487A6499D1C72DEB624D`
- Local archive: `work/OPENCV_SCRIBE_R6V2_PUBLISH/r/R6V2.response.zip`
- Local extraction: `work/OPENCV_SCRIBE_R6V2_PUBLISH/r/R6V2.response`

The canonical and copied response verifier both hash to `4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C`. The canonical and copied JBOD public certificate both hash to `5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B`. The certificate thumbprint is the pinned JBOD signer. RSA signature verification passed in-ZIP before extraction, and the standard verifier passed under Windows PowerShell 5.1 against both the temporary and final create-new extraction.

## Signed batch outcome

The signed `MAINTENANCE.stdout.txt` reports `PASS_R6V2_REAL_IMAGE_REVIEW_ONLY_BATCH`, but its disposition remains `PENDING_GATE`:

- Cases: 4 (`Slot22` through `Slot25`)
- Identity-eligible cases: 0
- Geometry-held cases: 4
- Image-first strings: none
- Proposed strings: none
- Checksums evaluated: none
- Provider SHA-256: `1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9`
- Configuration SHA-256: `C5343C53E94EB2297FBE0637D13E9684D1C11CC3134E856FACE5C57450CB3C92`
- Observed height ratio: `0.10538907694518568`
- Configured minimum height ratio: `0.2061033678437273`

Every slot retained `SCRIBE_AUTO_LOCALIZATION_GEOMETRY_HOLD`, `SCRIBE_REFERENCE_COVERAGE_HOLD`, and `SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD`. Each slot produced one unique geometric candidate, zero qualified candidates, and one geometry rejection. R6V2 therefore completed safely but did not decipher or make any slot identity-eligible.

The response returns the signed batch summary and endpoint result, not the four full `RESULT.json` leaves. Their hashes are signed inside the batch summary but the files themselves were not collected. This is sufficient terminal batch evidence, not deep per-result provenance.

## Safety adjudication

Safe to retain as signed terminal review-only evidence: **yes**.

Safe for identity acceptance, hold clearance, provider activation, XML, training, or production routing: **no**.

The signed response proves one declared installed wrapper change and successful entry-point execution. It also proves source alias removal, maximum one concurrent provider child, no automatic retry, no task/process restart, no source mutation or deletion, no wafer action, no hold clearance, and no provider activation. The reported resident processor count is zero and is retained as an observation only; no processor-health claim is inferred.

The operator screenshot was created approximately 55 seconds before the signed endpoint completion timestamp, explaining why `D:\A2\o\ocv\R6V2A` was not yet visible. The earlier response-only waiting was still procedurally incomplete because execution-start evidence was not obtained; it was stopped and not resumed after the exact response arrived.

No retry or second publication is authorized. Any detector/configuration successor requires a fresh revision and explicit authority; R6V2 remains immutable terminal evidence with all four holds preserved.
