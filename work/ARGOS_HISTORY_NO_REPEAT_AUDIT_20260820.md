# Argos history no-repeat audit

Date: 2026-08-20

State: `PASS_HISTORY_AUDIT_WITH_DISCLOSED_NONREUSABLE_LEGACY_ARTIFACT`

The C2O1 inspector-open checkpoint was written before this requested history
audit and is therefore provisional. Its signed terminal result remains valid,
but this audit found that its request declaration used the broader action token
`RESTART:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2` while the payload correctly
implemented start-if-absent. The response proves zero tray processes became one
stable process and no protected task changed; the ZIP is nevertheless blocked
from reuse, cloning, replay, or successor-parent status.

## Runtime and portal defects

- Portal response construction and deterministic work collisions could poison
  the queue head; replay also failed to search all terminal roots. Queue-safe
  compact failure, quarantine, ledger advancement, restart/idempotence, and a
  later control request are now required.
- Inspection outputs and cache used C: instead of the short D: JBOD roots,
  exhausting the system volume. Only the inspection data was cut over; the
  entire C: drive was never in scope. Historical long names remain deferred and
  require deterministic short names plus signed source mapping.
- Completed Lot was clickable but could silently exit, then could stay stale
  until a whole processing pass ended. The viewer contract and per-durable-
  commit dashboard refresh are separate mandatory gates.
- Incomplete scribe proposals and hash-only attempt identity could leave Insite
  waits indefinitely. Exact response-package identity, bounded retries,
  quarantine, and semantic downstream release are mandatory.
- Installed worker changes did not refresh resident processes, and strict-mode
  optional-property reads repeatedly crashed multiple consumers. Every consumer
  must pass absent/false/unsafe config cases and prove a revision-fresh PID plus
  downstream behavior.
- Scheduled-task state was confused with the exact tray-process singleton;
  both states must be measured. Task principals and definitions must be snapped
  from the exact current task rather than forced to a remembered value.
- Logs stored under extracted Downloads packages were lost when Downloads was
  cleared. Persistent operator evidence belongs under ProgramData or another
  pinned durable root.

## Fiducial and notch method defects

- Thumbnail-derived pose could let chipout bias the full wafer. Thumbnail pose
  authority was withdrawn; direct full-resolution BF/DF perimeter analysis and
  physical-competitor preservation are required.
- The first fiducial holdout used the wrong site/product-map interpretation.
  Bin 34/36 is only a rough location hint; the robust crosshair lives in a
  null/bin-32 cluster and must be bound through exact product/process topology.
- Crops were initially neither clearly full resolution nor straight enough for
  operator designation. Thumbnail navigation must lead to a straightened
  full-resolution crop before drawing or edge work.
- A displayed corner-ignore region was not always excluded from scoring.
  Inner and outer arrow corners must be removed from both visualization and
  line evidence, leaving the complete horizontal/vertical line inventory.
- Cyan and green inner/outer polarity swapped between examples. Polarity must
  come from signed distance to the frozen fiducial geometry, never sample order
  or brightness rank, and must pass all independent wafers.
- Operator pink lines and boxes express which lines/features must be accounted
  for unless explicitly declared pixel-exact; poor drawing coordinates are not
  detector truth.
- A synthetic chipout control did not qualify the V3 engine for sealed FS15
  transfer: 12/15 BF perimeters and 0/15 DF perimeters qualified. The source
  conditioned DF fitting on BF qualification and a BF-derived window, then
  would average BF/DF pose before profiling. The nine V1E holds and 77 peers
  are blocked. A successor must fit BF and DF independently, must not average
  transforms, must not tune from the exposed FS15 validation outcomes, and
  must reserve a new independent validation set.

## Packaging and implementation defects

- Installed roots, PASS tokens, utility switches, task principals, and output
  roots were sometimes guessed. All are now exact hashed dependencies.
- Mechanically cloned successors retained predecessor identifiers, fixed roots,
  worker hashes, schema tokens, response contracts, or omitted the target hash
  from the approved predecessor set. A literal residue inventory is mandatory.
- Strict-mode code directly read optional fields; one-item collections unwrapped;
  empty conditional collections serialized incorrectly; formatted external
  PowerShell output was mistaken for objects. These each require executable
  absent/false/unsafe or zero/one/many regressions.
- Direct `powershell.exe -File` array calls bound later arguments incorrectly.
  File-backed JSON or one scalar per process is required.
- Compound inline PowerShell repeated parser/lexical mistakes: a statement block
  piped directly, incomplete hash/brace literals, `$name:` interpolation,
  wildcard roots as literal paths, and compressed token boundaries. Compound
  release logic must be file-backed and parser-tested.
- Expected negative-control stderr was promoted to a terminating harness error.
  Capture mode must be explicit and asserted.
- Fixed rehearsal roots were reused or cleanup was attempted too broadly.
  Fresh short roots are required; preserved failed evidence is not recursively
  deleted as an incidental recovery step.
- Optional developer tools were invoked before an availability/version probe.
  Tool discovery is now part of pre-action validation; an absent optional tool
  is a recorded capability state, not a failed final validation command.
- The path guard's separator array binds differently under PowerShell 7.6.5,
  making an aliased multi-component path appear to be one overlong component.
  Windows path gates for Windows PowerShell 5.1/.NET Framework work must run
  under the exact Windows PowerShell 5.1 host and assert the maximum candidate's
  component length independently.
- The C2O1 task declaration was broader than its payload behavior. Future action
  tokens must be semantically exact; the existing C2O1 ZIP is non-reusable.
- The current-image candidate exporter used a request schema, state, and lookup
  key that the exact installed V2_1 relay does not accept. Every emitted request
  and response class must pass that installed binary's non-mutating package
  check; exporter output alone is not route evidence.
- The SQ4 fairness rehearsal proved newest-first visibility beyond 1,000 queue
  directories but did not exercise the exact relay boundary. Future fairness
  tests require separate assertions for exporter creation, bounded-window
  visibility, request acceptance, and response acceptance.

## Orchestration and checkpoint defect

The main repeated process error was allowing a narrow gate to trigger the next
build/checkpoint before the accumulated history was reconciled. The new
pre-action contract forces that reconciliation before work, rather than relying
on later detection. The provisional C2O1 checkpoint is preserved unchanged and
will be superseded only after the current contract and continuity/session gates
pass.

The machine-readable companion lists all 51 audited issues and their enforcement:
`work/ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json`.
