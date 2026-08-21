# Project Portal JBOD queue-recovery V2.1 released checkpoint

Date: 2026-08-17  
Revision: `PORTAL_JBOD_QUEUE_RECOVERY_V2_1_PACKAGE`  
Disposition: `RELEASED_REVIEW_ONLY`

## Outcome

The corrected V2.1 manual JBOD recovery package is published create-new to the
operator-provided `InspectionRevs` share. All four share files hash-match the
sealed local artifacts:

- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.zip`, 34,471 bytes, SHA-256
  `9BC3319A2D0988CB6ADAEE78EB5C5A02C3FAF049394E1262C798AB31B532FF56`;
- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.PATH_PREFLIGHT.json`, SHA-256
  `89362BE14786A481A98DC6282AA71DE64ED85B9A51851CE175C9616EAF2CAB72`;
- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.REHEARSAL_PASS.json`, SHA-256
  `F4FCE2D1E2AFDC35DFFA575EC6374ADE1456ECCB52ACCE16F2B23BF8A7E6EDC6`;
- `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.FINAL_PACKAGE_GATE.json`, SHA-256
  `1C19698CCB928264DA129351D32D500D4984404969638EB79CFBBB69EC61753D`.

Publication used a verified persistent short drive whose `DisplayRoot` exactly
matched the supplied share. The known V2 sentinel hash was verified through
that mapping before write. Every V2.1 leaf was absent, copied to a create-new
`.partial`, hash-verified, and atomically renamed. The short drive was removed
after publication.

## Exact recovery behavior

V2 remains `WITHDRAWN`; its `RUN_RECOVERY.cmd` must not be run. V2 preflight
made no live changes.

V2.1 has no expiry bypass. Its preflight requires the exact old patterned
request to be signed, hash-pinned, and already expired. It verifies that
request only for quarantine and refuses it for execution. It also requires the
exact FM7P24A maintenance request to remain signed, hash-pinned, and unexpired.

On apply, only the Project Portal JBOD endpoint and response sender stop. The
expired request, exact incomplete work root, and exact response partial move
recoverably to `C:\Q\A\R`, `C:\Q\A\W`, and `C:\Q\A\P`; the current FM
request remains in the live queue. The queue-safe worker is installed from its
sole approved predecessor, portal configs remain hash-identical, the response
sender and endpoint restart, and the request receiver plus detector, scribe,
Insite, and monitor tasks remain unchanged.

## Operator action

On JBOD:

1. Extract only `ARGOS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1.zip` to a fresh short
   local folder such as `C:\APR21`.
2. Run `PREFLIGHT_ONLY.cmd`.
3. Continue only if it reports
   `PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_PREFLIGHT_EXPIRED_REQUEST_QUARANTINE`
   and `ExpiredRequestEligibleForExecution : False`.
4. Run `RUN_RECOVERY.cmd` as Administrator and leave it open through success.

The current FM request expires at `2026-08-18T15:39:23.2520241Z`; V2.1 fails
closed if that current request is no longer valid. After successful recovery,
verify the signed FM7P24A terminal response. Only after endpoint health is
proven may the still-required patterned metadata be requested again under a
fresh signed request ID with an explicit replacement relationship.

This package changes no image, inspection, alignment, composite, defect, mask,
threshold, reviewer, XML, training, or production authority. JBOD apply is
still pending operator execution.
