# Argos PowerShell harness safety

Apply this gate to every new or changed package builder, signer, route test,
endpoint rehearsal, response collector, publisher, and operator launcher.

## Required ordering

1. Freeze the package design before the first signature.  The freeze record
   must pin the entry point and payload hashes, every approved predecessor,
   exact installed roots, invariant hashes, task-action allowlist, rollback
   failure-injection mechanism, response leaves, route-root revision, and
   review/production authority.
2. Gate the source, final target, longest deterministic temporary/partial
   target, quarantine target, extraction target, and response leaves.  Apply
   suffix reserve to the actual longest leaf.  Select a short physical staging
   root before the first write when effective length reaches 200.
3. Run `Confirm-ArgosPowerShellWrapper.ps1` and
   `Confirm-ArgosPowerShellHarnessSafety.ps1` on the exact script bytes.
4. Run the exact non-mutating `-Preflight`.  A preflight may read, parse, hash,
   and calculate, but it must not create an evidence file, directory, ZIP,
   package, fixture, mapping, process, task, or external request.
5. Exercise behavior and installer cases in unsigned/rehearsal form as far as
   possible before signing.  Never add an invariant or invent the rollback
   injection mechanism after the first signed draft.
6. Sign only the frozen bytes.  Verify the signature and manifest immediately.
7. Extract the final ZIP to a fresh path and repeat exact predecessor,
   idempotence, refusal-before-mutation, rollback, path, and queue gates against
   the extracted bytes before publication.
8. Quarantine a failed output root; never patch or reuse it.  Rebuild into a
   fresh root after the cause and prevention are recorded.

## Coding rules

- An external `powershell.exe` process returns stdout text.  Use an in-process
  script when typed objects are required, or require bounded JSON and call
  `ConvertFrom-Json` explicitly before property access.
- Capture a `foreach`, `if`, or `try/finally` result in `@(...)` or a variable
  before piping it.  Never append a pipe directly after an inline compound
  statement in Windows PowerShell 5.1.  This rule also applies to ad-hoc
  diagnostic and checkpoint commands: visually reject the unsafe token pattern
  before execution because the static file checker cannot inspect an unsaved
  command.
- When an assignment consumes an `if` expression intended to produce a
  collection, place the array boundary around the complete conditional:
  `$rows = @(if (...) { Get-Rows })`. An array wrapper inside each branch does
  not survive PowerShell output enumeration. The harness guard rejects a
  direct conditional assignment that contains branch array expressions or is
  later dereferenced through `.Count`.
- Do not use `Format-Table`, `Format-List`, or width-dependent console rendering
  as gate evidence.  Emit bounded JSON or explicit scalar `hash path` rows.
- Search with `rg` first.  Never recursively enumerate the whole project/work
  tree.  Use one exact subroot, stop on errors, cap row count, and save a large
  result file-backed.
- Enumerate direct and indirect callers whenever a configurable root or
  parameter changes.  Test legacy fallback and new-root propagation through
  every interactive and automatic caller.
- Before cloning or mechanically transforming a predecessor harness, run this
  guard against every source template as well as the generated outputs.  A
  legacy source violation requires an explicit transformation/remediation plan
  before the first generated-file write; a successful post-generation guard is
  still mandatory before execution.  Pinned hashes and parser success do not
  make a predecessor a safe template.
- A clone remediation map must enumerate every embedded test, fake-drive,
  extraction, partial, quarantine, and response root.  Give the new revision
  fresh path-gated roots and reject unchanged predecessor-root tokens before
  generation.  Never delete or reuse a predecessor test tree to satisfy a
  freshness check.
- A publisher using a temporary PSDrive must rehearse every provider/module
  command used after the first write, including hashing.  Create the drive only
  in apply with a tracked scope visible to those module cmdlets, exact-root
  verify it, and remove only a mapping the publisher created.  The queue state
  machine must accept only `NEW`, pinned `EXACT_UPLOAD`, or pinned
  `EXACT_READY`; repeat classification before commit, reject mismatches, resume
  an exact upload without overwrite, and recover an exact ready file only by
  reconstructing the missing local gate.
- Treat PSDrive and SMB-mapping create/remove commands as mutations when
  proving a preflight return precedes all changes.  Guard revisions require a
  self-pass, a corrected-target positive control, and a preserved legacy
  negative control that emits `MUTATION_BEFORE_PREFLIGHT_RETURN`.  Because an
  expected-failure in-process gate may not commit streamed output to assignment
  or `Tee-Object`, use the guard's metadata-only `-ReturnFailureResult` switch
  for exact negative-control assertions.  Default production calls must still
  throw on every violation.
- Apply continuity changes one file at a time with stable ASCII anchors.
  Encoding-damaged or rendered text is not a patch anchor.  Parse JSON and
  recompute hashes after each edit.
- Check optional executables with `Get-Command` before use.  Do not assume
  `git`, a mapped drive, or a shell alias exists in the current host.
- A migration/cutover manifest must use exact source/destination allowlists and
  an explicit excluded-root list.  It must reject `C:\`, user profiles,
  Windows, Downloads, portal/relay state, processor state, and any undeclared
  tree.  Never express migration scope as a drive-wide recursive operation.

## Gate command

Run one scalar script path per Windows PowerShell 5.1 invocation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File utilities\Confirm-ArgosPowerShellHarnessSafety.ps1 -PowerShellScript <exact.ps1> -Preflight -AsJson
```

Any non-pass result is a hard stop before build, signature, publication, or
operator launch.
