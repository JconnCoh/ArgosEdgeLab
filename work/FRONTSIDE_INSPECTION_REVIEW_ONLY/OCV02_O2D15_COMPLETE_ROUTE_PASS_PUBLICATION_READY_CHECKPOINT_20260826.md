# OCV-02 O2D15 Slot19 raw-source scribe request publication-ready checkpoint — 2026-08-26

Disposition: `PENDING_GATE`.

Authority remains review-only. This checkpoint does not accept wafer identity,
clear any hold, activate the OpenCV provider, restart or replace the protected
processor, authorize XML/training/production routing, mutate source or wafer
state, or expose independent-validation Slots22-25.

## Why Slot19 still reads the scribe

The signed S19P1 observation proved that the installed Slot19 proposal is held
at `SCRIBE_IDENTITY_CONFIRMATION_HOLD` because the upstream notch alignment did
not produce oriented scribe inputs. Per operator correction, that upstream hold
does not skip scribe development. O2D15 therefore binds the exact frozen raw BF
and DF full-wafer sources from `OLS6_EXACT_TWENTY_SOURCE_HASHES.json` and uses a
temporary JBOD-local `X:` alias only while the bounded OpenCV reader executes.
The alias is removed and verified absent in all terminal paths.

- Physical identity: `62619-433_20260824005735_Slot19`.
- BF bytes: `475379874`; SHA-256
  `83362565391B7245DAB450B67A6EF79062CAC431D6E7259E0ECEA594DCA3C239`.
- DF bytes: `475379874`; SHA-256
  `3F1CF8D84C5E4C3F4DFADD6368A0DE667B06D956F664CD69C5B4390F5ABC5256`.
- Source inventory SHA-256:
  `E54A15301A2B4FE914E6315DDFB9628E1D1364B0553D2155E9D5387A88E7FF3B`.
- V1R5 OpenCV engine SHA-256:
  `F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`.

The exact O2D15 Windows PowerShell 5.1 rehearsal passed with an evaluated,
nonempty scribe (`FE5565R022F5`) and checksum state
`SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`. That is test evidence only, not
Slot19 truth. It also proved the upstream notch hold did not skip the reader,
both reference-coverage and automatic-localization holds remained, the injected
source-hash mismatch failed before write, the temporary alias was removed, and
the protected processor identity did not change. Gate SHA-256 is
`1363BA73353FBD51F295C354F2103586ED513113149F12012036DB0707E451EB`.

## Withdrawn predecessor

O2D14 was signed locally but never published or executed. Its signed definition
named the older R2 rehearsal while the final package relied on corrected R3.
O2D14 is `WITHDRAWN`, non-reusable, and never a publication parent. Withdrawal
evidence SHA-256 is
`76317B063133AFEEA777949D957CF148786CD919932A4A4D929843791E01F885`.

## Frozen O2D15 request and route

- Revision: `O2D15_20260826T225708001Z_9A8661E9`.
- Request: `REQ_20260826T225708001Z_9A8661E9BF26`.
- Request ZIP: 21,046 bytes; SHA-256
  `01BD0CDE5EC4AA668FD153E93C4DF25D340C988B211CC7D5A57F9476848D9CDD`.
- Final-package gate SHA-256:
  `AF9335B4B52427B71961A1F847D2481C747C84F5EEBF1234B167525CD73C404B`.
- Maintenance definition and the extracted signed manifest both bind exact
  rehearsal state `PASS_O2D15_ENTRYPOINT_TEST_GATE_R3` and exact gate SHA-256
  `1363BA73353FBD51F295C354F2103586ED513113149F12012036DB0707E451EB`.
- Complete route evaluates 129 materialized leaves, including the real short
  alias source leaves, with maximum effective length 193 and maximum component
  length 63.
- Complete-route PASS gate SHA-256:
  `9496B3DE0DE4FA17E071506D416C2F0023EC07EB2592EA26AEEA970CF48F32B2`.
- Persistent `U:` alias gate SHA-256:
  `D4C09DA08CB56CF84BC8CB785E2250C2311837DB6C479D97EB57993408A3BA65`.
- The most recent matching signed full round trip is S19P1, terminal-gate
  SHA-256 `2623C0AE996049F564AD68D9C5EBDD1206D5C96074E9F82E6128B3B0E838EC8F`.
- Fresh share observation found zero pending request ZIPs/uploads and proved
  the O2D15 target and upload names absent. No O2D15 publication or target
  execution has occurred.

Exactly one create-new publication is authorized after continuity/session
safety and matching clean local/origin branch tips. Retry is false. Collection
is limited to the matching signed terminal response for this request.

## Unresolved prerequisites and exact next action

`SCRIBE_REFERENCE_COVERAGE_HOLD`, the Slot19 upstream notch/identity hold, the
development automatic-localization hold, every pre-existing map/pose/fiducial
hold, and the separate `lot62631586FrontGuiRecovery` `PENDING_GATE` remain
unchanged. None is silently superseded by this scribe-development request.

Slots16-18 remain frozen development evidence. Slot19 is started but not frozen;
Slots20-21 have not started; Slots22-25 remain unseen. The live provider remains
disabled.

Next: publish the exact O2D15 ZIP once, then collect and verify only its matching
signed terminal response. Do not retry. On an exact signed pass, freeze Slot19
as development evidence without accepting identity and continue directly to
Slot20, then Slot21. After Slots19-21 are complete, freeze the scribe engine and
run Slots22-25 blind without tuning before OCV-03 edge/notch work. The locked
OCV-03 cohort still requires `Lot_62629-419_NotchBad_Hotspot`, every discoverable
known chipout wafer, zero wrong rotations, zero chipout-as-notch selections,
independent BF/DF pose, and fail-closed ambiguity.
