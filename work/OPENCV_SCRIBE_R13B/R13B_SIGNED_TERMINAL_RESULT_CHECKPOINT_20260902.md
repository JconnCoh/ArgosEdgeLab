# R13B signed terminal result checkpoint — 2026-09-02

State: `PENDING_GATE` — the one authorized R13B publication completed, the single matching signed response was collected, and all four returned cases remain held from reference admission.

## Publication and signed response

- Request: `REQ_20260902T204408092Z_R13B`
- Frozen request ZIP SHA-256: `E03EF601339101663E4AABC1889A08C9DB92005F84F56DB3CF08955C8325A889`
- Published exactly once: `2026-09-02T23:01:17.1356114Z`
- Gateway acceptance observed by `2026-09-02T23:01:27.8966977Z`
- Response: `R_CC03FC22AD6B_20260902231013867_6fb787f9`
- Endpoint state: `PASS_MAINTENANCE_PATCH`
- Response ZIP SHA-256: `345153CD7AB1D251B0422DDE7429882C5993E907FDB1D60E9AEFCFDEDBFF27E8`
- JBOD signature verified: true; thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Bundle SHA-256: `337C6E4151D8B5AC2CD1FA70401D87432EDFC8052C03396BC307650E9B10ACAB`
- Collection state: `PASS_R13B_EXACT_SIGNED_TERMINAL_RESPONSE_AND_BUNDLE_COLLECTED`
- No retry, source mutation, source deletion, task/process restart, provider activation, or authority expansion occurred.

## Returned result

The provider executed all four cases with zero launch failures. Local validation passed for four case-result hashes, 58 raster artifact hashes, six target-glyph artifacts, and byte-identical cell-to-target provenance.

Every case is `HOLD_R13B_GRID_NON_TARGET_TRUTH_MISMATCH` and `referenceAdmissionEligible=false`:

- K25V / `13DCK076SUG1`: selected grid is sparse and not a coherent 12-character scribe; 3 of 11 non-target positions matched.
- X18V / `146XF111SUG7`: selected grid is sparse/off-target; 2 of 11 non-target positions matched.
- JQ16D / `147JQ122SUB6`: selected grid has strong dot-matrix structure, but only 2 of 10 non-target positions matched.
- JQ20V / `147JQ117SUD6`: selected grid has strong dot-matrix structure, but only 2 of 10 non-target positions matched.

The returned crops are safe as diagnostic evidence but are not safe to add to the character library. No automatic reference admission occurred.

## Next detector work

Improve full-perimeter scribe/grid localization and canonical non-target alignment before extracting missing-character references. K25V and X18V are the clearest localization-selection failures; JQ16D and JQ20V show that strong dot structure alone is insufficient without correct 12-position alignment.

Machine review gate: `work/OPENCV_SCRIBE_R13B_RESPONSE/R13B_RETURN_REVIEW_GATE.json`, SHA-256 `9593AD09D716DF4E66511B3D6F0621E2195CF4FE3F69C9E08B72A387BFB05EEF`.
