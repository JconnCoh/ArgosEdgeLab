# OCV-02 O2D17 Slot19 live-self-pin-corrected request publication-ready checkpoint — 2026-08-27

Disposition: `PENDING_GATE`.

Authority remains review-only. This checkpoint does not accept wafer identity,
clear any hold, activate the OpenCV provider, restart or replace the protected
processor, authorize XML/training/production routing, mutate source or wafer
state, or expose independent-validation Slots22-25.

## O2D16 terminal failure and mandatory stop-loss review

O2D16 was published exactly once and returned the matching signed terminal
response `R_43B046749202_20260826234809840_3bbc13fa`. The response signature,
signer, request identity, ZIP hash, manifest hash, and attached failure hashes
all passed. The endpoint failed at its own line 97 because the endpoint's
hard-coded live job SHA-256 did not match the packaged O2D16 job SHA-256:

- response ZIP SHA-256:
  `7A78A5EFEAF2C1015EBBA67D3B08D8A4C0CB1DF5B6D703E58C515B61F2F995E5`;
- exact terminal failure gate SHA-256:
  `1A6D61C2234E90533922B1A410E7CA653FDC882B5DA7A6D4FF32820F08671B8D`;
- stderr first line: `O2D16 live job changed.`;
- endpoint-pinned job SHA-256:
  `D14E47EF05FAF9FD8EC1C687E005BEC878C13FC69DF3B738B5B4762492A6B089`;
- packaged job SHA-256:
  `146C2E2A7973BA525983158552549C2FE42A6ACCAC663542D9200DC000F2CD5D`.

The failure occurred before alias creation, source-image reads, work/output
creation, Python start, processor contact, provider activation, source or wafer
mutation, and hold clearance. O2D16 is terminal diagnostic evidence only. It
is non-reusable and is not a publication parent or template.

This was the third signed premise failure in the Slot19 incident. Direct
post-failure observation, the stop-loss workflow review, and its one-successor
clearance are file-backed. Their SHA-256 values are respectively
`65BA70C9CB96D925B1DBCA47F9A90619BB72F6930913C7B389A3591A3DEAAB72`,
`32275F147DECC49E7E3751139AA681D37E62D6C0FA9671357A789E2C8983E606`,
and
`9C93C8A154FABA4DD83E6FE508A8E7472A6C4A208D4332B120C07783DD7DBE5D`.
Fresh O2D17 recovery-intent SHA-256 is
`CC5F7C6A4D2500BF6A66738D89B7F5DC7BD13EC73B0DAD5F91E2DDC4BF912B96`.
It clears stop-loss for exactly one fresh O2D17 publication and never permits
an O2D16 retry.

## Scribe execution remains required despite the notch hold

The upstream Slot19 state remains `SCRIBE_IDENTITY_CONFIRMATION_HOLD` with
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD_MULTIPLE_OR_NO_NATIVE_MORPHOLOGY`. That hold is
preserved as context and does not skip the requested scribe read. O2D17 binds
the exact frozen OLS6 raw BF/DF pair for
`62619-433_20260824005735_Slot19`, creates the temporary JBOD-local `X:` alias
only during bounded execution, and removes it on every terminal path.

- BF bytes `475379874`; SHA-256
  `83362565391B7245DAB450B67A6EF79062CAC431D6E7259E0ECEA594DCA3C239`.
- DF bytes `475379874`; SHA-256
  `3F1CF8D84C5E4C3F4DFADD6368A0DE667B06D956F664CD69C5B4390F5ABC5256`.
- Frozen source inventory SHA-256:
  `E54A15301A2B4FE914E6315DDFB9628E1D1364B0553D2155E9D5387A88E7FF3B`.
- V1R5 engine SHA-256:
  `F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`.

The exact Windows PowerShell 5.1 entrypoint rehearsal read image-first string
`FE5565R022F5`, result state `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, and checksum
state `SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`. These are development facts,
not accepted Slot19 identity. The rehearsal retained automatic-localization,
upstream notch/identity, ambiguity, and `SCRIBE_REFERENCE_COVERAGE_HOLD`; it
proved the reader executed, a source-hash mismatch failed before write, the
alias was removed, the provider remained disabled, and the protected processor
was unchanged. Entrypoint-test gate SHA-256 is
`DDDBE65A9D5D5C21A202C2AFB27B7BE6AECAE52427D461E51D66A100C6FCB925`.

