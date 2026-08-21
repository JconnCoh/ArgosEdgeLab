# Argos zero-recurrence pre-action policy

Revision: `ARGOS_ZERO_RECURRENCE_PREACTION_V1`

Disposition: `APPROVED_BASELINE`

This policy converts the accumulated Argos failure memory into a mandatory
execution boundary. It applies before a new or changed Windows/JBOD package,
launcher, portal request, long-running inspection, or continuity checkpoint
can be published, launched, or promoted.

## Required sequence

1. Read the governing continuity files and the Windows failure-prevention
   memory.
2. Identify the exact action, installed root, task definition and principal,
   dependency states, dependency hashes, input identities, output root, and
   return route from current file-backed evidence. Values reconstructed from
   chat or memory are prohibited.
3. If a predecessor is copied, enumerate and reject all undeclared predecessor
   identifiers, hashes, roots, state tokens, task verbs, worker pins, schema
   names, response contracts, and temporary fixture roots.
4. Build a pre-action contract from
   `work/templates/ARGOS_ZERO_RECURRENCE_PREACTION.template.json`. Every
   dependency must name an existing file and its exact SHA-256. Every relevant
   control must be explicitly true; omitted fields do not pass.
5. Run `utilities/Confirm-ArgosZeroRecurrencePreaction.ps1` against the current
   history audit and the exact contract. A failure is a hard stop before the
   first external write or continuity promotion.
6. After execution, require the action-specific terminal gate. A share move,
   task state, process heartbeat, output directory, or unsigned log is not a
   terminal result.

## Command and PowerShell controls

- Compound probes and release logic are file-backed and parser-tested under
  Windows PowerShell 5.1. Inline commands are limited to one simple read-only
  scalar operation.
- Do not pipe directly from a statement block, use wildcard roots as literal
  filesystem arguments, place a colon immediately after an interpolated
  variable name, or compact tokens until lexical boundaries disappear.
- Array parameters cross process boundaries only through a file-backed JSON
  manifest or one scalar per process invocation. A comma-joined string is not
  an array.
- External PowerShell evidence is emitted as compact JSON and rehydrated with
  `ConvertFrom-Json`; formatted output is never evidence.
- Expected negative-control stderr is captured to a file or under a bounded
  `Continue` preference and then asserted. It is not promoted to a harness-
  terminating error.
- Optional developer tools are discovered with a read-only availability and
  version probe before invocation. Their absence is recorded as a capability
  state and never discovered by making the release/checkpoint validation fail.
- Empty and one-item collections are materialized with an explicit array
  boundary before serialization and tested for 0, 1, and many cases.
- Optional properties are presence-tested under strict mode. Every resident
  consumer of a changed config schema is inventoried, tested, and refreshed.

## Semantic controls

- The declared task action must exactly equal the implemented behavior.
  `START_IF_ABSENT`, `START`, `STOP`, and `RESTART` are different contracts.
- Scheduled-task state is not a tray-process singleton. Both must be measured
  independently when relevant.
- Task principals, definition hashes, installed roots, utility switches, PASS
  tokens, and endpoint return roots are discovered from exact current evidence,
  never guessed or inherited.
- Operator drawings designate feature existence or bounded review intent unless
  explicitly declared pixel-exact truth.
- Thumbnails may locate a full-resolution source region but cannot establish
  notch pose, fiducial geometry, or defect truth. Full-resolution BF/DF evidence
  is authoritative.
- Rendered ignore masks must be applied to scoring, not merely displayed.
  Inner/outer polarity is defined geometrically and validated across every
  independent wafer before a model is frozen.
- Fiducial lookup uses the product/process topology and null/bin-32 cluster
  semantics; bin 34/36 is only a rough neighborhood hint, never identity.

## Legacy exception boundary

An already executed artifact with a disclosed declaration mismatch can remain
terminal evidence only when a signed response proves the narrower action and
all protected invariants. It must be listed under `blockedArtifacts`, carry
`futureReuseAllowed: false`, and cannot become a template, predecessor, or
publication parent. This exception cannot authorize a new execution.
