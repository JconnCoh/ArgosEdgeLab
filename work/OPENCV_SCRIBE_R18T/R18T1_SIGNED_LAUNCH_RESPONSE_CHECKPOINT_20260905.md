# R18T1 signed portal response collected — launch proved, corpus outcome pending

## Signed response outcome

One fresh operator-authorized `OBSERVE` found exactly one response whose signed manifest names requestId `REQ_R18T1`. The 3,299-byte response ZIP is `R_D65714DE5125_20260905121421282_631e5003.ready.zip`, SHA-256 `E642397BB1BA3DBD39E8B15248D8E5CB85E2239DC80796ECC06EEBC2EC909AF6`.

The response manifest and all three declared files were verified byte-for-byte. RSA-SHA256-PKCS1 verification passed with JBOD endpoint signer thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`. The response state and maintenance result are `PASS_MAINTENANCE_PATCH`; stderr is empty. The exact five-member response was collected create-new under `work/OPENCV_SCRIBE_R18T/collected_launch_response`.

This is a terminal signed Project Portal transaction response, but its payload is explicitly a launch response. It proves `PASS_R18T_LIVE_ONLY_WORKER_STARTED` on `A1025645101`, PID 39140, process start `2026-09-05T11:56:41.1535433Z`, work root `D:\A2\w\ocv\R18T1`, and output root `D:\A2\o\ocv\R18T1`. It does not contain `INVENTORY.json`, `RUNNING.json`, `COMPLETE.json`, `FAILURE.json`, case results, OCR proposals, or terminal corpus holds. Corpus completion and all per-case outcomes therefore remain unproven and must not be inferred from the signed launch PASS or the operator's running observation.

## Frozen launch facts

- exact configured cohort count: 20
- cohort SHA-256: `62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661`
- payload count: 29
- live-binding passes: 2
- source bytes hashed by launcher: true
- pixels decoded by launcher: false
- owned worker started: true
- automatic retry: false
- identity accepted: false
- Slot24 package-excluded: true
- R18S authorized: false
- production routing: false

The exact 20 configured identities remain:

1. `62546-481_20260707164232_Slot03`
2. `62546-481_20260707164232_Slot04`
3. `62546-481-POST_20260708155428_Slot04`
4. `62546-481_20260707164232_Slot05`
5. `62546-481_20260707164232_Slot06`
6. `62546-481_20260707164232_Slot07`
7. `62546-481-POST_20260708155428_Slot07`
8. `62546-481_20260707164232_Slot08`
9. `62546-481_20260707164232_Slot09`
10. `62546-481_20260707164232_Slot10`
11. `62546-481_20260707164232_Slot11`
12. `62546-481_20260707164232_Slot12`
13. `62546-481-POST_20260708155428_Slot12`
14. `62546-481_20260707164232_Slot17`
15. `62546-481_20260707164232_Slot18`
16. `62546-481_20260707164232_Slot21`
17. `62546-481-POST_20260713041740_Slot22`
18. `62546-481_20260707164232_Slot23`
19. `62546-481-POST_20260708155428_Slot23`
20. `62546-481_20260707164232_Slot25`

Signed terminal per-case results included: 0/20. This is not a negative OCR result and does not grant a Normal, Reject, identity, or hold disposition to any case.

## Holds and authority

The original six holds remain unchanged:

1. R18R2 remains withdrawn pre-inventory, no-retry, with no OCR conclusion.
2. R18T was published exactly once; no retry or republication is authorized.
3. R18S existing-crop/full-corpus work remains blocked and unauthorized.
4. Slot24 remains local-only, package-excluded, and forbidden from JBOD transfer.
5. Supplemental labels `I`, `O`, `V`, and `Y` remain absent; automatic admission is unauthorized.
6. The two-phase rollover hook remains deferred/unqualified; manual acceptance remains required.

Additionally, `HOLD_R18T_CORPUS_TERMINAL_OUTCOME_NOT_INCLUDED_IN_SIGNED_LAUNCH_RESPONSE` records the present evidence boundary. It does not replace or clear any of the six holds.

## Access and next action

This fresh action used only the qualified Project Portal response path. No request was published or retried; no second request, GUI/RDP route, direct JBOD observation, task/process action, source-image access, image-member-body access, identity acceptance, R18S work, or global-phase modification occurred.

Next action: `STOP_AND_REQUEST_SEPARATE_AUTHORITY_FOR_PACKAGE_ONLY_TERMINAL_CORPUS_OBSERVATION_IF_REQUIRED`.
