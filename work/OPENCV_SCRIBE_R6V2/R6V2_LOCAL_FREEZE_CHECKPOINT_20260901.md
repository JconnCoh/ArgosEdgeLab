# OpenCV scribe R6V2 local freeze checkpoint

- State: `PENDING_GATE`
- Scope: isolated `codex/opencv-scribe-deciphering` worktree only.
- Provider algorithm: unchanged R6 bytes, SHA-256 `1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9`.
- Configuration: SHA-256 `C5343C53E94EB2297FBE0637D13E9684D1C11CC3134E856FACE5C57450CB3C92`; minimum observed height ratio `0.2061033678437273`; width envelope unchanged.
- Derivation: midpoint between the frozen positive morphology floor `0.3068176587422689` and signed false-texture ratio `0.10538907694518568`. The Slot22-25 live candidate equals the false-texture control and remains rejected.
- Frozen-control regression: 15/15 exact identities; duplicate agreement 4/4.
- OCR expansion regression: 15/15 exact and duplicate agreement 4/4 at 0, 2, 4, 6, 8, and 12 pixels.
- Negative injections: false texture rejected, just-below floor rejected, at-floor accepted, widened identity authority refused, geometry and reference holds preserved.
- Entrypoint rehearsal: four serialized real-image children passed under Windows PowerShell 5.1; bad source hash failed before write; identity eligible count zero; four reference-coverage holds preserved.
- Local signed package: `REQ_20260901T220000222Z_5A348AE509A4.ready.zip`, SHA-256 `1048FB48EFDB736D397A856E75AD1A3F8B0D59599766636F9ABB1353C2AB291D`.
- Final package gate: SHA-256 `AF461D346CF6A6FAFD9B3B63FF6F13E0DDB9EF84DEF0E3E1871D739D0B8545BA`.
- Complete route gate: 184 paths, maximum effective length 193, maximum component length 63, PASS.
- Publication: not authorized and not performed.
- Activation/identity/XML/training/production authority: unchanged and false.
- Existing holds and no-retry restrictions: unchanged.
- R6V1 locked parity rerun was not used because its historical baseline dependency pin no longer matches the current branch copy; the already-frozen R6 parity gate remains predecessor evidence. R6V2 independently reran the positive/negative height semantics, all 15 controls, duplicate collapse, expansion regressions, and entrypoint cases.
- Automatic task rollover is required before further work because the fresh required evidence exceeds the 10,000-line task threshold.

Next action after rollover: inspect this frozen local commit, preserve all authority holds, and wait for explicit `PUBLISH` before any portal transaction.
