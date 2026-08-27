# OCV-02 O2D18 Slot20 exact-source request publication-ready checkpoint — 2026-08-27

Disposition: `PENDING_GATE`.

Authority remains review-only. This checkpoint does not accept wafer identity,
clear any hold, activate the OpenCV provider, restart or replace the protected
processor, authorize XML/training/production routing, mutate source or wafer
state, or expose independent-validation Slots22-25.

## Approved parent and exact Slot20 source binding

O2D17 returned and verified the exact signed Slot19 terminal response. Slot19
is frozen only as ambiguous development evidence. O2D18 is the fresh Slot20
successor; no predecessor is retried.

O2D18 binds physical identity `62619-433_20260824005735_Slot20` from the
frozen OCV-00 twenty-source inventory:

- BF bytes `475379874`; SHA-256
  `227E9F1CED3D6E49C10C7DEC9803EA76DC341CC64C77801453A930A9FAF3691B`;
- DF bytes `475379874`; SHA-256
  `28EDE033FEA4721E7D54DD77083428F13494A5E25D087B01DED9E76ADE87080F`;
- source inventory SHA-256
  `E54A15301A2B4FE914E6315DDFB9628E1D1364B0553D2155E9D5387A88E7FF3B`.

The unchanged V1R5 engine SHA-256 is
`F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`.
The endpoint pins the exact engine, Slot20 job, reference bundle, installed
runtime, BF, and DF hashes. Self-pin/live-branch gate SHA-256 is
`6C0DB5755372BC157C3AFF7F23AC43CB23547A9DA3FC3000E17D9A86DB0F4EC7`.

## Local Windows PowerShell 5.1 and package gates

The exact Windows PowerShell 5.1/OpenCV rehearsal passed. It evaluated a
nonempty image-first scribe, retained `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, automatic-localization and upstream
notch/identity holds, proved the upstream notch hold did not skip OCR, refused
an injected source-hash mismatch before write, removed its temporary alias and
root, and performed no provider/processor/source/wafer/authority action.

- entrypoint-test gate SHA-256:
  `858BF7DA83DCC2EF520C32D5ED4CB19FC412076135EBBB4A83D25957DB80241E`;
- no-argument Windows PowerShell 5.1 gate SHA-256:
  `74DC42CDBDE8CAD62F0F06796F80D39E6376F09A232817FDD6756F8B001B8F85`;
- endpoint SHA-256:
  `06FB6E82D86B98D6637A769AA82D053027016D4EFE296A6A96B03B29E67F8269`;
- Slot20 job SHA-256:
  `C0CC9FF91BAC0FEBD45EBEA335133E1BE65FA3F33310B79305C81FC3CDE456AF`.

The signed request is `REQ_20260827T004800111Z_227E9F1CBF26`. Its final ZIP
is 21,399 bytes with SHA-256
`DB098D3C98F620CC6C56F34B2541B0D685D83DE983FD31FC447D0EAB7A07A4E4`.
Final-package gate SHA-256 is
`CC517BC46739D79E0BB5B9E5C02A761933A9623FBA2D63AE8049614F95B3D13B`.
The extracted signed package, signature, endpoint installed hash, and all
declared rehearsal/self-pin evidence agree exactly.

## Complete route and exact next action

The complete route evaluated 129 materialized request/response leaves with
maximum effective length 193 and maximum component length 63. The persistent
exact `U:` alias is retained; the current share has zero pending requests, the
new target/upload names are absent, and the matching signed O2D17 round trip
proves the endpoint and return route. Complete-route PASS gate SHA-256 is
`0B7F836B5F32684E3A20A873A2DDCE75670F13758E269F0430DD82157D8DF4F4`;
alias-gate SHA-256 is
`0D1392E8FBA3296C076ED990C5A666E508BD5A35C2EF70C725A14B6F252962BD`.

Exactly one create-new O2D18 publication is authorized after continuity,
metadata-only session safety, clean worktree, and matching local/origin tips
pass. Retry is false. Collect only the exact matching signed terminal response.
On exact pass, freeze Slot20 only as review-only development evidence without
accepting identity and continue directly to Slot21. Slots16-19 remain frozen;
Slots22-25 remain unseen. `SCRIBE_REFERENCE_COVERAGE_HOLD`, every upstream
notch/identity, automatic-localization, map/pose/fiducial and existing hold,
plus the separate `lot62631586FrontGuiRecovery` `PENDING_GATE`, remain. The
provider stays disabled and the protected processor remains untouched.
