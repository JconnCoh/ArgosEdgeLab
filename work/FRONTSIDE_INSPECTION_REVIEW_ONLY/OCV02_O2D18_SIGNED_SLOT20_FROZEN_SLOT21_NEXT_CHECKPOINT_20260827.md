# OCV-02 O2D18 signed Slot20 result frozen / Slot21 next — 2026-08-27

Disposition: `APPROVED_BASELINE`.

Authority remains review-only. This checkpoint freezes bounded Slot20
development evidence only. It does not accept wafer identity, clear any hold,
activate the OpenCV provider, restart or replace the protected processor,
authorize XML/training/production routing, mutate source or wafer state, or
expose independent-validation Slots22-25.

## Exact signed terminal response

O2D18 request `REQ_20260827T004800111Z_227E9F1CBF26` was published exactly
once and returned matching response
`R_DDE1C032BD6B_20260827011029175_2677777e`.

- response ZIP: 3,683 bytes; SHA-256
  `940D0B0AB65C27A93C8B13428800359B70B12685FF0D414356B04A2A07D0A4AA`;
- response manifest SHA-256:
  `9550D366590CC1FB245D05831A56378C1F285BA5D7285EFBD6153B0502A762C4`;
- verified JBOD signer:
  `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`;
- endpoint state: `PASS_MAINTENANCE_PATCH`;
- terminal-response gate SHA-256:
  `7086F5005363A85175555603B2D4427F45BA948F219CDEE925E3B18138D09D82`.

The exact archive and extraction are under
`work/OPENCV_SCRIBE_O2D18/collected`. The temporary `C:` root was removed.
O2D18 must not be retried.

## Slot20 development result

The live execution read Slot20 despite the upstream notch/identity hold. It
returned image-first string `FFFFFFFFFFF7`, proposed string `FFF77FFF7FF7`,
six candidates, `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, and
`SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`. Selected automatic region
`AUTO_LOCALIZED_EXCEPTION_DIAGNOSTIC_120_0001` had score
`0.545153021812439`.

These are diagnostic development strings, not accepted identity. Slot20 is
frozen with Slots16-19 as bounded development evidence. The signed run
preserved `SCRIBE_REFERENCE_COVERAGE_HOLD`, ambiguity,
automatic-localization, upstream notch/identity and every existing hold. The
source alias was removed. No task/process restart, provider activation,
source/wafer action, or hold clearance occurred.

## Exact next action

Create one fresh Slot21 successor using the unchanged V1R5 engine and only the
exact frozen OLS6 Slot21 BF/DF pair; gate, sign, publish once, and collect only
its matching signed terminal response. Do not retry any predecessor. After
Slot21, freeze the development engine and run Slots22-25 blind without tuning.
The separate `lot62631586FrontGuiRecovery` `PENDING_GATE`, every map/pose/
fiducial hold, disabled provider, protected processor, and absent XML/training/
production authority remain fixed.
