# JBOD runtime recovery and PFC004 fiducial result checkpoint — 2026-08-19

Disposition: `PENDING_GATE`

This checkpoint supersedes the prior PFC004 exact-JSON DATA_PULL publication
checkpoint as continuation authority. The 38-file export was retrieved and
verified before the analyses below. No judgment raster, production defect
score, XML geometry, training authority, or production routing is created.

## JBOD inspection-log and Insite wait root-cause repairs

The JBOD all-wafer inventory outage was caused by a global parser exception:
the installed parser accepted only `HUMAN_CONFIRMED_REVIEW_ONLY`, while valid
V38 Slot08/09 identity rows used
`IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY`. Revision
V3.8.1 accepts the bounded declared identity states without weakening identity
or scribe evidence. It also replaces the Insite bridge's permanent canonical
pending-set suppression with terminal/incomplete-response-aware retry.

Signed request `REQ_20260818T225050553Z_20D98AA60E53` returned terminal signed
response `R_E8483FD28223_20260818225256222_4d7f4085`. A separate live proof
request `REQ_20260818T230529479Z_89F405E92C47` returned
`R_06A5D619CBBD_20260818230536943_f309dcd4`. Live state was `WATCHING` with
3,664 BMP files, 1,832 acquisitions, 590 route-ready records, and processor
state `PROCESSING`. Post-patch completions included Slots08, 09, and 10; the
Insite bridge advanced from 678 MES / 36 pending to 681 MES / 33 pending.

Installed V3.8.1 hashes are:

- inventory parser:
  `D171972C23CB810EFEFEB04E74B0403E2BB1AC48BDDDAC7A07A0FE99D0A755EE`;
- exporter:
  `5B9EA64DDFF4712D5BAF912C5B231B0F80282247425FB0E89B79D8830E855EE8`;
- importer:
  `7CD27A49769CA869D6ADE35655D389A90A021321D62B96631D1B68DBBEE89EBC`;
- bridge worker:
  `886A9B5A7F81F4537043F99F8913521A6AC688A8DEA3ACCDB6AA06881B3A6F89`.

## Portal queue root cause and live repairs

The gateway request-share importer was stuck because the exact PFC004 retry
already existed in its deterministic outbox after an interrupted import. The
old importer treated the exact-match collision as a process-fatal failure and
retried every two seconds. GWQ2 now resumes exact matches, quarantines
mismatches, advances the queue, and deduplicates logs. Signed direct gateway
request `REQ_20260819T000355413Z_0A168CBF22BF` returned terminal response
`R_D5F0E44E3EFB_20260819000525487_d02a7df6`.

The next queue head was the first PFC004 request existing in both gateway
request-sender pending and sent. The predecessor transport contacted the
receiver before discovering the sent-archive collision, allowing repeated
network replay and then refusing the local archive overwrite forever. GWQ4
moves exact pending/sent duplicates to local duplicate quarantine before any
network call; mismatches and malformed packages become terminal local holds;
later items advance. The exact Windows PowerShell 5.1 gate covers exact
duplicate resume, mismatch, malformed input, a second control, and effective
path boundaries 199/200/229/230. Live request
`REQ_20260819T002449445Z_44D45D2738C3` returned direct terminal response
`R_BD457D55E1CE_20260819002810073_e4275135`. Gateway transport SHA-256 is
`843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB`;
only `ArgosProjectPortal.Gateway.RequestSender.RO` was restarted.

The same queue-safe transport was then installed on Argos for only
`ArgosProjectPortal.Argos.RequestSender.RO` and
`ArgosProjectPortal.Argos.ResponseRelay.RO`. Signed request
`REQ_20260819T004457880Z_B4D076FE122C` returned verified signed response
`R_F14B49A49F48_20260819004722980` with terminal
`PASS_MAINTENANCE_PATCH`. Both tasks are running on transport SHA-256
`843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB`.

Signed diagnostic request `REQ_20260819T005027303Z_9C799D4595FC` returned
verified response `R_6E65BF659834_20260819005112214`. It proves all five Argos
portal tasks are running, but the PFC004 retry remains Argos pending and not
sent. The exact sender state is `SEND_RETRY_PENDING`; detail is
`Timed out connecting to relay receiver`. A direct TCP audit confirms
`172.16.0.10:48716` is not accepting connections. Therefore the remaining
root cause is the stopped/unreachable JBOD request receiver, not fiducial
calibration and not the gateway or Argos queues.

## Released JBOD receiver recovery