## O2D17 self-pin and frozen request proof

O2D17 was built from the O2D13 approved development baseline and the current
V1R5/raw-source specification. O2D15 and O2D16 were excluded as parents and
templates. The endpoint pins and the signed package contain these exact six
dependencies:

- endpoint payload SHA-256:
  `FF885657C01EEF2CC17DC19D4A8773F7F355855C1FE50FE91F0E09DBA8B2F2DA`;
- job SHA-256:
  `A60B494AB1F88A937372E8ABE2B30513037E6DFF486BC23A41FA8D66FBA03563`;
- engine SHA-256:
  `F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`;
- reference bundle SHA-256:
  `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`;
- installed processor SHA-256:
  `1289C59BA4A8A6E3063D96C259C6AB95855458525A73A9042ACF6B7B93B80F4C`;
- raw BF and DF SHA-256 values shown above.

The exact self-pin and live-branch gate exercised all six matches plus good,
bad-job, and bad-installed-processor branches. Both injected bad branches
failed before alias creation or image read. Gate SHA-256 is
`D45685722EFB79BA14DA656BFB85E73BBE3B31596971D608B1BEEBD92A864898`.

- Revision: `O2D17_20260827T000000000Z_CC5F7C6A`.
- Request: `REQ_20260827T000000111Z_CC5F7C6ABF26`.
- Request ZIP: 21,404 bytes; SHA-256
  `21DD0588B7FEDA639EA039585EC1B09615E300C410488651AE9ED3E3FF7C662B`.
- Final-package gate SHA-256:
  `6111AF1177332DE4A7AAA1EED9A2443A5A588B78FFF1645610C3F876EA243167`.
- Endpoint payload, maintenance `installedSha256`, extracted signed manifest
  `installedSha256`, and final-gate declaration all equal the endpoint hash.
- Complete route evaluates 129 materialized leaves with maximum effective
  length 193 and maximum component length 63.
- Complete-route PASS gate SHA-256:
  `B938B5103A6F182F9551CA59C573BEE9336444E5B6C993EDB4966B56E2B96CF4`.
- Persistent exact `U:` alias gate SHA-256:
  `407026224B938116C1AEAA46CB0B3A569E40E5E97EB8CB3D73FA59ADDA992646`.
- Current share observation found zero pending ZIPs/uploads, retained the
  persistent `U:` mapping, found the matching O2D16 response, and proved both
  O2D17 publication names absent.

Exactly one create-new O2D17 publication is authorized after continuity,
metadata-only session safety, and matching clean local/origin tips pass. Retry
is false. Response collection is restricted to the matching signed terminal
response.

## Unresolved prerequisites and exact next action

`SCRIBE_REFERENCE_COVERAGE_HOLD`, Slot19's upstream notch/identity hold, the
development automatic-localization hold, every pre-existing map/pose/fiducial
hold, and the separate `lot62631586FrontGuiRecovery` `PENDING_GATE` remain.
None is cleared or superseded.

Slots16-18 remain frozen development evidence. Slot19 is started but not
frozen; Slots20-21 have not started; Slots22-25 remain unseen. The live provider
remains disabled and the protected processor remains untouched.

Next: publish the exact O2D17 ZIP once, then collect and verify only its
matching signed terminal response. Do not retry. On exact signed pass, freeze
Slot19 as review-only development evidence without accepting identity and
continue directly to Slot20, then Slot21. After Slots19-21 complete, freeze the
scribe engine and run Slots22-25 blind without tuning. Only then proceed to
OCV-03 edge/notch work, including `Lot_62629-419_NotchBad_Hotspot`, every
discoverable known chipout wafer, independent BF/DF pose, zero wrong rotations,
zero chipout-as-notch selections, and fail-closed ambiguity.
