# JBQ2 protected-principal failure and JBQ2A release checkpoint

Date: 2026-08-19  
Revision: `JBQ2_PROTECTED_PRINCIPAL_FAILURE_AND_JBQ2A_RELEASE`  
Disposition: `RELEASED_REVIEW_ONLY`

## Live JBQ2 preflight result

The operator-run JBQ2 package failed closed during its non-mutating preflight
with:

`Task principal changed: ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2`

The recovered text is
`work/JBQ2/JBQ2_LIVE_PREFLIGHT_FAILURE_RECOVERED_FROM_OPERATOR_20260819.txt`,
729 bytes, SHA-256
`214447E80D4AA58BB147F854EB09F4EDBAF63651645CE219018D8A493C64DF13`.
The launcher had not reached its apply phase. No portal, detector, processor,
scribe, Insite, monitor, or inspection task was changed.

JBQ2 is withdrawn from live use. Its defect was a stale principal assertion:
the same helper pinned `SYSTEM` for both authorized portal tasks and unrelated
protected tasks. The monitor's pre-existing ordinary-user principal was
therefore rejected even though the package was not authorized to touch that
task.

## Corrected JBQ2A package

JBQ2A separates authorization from preservation:

- only `ArgosProjectPortal.JBOD.Endpoint.RO` and
  `ArgosProjectPortal.JBOD.ResponseSender.RO` are accepted by the literal task
  mutation wrapper;
- those authorized portal tasks retain the pinned `SYSTEM` requirement;
- every protected task is dynamically snapshotted with its actual principal
  and exported task-definition SHA-256 before apply;
- protected principal and definition SHA-256 must match after apply;
- natural protected-task `Ready`/`Running` transitions are recorded but are
  not mislabeled as a package mutation.

The exact final ZIP passed source and extracted Windows PowerShell 5.1
preflight/rehearsal, two source and two extracted wrapper gates, exact
extraction/hash comparison, four synthetic task-guard cases, a real read-only
ordinary-user scheduled-task rehearsal, and AST verification that both raw
scheduled-task mutation commands remain confined to the two-name wrapper.
The failure-prevention memory now records this failure signature and recovery.

Release artifacts:

- ZIP:
  `I:/ARGOS_JBOD_PORTAL_ENDPOINT_DRAIN_JBQ2A.zip`;
- operator-visible UNC:
  `\\shm-cifs/Department/DE-1302_FAB_BE_Engineering/60_Saw_VI_Sort/600_General/Joshua.conn/AVI_Images/Argos/Uploads/InspectionRevs/ARGOS_JBOD_PORTAL_ENDPOINT_DRAIN_JBQ2A.zip`;
- ZIP bytes: `8031`;
- ZIP SHA-256:
  `B4F83E0D91D58CA2D49A125D2B1ABF3E8D1E186E4F499EDA065483C885DAFA2C`;
- release-gate SHA-256:
  `2BF9FF114958AD0D60FE6497468013F417F8B4CD19D9BB9D46AE523F8BCBE9A0`;
- exact request: `REQ_20260818T232640487Z_591E16C31AD5`;
- exact request-manifest SHA-256:
  `9935A275D66F4EA6351427B7C966F8E04DA681EEBA5A7DA3B8D20E220D1D1FBD`;
- required installed endpoint worker SHA-256:
  `64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`.

## Required next sequence

1. Do not rerun JBQ2.
2. On JBOD, extract the distinct JBQ2A ZIP to a short fresh local directory
   and run `RUN_JBQ2A.cmd` as Administrator.
3. Require `PASS_JBQ2A_EXACT_ENDPOINT_DRAIN` and retain the create-new
   ProgramData transcript.
4. Require one matching signed terminal response for the already-published
   PFC004 request. Do not publish another request first.
5. Verify `PASS_PFC004SB2_TERMINAL_REVIEW_ONLY`, exact-resume evidence, and
   final audit SHA-256
   `2078C1695A13C1D33F7282E4C3711A5197A49515361FD3E907C05D4CD885A50E`.
6. Then retrieve the exact Completed Lot dashboard manifest and viewer stderr,
   repair that proven failure, and separately audit the `24/30` inspection.

All work remains review-only, training-ineligible, XML-ineligible,
production-ineligible, and production-routing-disabled. The storage migration
from high-volume `C:` output roots to `D:` remains a separate gated repair and
is not performed by JBQ2A.
