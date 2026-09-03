# OCV-02 R18E local signed data-pull package ready checkpoint

Date: 2026-09-03  
Disposition: `PENDING_GATE`  
Authority: review-only; local build/sign/gate only; portal publication not authorized

## Frozen reader and cohort

- R18D diagnostic provider SHA-256: `39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1`
- R18D local gate SHA-256: `0E3D94DBA81B37C83667FE7AE61E17D06476DDC4B466F86C58502EA52471609D`
- Supplemental reference manifest SHA-256: `8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A`
- R18E cohort SHA-256: `A36B94205B56CAF67B69D7CFB48651CC0D185AA74496CA4C7BF6EA2D5AC3931C`
- R18E data-pull definition SHA-256: `C4787C80AB9AFB05772112EED4D9DCAB83CFB26EEDF77317E1555B518B03AE5B`
- R18E selection gate SHA-256: `70C6862FDDBA435B77515266C31612F5819F51F333EE829E32843B13A3D38C0E`

The cohort remains pixel-blind. It contains eight exact acquisitions across six
lot families, split four development / four blind validation, with zero R17A
or R18A acquisition overlap. Lot context selected candidates only and did not
assign wafer identity truth.

## Exact local signed request

- Request ID: `REQ_20260903T192241716Z_R18E`
- ZIP: `work/OPENCV_SCRIBE_R18E/final/REQ_20260903T192241716Z_R18E.ready.zip`
- ZIP bytes: `1414`
- ZIP SHA-256: `C0218B20414CB2DF0B1C11F5273BD0C989CB6EE550D048C6163F5E21E8A2A502`
- Manifest SHA-256: `7A7730326DB7117587278318FA8EA92414783553D2204C75E9944592D66D8442`
- Signature SHA-256: `D5D07748843453A66E6AB6E702A50643AF0C96DA4A96059587B6B299CCA1BDC8`
- Signer thumbprint: `C82181052919C475CF888F49427C1B55AE65DC12`
- Expires UTC: `2026-09-04T19:31:19.7027286+00:00`

The request asks the unchanged qualified `DATA_PULL` endpoint for exactly 24
already-existing files beneath `JBOD_PROCESSOR_REVIEW`: eight proposal JSON
files and sixteen paired BF/DF oriented detector-input PNGs. The cap is
50,331,648 bytes. No full-wafer image, crop creation, source write, task or
process action, provider activation, or identity decision is requested.

## Gates

- Local cohort gate SHA-256: `C094EBC16024B2324E2EF68852A9F98280A419DF62375C8785A4424C19620A7B`
- Source/extraction path gate SHA-256: `32B29DC749B708C1281800CC7F8D962AF6C4758247BE9E97E5828FD18C856140`
- Pre-action contract SHA-256: `8D4393F7ACFCF7CC0DDB9F712F0122D5EF48C6E5B6310DFCFE3CBEF1D730FC61`
- Builder SHA-256: `24AF04B66C70D6BE9FD9B9BEAA118712E29C248AFB71A08A47F8A94B8B74A9A4`
- Clone-literal gate SHA-256: `32C3FE7BCDCD8A76038C5E9DDB68443D6864D40356465071EA92669E0ED7186F`
- Tooling gate SHA-256: `E6A573020F88F38429DFDEA7890FB292CE0384E559BB2907A7ECA5E01EE28FCA`
- Final package gate SHA-256: `F7A012A7F5920A68B702027AC6A0DDDEA4F434B708F098E4BBB818C49A3FEB26`
- Complete-route/path sidecar SHA-256: `E5219DD8D6DDCA9C41DC9B3BC0B029267EB95CB65D8899CD166E7959167E39B4`

Windows PowerShell 5.1 parser, harness, wrapper, clone-remediation,
zero-recurrence pre-action, exact ZIP extraction/signature, and complete-route
path gates passed. The full modeled route has 26 leaves, maximum effective
length 180, maximum component length 53, and 32 reserved suffix characters.
Temporary build roots `C:\R18EB` and `C:\R18EV` were removed.

## External-state proof and next action

The exact request ID is absent from portal upload, ready, and processed paths.
No portal request was published and no JBOD action occurred. Package and route
gates explicitly record `publicationAuthorized=false` and
`explicitPublishRequired=true`.

Next action: commit and push these frozen package bytes, verify the dedicated
branch is clean and matches origin, then stop. Publication requires a new
explicit operator `PUBLISH` for R18E, may occur once only, and has no retry.
After a matching signed terminal response is collected, verify the frozen R18D
reader before inspecting blind-validation pixels. Identity acceptance,
automatic reference admission, automatic hold clearance, XML, training,
production, and provider activation remain unauthorized.
