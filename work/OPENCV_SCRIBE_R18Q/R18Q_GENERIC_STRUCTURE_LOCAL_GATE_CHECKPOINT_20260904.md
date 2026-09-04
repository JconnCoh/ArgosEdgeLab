# R18Q generic structure arbitration — local gate passed, Slot25 replay pending

Classification: `PENDING_GATE`

Recorded UTC: `2026-09-04T19:31:22.0589830Z`

R18Q implements a label-agnostic strong run-structure consensus lane above the
frozen R18H reader. It does not contain a `K`/`R`, lot, slot, truth, source-root,
or authority special case. The R18H near-tie lane remains unchanged, selected
appearance scores are never increased, and checksum remains verify-only.

## Exact local artifacts

- Provider: `work/OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py`
  - SHA-256: `AB20CFB25D223D40D31237118436446018AE213F800ECF1652213EB942C40DC1`
- Fixture manifest: `work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE_FIXTURES.json`
  - SHA-256: `2B09530AFEABE3425F0E8D47F0BFD630DE81E32430B2F34D1C332B4223EB2E3A`
- Gate runner: `work/OPENCV_SCRIBE_R18Q/Test-R18QLocalGate.py`
  - SHA-256: `99CE4A6F85C55B00490692BC648670ACF2D29F2B2E413FC707B1A0887C14B834`
- Machine gate: `work/OPENCV_SCRIBE_R18Q/R18Q_LOCAL_GATE.json`
  - SHA-256: `E080BDC20040973E6E9F533B2C650B60FFBD7BA939A375ABC9E33F6C4AE53111`
  - State: `PASS_R18Q_GENERIC_STRUCTURE_LOCAL_GATE_FULL_SLOT25_CROP_REPLAY_PENDING`

The fixture gate is mechanically bound to the R18N complete-scribe manifest
SHA-256 `1AF8D4150B26DB7666900C5B0508C8A3723B635CB6C1D6DC02CA53469CA6D3C2`
and the R18P review cohort SHA-256
`62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661`.

## Passed evidence

- The canonical 465-reference whole-lot/slot-lineage exclusion sweep improved
  from 387 to 389 exact, changed two reads, harmed zero previously correct
  reads, and never increased the selected appearance score.
- Both K references passed across two distinct physical lineages. All four R
  references passed across three distinct physical lineages, with zero K/R
  cross-confusion. A seven-case label-renaming behavioral invariant also
  passed, proving that arbitration does not depend on literal class names.
- The exact locally available Slot22 BF/DF existing-crop wrapper returned
  `13DCK060SUF5`, checksum valid, one close image-first string, four hypotheses,
  and `PASS_REVIEW_ONLY_IMAGE_FIRST_SCRIBE`. Thirteen same-lineage/source
  prototypes were excluded and identity acceptance remained false.
- All 21 frozen visible strings passed. The established T/7 case remained on
  the inherited `RUN_STRUCTURE_CONSENSUS_TIE_BREAK` lane and did not enter the
  new strong-structure lane.
- Five blank/wrong-location controls were tested in BF/DF, both polarities,
  and both directions: 40 views total. Every maximum stayed below the frozen
  `0.60` presence floor; the largest was `0.4153806639783699`.
- The displaced S17 selected-grid replay remained `6KB71041XDE5`, checksum
  valid, with its frozen localization hold and identity rejection preserved.
- Slot24 remained `143B0083SUE6` at the pinned fixed grid and retained the
  required ambiguity hold between `103B0083SUE6` and `143B0083SUE6` through
  the four-hypothesis existing-crop wrapper.
- Eleven runtime sources passed the expanded hardcode scan against all 20 R18P
  cohort identities, all configured truths/controls, underscore-delimited
  lot/slot forms, absolute roots, and upper/lower-case one-character label
  literals. No synthetic-dot or notch dependency was introduced.

## Frozen predecessor bytes and invariants

The R18H provider, R18J crop sweep, R18J corpus worker, base reference
manifest, and supplemental reference manifest remain byte-for-byte unchanged:

- R18H: `3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD`
- R18J crop sweep: `EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F`
- R18J worker: `E8C193024317C683EA0E8DC999F3D632BF113B65C1E6F528949AE5B33F83A069`
- Base references: `AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`
- Supplemental references: `FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114`

No full-wafer image was read, no source was mutated, no external route was
accessed, no reference was admitted, and no identity or production authority
was granted during R18Q development.

## Remaining hold and exact next action

The exact Slot25 whole-crop BF/DF pair is not present in the permitted local
fixture roots. Its required hashes are:

- BF: `2AD91F530FEDCBA7B6F30FA43B0017991419F4D8772FACD5A1B8CD2BF659A738`
- DF: `7472E279D26DA8E473C2E54D56208A6720FAC392B8510B0D2E303F19707B6A3A`

Its K glyph passes the reciprocal whole-lineage exclusion gate, but that is not
a substitute for replaying the exact paired existing-crop wrapper. Therefore
R18Q is not publication-ready and is not full-KLARF-ready.

Next action: obtain or execute only that exact hash-pinned Slot25 pair through a
separately authorized bounded gate. If it passes without changing R18Q bytes,
reassess full-KLARF packaging. Publication requires fresh explicit authority;
no package has been built, signed, or published from R18Q.

Authority remains review-only. Identity acceptance, automatic reference
admission, hold clearance, activation, training, XML, source mutation/deletion,
production routing, and publication are false.
