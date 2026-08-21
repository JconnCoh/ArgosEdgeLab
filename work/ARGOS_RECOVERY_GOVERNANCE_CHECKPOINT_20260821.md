# Argos recovery observation and stop-loss governance checkpoint

Created: `2026-08-21T19:45:00Z`

Disposition: `RELEASED_REVIEW_ONLY`

## Outcome

Recovery work now begins with a file-backed intent classified as `OBSERVE` or
`MUTATE`. An observation may use only a qualified `STATUS`, `DATA_PULL`, or
exact direct-admin read-only route, and its requested capabilities must be
proved by a pinned capability inventory before publication. Observation may
not install code, launch a helper, act on tasks or processes, mutate a queue or
ledger, read image bytes, or perform a wafer action.

One signed premise failure requires a direct observation before another
mutation. Two signed premise failures activate a mutation stop-loss. A failed
local draft may be corrected in place only while it remains unfrozen,
unsigned, unpublished, unexecuted, and without external mutation. This ends
the prior automatic fresh-root/package cascade without weakening any release
gate.

GUI code is ineligible as a recovery remedy while the authoritative completed
ledger/dashboard rows are absent. Backend state must be established first.

## Mechanical evidence

- Policy: `work/ARGOS_RECOVERY_OBSERVATION_AND_STOP_LOSS.json`, SHA-256
  `F8DEA0BD4F816A174AF5D81384A264A0886ADFB1D01F46E62E53CF4356B09D41`.
- Intent validator: `utilities/Confirm-ArgosRecoveryIntent.ps1`, SHA-256
  `756FFC0B52DF7CB60B07918AE201CD64536DCA5B9C87DE34560DF40EDBBD6812`.
- Eight-case intent gate: `work/ARGOS_RECOVERY_INTENT_TEST_GATE_20260821.json`,
  SHA-256
  `75F2E11728D30418D2BF58E19DF5CE2FDDAA6DCBEF72307E024A1D0D64026099`.
  It passes qualified portal observation, qualified direct-admin observation,
  and a single evidence-supported mutation. It rejects an unproved failure
  count, maintenance-as-observation, a route capability gap, mutation
  without observation, and mutation under active stop-loss.
- PowerShell collection gate:
  `work/ARGOS_POWERSHELL_COLLECTION_CASE_GATE_20260821.json`, SHA-256
  `46BBFAAB6F2F63FA79B888CE16B3FB8AAED172AAA891E22E82C9E3E747354457`.
  Windows PowerShell 5.1 passed zero, one, and many cases; the unsafe RA1A
  conditional-collection pattern is statically rejected as
  `CONDITIONAL_COLLECTION_ASSIGNMENT_CAN_SCALARIZE`.
- Evidence-backed preaction V2 gate:
  `work/ARGOS_ZERO_RECURRENCE_V2_TEST_GATE_20260821.json`, SHA-256
  `70321FD3008C255EA0B7F4B5D29CECC6F8DA80EBC66FFAF1F2E18662BC99A65F`.
  V2 evidence passes, historical V1 remains readable only before the effective
  cutoff, and V2 missing collection evidence fails closed.
- Promotion preaction:
  `work/ARGOS_RECOVERY_GOVERNANCE_PREACTION_20260821.json`, SHA-256
  `979011DDF642990DBA464BC880508CC4624AFD425BCC9C71D3469AF49846C371`.
  The validator returned `PASS_ARGOS_ZERO_RECURRENCE_PREACTION` over 80
  classified history issues and ten pinned dependencies.

All changed PowerShell entry points pass the Windows PowerShell 5.1 parser,
harness-safety guard, and wrapper preflight. No endpoint was contacted and no
portal request, installed file, task, process, source, queue, ledger, GUI,
image, or wafer state changed.

## First application

The policy was applied to the post-R10 lot `62631-586` recovery before any live
request. The existing C1E `STATUS` route cannot return exact process inventory,
and `DATA_PULL` can return only approved exact files. A bounded repository
route audit found no qualified generic direct-admin read-only process route.
The intent therefore stopped at `OBSERVATION_ROUTE_CAPABILITY_GAP`; no R11 was
named or designed and no endpoint mutation or restart was attempted.

The lot-specific continuation authority is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/LOT_62631_586_FRONT_GUI_OBSERVATION_CAPABILITY_STOP_CHECKPOINT_20260821.md`.

The global FS15 hold and all XML, training, production, deletion, image-byte,
and wafer-abort boundaries remain unchanged.
