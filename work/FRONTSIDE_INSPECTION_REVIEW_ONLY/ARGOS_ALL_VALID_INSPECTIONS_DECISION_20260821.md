# All-valid-inspections live decision — 2026-08-21

Disposition: `PENDING_GATE`

The signed live audit proves that this is not a ten-row GUI-only loss. All ten
August 19 FRONT physical identities are exact and unique in the identity queue,
confirmed overlay, verified metadata overlay, and catalog, but none is in the
FRONT completed ledger or GUI manifest. The ten rows are the regression cohort;
the product invariant is that every producer-approved, route-valid inspection
receives an explicit terminal disposition and every completed inspection is
visible exactly once in the Completed Lot GUI.

The current live processor failure is now exact. Signed response
`R_8D1D77EB8AD0_20260821222027680_bcba8bef` returned the installed
`processor/PROCESSOR_LOOP_FAILURE.txt` at SHA-256
`7566DBF2704BB7D45D15F62C9F0953D72946FE3B016873C02F56D3B82FC50DD5`.
It records `Ordered consumer: INVENTORY` and a Windows PowerShell parameter
binding failure because runner
`46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4`
passes `-MetadataSnapshotRoot` to inventory
`8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160`,
whose exact parameter surface does not declare it. Every other direct named
argument on the runner, processor, dashboard, acquisition, reference-registry,
Completed Lot, Insite import, and Insite export orchestration surface matched
its exact installed callee.

Removing that binding error alone is insufficient. The exact producer/verified
contract accepts three review-only identity states, but installed inventory,
processing, and dashboard consumers do not consistently accept the same set.
The full signed live dataset has 745 verified rows. It includes 47 non-FRONT
image-confirmed rows; 12 of them satisfy every other current reference-family
gate when evaluated with the human-confirmed state. A FRONT-only consumer
exception would therefore break valid BowComp/backside work. The corrected
contract accepts the same three producer-approved states in every domain while
leaving all existing domain route, appearance, geometry, context, XML,
training, and production gates intact.

The broader GUI invariant fails independently: 32 unique completed FRONT
identities exist in the ledger while only 29 appear in the dashboard. The three
missing identities each have exactly one completed historical result whose
fingerprint was superseded by the current catalog acquisition. They can be
included without ambiguity only with explicit historical/current fingerprint
provenance. The reported Completed Lot popup is a separate two-line tray-state
defect: the WinForms event callback reads `$script:lastActivityKey` from an
unreliable callback script scope. Anchoring this value on the captured form's
`Tag` state fixes the exception without changing the viewer or redesigning the
GUI.

## Credible remedies

- **A — no code/package:** rejected. The exact current failure file proves the
  resident loop dies before inventory, and the processor/inventory heartbeats
  are over 24 hours stale against a 15-second poll contract. Observation cannot
  repair it.
- **B — remove the invalid precondition:** necessary as part of the remedy. The
  runner must stop passing the nonexistent inventory parameter, and downstream
  consumers must use the exact producer-approved identity set rather than a
  one-lot or one-domain substitute.
- **C — repair queue/data state:** rejected. The exact confirmed and verified
  overlays already contain the authoritative identities and MES context. No
  guessed scribe, queue rewrite, metadata fabrication, or wafer action is
  warranted.
- **D — repair code/install state:** selected. Five exact installed consumers
  have independently proved defects: runner binding, inventory state contract,
  processing state contract, dashboard completion reconciliation, and tray
  callback state.

A restart has a point, but only after the exact five-file correction is present.
The running processor has parsed the old runner and owns the global processor
mutex, so it cannot load the corrected runner in place. The bounded action must
stop only the exact processor task, execute the corrected runner once with
`-PlanOnly` against live state, require all direct call surfaces and the live
catalog/route predicates to pass, then start that exact processor task. The
exact monitor task must be restarted only to load the corrected tray bytes.
Any failed live PlanOnly or task identity/hash check must restore task
availability and terminate the single action; it must not iterate.

The endpoint action may refresh catalog, queue, processor status, and dashboard
state and may read the existing acquisition headers needed by inventory. It may
not alter source images, the completed ledger directly, detector thresholds,
XML, training eligibility, production routing, other inspection tasks, or wafer
state. Completion still requires a matching signed PASS action response followed
by direct exact-endpoint evidence of ten completed FRONT ledger identities, ten
GUI identities, reconciliation of the three historical completed FRONT rows,
and an error-free real Completed Lot launch.
