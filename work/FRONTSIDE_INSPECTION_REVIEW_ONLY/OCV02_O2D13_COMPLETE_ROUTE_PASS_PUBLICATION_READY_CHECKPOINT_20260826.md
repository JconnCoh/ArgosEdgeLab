# OCV-02 O2D13 Slot18 exact source binding / signed request / publication ready checkpoint — 2026-08-26

Disposition: `PENDING_GATE`  
Authority: review-only; production routing, XML, training, provider activation, task/process restart, source mutation/deletion, hold clearance, and wafer action remain disabled.

## Slot18 exact signed source binding

The exact physical identity is `62619-433_20260824005735_Slot18`. Matching signed `DATA_PULL` responses froze the current installed proposal and multi-channel summary plus the exact oriented detector-input byte hashes:

- proposal SHA-256 `52750D994411CB6E687F0B02B273B23A8B232A35EA77895B58E7C3A42A526473`;
- multi-channel summary SHA-256 `B5E8F920FD6F2650F4D80B63A5E66E86C1E78536E92E8A191AF2BB9BAF381FDF`;
- BF: 1,655,393 bytes, SHA-256 `68BC8F2A68CCDBE0D9C71BFE742509509DEE43E79FF3661723F5429A2799AC66`;
- DF: 671,586 bytes, SHA-256 `5E8D1377A8D84C467AC60FF9EEAAEA1FCC5C8835AC384246F84F1936624B9048`.

The installed proposal is not identity-eligible; the installed consensus remains `MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES`. B1 terminal-gate SHA-256 is `DE799E4183DEB75E9CEA1D82D13A8F8E86CE00D785D6A4AA1C236269924636B3`; B2 terminal-gate SHA-256 is `25CF8C9B04BFE5DEC485FCE2D7D5231AE8BA632602544E6BE928D2001C95FCF9`.

## O2D13 exact tests and frozen request

Fresh revision `O2D13_20260826T211907000Z_10B0E71B` uses the unchanged OpenCV V1R3 engine SHA-256 `8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB` and unchanged 456-reference bundle SHA-256 `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`.

Windows PowerShell 5.1/OpenCV rehearsal passed, preserving `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, `SCRIBE_REFERENCE_COVERAGE_HOLD`, the installed multiple-candidate ambiguity, processor identity, and review-only authority. The injected source-hash mismatch failed before write. Entrypoint-test gate SHA-256 is `4B3BA8CABB7DE0C16FBB0DD82E726094E3E3162075FDEB1CD55DAC8631AF92D3`; exact no-argument gate SHA-256 is `0CD1BE84A046047B664FAFE15B2ED0B5C5159457D4FED4D3F71549B91FB86D87`.

The frozen signed request is `work/OPENCV_SCRIBE_O2D13/final/REQ_20260826T211907111Z_AC64E36ED036.ready.zip`, 19,326 bytes, SHA-256 `2BBACC6305D34A68A2104E3DFAAA7822398EDC9B5722F9ED1378D9CF042DD8B6`. Final-package gate SHA-256 is `320382D295E21CC51F24C6CDAC3D9242110ECC36F29EB554A0EBDAB335A98EDC`.

## Complete route and exact next action

All 129 constructed request/response leaves pass path budget; maximum effective length is 193 and maximum component length is 55. The persistent exact `U:` mapping is retained, current share pending-request count is zero, and the recent matching signed Slot18 B2 terminal response proves the complete gateway → Argos → JBOD → Argos → gateway return route. Superseding route-gate SHA-256 is `F7F65BCAF809D586E7E55ED86C83BCD9149703AD399262EAFC28C09E65FE9116`; alias-gate SHA-256 is `FE7A32571197F9FC3AD53BF268A4FDBDDE7443A85847C7105114ED3BFB3E0B3E`.

Publish exactly one create-new copy of the frozen `REQ_20260826T211907111Z_AC64E36ED036` ZIP through `U:` with no retry. Then collect and verify only the matching signed terminal response. On exact pass, freeze Slot18 as development evidence and continue directly to Slot19 source binding; on signed failure, follow direct-observation and stop-loss policy before any later mutation.

Slots16 and 17 remain frozen; Slots22-25 remain unseen. The live provider remains disabled, the protected processor remains untouched, `SCRIBE_REFERENCE_COVERAGE_HOLD` and every existing hold remain. Never rerun O2D10, O2A3, O2D5, O2D4, JEO1, CDM1, CDO1, or O2A2. O2D8/O2D9 remain withdrawn and non-reusable; DFLY3005 is excluded.
