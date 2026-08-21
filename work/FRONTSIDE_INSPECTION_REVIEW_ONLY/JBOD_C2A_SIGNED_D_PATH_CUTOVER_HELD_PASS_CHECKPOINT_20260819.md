# JBOD C2A signed D-path cutover-held pass — 2026-08-19

Disposition: `PENDING_GATE`

## Outcome

Matching signed terminal response
`R_1097D7BE8735_20260820010154306_a659baf7` proves C2A completed. The
installed review-only processor configuration now uses the short D: consumer
roots below while cooperative hold `STORAGE_CUTOVER_H1_20260819` remains
active:

- future output: `D:\A2\o`;
- dashboard output: `D:\A2\d`;
- cache: `D:\A2\c`;
- verified metadata: `D:\A2\m\verified`.

`D:\A2\o` was created as a fresh empty output root. C2A did not delete any C:
source, clear the hold, restart the tray, change an inspection task, or abort a
wafer.

## Exact evidence

- request ID: `REQ_C2A`;
- request ZIP SHA-256:
  `D47FEB2160A5F1D1E34A26632A5CE30269E4B9BFC6B799FCF372D6D96A178E63`;
- request manifest SHA-256:
  `863B15A84C2B1CA9A2386EC543933E0A89568E8E204D1FACA105051EAD54DBB6`;
- final-package gate SHA-256:
  `8BA35B60D748A23A6E636995C592425245FDE994E9958BCA5E7842BC4E09FAFE`;
- final extracted-endpoint gate SHA-256:
  `A29B0A69741F0EF629F9D0ED157168A4B2E723A921A3ADCA17A7FBC90C2CBF98`;
- publication gate SHA-256:
  `E86BBBD9EC9D0CC0E98EC2EDF0FA8E8DC509DB1075BAA6B2B9AEA8A81668CDAD`;
- response ZIP SHA-256:
  `D987A2AF2B76ED4FFAAEEF613D83CD8DBCA6E8DD1F570BB8B2376093697CBB64`;
- response manifest SHA-256:
  `9D15CEC3FFBE617C84421D08DD9BC31AD53D684EC031F772047B89FE85FACDCF`;
- response signature SHA-256:
  `06B7681D05A996EE376899957298458B14E48F2FD7651B401F5D076900957316`;
- response route gate SHA-256:
  `02AEE8F4834067EDFE4D92841066AE57B5F4056128A9E1E491FAD798AA06206F`;
- terminal response gate SHA-256:
  `309FDE4287E6A361BC282B2F81EA5F6E81B3F5FEAD93FF91833740700272EE2F`.

The exact final-package rehearsal exercised both approved predecessor states,
target idempotence, refusal of an unapproved predecessor before mutation,
rollback after verifier failure, and a following control request. All five
response signatures verified. The laptop config was restored to the pinned
pre-cutover hash after both endpoint rehearsals.

The first final extracted-package attempt at `C:\C2AF` was preserved after its
generic `extract` directory was correctly ignored by the endpoint's
`*.ready` queue discovery. The corrected fresh attempt at `C:\C2AF2` retained
the signed `REQ_C2A.ready` basename and passed. The failure signature and
prevention are recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## Next gate

While the processor remains held, build and execute one separately rehearsed,
bounded tray-only restart and Completed Lot behavior validation. Protect all
other task definitions and principals. After its matching signed terminal
response, apply C2B to clear the cooperative hold and reactivate inspection,
then use newly run lot `62631-586` to prove real consumer writes and Completed
Lot visibility under D:. Do not recover any C: duplicate tree until that real
D: validation passes. Insite-wait repair follows the lot validation.
