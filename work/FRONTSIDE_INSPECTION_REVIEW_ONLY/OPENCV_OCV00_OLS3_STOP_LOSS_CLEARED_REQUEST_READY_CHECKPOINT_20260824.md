# OpenCV OCV-00 OLS3 Stop-Loss Cleared / Request Ready Checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

## Scope and migration order

OCV-00 remains the active work package. The fixed migration order is:

1. OCV-00 exact operation/source inventory and frozen regression baselines;
2. OCV-01 configuration-selected OpenCV provider platform;
3. OCV-02 scribe deciphering;
4. OCV-03 independent perimeter, notch, and global pose;
5. OCV-04 reusable fiducial localization;
6. later family work packages in the locked migration program.

Fiducial implementation is not the first step and has not begun. The current
action resolves metadata authority for the operator-selected JBOD lot
`D:\KLARFExport\PatternedFront\Lot_62619-433`.

## OLS2 incident review and bounded OLS3 recovery

Both signed OLS2 incident premise failures were reviewed. The first proved
that the OLS2 entrypoint rejected an incomplete inventory result; the second
proved that the stable OLS2 output was absent when requested. Neither proves
that the selected lot or its image files are absent.

The direct post-failure observation is pinned at
`work/OPENCV_OLS3/OLS2_POST_FAILURE_OBSERVATION_EVIDENCE.json`, SHA-256
`B3688B81727654C02111CE2A3BC8DC61D0F7E55D132E3C33C042A46936861C5B`.
The workflow review clearance SHA-256 is
`FE505A47A819CE63C9F621CE0762DE7934202B9F3B92727BC02C535C4CE564D9`.
The fresh frozen MUTATE intent SHA-256 is
`E8178DA721A2B3CDC684B3E102935DC42250FFB2B907EECEDFE027B66A69BD71`.
Together they explicitly clear the two-failure mutation stop-loss for one
minimal metadata-only request, with no retry.

## Exact request ready

`REQ_OLS3` is frozen, signed, and packaged locally but is not yet published.
It reuses the unchanged tested metadata provider worker SHA-256
`CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250`.
The corrected entrypoint preserves useful bounded metadata as either
`COMPLETE` or `HOLD_INCOMPLETE`; it does not turn incomplete evidence into a
pass and does not discard the partial inventory.

Frozen evidence:

- entrypoint gate: 10/10 cases pass, SHA-256
  `4BECCB3A5C1A7EF5A3E508CE11CA41854EEC77C06181EAB0000876AE750AF95B`;
- complete clone/literal gate R4 SHA-256
  `CCEC08EC2579724F60EBB9848293BCD87D0383374FC8E1FF58D810A763AC85D9`;
- signed-source gate SHA-256
  `3CB3B683CFB6FF54C8778F0E76B3AC780D92C799A379F67BD80F1E2EF3D319C5`;
- exact final ZIP: 21,033 bytes, SHA-256
  `952C6C02ED5E7C18EC9976F2226D5DFA8403DC990CB0D9919F4A5774BACFF09C`;
- final-package gate SHA-256
  `D7151F914D4D8C303CF270DFF9380ABF725C322EF7C5D08C25D413BA14C7CB58`;
- complete 50-path gateway/Argos/JBOD/return route gate SHA-256
  `932C792DA3095FA43FF1749775D7F4BD3473FA6043ABE86C449FBA16A3914F3A`,
  maximum effective length 187 and maximum component length 51.

The request can return directory and BMP-leaf metadata only. It reads no file
content or image bytes, hashes no source image, decodes or processes no image,
changes no inspection task or processor process, deletes no source, aborts no
wafer, and grants no inspection or production authority.

## Next action and preserved holds

Verify current continuity, session safety, exact branch-tip equality, zero
pending gateway requests, and create-new request uniqueness. Then publish
exactly one `REQ_OLS3` ZIP through the established Project Portal gateway and
wait for its matching signed terminal response without retry.

If the signed inventory is `COMPLETE`, freeze the exact BF/DF source partition
before any source hashing or image read. If it is `HOLD_INCOMPLETE`, use its
bounded metadata only to narrow one exact follow-up observation; do not claim
completion. No OpenCV image-processing code is written or run at this stage.

The healthy processor and all existing global FS15, notch, map, pose,
fiducial-site, composite, registration, defect-scoring, reviewer, R10/AVS1,
XML, training, production, deletion, and wafer-action holds remain unchanged.
