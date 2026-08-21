# JBQ2A live worker collision and JBQ2B release checkpoint

Date: 2026-08-19  
Revision: `JBQ2A_WORKER_COLLISION_AND_JBQ2B_RELEASE`  
Disposition: `RELEASED_REVIEW_ONLY`

## Live JBQ2A result and withdrawal

JBQ2A passed its corrected protected-task preflight and started the installed
JBOD portal endpoint. That live start exposed a deeper pre-existing endpoint
worker defect at the older queue-head request
`REQ_20260818T231924045Z_B5BF14D98D13`.

The endpoint created signed compact failure response
`R_D997CDF11F4B_20260819131136555_07d20bb8`, state `FAILED`, detail
`Portal request ledger exists without its ready response.` The response sender
committed that response to its sent root. The worker then attempted a
create-new write to the already existing poisoned ledger and stopped before it
could archive the request and advance the queue. On restart, the worker would
search only the pending response outbox and could not see the already-sent
signed response.

The exact intended PFC004 request
`REQ_20260818T232640487Z_591E16C31AD5` therefore remained without a signed JBOD
terminal response. JBQ2A is withdrawn and must not be rerun. No new portal
request was published, and no detector, processor, scribe, Insite, monitor, or
inspection task was changed.

## JBQ2B endpoint worker correction

The target endpoint worker SHA-256 is
`5A861FB4BF95A9A7978057B20101B2A6C1F2E4CA8332D6BAC8AF4EDBB6767D7A`.
It makes the queue-head recovery resumable and terminal:

- signed ready responses are searched and verified in both the response
  pending root and the sender sent root;
- an already-sent response replay-archives the exact request without creating
  a duplicate response;
- a pre-existing ledger with no response is preserved in a short path-gated
  ledger quarantine before one terminal ledger is committed;
- a terminal-ledger failure attempts restoration of the preserved prior
  ledger;
- the worker continues to the next queued request in the same lifetime.

The installer accepts only the exact installed predecessor SHA-256
`64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`
or the target hash above. It atomically installs the target with a legal,
create-new predecessor backup path. An injected post-replacement failure
atomically restores the predecessor and preserves the displaced target.

Only `ArgosProjectPortal.JBOD.Endpoint.RO` and
`ArgosProjectPortal.JBOD.ResponseSender.RO` are authorized for task mutation.
Every protected task retains its dynamically captured principal and exported
definition hash. Runtime configuration hashes remain invariant.

## Exact-package release gates

The fresh final ZIP extraction passed all of the following under Windows
PowerShell 5.1:

- five-case exact installer matrix: non-mutating predecessor preflight,
  predecessor replacement/archive, target idempotence, unapproved refusal
  before mutation, and injected replacement rollback;
- sixteen-case queue-recovery matrix including effective path boundaries 199,
  200, 229, and 230; work/partial collision; injected response failure;
  forced termination/restart; replay; and a second queued control request;
- exact sent-response replay and poisoned-ledger test with signed compact
  failure, prior-ledger quarantine, terminal-ledger commit, no duplicate
  replay response, successful second control request, and zero queue remainder;
- extracted apply and launcher wrapper gates;
- exact package-manifest hashes, fresh ZIP extraction, task-mutation AST
  allowlist, and path/component budgets.

Evidence SHA-256 values:

- exact extracted installer:
  `42A789182E12C85D2A6E9708412E8B294845640E2789B6AC86AA19246E633F6E`;
- sixteen-case queue recovery:
  `FF8C5A06E8C02AD03775FC7DD3FA4AC48B87CECDC63A57D96242B1B5FDD76B8B`;
- sent-response/ledger queue advance:
  `504123A0582E7F27468D3F76764C105D174CE604681CBD08688F8C610F65E297`;
- extracted apply wrapper:
  `A90A4DA508F5549810E51C3F7B4E94C40A25CF20DC656BCD7DB5AC6E231780A5`;
- extracted launcher wrapper:
  `C40CC79248E35C0AF1D23B2789D110D3317158B938A80A99986F7737A04C0BEF`.

## Published release

- operator-visible ZIP:
  `\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_JBOD_PORTAL_QUEUE_WORKER_PATCH_JBQ2B.zip`;
- ZIP bytes: `17976`;
- ZIP SHA-256:
  `CDF4516932129C5E887516D8CD8DD6407386AF6219EEC1401B8CF19D915337A4`;
- release-gate leaf:
  `ARGOS_JBOD_PORTAL_QUEUE_WORKER_PATCH_JBQ2B.RELEASE_GATE.json`;
- release-gate bytes: `3908`;
- release-gate SHA-256:
  `B4DCB07CFECAE660FF500EC52910B6FF7772E5FED801E40FEA3A383EF890784E`;
- exact PFC004 request-manifest SHA-256:
  `9935A275D66F4EA6351427B7C966F8E04DA681EEBA5A7DA3B8D20E220D1D1FBD`.

Both share copies were created new through the verified engineering-share
alias and hash-match the tested local artifacts. The operator does not need an
`I:` drive; the UNC path above is authoritative.

## Required next sequence

1. Do not run JBQ2, JBQ2A, or any old `APPLY` script.
2. On JBOD, copy/extract the JBQ2B ZIP to fresh short root `C:\JBQ2B` and run
   `RUN_JBQ2B.cmd` as Administrator.
3. Require `PASS_JBQ2B_QUEUE_WORKER_PATCH_AND_DRAIN`. Retain the create-new
   transcript under
   `C:\ProgramData\ArgosProjectPortalRO\state\operator_logs`.
4. Verify one matching signed terminal response for already-published PFC004
   request `REQ_20260818T232640487Z_591E16C31AD5`. Do not publish another JBOD
   request first.
5. Verify normal state `PASS_PFC004SB2_TERMINAL_REVIEW_ONLY`, exact-resume
   evidence, and audit SHA-256
   `2078C1695A13C1D33F7282E4C3711A5197A49515361FD3E907C05D4CD885A50E`.
6. Only after that terminal-response gate, retrieve the exact current
   Completed Lot dashboard manifest and viewer startup stderr and repair the
   viewer root cause. Separately audit the operator-visible `24/30` inspection
   without changing its task until exact evidence authorizes recovery.
7. Keep the C-to-D high-volume output migration as a separate hash-verified
   bounded repair.

Fiducials remain resolved for all six pose-qualified wafers. Slot07 remains an
operator-visible notch review hold. All earlier registration and transfer
prerequisites and immutable R5P30 remain in force. No judgment raster,
alignment transfer, production defect scoring, XML, training, or production
routing authority is granted.
