# OCV02 R6V1 signed live geometry-hold checkpoint

State: `PENDING_GATE`

The exact frozen review-only request `REQ_20260901T160000111Z_7F77B8EFE092` was published once. The gateway accepted it, and the matching JBOD terminal response `R_B4C04F87A1E5_20260901212658192_c4776b8b` was collected and cryptographically verified against signer `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

- Publication gate SHA-256: `A589F88EC47F1F9FCA456776A16551823BC955B01392BC3AD0109B53F3C3C4A4`
- Response ZIP SHA-256: `6C100BCB92F53FE9E22D4DDD3B3D490ADBFDD81C398389D2372B34E19E7137FD`
- Signed-terminal collection gate SHA-256: `AD17B7AB10CDED9C8B19AFEC42F4D9FFE55D38FBAE314DD5C9280E35F34CEA83`
- Four-case signed-batch adjudication SHA-256: `9AE97C3D24558DF9EFE9C524C267035118D5C91812DD9AFCDEDCA4975DF9C2D0`

All four real cases (`Slot22` through `Slot25`) remained held with `SCRIBE_AUTO_LOCALIZATION_GEOMETRY_HOLD`; identity eligibility stayed zero. Each case produced four exception-search diagnostics that collapsed to one unique geometric candidate. The common candidate width ratio was `0.7680559538006783`, while the height ratio was `0.10538907694518568` against the frozen minimum height ratio `0.2`. The candidate was therefore rejected before OCR and no scribe proposal was formed.

The response ZIP carried the signed batch gate in `MAINTENANCE.stdout.txt` but did not return the four full `RESULT.json` files or the JBOD output tree. The gate-level four-case outcome is adjudicated; deep per-result provenance validation remains unavailable without a separately authorized read/data-pull. No second request, retry, identity acceptance, hold clearance, provider activation, XML work, or production action was performed.

The next bounded local detector action is to calibrate a lower image-derived observed-height envelope from the frozen offline controls and retain the width, duplicate-collapse, reference-coverage, development, and no-authority gates. Any later live execution requires a fresh explicitly authorized revision and is not a retry of R6V1.
