# OCV-02 O2D16 Slot19 corrected raw-source request publication-ready checkpoint — 2026-08-26

Disposition: `PENDING_GATE`.

Authority remains review-only. This checkpoint does not accept wafer identity,
clear any hold, activate the OpenCV provider, restart or replace the protected
processor, authorize XML/training/production routing, mutate source or wafer
state, or expose independent-validation Slots22-25.

## O2D15 terminal failure and stop-loss review

O2D15 was published exactly once and returned the matching signed terminal
response `R_9641D12F7275_20260826231910853_331d63ea`. Signature and request
identity passed. The endpoint rejected the package before entrypoint execution
because the signed maintenance declaration named the O2D14 endpoint hash while
the payload contained the O2D15 endpoint:

- terminal response ZIP SHA-256:
  `C7DE7023A7921A14ADDDAC80A781144754C3A103B245F90DA1E62CD1E207F08F`;
- terminal failure gate SHA-256:
  `50656FD549D1DFB8E824A60B22FA47F41C7CD3943F7AD2A9B411F14344618F46`;
- failure: `Maintenance source hash mismatch: payload/Invoke-O2D15ScribeEndpoint.ps1`;
- declared installed SHA-256:
  `29EAE036C05009CEAF35820EAB45BCFCB19832F9A25256B4EDD7BF8867871C80`;
- actual O2D15 payload SHA-256:
  `748C9DCB2E20F653A367D091A588BDA3AC93CCCE653F20F3D0C047D0580E8F61`.

O2D15 did not execute its entrypoint, read source-image bytes, change an
installed file, start or restart a task/process, activate a provider, touch a
wafer/source, or clear a hold. It is failed, non-reusable, and is not a parent
or template for publication.

This was the second signed premise failure in the Slot19 incident. Mutation
stop-loss was activated, then cleared only after direct file-backed
post-failure observation and workflow review. Review and clearance SHA-256
values are respectively
`63D8CF225CCA941D1985DB2F68F791F90438F4A25D1BBF882AE2C0F6E9FF0FFE`
and
`D907C6475B4D7D2F6AB09412952E7A307F7877A01B4102FCC3D0617636FAE8C4`.
Fresh O2D16 recovery-intent SHA-256 is
`036FCF3FFC1D866A64D7BCCA337E8E4D338E1C48778DED51C3C7E8A94B397DED`;
it authorizes one new namespace and no O2D15 retry.

## Why the notch hold does not suppress OCR

The upstream Slot19 notch/identity state remains
`SCRIBE_IDENTITY_CONFIRMATION_HOLD`, but operator direction requires scribe
deciphering to continue. O2D16 binds the exact frozen raw BF/DF full-wafer
sources from `OLS6_EXACT_TWENTY_SOURCE_HASHES.json`, creates the temporary
JBOD-local `X:` source alias only during the bounded OpenCV execution, and
removes it on all terminal paths.

- Physical identity: `62619-433_20260824005735_Slot19`.
- BF bytes `475379874`; SHA-256
  `83362565391B7245DAB450B67A6EF79062CAC431D6E7259E0ECEA594DCA3C239`.
- DF bytes `475379874`; SHA-256
  `3F1CF8D84C5E4C3F4DFADD6368A0DE667B06D956F664CD69C5B4390F5ABC5256`.
- Frozen source-inventory SHA-256:
  `E54A15301A2B4FE914E6315DDFB9628E1D1364B0553D2155E9D5387A88E7FF3B`.
- V1R5 OpenCV engine SHA-256:
  `F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`.

The exact Windows PowerShell 5.1 rehearsal passed with evaluated image-first
string `FE5565R022F5`, result state
`SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, and checksum state
`SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`. Those are rehearsal facts, not
accepted Slot19 identity. The rehearsal explicitly proves that the upstream
notch hold did not skip OCR, both automatic-localization and
`SCRIBE_REFERENCE_COVERAGE_HOLD` remain, an injected source-hash mismatch
failed before write, the alias was removed, and processor identity remained
unchanged. Gate SHA-256 is
`DCCB416A83B0828C20694C6A75B92FB1F450E7807229DC62E4027E4EAB7EF3E6`.

## Frozen O2D16 request and route

- Revision: `O2D16_20260826T232833075Z_7A14DACF`.
- Request: `REQ_20260826T232833075Z_7A14DACFBF26`.
- Request ZIP: 20,968 bytes; SHA-256
  `9B8F9EEDF5C39BDBE36968938C04C39D9C8FDD19C95FBBD55E107B5B469E36FD`.
- Final-package gate SHA-256:
  `2AA66D10A147DFE303CA1D0F228127E7ADFD1757B502A3A34919D95B91DB2F71`.
- Endpoint payload SHA-256, maintenance `installedSha256`, extracted signed
  manifest `installedSha256`, and final-gate declared installed SHA-256 all
  equal
  `AC85BD4CD2CF8211EC2546F715298B9C62944B1FBF175569D9D24703AEC1DA7D`.
- The builder mechanically rejects any future inequality among those values.
- Exact no-argument Windows PowerShell 5.1 gate SHA-256:
  `13827071DF60DCB30911AB9D5B35F6D8577DBF916B3F9A9C5D68F80A58E6663B`.
- Complete route evaluates 129 materialized leaves with maximum effective
  length 193 and maximum component length 63.
- Complete-route PASS gate SHA-256:
  `D218E70E5264402DE1C50B25B9730D5B89B730464D10324A65A5168A38BE9F40`.
- Persistent `U:` alias gate SHA-256:
  `88CCD4B1E998958C44BEFC156A09B7177087FB80241EE063D5F5216DEC3D91AA`.
- Fresh share observation found zero pending request ZIPs/uploads, retained
  the persistent exact `U:` mapping, found the matching O2D15 signed response,
  and proved both O2D16 publication names absent.

Exactly one create-new O2D16 publication is authorized after continuity and
metadata-only session safety pass and matching clean local/origin branch tips.
Retry is false. Response collection is limited to the matching signed terminal
response for this request.

## Unresolved prerequisites and exact next action

`SCRIBE_REFERENCE_COVERAGE_HOLD`, Slot19's upstream notch/identity hold, the
development automatic-localization hold, every pre-existing map/pose/fiducial
hold, and the separate `lot62631586FrontGuiRecovery` `PENDING_GATE` remain
unchanged. None is superseded by this request.

Slots16-18 remain frozen development evidence. Slot19 is started but not
frozen; Slots20-21 have not started; Slots22-25 remain unseen. The live provider
remains disabled.

Next: publish the exact O2D16 ZIP once, then collect and verify only its matching
signed terminal response. Do not retry. On an exact signed pass, freeze Slot19
as development evidence without accepting identity and continue directly to
Slot20, then Slot21. After Slots19-21 complete, freeze the scribe engine and run
Slots22-25 blind without tuning. Only then proceed to OCV-03 edge/notch work,
including `Lot_62629-419_NotchBad_Hotspot`, every discoverable known chipout
wafer, independent BF/DF pose, zero wrong rotations, zero chipout-as-notch
selections, and fail-closed ambiguity.
