# JBOD C2V1 signed lexical failure checkpoint — 2026-08-19

Disposition: `WITHDRAWN`

## Outcome

The first live read-only validator for lot `62631-586`, request `REQ_C2V1`,
returned one matching signed terminal response:
`R_62BFE69D6B2E_20260820022810235_25bed068`.

The response state is `FAILED`. Its exact stderr proves that Windows
PowerShell 5.1 executed the unseparated token `return$v` as a command in the
`Normalize-Key` fallback branch. This was a validator implementation failure,
not an inspection, storage-cutover, or lot-processing failure. The synthetic
fixture had not exercised that fallback branch.

Terminal response ZIP SHA-256:
`A1B1239ABF9A95289DD9AABA8FFA868DCF0117E8B2D0BD245F63361F4EA87147`.
Terminal failure gate:
`work/JBOD_LOT_VALIDATE_C2V/C2V1_TERMINAL_RESPONSE_GATE.json`, SHA-256
`AA511CACF8179508E25BA286350B8689D490AEDE579C27E8538D3B2C0188197F`.

## Preserved safety state

- The signed response manifest and all three declared response files passed
  signature, length, and SHA-256 verification.
- The response was extracted under fresh bounded root `C:\A14S`.
- The request authorized no scheduled-task action, source deletion, tray
  restart, wafer abort, XML export, or production routing.
- The live C2B D-path configuration and active review-only processor remain
  unchanged.
- No conclusion about lot `62631-586` was produced by C2V1.
- C2V1 is permanently withdrawn and cannot be used as validation evidence.

## Prevention and next gate

`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md` now requires lexical whitespace
after PowerShell control-flow keywords and a static rejection gate for fused
`return`, `throw`, `break`, and `continue` tokens. The corrected C2V2 package
must also run a behavior case that enters the `Normalize-Key` fallback branch,
then repeat exact endpoint, path, final-ZIP, publication, and signed-response
gates under a fresh request identity.

Do not recover any duplicate C: inspection root until the corrected live
validator proves lot `62631-586` across the D: output, cache, metadata,
inspection-log, dashboard, and Completed Lot consumers and proves no post-C2B
write to the old C: roots. Insite waits remain next after this lot gate.
