# Argos checkpoint — JEO1 JBOD evidence observation frozen; publication pending

Date: 2026-08-25

Revision: `JBOD_EVIDENCE_OBSERVATION_JEO1_20260825`

Disposition: `PENDING_GATE`

## Outcome

The exact next recovery step is frozen as one portable direct-admin read-only
observation package outside the blocked JBOD Project Portal queue. `JEO1` is a
D-drive-only evidence collector. It has not contacted JBOD, has not run on a
production host, and has not changed any target state.

Frozen package:

- path: `work/JBOD_EVIDENCE_OBSERVATION_JEO1/final/ARGOS_JEO1.zip`
- bytes: `10365`
- SHA-256: `DFAA7601296DB64870D7C8752490EAF0FD962A8338AC12395480CD6F489889C4`
- final gate:
  `work/JBOD_EVIDENCE_OBSERVATION_JEO1/final/JEO1_FINAL_PACKAGE_GATE.json`
- final-gate SHA-256:
  `6B2B0410BC89E5151CCA9085BFE642E3B14387AC9AE5E0396C48CAD0C5504D74`

The package lifecycle is `FROZEN`. Its bytes are immutable. Any package defect
requires withdrawal and a fresh namespace; `JEO1` must not be patched in place.

## Corrected access topology and scope

The only authoritative operator access path is:

`engineering laptop -> RustDesk gateway -> gateway RDP to Argos -> Argos RDP to JBOD`

`DFLY3005` is a Rudolph tool, is not Argos, and is excluded from this workflow.
No package, observation, or future evidence-channel design may use DFLY3005 as
an Argos or JBOD access hop.

Native RustDesk/RDP desktop control is not exposed to this Codex task. JEO1 is
therefore designed so the only required operator action after publication is
one launch on the already-open JBOD desktop, not a sequence of manual relay or
diagnostic steps.

## Observation boundary

JEO1 performs only metadata, bounded text, exact evidence-ZIP, drive-space,
process/task identity, installed-config, and exact portal-state observation.
It captures the already-existing CDM1 evidence needed to determine what the
operator attempt did without rerunning CDM1. It also captures exact O2D4
endpoint state needed to resolve the blocked request without a retry.

All JEO1 live files remain on JBOD `D:`:

- persistent launch log: `D:\A2\x\JEO1_LAUNCH.log`
- evidence root: `D:\A2\x\JEO1`
- local result ZIP: `D:\A2\x\JEO1R_LOCAL.zip`
- returned result name: `JEO1R.zip`

The package does not install a helper, change an installed file, start, stop,
or restart a task or process, change a queue or ledger, read image bytes,
delete a source, abort a wafer, or write evidence to `C:`. Exact CDM1 result
ZIP bytes may be preserved as bounded file-backed evidence; image extensions
are never content-read.

## Frozen gates

- Windows PowerShell 5.1 ZERO/ONE/MANY and exact-evidence test gate SHA-256:
  `8DA52535416F335F1BAA24189F33CC0AA007642FA7D7774C42D15DD913E59390`
- path gate SHA-256:
  `15894BC8431AE193EA113261279037E2F34C5CE4015CA8EDE3B10B74F10FCE74`
- clone-literal gate R2 SHA-256:
  `27C66B560C7019FF183A715B7EBE8A131858492CBC40602FB905ABA15C90CB83`
- zero-recurrence preaction SHA-256:
  `AD524E3EA65537C8980CC1EAA277F6A00CBE3222F2C018EA74BA3F5B0BE47E77`
- recovery intent SHA-256:
  `CF941ECA21F23D53C0765A8EB6835B454C7749672517E0D08F3341E14F799A69`
- direct-admin authorization gate SHA-256:
  `6734664D2FE3E4A4EA3DAC6752C08AF171BA1DB81D4A9FA6A65BF72FB869B1E7`
- direct-admin capability inventory SHA-256:
  `2C63C7C57E57CE089F057101F240D20A01D0118ECB32E17F2BDCF671A29F49DA`
- incident observation authority SHA-256:
  `606168B8F5410BD68D917AD5B7446329F5CB5CECFCD55713A68309ABF70626EF`

The maximum effective path length is 185 with the required suffix reserve;
the maximum component length is 30. The final ZIP has five exact entries, and
fresh extraction passed wrapper, harness, rehearsal-preflight, and engineering-
laptop refusal gates. Tests report zero target mutations and zero image-byte
reads.

## Current CDM1 evidence status

The operator reported attempting CDM1 and later seeing only 1.63 GiB free on
JBOD `C:`. `CDM1R.zip` remains absent from the engineering share. This is not
proof of a successful or failed deletion. CDM1 must not be rerun. JEO1 will
recover the persistent D-side launch log, any local CDM1 output/result ZIP, the
current aggregate counts under the three exact retired C roots, and current C
and D free space. The historical `outputs` tree remains excluded from deletion.

## Unresolved prerequisite sequence

The fixed prerequisite order is:

1. Publish the exact frozen JEO1 ZIP and adjacent machine path gate create-new
   after clean matching local/origin branch tips.
2. Run JEO1 once on JBOD as administrator from a fresh `D:\JEO1` extraction.
3. Collect and verify only exact `JEO1R.zip`, or recover its exact D-side local
   evidence if the share return is absent. Do not rerun JEO1 merely because a
   share return is absent.
4. Pin the direct post-attempt CDM1 and O2D4 observation before any mutation.
5. Build the separately authorized durable signed read-only JBOD evidence
   channel outside the blocked portal queue.
6. Resolve O2D4 terminal state. Slot16 remains unfrozen until exact evidence
   justifies a disposition; Slot17 remains blocked until Slot16 is frozen.
7. Slots22-25 remain unseen until the development contract is frozen.

No later reviewer, detector, transfer, or production-source action may bypass
this sequence.

## Preserved authority and holds

- Review-only authority remains unchanged.
- The healthy processor must remain running with unchanged identity; no
  processor or scheduled-task action is authorized.
- The live OpenCV provider remains disabled.
- Slot16 remains unfrozen; Slot17 remains blocked; Slots22-25 remain unseen.
- `SCRIBE_REFERENCE_COVERAGE_HOLD` and every other existing hold remain.
- `REQ_O2D4` is non-reusable and must not be retried.
- `ARGOS_CDM1.zip`, `ARGOS_CDO1.zip`, and `ARGOS_O2A2.zip` must not be run.
- JEO1 grants no image processing, XML, training, production routing,
  deletion, source mutation, or wafer authority.

## Exact next action

Commit and push the frozen JEO1 checkpoint and exact package evidence, fetch
`origin`, and require a clean worktree with matching local and remote tips.
Then publish only the exact frozen `ARGOS_JEO1.zip` and its adjacent machine
path gate create-new to `InspectionRevs`.

After publication, the operator's one action is to copy/extract the ZIP on the
already-open JBOD desktop to fresh `D:\JEO1`, right-click `RUN_JEO1.cmd`, and
choose **Run as administrator**. The launcher leaves a persistent D-side log
and returns `JEO1R.zip`. No other package is to be run and O2D4 is not retried.
