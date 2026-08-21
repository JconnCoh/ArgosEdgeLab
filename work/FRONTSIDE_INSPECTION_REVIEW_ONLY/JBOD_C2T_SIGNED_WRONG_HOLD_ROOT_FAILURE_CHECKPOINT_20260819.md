# JBOD C2T signed wrong-hold-root failure — 2026-08-19

Disposition: `PENDING_GATE`

Matching signed response `R_76C805E3EB90_20260820011809952_b83cbb04`
terminally failed before any tray task action. Exact signed stderr proves C2T
requested the invented path
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\state\processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json`.
The installed path already pinned by signed C2A is
`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json`.

- response ZIP SHA-256:
  `AD435A723DFA3AFD76FFAAEEF613D83CD8DBCA6E8DD1F570BB8B2376093697CBB64`;
- response manifest SHA-256:
  `3794AF39EB38AB6E7C06E957D63FFAFE678FE952A48FEE62D3A1283B50DFC509`;
- response signature SHA-256:
  `91F1A77C44C5E80B100D96F4BB77E1D28CF978D24AE5730389E9FFEA3CD94C77`;
- response route gate SHA-256:
  `EE3DCE62FFF03F69EBFF7CFD9F48853B642EE511226D57BA916E0F07A631308B`;
- terminal failure gate SHA-256:
  `91240B35701847C0AAE14F029A1F55D2BC8CB1B8022459E34EC16D5964693E36`;
- current failure-prevention memory SHA-256:
  `8078A46819F570208CEB73FF8C662A43D11F5556D8A3948E864A99D4490C554E`.

The response has empty maintenance stdout. Therefore no tray restart,
Completed Lot probe, inspection-task change, hold clearance, source deletion,
wafer abort, or production routing occurred. C2A's D: configuration and the
cooperative hold remain active.

Withdraw `REQ_C2T`. Build a fresh successor identity and fresh roots. The
successor payload, behavior fixture, exact endpoint fixture, and complete-route
gate must all use the signed-live `processor` root and must pass a literal
three-way equality check against the C2A payload before signing. Then repeat
all behavior, endpoint, ZIP, route, queue, publication, and matching signed
terminal-response gates. C2B remains blocked until the tray/Completed Lot gate
passes.
