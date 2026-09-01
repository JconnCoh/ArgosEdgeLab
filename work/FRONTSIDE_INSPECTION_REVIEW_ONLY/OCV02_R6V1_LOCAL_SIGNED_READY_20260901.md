# OCV-02 R6V1 local signed request ready — 2026-09-01

Disposition: `PENDING_GATE`

This checkpoint records the isolated scribe worktree's fresh review-only R6
real-image validation package. It does not change the shared inspection
processor, active backside provider, GUI, XML, training, production routing,
source images, wafers, tasks, or existing processes. It does not authorize
publication or activation.

## Frozen provider and batch

- Engine: `work/OPENCV_SCRIBE_V1R6/ArgosOpenCvScribeV1R6.py`, SHA-256
  `1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9`.
- Endpoint: `work/OPENCV_SCRIBE_R6V1/Invoke-R6V1ScribeBatch.ps1`, SHA-256
  `F805E8336FF0A1847D0326ED8A77FFC39207128E8C69177559D0F6BE9E888A25`.
- Batch: `work/OPENCV_SCRIBE_R6V1/BATCH.json`, SHA-256
  `7F77B8EFE0926E4AD37A737F07C98E1A3DF2E8F1392D0B47B886E05F9F52143B`.
- Exact frozen population: full-wafer BF/DF Slot22, Slot23, Slot24, and
  Slot25 from `62619-433_20260824005735` using the already recorded source
  paths and byte hashes. No source discovery or source mutation occurred.
- Execution is serialized: at most one OpenCV child, four maximum children,
  and no automatic retry.

R6 preserves R5 OCR mechanics and adds only same-rectangle localization
deduplication plus observed-geometry support for the configured OCR envelope.
The exact false-texture control is rejected before OCR expansion because its
observed height support ratio is `0.1054`, below the frozen `0.20` minimum.

## Local exact gates

- Offline locked parity: 15/15 PASS and duplicate-view regression 4/4 PASS;
  gate SHA-256
  `267086773F7233246FE621EAA8824B495DD4CE4369CD95D92D29438D7B14DE8E`.
- Offline full localization: 15/15 PASS and duplicate-view regression 4/4
  PASS; gate SHA-256
  `704EC0CB9303EA6DC74585A55213DD525773E44E77BBC8EE18DE203C2AF4789F`.
- Final exact Windows PowerShell 5.1 endpoint rehearsal:
  `PASS_R6V1_ENTRYPOINT_TEST_GATE_R2`, SHA-256
  `2831A8F082E1B6B6D43B460665E875200B6D666B84E9320E49D51AB9C03859DA`.
  It proves four serialized cases, zero identity-eligible results, four
  reference-coverage holds, source-alias removal on success and injected
  failure, hash-mismatch refusal before output write, and unchanged processor
  identity.
- Live-only self-pin gate: 4/4 endpoint dependency pins and 3/3 positive and
  negative branch controls PASS; SHA-256
  `58A296205B0A8398087E4059539932F0E5A1570488C601902ADF8D952D0E5A46`.
- Zero-recurrence preaction passed with 29 exact dependencies and fresh
  worktree-byte ZERO/ONE/MANY collection evidence. Preaction SHA-256 is
  `A0C0C8039240B7108CB4B9595B0E54E3A722D4B7753121206FAC0CE8C1A143E8`.

The earlier `R6V1_ENTRYPOINT_TEST_GATE.json` remains valid local evidence for
the predecessor endpoint bytes but is superseded by R2 after the live-only
self-pin fixture branch was added. It is not a package or publication parent.

## Signed package and route budget

- Request ID: `REQ_20260901T160000111Z_7F77B8EFE092`.
- Local ignored ZIP:
  `work/OPENCV_SCRIBE_R6V1/final/REQ_20260901T160000111Z_7F77B8EFE092.ready.zip`.
- ZIP SHA-256:
  `E4F62D6126F9FBEDD228CDDE8678136D7FDEFCF5CB2B3825BF1245E11BBF925D`.
- Manifest SHA-256:
  `7E38E273CAE0AE1DFF2E9B6FF476E8D1DDCF7B9FADC95759664A68C2B16A7C3B`.
- Signature SHA-256:
  `1A93BFA459892D94B98A281D9E8CA88C3E07C99BB21C091B7ABB30D138FB2D8A`.
- Final package gate:
  `work/OPENCV_SCRIBE_R6V1/R6V1_FINAL_PACKAGE_GATE.json`, SHA-256
  `04E8330DAF95AE6274626F50284B1312118402BD5565F44EEDBD56F940D9BFB4`.
- Complete route/path gate evaluated 175 request, response, endpoint,
  installed, source-alias, work, output, and return leaves. Maximum effective
  length is 193 and maximum component length is 63. Gate SHA-256 is
  `C34C5163AE3DA95BF58179B2CCCBAF61D79C4A24ADC4167118C3376FFB93F9A0`.

The final ZIP passed signature verification, exact extraction, all seven
payload hashes, maintenance `installedSha256 == endpoint payload`, and the
unchanged qualified queue-safety inheritance. The package is locally signed
but unpublished. Its own gate records `publicationAuthorized=false`,
`retryAuthorized=false`, `automaticIdentityAuthority=false`, and all XML,
training, production, activation, and hold-clearance authority false.

## Exact next action

Wait for the main task's current portal owner to provide an exact matching
signed terminal response and explicit portal-lane clearance. Then perform one
fresh current-route/share-health observation through the already qualified
read-only route, freeze the result, and only with separate publication
authority publish this exact ZIP once. Collect only its matching signed
terminal response. Do not retry, activate, clear holds, accept an identity,
begin XML output, or integrate the shared processor from this checkpoint.
