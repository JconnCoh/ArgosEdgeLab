# JBOD D2S7 signed terminal copy-complete checkpoint — 2026-08-19

Disposition: `PENDING_GATE`

## Outcome

The completed C:-to-D: inspection-output copy is now proven terminal by a
matching signed Project Portal response. The copy must not be rerun.

- request: `REQ_D2S7`
- response: `R_19776C944D4B_20260820000119516_cad528d0`
- response state: `PASS_MAINTENANCE_PATCH`
- terminal state: `PASS_JBOD_STORAGE_DELTA_STATUS_D2S7_SIGNED_TERMINAL_RESPONSE`
- completed files: `93,709`
- completed bytes: `232,912,232,897`
- copy task: `Ready`
- task result: `0`
- final delta terminal pass: `true`
- result contract pass: `true`
- D3 publication allowed: `true`

## Exact evidence

- request ZIP SHA-256:
  `1E8074D539812A7F0283F3497A27213B5D9D8A65D0032E41C4EC3FE0F78A5232`
- publication gate SHA-256:
  `848C5A947071A9A07577A03DA1AFD22D82BE3CB21F35671AAAE0E6C7F1FD421D`
- response ZIP SHA-256:
  `F771488FDABC68F6EB82D1E2E7108EA50AB6440074118CE46C4A723A2B8063D9`
- response manifest SHA-256:
  `913897AB27FB04FA8043C4676C933FCAA5AC9D67A13758C729B126E02819DEAD`
- response signature SHA-256:
  `A8406F7EC44BB701F8FFD00559FF3B433F9E3AAEA417355B972FDDBAF58B90E2`
- response recovery route gate SHA-256:
  `EFC45661DA255F358564F7FD0BB981DB1BB17E8179096E3F5974A0A275758733`
- terminal response gate SHA-256:
  `5C1F39525CFD9F3754FC7758562712C12027202392DA1BA85E4C6AA26B81E4E5`
- exact completed result SHA-256:
  `E311749CBE8F2E2EA2560A4CAF1FA608CBBCD7BDA275AD886276CB6EE3032041`
- completed manifest:
  `D:\A2\x\manifests\M1_20260819T172439962Z.jsonl`
- completed manifest SHA-256:
  `5C42EFF1431867076DC3F3DEE15FA0FB20A0B0C204C2AA38B5E5BDBCD0806DEB`

## Corrected causality proof

The hold `updatedUtc` field is a mutable held-loop heartbeat and is not used
as the hold-entry causal origin. The signed response independently reverified
the earlier signed held launch
`R_B2AADAF7BFD0_20260819172440891_05a34b2c`, matched its exact task last-run
identity, and matched the result-manifest lineage. The manifest timestamp is
962 ms after that held launch. `heldLaunchBindingPass=true`.

## Authority and next gate

This checkpoint authorizes preparation/publication of the already designed D3
verification request only. It does not authorize a tray restart, cooperative
hold clearance, D: cutover, C: deletion, inspection-task change, current-wafer
abort, XML, training, or production routing. D3 must produce its own matching
signed terminal response before C2A/C2B or any recovery of exact C: sources.

After D3, apply C2A/C2B and validate the real D: consumers and Completed Lot
view before any exact-target C: recovery. Then return to PFC004 fiducial work
with the six-pass fiducial requirement and Slot07 notch hold preserved.