The separately rehearsed manual/admin recovery is
`I:\ARGOS_JBOD_PORTAL_TRANSPORT_QUEUE_RECOVERY_JBQ1.zip`, 30,760 bytes,
SHA-256
`46341FCAF2FA2E7DFB6298C1ADAAD0E3A92EEC9568115132FCAF95D3A414B678`.
Its gate is the adjacent
`ARGOS_JBOD_PORTAL_TRANSPORT_QUEUE_RECOVERY_JBQ1.zip.RELEASE_GATE_RESULT.json`,
SHA-256
`414C739B2FACBA40E6A610CCFCB24E0C5C9AA68A429CD69931091722F65DC18F`.

The exact final ZIP passed source and extracted Windows PowerShell 5.1
rehearsals for the one approved predecessor, idempotent target, unapproved
predecessor refusal before write, exact duplicate queue advance, wrapper
safety, and path limits. It contains one operator launcher. On the JBOD host,
extract the complete ZIP to `C:\JBQ1` and run `RUN_JBQ1.cmd` as Administrator.
The launcher writes a persistent create-new log, runs non-mutating preflight,
then applies automatically. Only these tasks may be stopped/restarted:

- `ArgosProjectPortal.JBOD.RequestReceiver.RO`;
- `ArgosProjectPortal.JBOD.ResponseSender.RO`.

The launcher requires `172.16.0.10:48716` to listen before success. Detector,
scribe, Insite, monitor, inspection, image, alignment, reviewer, XML, training,
and production tasks are not touched. The PFC004 retry request
`REQ_20260818T232640487Z_591E16C31AD5` has no signed terminal response yet and
must not be described as executed or complete.

## PFC004 fiducial result

The reusable method remains locked as `ARGOS_FIDUCIAL_MODEL_WORKFLOW_V1`:
operator topology designation when needed; native full-resolution BF/DF
calibration of every fixed straight line; complete inner/outer corner-profile
exclusion; frozen topology/polarity/line identity; invariance and lookalike
checks; then independent no-tuning validation. Per-candidate line refits,
BF/DF averaging, edge-family switching, XML-bin location assumptions, and
target-specific tuning remain prohibited.

The exact returned PFC004 evidence supports six of six fiducial qualifications
on Slots02, 04, 06, 08, 09, and 10. Slots02/04/06/08/10 pass the frozen strict
contract. Slot09 passes a bounded paired-channel recovery: BF retains 12/12
fixed lines; DF retains 11/12 strict lines and recovers only weak fixed-polarity
`L07_BOTTOM_CAP_H`. Recovery activates exactly once in all 300 stored
candidates, only on Slot09; negative mutations hold. There is no geometric
refit, polarity swap, inner/outer edge swap, or corner evidence admitted.

The governing diagnostic is
`work/PATTERNED_FIDUCIAL_INVENTORY/analysis/PFC004_LT1A_PAIRED_CHANNEL_RECOVERY_DIAGNOSIS_V2.json`,
SHA-256
`B673E3B1BBBC5D2C2B989026FE280EAC62CDBFAD979E56D5B2F5779C236B391D`,
state
`PASS_DIAGNOSTIC_PFC004_SIX_OF_SIX_WITH_BOUNDED_PAIRED_CHANNEL_RECOVERY`.
This resolves the fiducial-model issue for every wafer with a qualified pose.

Slot07 remains
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD_REVIEW_REQUIRED`. Its notch audit SHA-256 is
`7A683A898FDDD0AF099BB33789B5DBC5E09EB4E8E587876F359C14AFC0A59EC3`.
This is an operator-visible notch review hold, not a fiducial failure and not
Normal/reject truth. No notch candidate was forced by fixed angle or deepest
indentation.

## Ordered next action

1. Run the single JBQ1 launcher locally on JBOD and retain its persistent log.
2. Require the existing PFC004 retry to leave Argos pending and receive one
   matching signed JBOD terminal response; do not publish another JBOD request
   first.
3. Verify the response with the pinned JBOD endpoint certificate and require
   normal state `PASS_PFC004SB2_TERMINAL_REVIEW_ONLY`, exact-resume evidence,
   and audit SHA-256
   `2078C1695A13C1D33F7282E4C3711A5197A49515361FD3E907C05D4CD885A50E`.
4. Present Slot07 notch evidence for operator review. Only after a fresh
   alignment-transfer pass may patterned production defect scoring begin.

All 11 other top-level unresolved `PENDING_GATE` objects, the map hold, nine
pose holds, category/designation holds, later wet-strip separation, and
immutable R5P30 authority remain preserved.
