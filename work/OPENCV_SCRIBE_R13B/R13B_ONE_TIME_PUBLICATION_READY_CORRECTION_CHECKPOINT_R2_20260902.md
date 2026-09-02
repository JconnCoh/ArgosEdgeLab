# R13B one-time publication-ready correction checkpoint R2 — 2026-09-02

State: `PENDING_GATE` — the non-mutating publisher preflight defect is corrected in a fresh local namespace. No publication or external write occurred during the failed preflight.

## Failure and correction

The R2 queue observer correctly used signed exact-request-ID correlation, but its create-new output assertion ran in both `-Observe` and `-Preflight`. Because the prior frozen observation already existed, publisher preflight stopped before any publication action.

The R2 observer and R4 correction gate remain unchanged and are withdrawn for publication. The R3 observer restricts the create-new assertion to `-Observe`; `-Preflight` remains non-mutating and may run when frozen observation evidence already exists.

- Current observer: `Get-R13BCurrentShareObservationR3.ps1`
- Observer SHA-256: `7FC685CF3CA9642D6407120F3A488726024667E16519A8B295FF4E2E6446E792`
- Existing pinned invocation SHA-256: `079AA083683F9DA823E09642EF6FDA28ECE14874DAB2306E963EEB99E6526C01`
- Harness state: `PASS_ARGOS_POWERSHELL_HARNESS_SAFETY`
- New correction gate: `R13B_QUEUE_OBSERVER_CORRECTION_GATE_R5.json`
- Correction-gate SHA-256: `E0F58860F48D4BF0F5EB4B858176659EB50FF38F463B59A58730C6C28CB39CBF`
- Correction-gate state: `PASS_R13B_QUEUE_OBSERVER_PREFLIGHT_CORRECTION_R5`

## Publication binding

- Current publisher invocation: `Publish-R13B_R4.invocation.json`
- Invocation SHA-256: `65D1EBB0A33100B97A6E5B2CE53A6EFB697BBEAFA13E48E51E59CCD61E271567`
- Frozen request ZIP SHA-256: `E03EF601339101663E4AABC1889A08C9DB92005F84F56DB3CF08955C8325A889`
- Request ZIP bytes: `59619`
- Publication count consumed: zero.
- Retry count consumed: zero; the failed operation was a local non-mutating preflight.

## Exact next action

Commit and push this fresh correction namespace, require local/origin equality and a clean worktree, rerun the exact publisher preflight with the R4 invocation, and publish exactly once only if that preflight passes.
