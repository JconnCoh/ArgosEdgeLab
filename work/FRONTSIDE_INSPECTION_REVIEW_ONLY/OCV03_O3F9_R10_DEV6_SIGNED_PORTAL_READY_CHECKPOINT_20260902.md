# OCV-03 O3F9 R10 DEV6 signed portal ready — 2026-09-02

Disposition: `PENDING_GATE`

O3F6 remains the accepted full-frontside acquisition baseline: 978/978 paired
FRONT acquisitions, 794 R8 passes, 184 explicit holds, current
UnpatternedFront 49/49 pass, and PatternedFront 204/216 with 12 explicit holds.
The operator reviewed the frozen O3F7 crop cohort, labeled cases 1–6, clarified
that frontside holders do not obscure the wafer, and authorized a small detector
test before any larger run. Stitch displacement may be vertical or horizontal;
rear-holder structure can contaminate the measured cyan edge but must not be
treated as a frontside notch selector. No prior hold is cleared by those labels.

R10 detector `0EEEE7A396E918AF44082EC0930871A6A94C1FBB59D3F5CEF1AC34D1273745FA`
preserves R8/R9 behavior and invokes its symmetric recovery only after zero
baseline eligible physical pairs. The fixed 1.5-degree center tolerance remains
unchanged. The only alternate correspondence is positive mouth-interval overlap,
and BF-seeded local DF recovery remains channel-local. Exactly one physical
cluster is still required; multiple clusters remain a hold. No expected angle,
nearest/strongest selector, post-result relaxation, or automatic hold clearance
is introduced. Local focused gate
`BA661D01D1320AA2CDD9BBB40873B5354DC9290639E011AE3858EC40BBD5F4EE`
and inherited synthetic gate
`A4A85A46B61701EA9973DA768AF77D5240A682DBE4D1085FAF14BEAB21F8D937`
pass.

Fresh staged runner
`work/O3F8/Run-O3F9Staged.py`, SHA-256
`606AFE5DF058F0298CFE333D9091DF3F5F0B5F222EC03C40E73006773F587D72`,
runs only `SELF_TEST`, `PREFLIGHT`, `GATE`, and the six frozen DEV cases. DEV6
is observational: detector holds remain results, while only child/provider
execution failures stop the endpoint.

One fresh signed review-only `MAINTENANCE_PATCH` request is frozen:

- request: `REQ_O3F9_20260902A`;
- ZIP SHA-256: `5C93DD867E8C3D818BAFAB283AF79545ACC84B3B3106393768D34F02AC85D8F4`;
- final-package gate: `1D6490502FB5D4FB6A4C970A34574A6908CE954CBDEFDE4F6CCBB8012DE7B597`;
- exact packaged PowerShell 5.1 rehearsal gate:
  `2DEE23270473A9A375598BAA8107E372BAAEC844E157145FE86D8B49E87841FA`;
- exact entrypoint success/injected-failure rehearsal gate:
  `7AFF30EFB72E427FAEAFB4B3E0227E6F4E0A0CF95CFDB1B29D76F9A342267F16`;
- complete 54-path round-trip gate:
  `80034905CB2D258C2C84482EA73E970561FA613E4FC61EF55761066312CAF174`;
- zero-pending persistent-share observation:
  `680A8FFACF54031BFFF5639DFA1F281B40EEB762E42C956B89ECCAAFC234493B`.

The package uses the unchanged qualified endpoint and a byte-identical installed
protocol anchor. It creates only fresh `D:/O3F9G1` and `D:/O3F9D1` trees, starts
four sequential bounded owned children, reads only the already frozen source
images, and performs no source deletion/mutation, existing task/process action,
provider activation, XML/training/production action, wafer action, retry, or
hold clearance. The signed request is not yet published.

Exact next action: commit and push the frozen O3F9 bytes, require matching local
and origin tips plus zero pending/unresolved accepted requests, publish this ZIP
exactly once through the recorded Project Portal route, and collect only its
matching signed terminal response. Do not use RustDesk or require operator
clipboard/Enter input. Do not retry. Inspect the six returned results before
authorizing any broader frontside run. Preserve all O3F6/O3F7 holds, including
rare hotspot Slot16, unless a later explicit gate resolves them.
