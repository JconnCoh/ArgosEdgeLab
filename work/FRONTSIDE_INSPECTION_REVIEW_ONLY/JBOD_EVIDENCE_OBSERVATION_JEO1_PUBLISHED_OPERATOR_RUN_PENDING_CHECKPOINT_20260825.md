# Argos checkpoint — JEO1 published; one JBOD observation run pending

Date: 2026-08-25

Revision: `JBOD_EVIDENCE_OBSERVATION_JEO1_PUBLISHED_20260825`

Disposition: `PENDING_GATE`

## Outcome

The exact frozen JEO1 direct-admin read-only observation package and its
machine path gate were published create-new to `InspectionRevs`. Share
readback matches the frozen local evidence. `JEO1R.zip` is absent because JEO1
has not run on JBOD. Publication did not contact JBOD and did not execute the
target collector.

Published files:

- `ARGOS_JEO1.zip`
  - bytes: `10365`
  - SHA-256: `DFAA7601296DB64870D7C8752490EAF0FD962A8338AC12395480CD6F489889C4`
- `ARGOS_JEO1_PATH_GATE.json`
  - bytes: `7925`
  - SHA-256: `15894BC8431AE193EA113261279037E2F34C5CE4015CA8EDE3B10B74F10FCE74`

Publication gate:

- path:
  `work/JBOD_EVIDENCE_OBSERVATION_JEO1/JEO1_PUBLICATION_GATE.json`
- SHA-256:
  `0F3077FA4324D07C219F78D354F20883B30CABFC7D2948E7243D6E842BF3DBE3`
- state: `PASS_JEO1_PUBLISHED`
- single publication performed: `true`
- overwrite performed: `false`
- target executed: `false`
- JBOD contacted: `false`

The publication zero-recurrence preaction SHA-256 is
`A0677DEAB903F41306C77E3A2B6E44BF97372057E3E624863A53FFB86C7CA9E6`.
The publisher clone-literal gate SHA-256 is
`85466B51A678268FB75888615959844282BDD524928BCFDE7F64AD14427E4BDD`.
The exact prepublication gate SHA-256 is
`305B112B7A7DF6D817FEF045FDE743E712EEFBC8C84BF985EBA212E626F7C3A3`.

## Corrected topology

The only operator access path remains:

`engineering laptop -> RustDesk gateway -> gateway RDP to Argos -> Argos RDP to JBOD`

`DFLY3005` is a Rudolph tool and is excluded. No JEO1 artifact depends on it.
Native control of the already-open RustDesk/RDP desktop is not exposed to this
Codex task. The remaining operator input is therefore one JBOD launch.

## One required operator action

On the already-open JBOD desktop:

1. Open `InspectionRevs` and copy `ARGOS_JEO1.zip` to a fresh `D:\JEO1`.
2. Extract the ZIP into `D:\JEO1`.
3. Right-click `D:\JEO1\RUN_JEO1.cmd` and choose **Run as administrator**.

Run it once. The launcher remains visible on failure and writes the persistent
log `D:\A2\x\JEO1_LAUNCH.log`. Successful evidence is returned as
`JEO1R.zip`; exact local evidence remains at `D:\A2\x\JEO1R_LOCAL.zip`.

Do not run `ARGOS_CDM1.zip`, `ARGOS_CDO1.zip`, or `ARGOS_O2A2.zip`. Do not
retry `REQ_O2D4`.

## Fixed prerequisite order and holds

After the one JEO1 run, collect and verify only exact `JEO1R.zip`, or recover
the exact D-side JEO1 evidence if the share return is absent. Do not rerun JEO1
merely because a share return is absent. Pin the observed CDM1 and O2D4 state,
then build the separately authorized durable signed read-only JBOD evidence
channel. Only after O2D4 is resolved may Slot16 be frozen; Slot17 stays blocked
until Slot16 is frozen. Slots22-25 remain unseen until the development contract
is frozen.

Review-only authority, the disabled live provider, the healthy processor,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, and every existing hold remain unchanged.
No image-processing, XML, training, production-routing, deletion, source-
mutation, scheduled-task, process, or wafer authority is granted.

## Exact next action

The operator performs the single JBOD launch above. Codex then collects and
verifies the file-backed result and continues directly through O2D4 resolution,
the durable evidence channel, Slot16 disposition, and frozen Slot17 development
until inspection results or a concrete decision requiring operator input.
