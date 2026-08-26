# OCV-02 O2D12 Slot17 exact source binding / signed request / publication ready checkpoint — 2026-08-26

Disposition: `PENDING_GATE`  
Authority: review-only; production routing, XML, training, provider activation, task/process restart, source mutation/deletion, hold clearance, and wafer action remain disabled.

## Slot17 exact signed source binding

The exact physical identity is `62619-433_20260824005735_Slot17`. Signed `DATA_PULL` responses froze the current installed proposal and multi-channel summary plus the exact oriented detector-input byte hashes:

- proposal SHA-256 `5B529F708E2B956DFF79B2EC19C8B9D92EEE94E483093ADC92417F242A056761`;
- multi-channel summary SHA-256 `84CC935A49E79F33A756D26FADC1545FB92961D7220EEAB14C3D2CE7DC8D8E6B`;
- BF: 1,642,696 bytes, SHA-256 `46ACA8C9C32850EF052C1BF7F26550EFD474E00372B0F43F0DD391AFEA1A431D`;
- DF: 672,445 bytes, SHA-256 `012365504979E0A89E387FBD735E0E60B9B49899FC9A516D05C0BAE0ACC631E9`.

The installed proposal is not identity-eligible; the installed consensus remains `MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES`. B1 terminal-gate SHA-256 is `72F646F8A3BE332368154B3B9E5D4EC6D821D23C368D2BF5B49DB5A608BB52D7`; B2 terminal-gate SHA-256 is `C97719FE27BFBAD5CC983FB87C9BC0E922742D7FE41A4FF4791776097676CDB6`.

## O2D12 exact tests and frozen request

Fresh revision `O2D12_20260826T202600000Z_6B91F2C4` uses the unchanged OpenCV V1R3 engine SHA-256 `8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB` and unchanged 456-reference bundle SHA-256 `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`.

Windows PowerShell 5.1/OpenCV rehearsal passed, preserving `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, `SCRIBE_REFERENCE_COVERAGE_HOLD`, the installed multiple-candidate ambiguity, processor identity, and review-only authority. The injected source-hash mismatch failed before write. Entrypoint-test gate SHA-256 is `A657C2A1D8EAD153DCAAA7CA8CEB3038F05CAF8A9C1849CF412858FD58C6E97B`; exact no-argument gate SHA-256 is `5109A9FED6F18F33A4F39483B382F1F585832D4DCA44CEA0E1F34F3357CCACCB`.

The frozen signed request is `work/OPENCV_SCRIBE_O2D12/final/REQ_O2D12_20260826.ready.zip`, 19,297 bytes, SHA-256 `03FEB764BADE1637FE25B169BBF47649D8B5ECB2C578433FB050119A583858FF`. Final-package gate SHA-256 is `A6C98D3DE395D164851D8E2EA6A9A59B1141B22F5020D76363EEDDBB8A15FCF8`.

## Complete route and exact next action

All 129 constructed request/response leaves pass path budget; maximum effective length is 193 and maximum component length is 55. The persistent exact `U:` mapping is retained, current share pending-request count is zero, and the recent matching signed B2 terminal response proves the complete gateway → Argos → JBOD → Argos → gateway return route. Superseding route-gate SHA-256 is `07A423E398D022EFF3D819B2F5679C87D577E4A97013D30DBAF71C1632442263`; alias-gate SHA-256 is `EAAD8DDC7F6AF3939F6901C0908B44546AA8E89B816186CCCF0301480DA96461`.

Publish exactly one create-new copy of the frozen `REQ_O2D12_20260826` ZIP through `U:` with no retry. Then collect and verify only the matching signed terminal response. On exact pass, freeze Slot17 as development evidence and continue to development Slot18; on signed failure, follow direct-observation and stop-loss policy before any later mutation.

Slot16 remains frozen; Slots22-25 remain unseen. The live provider remains disabled, the protected processor remains untouched, `SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold remain. Never rerun O2D10, O2A3, O2D5, O2D4, JEO1, CDM1, CDO1, or O2A2. O2D8/O2D9 remain withdrawn and non-reusable; DFLY3005 is excluded.
