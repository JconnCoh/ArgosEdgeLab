# Front-metal native-peer confirmation V1.6 checkpoint — 2026-08-11

## State

`PASS_FRONT_METAL_NATIVE_PEER_CONFIRMATION_REVIEW_V1_6_REVIEW_ONLY`

This checkpoint adds a deterministic native-peer physical-damage confirmation
layer to the operator-approved canonical BowComp reviewer. It does not grant
automatic reject, training, XML, binning, or production authority.

## Exact operator feedback

- Feedback:
  `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- Feedback SHA-256:
  `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- 74 saved strokes: 70 positive defect marks and four false-detection scribe
  controls.

The feedback remains audit truth only. It was not applied automatically to a
detector mask or model.

## Detector and replay

- Detector source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FrontMetalNativePeerPresenceV2.cs`
- Detector-source SHA-256:
  `B3DE991972B2CC0E20024E81BC115601D9BF857B8E2CD14334BF8E984EC36AFF`
- Cached-peer replay source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FrontMetalCachedPeerSupportReplayV2.cs`
- Replay-source SHA-256:
  `AAAB4D659EBE499183B0A3B35CDCDA76BBF451B90E474B82F7F75B90774471E2`
- Batch runner SHA-256:
  `B2131C4BE2E9C372FB223106F7A5FB791F69D14999B03F3EEFC6F5C3CF27BB44`
- Primary replay:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM_REPLAY_V2_R1/BATCH_RESULT.json`
- Replay SHA-256:
  `844C0DB93CDB36C861906FCD5DEE33B8931B9A8E223CAEBD94EAFA01BDBC76E7`
- Determinism result:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM_REPLAY_V2_DETERMINISM/DETERMINISM_RESULT.json`
- Determinism SHA-256:
  `378D41D57E058D584B81DAB5910FEA5ACD3F9249D3F09D9F63EC6A8902745D82`

The replay evaluated the 11 operator-selected native `2400 x 2000` BF/DF
fields at scale X=1 and Y=1. The independent repeat matched all 66 emitted PNG
and CSV artifacts byte-for-byte. The primary replay produced 85,785
native-peer confirmation pixels and 100,102 frozen-plus-native-peer review
union pixels. Scribe, holder, and boundary overlap were all zero pixels.

The cached peer support reconstructs the already-qualified native peer masks
and recorded strict-support cardinality. It is confirmation/localization
evidence only. A complete peer-image residual regeneration remains a separate
transfer check and does not block this review revision.

## Feedback audit

- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM_REPLAY_V2_FEEDBACK_AUDIT_R1/FEEDBACK_AUDIT.json`
- Audit SHA-256:
  `B44D890452D4746A6C1AB74DE1C8669DC653E7C1FF48EE6D49A3B720A30D4790`
- Review union touched 43/70 positive marks.
- Native-peer confirmation alone touched 39/70 positive marks.
- Neither layer touched any of the four scribe false controls.

| Class | Operator marks | Review union touched | Native-peer touched |
|---|---:|---:|---:|
| Scratch | 53 | 41 | 37 |
| ResidueStreak | 8 | 0 | 0 |
| Contamination | 5 | 2 | 2 |
| Residue | 4 | 0 | 0 |

This revision strengthens physical-damage/Scratch presence. It does not solve
the separate residue and residue-streak branch. The remaining review-union
misses are in T09 (1), T16 (3), T17 (11), T21 (1), and T29 (11).

## Canonical reviewer

- Review directory:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FRONT_METAL_NATIVE_PEER_V1_6_20260811T220500Z`
- Manifest SHA-256:
  `162BFE2CD4AC86FC7C2188A41514E2C718B715040B4FFEE769CF8D6D332486EB`
- Build-result SHA-256:
  `BB37E65A7B3CA52664319E5BBD59138DA962F2FA1F226FD40A68E69EB99BE952`
- Final state:
  `PASS_FRONT_METAL_NATIVE_PEER_CONFIRMATION_REVIEW_V1_6_REVIEW_ONLY`

The build copied the locked original BowComp reviewer and preserved its
byte-identical canonical `styles.css`, required tabs, control IDs, four
highlighter actions, native-coordinate capture, queue workflow, and staged
feedback semantics. It contains 11 native fields and 22 detector alpha assets.
All manifest asset links exist, the local HTTP index and manifest return 200,
and no HTML, JavaScript, or JSON contains embedded image/base64 payloads.

Use `START_CANONICAL_FRONT_METAL_NATIVE_TILE_REVIEW.cmd` in the review
directory. The `Review presence union` and `Native-peer confirmation` panels
are localization/confirmation aids. Native raw BF and DF remain the only
physical footprint and defect-size authority.

## Authority

- Review only: yes.
- Automatic reject authority: no.
- Human feedback applied automatically: no.
- Training eligible: no.
- XML eligible: no.
- Production eligible: no.

