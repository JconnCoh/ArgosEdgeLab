# OCV-02 R18G local signed data-pull package ready checkpoint

Date: 2026-09-03  
Disposition: `PENDING_GATE`  
Authority: review-only; local build/sign/gate only; portal publication not authorized

## Frozen reader and cohort

- R18F provider SHA-256: `0E2CD994BB389F1DB5A50FCB2C5C9D0DD6C906925E206C913CB0FCEC1B1543B1`
- R18F local gate SHA-256: `5D2C076F47F0555DE7C23EA049DF1C49B144096A85308153A7E173B9EED5BD76`
- Supplemental reference manifest SHA-256: `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`
- R18G cohort SHA-256: `91A367581F02709301A03D972E7A96C68FC1371A33DC7E13B02997442220E2BA`
- R18G data-pull definition SHA-256: `D38269F2D4C04D6EC130E616800AFFDBC70835DF62CC35117625A3A0EED29C72`
- R18G selection gate SHA-256: `980A86CEF6CCD2324EAD4CD3297ACF1E10B1A9C20559EB7A3F9020650E8D3B6F`

The cohort remains pixel-blind. It contains eight exact current-reader
failures across seven lot families, split four development / four blind
validation, with zero R17A/R18A/R18E acquisition overlap. Both remaining
eligible POST2 rows are included. Missing `I/O/V/Y` coverage remains held.

## Exact local signed request

- Request ID: `REQ_20260903T220000000Z_R18G`
- ZIP: `work/OPENCV_SCRIBE_R18G/final/REQ_20260903T220000000Z_R18G.ready.zip`
- ZIP bytes: `1414`
- ZIP SHA-256: `B78FE1E9112FEEEB22FBDA3AA442B81237A207C26F6A62E4E1AAADFD5DA5AEE4`
- Manifest SHA-256: `50AD77EEA2DEA73C623BDB324EEA5E01AE7B4AA954305376E60499235BF2DD12`
- Signature SHA-256: `7ADC2D1E39596EE3BEDD7CFAFCF7659B5C460FAE1D3B664C499877EEB0302D24`
- Signer thumbprint: `C82181052919C475CF888F49427C1B55AE65DC12`
- Expires UTC offset value: `2026-09-04T17:03:25.5014181-05:00`

The unchanged qualified `DATA_PULL` endpoint is asked for exactly 24
already-existing files beneath `JBOD_PROCESSOR_REVIEW`: eight proposal JSON
files and sixteen paired BF/DF oriented detector-input PNGs. The cap is
50,331,648 bytes. It does not request full-wafer images, crop creation, source
writes, tasks, processes, provider activation, or identity decisions.

## Gates

- Local cohort gate SHA-256: `45A9E144E3D580A6A01DB7EBAF6113C1741A44D6ECE18930A926472C165DDBCE`
- Source/extraction path gate SHA-256: `49FC01CF92AD431168162BD614EA9A1D8E18FFE90894E5BCB48655E7E8269B0E`
- Pre-action contract SHA-256: `A4084CC9E8B520E01BDE0F81D2D7B7DC4AC189E9DDCFD2EA38B41B0B6A445E44`
- Builder SHA-256: `729C0923FFAEE7F3964B704E8185FF563F6DA19CA552B09439BD3B320A98E0E5`
- Clone-literal gate SHA-256: `39C10395424EB0C75C6D1C136341FF25619C927DD7C03566A4E01B48A673139F`
- Tooling gate SHA-256: `1876E72B8CA626E4BAED6CA016CF93493B39713451E1CC0BD48E2867D969898A`
- Final package gate SHA-256: `B36DACA9EBBD44906EC021B48DA67D0C3F4C72436880A52880E8DFA262B19073`
- Complete-route/path sidecar SHA-256: `5F4E1434B142EED5C85517AEFD11614D0D8380424219BB5B6A9BE219403E2646`

Windows PowerShell 5.1 parser, harness, wrapper, clone-remediation,
zero-recurrence pre-action, exact ZIP extraction/signature, and complete-route
path gates passed. The 26 modeled route leaves have maximum effective length
182, maximum component length 53, and 32 reserved suffix characters.
Temporary build roots `C:\R18GB` and `C:\R18GV` were removed.

## External-state proof and next action

The exact request ID is absent from portal upload, ready, and processed paths.
No portal request was published and no JBOD action occurred. The package and
route gates record `publicationAuthorized=false` and
`explicitPublishRequired=true`.

Next action: commit and push the frozen package bytes, verify the dedicated
branch is clean and matches origin, then stop. Publication requires a new
explicit operator `PUBLISH` for R18G, may occur once only, and has no retry.
After a matching signed terminal response is collected, verify frozen R18F
before reading development pixels; freeze a successor before blind review.
Identity acceptance, automatic reference admission, automatic hold clearance,
XML, training, production, and provider activation remain unauthorized.
