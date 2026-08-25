# Argos checkpoint — OCV-02 O2D5 published; one JBOD Slot16 run pending

Date: 2026-08-25

Revision: `OCV02_O2D5_PUBLISHED_OPERATOR_RUN_PENDING_20260825`

Disposition: `PENDING_GATE`

## Exact publication

The frozen O2D5 package was published create-new to the engineering share only
after its exact publication preflight passed with clean matching local/origin
branch tips at `7ecdf345153f6c6c8694370de821ab8445578b43`.

- destination:
  `InspectionRevs\ARGOS_O2D5.zip`
- bytes: `14,830,285`
- share-readback SHA-256:
  `31C03DFE334551999169152A64050E3BFD05BD35730B0840AB12132797ACE335`
- adjacent path-gate SHA-256:
  `2DAD77D5D6C689F6345E93BA2527F6FD2AEF8B328295EE6A6C3C083E116A095F`
- publication-gate path:
  `work/OPENCV_SCRIBE_O2D5/O2D5_PUBLICATION_GATE.json`
- publication-gate SHA-256:
  `50CFF31A436437CF315A6B0878AF08F55E2DD3F78FA415711FAA8704A5442F3B`
- publication state: `PASS_O2D5_PUBLISHED`

The exact manual fallback return leaf `InspectionRevs\O2D5R.zip` was absent at
publication. Publication performed no overwrite, created no portal inbound
request, contacted no JBOD, and performed no task, process, wafer, source, or
image action.

## Frozen execution and return contract

The only authorized JBOD execution identity is
`O2D5_20260825T190855Z_54B4C08C`; the required signed response identity is
`DIRECT_O2D5_20260825T190855Z_54B4C08C`. The package must be extracted to a
fresh `D:\O2D5` and `RUN_O2D5.cmd` must be run once as administrator on JBOD
`A1025645101`.

O2D5 may start only its bounded portable Python child. It may not start, stop,
restart, or change any installed task or resident process, install a helper,
or activate the disabled provider. All heavy work and output remain on JBOD D.
The exact durable local fallback is
`D:\A2\x\O2D5R_20260825T190855Z_54B4C08C.zip`; the persistent launcher log is
`D:\A2\x\O2D5_20260825T190855Z_54B4C08C_LAUNCH.log`.

The installed response-sender route is attempted only after the durable local
result exists. If the signed result does not return automatically, retrieve
only that exact D-local ZIP through the already-open nested RDP sessions and
place it create-new in `InspectionRevs` as `O2D5R.zip`. Do not rerun O2D5.

## Authority and holds

Exactly one JBOD execution is now authorized and has not yet been verified as
executed. Review-only authority, disabled live provider, healthy-processor
preservation, `SCRIBE_REFERENCE_COVERAGE_HOLD`, and every existing hold remain.
Slot16 is not frozen until the matching result passes. Slot17 remains blocked
until then. Slots22-25 remain unseen. No XML, training, production routing,
source mutation, source deletion, wafer action, hold clearance, or installed
processor/task restart is authorized. O2D4, JEO1, CDM1, CDO1, and O2A2 must
not run. DFLY3005 remains excluded.

## Exact next action

On the already-open JBOD desktop, extract the exact published
`ARGOS_O2D5.zip` into fresh `D:\O2D5` and run `RUN_O2D5.cmd` once as
administrator. Then collect and verify only the matching signed response; if
the response is absent, retrieve only the exact durable D-local result. Never
rerun O2D5. On exact Slot16 pass, freeze Slot16 and continue directly to frozen
development Slot17.
