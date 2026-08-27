# OCV-02 O2D17 signed Slot19 result frozen / Slot20 next — 2026-08-27

Disposition: `APPROVED_BASELINE`.

Authority remains review-only. This checkpoint freezes bounded Slot19
development evidence only. It does not accept wafer identity, clear any hold,
activate the OpenCV provider, restart or replace the protected processor,
authorize XML/training/production routing, mutate source or wafer state, or
expose independent-validation Slots22-25.

## Exact signed terminal response

O2D17 request `REQ_20260827T000000111Z_CC5F7C6ABF26` was published exactly
once through the persistent `U:` mapping and returned exact matching response
`R_EE54DA2619E9_20260827003857253_5197c64e`.

- response ZIP SHA-256:
  `D2142C0220E81239E0DE4F944C1A7353D74B76988E03D11D3CE3770370FDDA91`;
- response manifest SHA-256:
  `A0D4933DAC55835DAA45BBA9DABFEE2865573AD0447963A4481C97488747A2B5`;
- verified JBOD signer thumbprint:
  `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`;
- endpoint state: `PASS_MAINTENANCE_PATCH`;
- maintenance result SHA-256:
  `427B46357F4D32C216A3200CD7E41C30F3F58DCF90160AFD6C9A7AEBE32EBE74`;
- provider result SHA-256:
  `8F88947BF17276E2718E59F5BA24B42F9E81DF62EB954419F6BBD3142305900F`;
- terminal-response gate SHA-256:
  `D2CA85670EED654572522AB45BF9CC5D90DBBC84B47D4BAB1AA1C7842B1945E2`.

The exact response archive and bounded extraction are under
`work/OPENCV_SCRIBE_O2D17/collected`. The temporary extraction root was
removed. O2D17 must not be retried.

## Slot19 development result

The live JBOD execution read the raw Slot19 scribe despite the upstream
notch/identity hold. It returned image-first string `FFFFFFFFFFF7`, proposed
string `FFF77FFF7FF7`, seven candidates, state
`SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`, and checksum state
`SCRIBE_M12_RERANKED_CONFIRMATION_REQUIRED`. The selected automatic region was
`AUTO_LOCALIZED_EXCEPTION_DIAGNOSTIC_120_0001` with localization score
`0.5403790473937988`.

These strings are diagnostic development output, not accepted wafer identity.
Slot19 is frozen with Slots16-18 as bounded development evidence. The run
preserved `SCRIBE_REFERENCE_COVERAGE_HOLD`, the automatic-localization hold,
the upstream notch/identity hold, every map/pose/fiducial hold, and every other
existing hold. The temporary source alias was removed. No task or process was
restarted; no provider, source, wafer, XML, training, or production action
occurred.

## Unresolved prerequisites and exact next action

The separate `lot62631586FrontGuiRecovery` `PENDING_GATE` remains. Slots20-21
remain development inputs. Slots22-25 remain unseen and must not influence
tuning. The live OpenCV provider remains disabled and the protected processor
remains untouched.

Next: create one fresh Slot20 successor from the approved O2D13/O2D17
development lineage, bind only the exact frozen OLS6 Slot20 BF/DF source pair,
run all mandatory preaction, self-pin, Windows PowerShell 5.1, package,
complete-route, continuity, and session-safety gates, publish exactly once,
and collect only its matching signed terminal response. Do not retry any
predecessor. Continue directly to Slot21 on exact pass. After Slots20-21,
freeze the development engine and run Slots22-25 blind without tuning, then
proceed to the locked OCV-03 hotspot/chipout edge-and-notch contract.
