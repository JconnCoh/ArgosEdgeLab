# OCV-03 O3K1 actual-pixel notch gallery ready / operator review pending — 2026-08-27

## Disposition

`PENDING_GATE` — the exact render and one-file DATA_PULL both completed with matching JBOD-signed terminal responses. The local actual-pixel gallery is hash-verified and raster-provenance preflight passes, but the controlled browser rejects local `file://` URLs. Operator manual browser review is therefore the next and only active gate.

## Signed terminal chain

- Render request `REQ_20260827T201500111Z_62629419O3K1` was published exactly once with no retry.
- Matching render response `R_34948C162186_20260827202149504_651be723` is signature-verified; response ZIP SHA-256 `AB08F56DD42317734750CA27159694598268D4029656500FC2485D4D21517034`.
- DATA_PULL request `REQ_20260827T203242373Z_0DBC2A7558B3` was published exactly once with no retry; publication gate SHA-256 `9EB91E74C48F4EA6FDED8BFA574441298EB871B9E043859118C83E21A623AB27`.
- Matching DATA_PULL response `R_859705B2A128_20260827203835267_ee050a5b` is signature-verified; response ZIP SHA-256 `DD5FB84E80A8566F731249BB9D009A07044217C392D5F0C2B79E8E7133962E66`.
- DATA_PULL collection gate SHA-256: `5C2C873B0C77CEC7FCAA92CA34C961F52025B0924588706205DDF64ACD8F5DAE`.
- Exact reconstituted `O3K1_REVIEW.zip`: `5666342` bytes, SHA-256 `CEE193475613E04D0AD25F0402437E3E21E310EF1F8B1312737B28463699F724`.
- Render manifest SHA-256: `26F784FD7C5B4C35D89083CCAFDE5CD499F9CD3533AFE8319AD4877B38C8186A`.
- Asset set: 18 PNGs plus one render manifest; six candidate/channel groups for `S16-C1`, `S17-C1`, and `S17-C2` in BF and DF.

Both signed terminal gates preserve no detector rerun, no threshold or algorithm change, no source mutation or deletion, no task/process action, no provider activation, and unchanged protected-processor identity. Gateway acceptance was not used as execution evidence.

## Local gallery

- Gallery: `work/OPENCV_EDGE_NOTCH_O3K1/local_review/gallery.html`
- Gallery SHA-256: `6B929D147DE393F93BADA05AF55485B30D7C6A9B54604FC1C87683CF21E78623`
- Exact launch URL: `file:///C:/Users/joshua.conn/Desktop/ArgosDev/ArgosEdgeLab/work/OPENCV_EDGE_NOTCH_O3K1/local_review/gallery.html?manifest=assets%2FRENDER_MANIFEST.json`
- Review ID: `FMOCV03_O3K1_20260827T200000Z`
- Static gallery gate SHA-256: `FAFA4046323BE216007A9F01E2285F1110FC1873F58B04A8D31D04EE337E5279`
- Raster provenance preflight: `PASS_RASTER_PROVENANCE_PREFLIGHT`; 6 clean bases, 6 current overlays, and 6 current masks verified by hash; zero changed pixels outside every current mask.
- Local extraction prepared with no image decoding by PowerShell and no image bytes emitted into the task.

The page presents three equal-size candidate columns and independent BF/DF rows. A global opacity slider and Clean only, Overlay only, and Blink clean / overlay controls let the operator compare actual pixels. Green is the frozen fitted wafer perimeter, yellow is the frozen candidate interval bounds, and red is the frozen candidate center ray.

## Real-browser capability gap

The controlled Codex in-app browser rejected the exact local `file://` URL under its URL security policy. No workaround, localhost relay, alternate automation surface, screenshot, or image-byte return was attempted. Capability-gap SHA-256: `DE3AEF2A81930079C1274855F1C6D462D2F65EAE02EFC61E83C6115081921DAF`.

The raster-provenance release gate remains incomplete until the operator opens the exact local page and reports the visual result. Static verification is not substituted for that visual gate.

## Requested operator classification

For each candidate/channel, check whether the yellow interval brackets the visible physical indentation and the red ray crosses its apparent center. Then compare S17-C1 and S17-C2 to each other and to S16-C1. Report one of:

- `SAME_MANUFACTURED_NOTCH_FAMILY`
- `DISTINCT_MANUFACTURED_NOTCH_FAMILIES`
- `NON_NOTCH_COMPETITOR_PRESENT`
- `HOLD_VISUALLY_AMBIGUOUS`

Free-form observations are welcome, especially which candidate or channel looks wrong.

## Preserved holds and prerequisite order

- Slot16 and Slot17 remain review-only morphology holds; Slot18 remains the frozen O3J1 detector pass.
- The operator gallery does not itself clear a hold or change a detector criterion.
- No algorithm or threshold change is supported before the operator classification is recorded and assessed against frozen evidence.
- The frozen POST2 R6 regression remains mandatory before any later fresh hotspot detector successor.
- Patterned-wafer fiducial designation, map/pose/registration, coverage, sensitivity, transfer, XML, training, and production-routing prerequisites remain unresolved where previously recorded.
- Live provider activation remains disabled. The protected all-wafer processor, resident process, and inspection tasks remain untouched.

## Exact next action

The operator opens the exact local gallery URL, exercises Clean only, Overlay only, and Blink clean / overlay, and reports whether the overlays are wrong and whether S17-C1/S17-C2 are the same notch family, distinct notch types, a non-notch competitor, or visually ambiguous. Do not change detector code or thresholds, rerun O3D3R4, activate a provider, touch the protected processor, clear a hold, or begin a fresh hotspot successor before that file-backed operator feedback is received.
