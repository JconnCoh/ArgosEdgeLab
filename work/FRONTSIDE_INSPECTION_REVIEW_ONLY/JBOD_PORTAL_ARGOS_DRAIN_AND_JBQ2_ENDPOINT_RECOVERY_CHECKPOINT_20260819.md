# JBOD portal Argos drain and JBQ2 endpoint-recovery checkpoint

Date: 2026-08-19  
Revision: `JBOD_PORTAL_ARGOS_DRAIN_AND_JBQ2_ENDPOINT_RECOVERY`  
Disposition: `RELEASED_REVIEW_ONLY`

## Live transport result

The operator-run JBQ1 transcript proves that the exact queue-safe transport
SHA-256
`843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB`
was installed on JBOD, both authorized JBOD portal transport tasks were
running, and `172.16.0.10:48716` was listening. The operator-pasted transcript
was recovered as
`work/JBQ1/JBQ1_LIVE_TRANSCRIPT_RECOVERED_FROM_OPERATOR_20260819.txt`,
3,843 bytes, SHA-256
`647371DEC4B0DE14ECE4A8FD4E2319FEE500700B95CCC050F328A33846F22F86`.

Fresh signed Argos maintenance request
`REQ_20260819T122205653Z_885B10B13E2F` then reran the already-rehearsed,
idempotent Argos sender recovery. Signed response
`R_B5D594583F00_20260819122427776` passed the pinned Argos certificate and all
declared file hashes. Its endpoint stdout proves exact PFC004 retry
`REQ_20260818T232640487Z_591E16C31AD5` changed from pending to sent, both Argos
relay tasks were running, no transport binary update was needed, and stderr
was empty.

This distinguishes gateway acceptance from actual Argos-to-JBOD delivery and
closes the Argos sender failure branch.

## Remaining JBOD endpoint failure branch

The exact PFC004 request still had no matching signed terminal response at
`2026-08-19T12:37:54Z`. Its packaged verifier has a bounded exact-resume path,
so this delay is not accepted as normal execution time. No second JBOD portal
request was published.

The separately rehearsed manual/admin recovery is JBQ2:

- share ZIP: `I:/ARGOS_JBOD_PORTAL_ENDPOINT_DRAIN_JBQ2.zip`;
- bytes: `7251`;
- SHA-256:
  `6F4645EE8DDBD953E2D1E448D2B8A14F19A6F4947AC16006BCB6D2B6FA7718D0`;
- release-gate SHA-256:
  `6398005D14E5AE6F49857C62DC644619FD3AB71BC45C06E9B2B3A5200277CBCD`;
- exact request manifest SHA-256:
  `9935A275D66F4EA6351427B7C966F8E04DA681EEBA5A7DA3B8D20E220D1D1FBD`;
- required installed queue-safe endpoint worker SHA-256:
  `64F1BFA34A2F54F6D84D14C5D91BC270346E88E3D95E2E303C0A858206E770B2`.

JBQ2 performs a non-mutating exact-state preflight, refuses a ledger without a
recoverable signed response, replays an already signed sent response when that
is the recoverable state, or drains the exact pending request by restarting
only `ArgosProjectPortal.JBOD.Endpoint.RO`. It may restart the JBOD portal
response sender only for signed-response return. Exact incomplete maintenance
and staged paths may move recoverably to a short `C:/Q/B2` root. It does not
touch detector, processor, scribe, Insite, monitor, or inspection tasks.

The exact final ZIP passed Windows PowerShell 5.1 wrapper checks, exact signed
request verification, final-ZIP extraction, route/path budgeting with maximum
effective length 162, and a synthetic exact endpoint-state rehearsal. Its
create-new persistent transcript is under
`C:/ProgramData/ArgosProjectPortalRO/state/operator_logs`, independent of the
operator's Downloads folder.

## Inspection and viewer separation

The operator-visible inspection progress at `24/30` was not paused or changed
by this work. Only portal tasks were changed. The inspection progress issue is
a separate status/audit item and remains untouched pending exact evidence.

The Completed Lot button failure remains diagnosed but not yet patched. The
tray launches the viewer without retaining stderr; the viewer validates the
entire current dashboard manifest at startup and exits on the first invalid
catalog row or referenced asset. The current installed manifest and exact
startup exception must be retrieved only after the existing PFC004 request
receives its signed terminal response. Inspection evidence must not be
regenerated to repair the viewer.

## Required next sequence

1. On JBOD, extract the exact JBQ2 ZIP to a short fresh local root and run
   `RUN_JBQ2.cmd` as Administrator.
2. Retain the ProgramData JBQ2 transcript and require
   `PASS_JBQ2_EXACT_ENDPOINT_DRAIN`.
3. Require one signed terminal JBOD response for exact PFC004 request
   `REQ_20260818T232640487Z_591E16C31AD5`; do not publish another JBOD request
   first.
4. Verify normal endpoint state `PASS_PFC004SB2_TERMINAL_REVIEW_ONLY`, exact
   resume evidence, and final audit SHA-256
   `2078C1695A13C1D33F7282E4C3711A5197A49515361FD3E907C05D4CD885A50E`.
5. Only then retrieve the exact current dashboard manifest and viewer startup
   stderr, patch the Completed Lot root cause, and validate the real tray
   launch.
6. Audit the separate `24/30` inspection progress without stopping or
   restarting its worker unless exact evidence authorizes a bounded recovery.

All work remains review-only, training-ineligible, XML-ineligible,
production-ineligible, and production-routing-disabled. Fiducials remain
resolved for all six pose-qualified PFC004 wafers; Slot07 remains an
operator-visible notch review hold.
