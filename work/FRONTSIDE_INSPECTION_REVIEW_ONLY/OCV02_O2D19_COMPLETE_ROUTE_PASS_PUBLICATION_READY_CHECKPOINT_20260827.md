# OCV-02 O2D19 Slot21 exact-source request publication-ready checkpoint — 2026-08-27

Disposition: `PENDING_GATE`.

Authority remains review-only. This checkpoint does not accept wafer identity,
clear any hold, activate the OpenCV provider, restart or replace the protected
processor, authorize XML/training/production routing, mutate source or wafer
state, or expose independent-validation Slots22-25.

## Approved parent and exact Slot21 source binding

O2D18 returned and verified the exact signed Slot20 terminal response. Slot20
is frozen only as ambiguous development evidence. O2D19 is the fresh Slot21
successor; no predecessor is retried.

O2D19 binds physical identity `62619-433_20260824005735_Slot21` from the
frozen OCV-00 twenty-source inventory:

- BF bytes `475379874`; SHA-256
  `73C073D01127CE0BD7C2C26BB7BF10FE223200847DEE474FBEBA2E8D6882DFCE`;
- DF bytes `475379874`; SHA-256
  `B5A3429B3A307991AD29E11F710E2BDD0DCEC89EE178B15F92B0370CD9ABDFC6`;
- source inventory SHA-256
  `E54A15301A2B4FE914E6315DDFB9628E1D1364B0553D2155E9D5387A88E7FF3B`.

The unchanged V1R5 engine SHA-256 is
`F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB`.
The endpoint pins the exact engine, Slot21 job, reference bundle, installed
runtime, BF, and DF hashes. Self-pin/live-branch gate SHA-256 is
`CA309879CDBA1C71CC616DE74458A9FF3C583A45318CD9F50912FA7C60A643B5`.

## Local Windows PowerShell 5.1 and package gates

The exact Windows PowerShell 5.1/OpenCV rehearsal passed. It evaluated a
nonempty image-first scribe, retained `SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID`,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, automatic-localization and upstream
notch/identity holds, proved the upstream notch hold did not skip OCR, refused
an injected source-hash mismatch before write, removed its temporary alias and
root, and performed no provider/processor/source/wafer/authority action.

- entrypoint-test gate SHA-256:
  `6CF3D8E25B21CFE93613668733813B659083D0F56D3232ED8CAB3A72E52BEEDE`;
- no-argument Windows PowerShell 5.1 gate SHA-256:
  `91D05905185A07D290BAAE4A4A9833D2ADD29EB9E447C24565415C176AD809A7`;
- endpoint SHA-256:
  `6961BC0D73216CC661BA8B5ED9FC814D56B5374AB3882DDBFDD5C1783CF8ED2D`;
- Slot21 job SHA-256:
  `6AA9092B81B0C273AA913038A62E60C4F7AD93D11274EE88A604366B377A03ED`.

The signed request is `REQ_20260827T012505111Z_73C073D0BF26`. Its final ZIP
is 21,403 bytes with SHA-256
`DAA71BB4A819409176975EAD72485ED02E2C294BC2EC9031A4C6CDE0E6054773`.
Final-package gate SHA-256 is
`96158335F247702B030FACBB63785279D5D8DF9E2300E9EF1ECF8B69773AEBDC`.
The extracted signed package, signature, endpoint installed hash, and all
declared rehearsal/self-pin evidence agree exactly.

## Complete route, prerequisite ordering, and exact next action

The complete route evaluated 129 materialized request/response leaves with
maximum effective length 193 and maximum component length 63. The persistent
exact `U:` alias is retained; the current share has zero pending requests, the
new target/upload names are absent, and the matching signed O2D18 round trip
proves the endpoint and return route. Complete-route PASS gate SHA-256 is
`6F99757B4D17F516086E98BC8486D726BC05F6E1809FD15E6A3ED62082BB5B51`;
alias-gate SHA-256 is
`118C2D9D4B5B386FC9C3176A92C5909B6313D8F88D5555E4AA3056A6D9E7CDDD`.

The unresolved-prerequisite audit found 26 `PENDING_GATE` disposition rows,
214 hold-token rows, and 437 alignment/map/pose/fiducial-token rows in the
continuity state. None is cleared, reordered, narrowed, or superseded here.

Exactly one create-new O2D19 publication is authorized after continuity,
metadata-only session safety, clean worktree, and matching local/origin tips
pass. Retry is false. Collect only the exact matching signed terminal response.
On exact pass, freeze Slot21 only as review-only development evidence without
accepting identity, freeze the unchanged V1R5 development engine, and run
Slots22-25 blind without tuning before OCV-03 hotspot/chipout edge-and-notch
work. Slots16-20 remain frozen; Slots22-25 remain unseen.
`SCRIBE_REFERENCE_COVERAGE_HOLD`, every upstream notch/identity,
automatic-localization, map/pose/fiducial and existing hold, plus the separate
`lot62631586FrontGuiRecovery` `PENDING_GATE`, remain. DFLY3005 remains excluded,
O2D14 remains withdrawn, the provider stays disabled, and the protected
processor remains untouched.
