# PFC004 exact JSON exporter terminal-response checkpoint

Date: 2026-08-18  
Revision: `PFC004LT1A_EXACT_JSON_RESULT_EXPORT_V1`  
Disposition: `PENDING_GATE`

## Matching signed terminal response

Request `REQ_20260818T212606693Z_7EFD0668E6FB` returned matching signed JBOD
response `R_DCCFD7C2CB51_20260818213347072_2d7236c9`. The response passed the
pinned JBOD certificate, exact request identity, source role, signature, safety
flags, and all three declared response-file hashes. Endpoint state is terminal
`PASS_MAINTENANCE_PATCH`.

The 2,251-byte response ZIP SHA-256 is
`1F31EE2E6C0A043FB4CD14E71D37AF832B1239EEE042870FAF88FFFFBEF96E03`.
Response-manifest and signature SHA-256 values are
`8285E4EA2567E805D53D9B83B6CD4A122B7E393517881A482D69D0EC635E7AFD`
and
`CA4C56F1EC102093DDD06471FB97CD148986EEA9CB0040ADCB1829E06AAB38C5`.
Exact signed stdout SHA-256 is
`01EC796B75D23965E6C43C3ED175943B6D79E656A6B1BDA8B23C6EC5C911A131`;
`RESULT.json` SHA-256 is
`E6E18A713F66C4045D2FC0C25129C02993CEA8E042EEE4823AAF38CC169CD83A`.

## Export result

Normal execution emitted the required state
`PASS_PFC004LT1A_RESULT_EXPORT_V1`, proving the corrected normal/rehearsal
contract. It hash-matched frozen parent audit
`A1018988FF413C1C02AD0D90AC79C2657EFDAED689A99D700C6AE8191A70728E`
and exported exactly 36 parsed JSON source files totaling 11,135,086 bytes.
The exact returned-name mapping SHA-256 is
`EF6D8555882943C2E0E9014495A7068F94A2F505AEA11017F9E994970B6A9BD8`;
the export-audit SHA-256 is
`2B1D1B6B7200E4DE2DD262BA7D1A0890A884AB13A85CFFF16D7C6DC6FA670471`.
No source image was read or changed, no model was tuned, and no judgment raster
was built.

## Required next action

Build a separate signed `DATA_PULL` for exactly `F000.json` through
`F035.json`, `SOURCE_TO_RETURN_MAPPING.json`, and `EXPORT_AUDIT.json` under
approved root `JBOD_PROCESSOR_REVIEW`. Enumerate and path-gate every result
leaf and return hop, bind the installed route and queue-safety revision, verify
the exact signed package, and publish only after zero pending requests. Require
its matching signed terminal response and verify the returned container before
interpreting any per-wafer result.

The one notch-pose hold and five frozen-model holds remain uninterpreted. Do
not tune, build or present a judgment raster, start alignment transfer, or
score production defects first. All reusable fiducial workflow, V17R5,
wet-strip separation, other pending alignment/map/pose gates, and immutable
R5P30 authority remain unchanged.
