# GUIR8 GUI installation safe-stop checkpoint — 2026-08-22

## Authority and preserved boundaries

- Authoritative repository: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`.
- Required recovery commit `bb09223748c446f0b9e38656d80ca996049a3e55` was verified present before this work.
- Branch: `codex/fiducial-opencv-d-drive`.
- AVC1 remains the installed review-only processor authority. The healthy processor was not stopped, restarted, or changed.
- Fiducial/OpenCV work remains intentionally paused at the existing FOP1 checkpoint. No fiducial artifact, source image, composite, alignment, detector, inspection truth, XML, training, production route, deletion boundary, or wafer state changed.
- R10 and AVS1 remain `WITHDRAWN` and were not replayed or used as parents.

## GUIR7 final local package

The fresh frozen local GUI package completed its exact Windows PowerShell 5.1 installer rehearsal:

- ZIP: `C:\G7F\GUIR7_REVIEW_ONLY_GUI_FIX_20260822.zip`.
- ZIP SHA-256: `47ACE6B1F3924762A720A890C336CA9636425C731856ECC6066C695A33397BA7`.
- Gate: `work/GUIR7/GUIR7_FINAL_PACKAGED_INSTALLER_REHEARSAL_PASS.json`.
- Gate SHA-256: `A878BCFF2B49FCD676BAE9FF24C1AEDC7F44B5A4DD91665ADB64D5E73AC839A5`.

This local package remains valid frozen rehearsal evidence, but it was not installed or published.

## GUIR7 portal request withdrawal

Signed local request `REQ_G7_0822_A1` was never published. Its first exact local endpoint rehearsal returned a signed local `FAILED` response before any task/process action or inner ZIP extraction. Windows PowerShell 5.1 rejected `@($priorRows)` where `priorRows` was a `Generic.List[object]` with `Argument types do not match`.

- Withdrawal: `work/GUIR7_PORTAL/GUIR7_PORTAL_WITHDRAWAL.json`.
- Withdrawal SHA-256: `9423761CBF6B117ACBC3FF24160A9E2FA3D662BD006173BB553CE4E439BD292C`.
- Signed manifest SHA-256: `65DFFEC304853929B3A8119F45799AB5FE69230744F3FAE9FDD5454EBD7A332B`.
- Signed request signature SHA-256: `613E89BB83B65787451A9D41E0505ED3FA4E39225293CCE9F8B0080657629F65`.
- Local failure response: `R_2294BAEED240_20260822194700116_358cf406` under retained root `C:\G7E2`.

The request, entrypoint, `C:\G7E`, and `C:\G7E2` are non-reusable and cannot be published, replayed, or parent a successor.

## GUIR8 pre-sign successor withdrawal

One fresh, unsigned successor was attempted with the generic-list boundary removed. Its exact Windows PowerShell 5.1 non-mutating result-construction preflight passed and emitted all four explicit predecessor rows. The full direct pre-sign rehearsal then failed before the inner installer ran: the child PowerShell emitted the Windows PowerShell banner rather than JSON because the process helper declared `$Args`, colliding with the automatic `$args` variable and leaving the constructed child argument list empty.

- Withdrawal: `work/GUIR8_PORTAL/GUIR8_DRAFT_WITHDRAWAL.json`.
- Withdrawal SHA-256: `EFA2485C1E882F113E07ADD8BF8B6123C2238A2F33B107BAC7073D3143CDCDE5`.
- Retained local root: `C:\G8D`.
- The four fixture destinations were restored to the exact predecessor hashes.
- No inner GUIR7 audit root was created, proving the inner installer did not execute.
- GUIR8 was not signed, zipped, published, or sent to any endpoint.

GUIR8 and `C:\G8D` are non-reusable. The newly recorded failure-prevention rule requires a non-reserved `$ArgumentList` parameter, a nonempty exact `ProcessStartInfo.Arguments` assertion containing the pinned `-File` scalar, and full parsed-result validation before any future signature.

## Safe-stop evidence

- Engineering-share Project Portal request queue count after both failures: `0`.
- JBOD requests published: `0`.
- JBOD terminal responses generated: `0`.
- JBOD task actions: `0`.
- JBOD process actions: `0`.
- JBOD installed changes: `0`.
- Processor actions: `0`.
- Image bytes read: `0`.
- Source/deletion/wafer actions: `0`.
- Checkpoint preaction: `work/GUIR8_PORTAL/GUIR8_STOP_CHECKPOINT_PREACTION.json`, state `PASS_ARGOS_ZERO_RECURRENCE_PREACTION` across 90 audited issues and 10 pinned dependencies.

## Continuation rule

Stop GUI package iteration here. Do not publish GUIR7, sign or repair GUIR8, or create another successor in this task. If the operator later directs another attempt, begin in a fresh namespace from the still-valid frozen GUIR7 local installer evidence—not from either withdrawn portal entrypoint—and first prove the exact child argument string and complete Windows PowerShell 5.1 success/failure result paths. Leave the healthy processor and fiducial pause untouched.
