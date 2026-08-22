# All-valid-inspections live decision — 2026-08-21

Disposition: `PENDING_GATE`

The signed read-only audit is closed. This is not a GUI redesign and the ten
missing wafers are not the whole requirement. They are the regression cohort
for the invariant that every producer-approved current inspection receives a
truthful explicit disposition and every current completed result appears once
in Completed Lot data.

The exact ten target queue rows are unique. The verified overlay contains ten
unique exact acquisition rows with authoritative MES context and confirmed
FRONT routes. None is in the completed FRONT ledger or dashboard. Across the
current FRONT population, the ledger has 32 completed rows and the dashboard
has 29 unique rows. The three omissions are historical completed results whose
job-key fingerprints differ from the current acquisitions; identity uniqueness
does not make them current.

The exact installed call path has four proved orchestration/consumer defects:

1. the runner passes nonexistent `-MetadataSnapshotRoot` to inventory;
2. inventory, processing, and dashboard disagree with the exact three identity
   states emitted and approved by the identity producer;
3. the tray timer reads `$script:lastActivityKey` from an unreliable callback
   scope; and
4. AVS1 attempted to treat a unique same-identity historical result as current
   without source-byte equivalence.

AVS1 also installed a changed dashboard updater but never invoked it. Its
`-Once -PlanOnly` runner path returns before dashboard refresh, after which the
entrypoint read the unchanged 29-row predecessor dashboard and required a new
field. The signed failure therefore did not prove a dashboard updater failure.
It proved a producer-never-ran/consumer-validated-new-output sequencing defect.

The R5 source audit traversed the full text/source dependency path through
pose, scribe exclusion, glyph references, FRONT and BowComp workers, native C#
detectors, composite/viewer builders, and Bare support utilities. All eight
PowerShell sources parse, all exact caller/callee parameter surfaces match, all
MJS relative imports resolve, and the C# public APIs match their PowerShell
calls. The three live-versus-local source differences are compatible with the
current callers. No evidence supports changing detector thresholds, raster
logic, pose, scribe exclusion, composites, or the Completed Lot viewer.

Signed R5C then proved all five installed top-level files match the coherent
pre-AVS1 baseline exactly. There is no mixed rollback state.

## Credible remedies

- **A — no code/package:** rejected. Both scheduled tasks are stopped/Ready,
  and the coherent baseline contains the proved runner, state-predicate, and
  tray defects. Restarting it would knowingly restart broken code.
- **B — correct the invalid precondition:** selected. Remove only the invalid
  runner argument and align the three downstream identity predicates to the
  exact producer-approved set.
- **C — repair queue/data state:** rejected. The signed queue and overlays
  already contain exact unique identities, MES context, and confirmed routes.
  No queue rewrite, guessed scribe, fabricated metadata, or wafer action is
  supported.
- **D — repair code/install state:** selected in its smallest form. Change only
  the runner, three consumer predicates, and tray callback state. Do not add
  historical fallback and do not change image processing or viewer code.

An endpoint mutation has a point only for that bounded repair. A restart has no
point before it. After exact install verification, the existing runner's real
`-Once -PlanOnly` path must pass against live state and admit the ten target
rows before the processor and tray tasks are started. Dashboard output must not
be validated as new until its exact producer has actually run successfully.

The fixed acceptance boundary is recorded in
`ARGOS_ALL_VALID_INSPECTIONS_FIX_AND_ACCEPTANCE_CHECKLIST_20260821.md` and its
machine-readable companion. Any new systemic premise failure is a terminal stop,
not permission to publish another trial.
