# FM7P24A 41-file return and share-publication checkpoint — 2026-08-17

Disposition: `DIAGNOSTIC_ONLY`

State: `PASS_FM7P24A_41_FILE_RETURN_HASH_VERIFIED_ZERO_BLANK_REVIEW_PENDING`

## Outcome

The gateway repair and complete request/response route are working. Signed
JBOD DATA_PULL request `REQ_20260817T195449639Z_2EF1EFFE99F2` returned signed
response `R_63E9A7CC8A0E_20260817195508913_8a814062` with endpoint state
`PASS_DATA_PULL`. The 41 declared FM7P24 files were materialized locally and
copied create-new to the operator-provided `InspectionRevs` share. Every
source-to-container-to-local mapping passed, and every local-to-share relative
name, byte count, and SHA-256 matched.

Local result root:

`work/FM7P24A/result/FM7P24_20260817T153800Z`

Published review root:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P24_20260817T153800Z`

## Signed return evidence

- Response ZIP: 14,131,542 bytes, SHA-256
  `6D5251E22545EACA4A64847DA7BC2DAAE48A6C394CC70BC6A7D401AC501C60D7`.
- Response manifest: SHA-256
  `B24F775FF05914E7DA78A98F71272FA5185FA4BF1A47E150A8B264956581F1AA`.
- Result: SHA-256
  `4FECE6A758D6429F874FB8FC32E11164C2D10895EDE20E71DEE95915BE66569A`.
- Data container: 16,583,436 bytes, SHA-256
  `D7FCB799BA6A44A6C9F57FC9D43C69338CA3EC7830FF267440F07F927AAF8927`.
- Declared and returned payload: 41 files, 16,569,619 source bytes.
- Final local/share folder: 42 files and 16,591,233 bytes, including the
  separately generated `RETURN_GATE.json`.
- `RETURN_GATE.json`: SHA-256
  `716B25090971F9BF671523160A9D0A4DD3548AE46FC84D989A10235087ED3746`.
- Final `AUDIT.json`: SHA-256
  `07CE75FB964E24416E827145A40594A545AFDB317E0E2140B1666E8DC0A7C712`.
- Share-publication gate:
  `work/FM7P24A/result_pull/FM7P24A_SHARE_PUBLICATION_GATE.json`.

## T16/T17 coverage result

Final audit state is
`PASS_FM7P24_T16_T17_ZERO_BLANK_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`.
All 12 expected targets completed with zero skipped. Each target used the
other 11 wafers as references and remained excluded from its own reference.
There are 24 control composites: 12 T16 and 12 T17.

Across the 24 controls, BF and DF each contain 3,638,111 valid pixels:

- BF: 3,332,904 strict-consensus pixels plus 305,207 separately labeled
  robust-fallback pixels; zero direct-native, zero unassigned, and zero
  coverage-hold pixels.
- DF: 3,434,750 strict-consensus pixels plus 203,361 separately labeled
  robust-fallback pixels; zero direct-native, zero unassigned, and zero
  coverage-hold pixels.

For every target and both controls, strict plus fallback plus direct-native
equals valid pixels. The black/blank coverage failure is therefore closed in
this bounded composite audit. Fallback pixels were not silently promoted to
strict consensus or Normal truth. The general model retains explicit hold
semantics if a future pixel cannot be assigned, but no T16/T17 pixel in this
run required that route.

## Authority boundary and next action

This is composite evidence for operator review. It emits no defect masks or
defect outcomes and grants no Normal, training, XML, or production authority.
The operator should now review `ALL_WAFER_COMPOSITE_SUMMARY.png`, the twelve
`*_T16_S238.png` sheets, the twelve `*_T17_F10_S254_TO_S258.png` sheets, and
the twelve `*_COVERAGE.png` sheets from the published file-backed folder.
Do not load image bytes into Codex task history.
