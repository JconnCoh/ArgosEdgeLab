# Argos recovery observation and stop-loss workflow

Revision: `ARGOS_RECOVERY_OBSERVATION_STOP_LOSS_V1`

Disposition: `APPROVED_BASELINE`

This workflow prevents recovery machinery from becoming larger and riskier
than the product defect. It applies after a failed Windows, JBOD, portal,
processor, queue, ledger, dashboard, or GUI recovery premise.

## 1. Classify before design

Create an exact file-backed recovery intent and classify the next step:

- `OBSERVE`: obtain current facts without changing installed code, tasks,
  processes, queues, ledgers, sources, wafers, or production authority.
- `MUTATE`: perform exactly one evidence-supported repair after observation.

Run `utilities/Confirm-ArgosRecoveryIntent.ps1 -Preflight`. A failed intent is
a design stop, not permission to build another package.

## 2. Observation route priority

Use the first capable route:

1. the already installed qualified `STATUS` handler;
2. the already installed qualified `DATA_PULL` handler for exact bounded text
   files under an approved root;
3. an already authorized exact admin/read-only route.

An observation must not use `MAINTENANCE_PATCH` or install an audit helper. If
the installed routes cannot supply the required fields, record
`STOP_RECOVERY_OBSERVATION_CAPABILITY_GAP` and ask for one bounded capability
change. Do not create a per-incident helper as a workaround.

The generic endpoint's exact behavior gate may be inherited across read-only
requests only when the endpoint-worker hash, installed-config evidence hash,
route-gate hash, and request-specific schema/path/byte limits are pinned. Do not
repeat endpoint implementation certification when those bytes are unchanged.
The intent must also pin a worker-hash-bound capability inventory. Every
requested capability must be present for the selected route. A known limitation
is a capability gap, not permission to send a request that cannot answer the
decision question.

Failure counts are evidence fields, not operator assertions. Every declared
signed or local premise failure must pin a unique exact gate/checkpoint and
hash. A true `directObservationAfterLastSignedFailure` value must pin an
incident-bound `PASS_ARGOS_RECOVERY_OBSERVATION` record with exact sources,
field-specific expected/observed values, and either direct endpoint evidence or
a matching signed terminal response. An exact read-only admin route must pin a
read-only authorization gate and capability inventory. Stop-loss clearance must
pin an incident-bound workflow-review gate authorizing one mutation attempt.

## 3. Artifact lifecycle

- `DRAFT`: local, unsigned, unexecuted, unpublished, and externally
  non-mutating. It may be corrected in place.
- `FROZEN`: source, dependencies, behavior cases, and rollback design are
  pinned. Bytes are immutable.
- `SIGNED` or `PUBLISHED`: immutable. Any failure withdraws the artifact.
- `WITHDRAWN`: evidence only; never replayable or a publication parent.

A command-line typo, guard invocation error, conservative guard false positive,
or omitted draft manifest classification does not require a fresh revision when
no target bytes changed and the artifact remains `DRAFT`. Failures at or after
`FROZEN`, or any external mutation, require a fresh namespace.

## 4. Premise-failure stop-loss

- After one signed failure disproves a live-state premise, the next step must be
  `OBSERVE`; mutation is blocked until that post-failure observation is pinned.
- After two signed premise failures in one incident, mutation stop-loss is
  active. No successor mutation package may be created until the workflow is
  reviewed and an exact intent records explicit stop-loss clearance.
- A local rehearsal failure never authorizes iteration. Fix a known defect only
  after the failed root is classified and the required prevention is mechanical.

## 5. Decision boundary

Observation must support exactly these remedies:

- `A`: no package; existing processor/refresh behavior is healthy;
- `B`: correct or remove an invalid precondition while preserving invariants;
- `C`: repair a proved queue/data-state blocker;
- `D`: repair a proved processor-code/install-state defect.

Implement at most one supported remedy. A GUI change is ineligible until the
authoritative ledger/dashboard contains the expected records and the unchanged
GUI still fails to display them.

## 6. Evidence, not Boolean assurance

New pre-action contracts must pin machine-readable zero/one/many collection
evidence. A true Boolean without the exact gate path and SHA-256 is not proof.
The PowerShell harness guard must reject conditional collection assignment with
an inner branch array boundary; the boundary belongs around the complete
conditional.
