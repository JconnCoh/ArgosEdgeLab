# Argos Windows/JBOD Failure-Prevention Memory

### Legacy portal signer has no non-mutating preflight boundary

- Signature: the exact generic portal signer fails
  `Confirm-ArgosPowerShellHarnessSafety.ps1` with
  `MISSING_NON_MUTATING_MODE` before a new signed request may be built.
- Cause: `New-SignedPortalPackage.ps1` predates the current harness contract;
  it validates and immediately creates the request partial, and it reassigns
  its typed identity-path parameter while resolving the default.
- Preflight: every signer revision must expose `-Preflight`, resolve optional
  parameters into separate local variables, validate the definition, payload,
  signing identity, certificate, and fresh target paths, then return before
  creating any directory, manifest, signature, or ZIP. Run the exact source
  through the parser and harness guard before signing.
- Recovery: retain an artifact signed before this discovery as withdrawn
  evidence unless its complete publication gate had already passed. Create a
  fresh backwards-compatible signer revision, change only the preflight
  boundary and parameter resolution, run exact preflight, and sign into a new
  path-gated root. Never resume a partial package.
- First observed on 2026-08-20 while preparing the Argos SNA1 remote portal
  request. The source gate failed before the corrected signer ran; no request
  was published and no Argos, JBOD, image, wafer, task, XML, or production
  state changed.

### A cloned signer cannot retain a PSScriptRoot-relative sibling verifier

- Signature: a fresh signed request directory is created successfully, then
  the signer stops because `Test-SignedPortalPackage.ps1` is not found beside
  the cloned signer.
- Cause: the clone moved the signer without remediating its implicit sibling
  dependency. Payload, manifest, and signature creation completed before the
  missing verifier was discovered.
- Preflight: every cloned harness must inventory script-relative helper files
  as dependencies, resolve each helper to an exact hash-pinned project path,
  and assert that path during non-mutating preflight. A clone-remediation gate
  that checks only drive/UNC literal roots does not prove sibling adjacency.
- Recovery: preserve the signed-but-unverified output root as withdrawn and
  non-publishable. Fix only the verifier resolution, rerun clone, parser,
  harness, path, and zero-recurrence gates, and sign into a fresh output root.
  Never verify and publish the stranded artifact after repairing the signer.
- First observed on 2026-08-20 for withdrawn request
  `REQ_20260820T192512528Z_E627EA97B31A` under `R:\snp2\signed`. Nothing was
  copied to the portal request share and no endpoint, task, image, wafer, XML,
  or production state changed.

This is durable project operating memory. Read it before any Windows batch,
mapped-drive analysis, portable installer, JBOD hotfix, relay/portal change,
or long-running inspection. Add new observed failures here when their cause
and safe recovery are known. Chat history is not the authority.

## Mandatory preflight order

1. Resolve every source, destination, script, manifest, and expected
   predecessor to an absolute path. Reject null, empty, malformed, or
   unexpectedly nested paths before mutation.
2. If a source uses a mapped drive, record both the drive path and its UNC
   `DisplayRoot`. Verify the exact file through the execution context that
   will perform the work. Child processes, scheduled tasks, background jobs,
   and elevated sessions must use the explicit UNC path when the mapping is
   not guaranteed.
3. Verify native source hashes and dimensions before the long run. A path
   translation may change only the path, never image content or identity.
4. Measure free space with `[IO.DriveInfo]::new('C').AvailableFreeSpace`, not
   only `Get-PSDrive`. Inventory the expected output footprint and keep a
   safety reserve. Refuse a new batch if the reserve would be crossed.
5. Refuse-on-overwrite for every output root. A retry must first determine
   whether a valid result already exists. Preserve partial outputs for audit;
   never silently mix them with a retry.
6. On JBOD/hotfix work, hash the actually installed predecessor first. Test
   the exact packaged installer under Windows PowerShell 5.1 against fresh
   rehearsal copies of every approved predecessor hash, plus unapproved and
   idempotent-target cases, as required by `AGENTS.md`.
7. Run a bounded one-item proof through the same execution context and exact
   paths before launching a batch. Assert the required result file, state,
   dimensions, hashes, and non-mutation properties.
8. Before any output root is created, enumerate the longest planned input,
   output, temporary, retry, and nested-extraction paths. Run
   `utilities/Confirm-ArgosPathBudget.ps1` with the default 32-character suffix
   reserve. At 200 effective characters, establish and verify the short
   execution path first. At 230 effective characters, refuse launch.
9. Before running a new or changed `.cmd`/`.ps1` entry point, apply
   `work/ARGOS_POWERSHELL_WRAPPER_SAFETY.md` and run
   `utilities/Confirm-ArgosPowerShellWrapper.ps1` against the exact script,
   wrapper, and bounded UTF-8 JSON invocation manifest. Then execute only the
   target's own non-mutating `-Preflight` or `-Rehearsal` mode under Windows
   PowerShell 5.1.

## Observed failure signatures and required prevention

### Mapped drive visible interactively but missing in a child job

- Signature: `Native source missing: P:\...` even though the same file opens
  in the interactive operator session.
- Cause: drive mappings are logon/session scoped and are not guaranteed in a
  child process, background job, elevated shell, scheduled task, or service.
- Prevention: resolve `Get-PSDrive P` and record `DisplayRoot`; make a
  file-backed manifest copy whose paths use the explicit UNC root; retain the
  original manifest hash and record `imageContentChanged=false`; verify exact
  native source hashes again in the consuming context.
- Recovery: abandon only the invocation that could not see the drive. Do not
  alter or recopy native images merely to work around drive visibility.

### A two-host operator handoff cannot assume the same local staging drive

- Signature: the Argos-side launcher stops at preflight with
  `Local D drive is unavailable` even though Explorer may show a `D:` mapping.
- Cause: the handoff manifest and shared runner treated `D:` as host-local on
  both JBOD and Argos. On Argos, `D:` is not a guaranteed local volume and an
  elevated shell may not inherit the interactive user's mapped drive. A
  successful laptop or JBOD rehearsal therefore did not prove the exact
  Argos execution-context root.
- Preflight: assign and freeze a separate physical staging/log root for every
  host role. Verify that exact root in the same elevated/non-elevated context
  used by the wrapper. JBOD may use its known local `D:`; Argos must use a
  verified local root such as its approved `C:\ProgramData` application area
  when no local `D:` exists. A role-generic `Local D` assertion is prohibited.
- Recovery: preserve the failed package and any create-new log, withdraw its
  handoff freeze, choose a fresh host-specific staging/log root, rerun path,
  wrapper, exact-package, and two-host rehearsal gates, and publish a newly
  frozen handoff. Do not tell the operator to remap or retry the rejected
  launcher.
- First observed: SNR1/SNA1 manual two-host handoff on 2026-08-20. Argos
  stopped before log creation, extraction, task access, or installed-file
  mutation. No image, wafer, XML, or production route ran.
- Rehearsal recurrence observed 2026-08-20: an exact JBOD endpoint fixture
  copied the production processor configuration, including its valid JBOD-local
  `D:\KLARExport` metadata root, into a laptop rehearsal where `D:` was absent.
  The exact worker correctly logged `Cannot find drive ... D` and the signed
  endpoint case failed. Endpoint fixtures that retain a pinned production
  configuration must preflight the host role and provide a bounded, verified,
  child-visible drive alias to a case-local empty metadata root only when the
  production drive is absent. Query `subst.exe` with no drive argument, require
  the alias to be absent before creation, bind its exact normalized target, and
  remove only that exact alias in `finally`. Never reuse the failed case root.

### Create-new host staging collision blocks safe handoff recovery

- Signature: a retry stops at `Fresh staging root required` because the exact
  package staging directory already exists from an earlier attempt.
- Cause: the handoff requires create-new staging but provides no bounded
  continuation path after preserving the prior attempt. A retry therefore
  cannot distinguish a completed, partial, or unrelated directory.
- Preflight: allocate and freeze a new host-specific staging and log namespace
  for every recovery attempt. Check both exact paths before publication and
  exercise the unchanged package through that new namespace.
- Recovery: preserve the existing staging directory and persistent log without
  deletion or reuse. Withdraw the colliding handoff, reuse the already gated
  payload ZIP byte-for-byte, select one fresh revisioned staging/log root, and
  rerun only the bounded wrapper, path, exact-package, and idempotence gates.
  Never tell the operator to delete the directory or retry the same launcher.
- First observed: SNR2 Argos handoff on 2026-08-20 at
  `C:\ProgramData\ArgosEdgeLabRO\pkg\SNA1_20260820R2`. The retry stopped before
  any new extraction, installed-file mutation, or scheduled-task operation.

### PowerShell-only PSDrive is not a Win32 path for .NET file streams

- Signature: `Test-Path I:\...` and `Get-FileHash I:\...` succeed after a
  session-scoped `New-PSDrive`, but `[IO.File]::Open('I:\new.partial', ...)`
  fails with `Could not find a part of the path` before creating any file.
- Cause: a non-persistent PowerShell provider drive is resolved by PowerShell
  cmdlets but is not registered as an operating-system drive for direct .NET
  `System.IO` APIs. The failure is a path-provider mismatch, not share loss.
- Preflight: before using a short publication drive, exercise the exact API
  class that will perform the write. A provider-only drive may be used only
  with PowerShell provider cmdlets. Direct .NET file streams require a
  persistent operating-system mapping (or a short physical/UNC path that
  already passes the budget). Verify a known sentinel hash through the chosen
  mapping and require all final and temporary leaves to be absent.
- Recovery: confirm that no final or `.partial` leaf was created, remove the
  provider-only drive, and retry through a freshly verified persistent drive
  mapping using create-new temporary leaves, hash verification, and atomic
  rename. Never fall back to a long unchecked UNC write and never overwrite a
  prior publication.
- Repeated observation: D2S6's isolated publisher-provider rehearsal correctly
  copied, hashed, and renamed its 3,419-byte ZIP through session-only `V:`,
  then repeated the same provider mismatch by calling
  `[IO.File]::WriteAllText` for `V:\...\PASS.json`. The direct .NET write
  failed while the exact ZIP remained intact in the non-queue rehearsal root.
  The portal request queue and JBOD were untouched. Preserve that failed root,
  use a fresh rehearsal root, and use provider-native `Set-Content` for every
  PSDrive leaf; direct .NET file APIs remain valid only for the local `C:` gate.

### `Set-Content` can mis-resolve a session PSDrive backed by a long UNC root

- Signature: `Copy-Item`, `Get-FileHash`, and `Move-Item` succeed through a
  session PSDrive, but a later `Set-Content -LiteralPath V:\...` fails with a
  path whose UNC share prefix is repeated multiple times.
- Cause: the provider-native content writer re-expanded the UNC-backed global
  PSDrive path incorrectly in the observed Windows PowerShell 5.1 host. The
  failure is distinct from direct .NET not recognizing PSDrive letters.
- Preflight: a publisher-provider rehearsal must contain only the exact
  provider commands used by the real publisher. Do not add a share-side
  content-write step when the production path performs only directory create,
  copy, item/hash verification, and atomic rename. Persist the machine gate on
  a normal local `C:` path after the mapped-drive operations pass.
- Recovery: preserve the failed rehearsal root, do not reuse or delete it, and
  retry from a newly path-gated share rehearsal root without `Set-Content` or
  another unneeded share-side writer. Keep the exact copied ZIP as evidence.
- First observed: D2S6 publisher-provider rehearsal `_R2` on 2026-08-19.
  Copy, post-copy hash, rename, and post-rename hash all completed before the
  optional `PASS.json` write failed. The portal request queue and JBOD were not
  touched.

### Subst alias and canonical path treated as different project roots

- Signature: a bounded builder invoked through a verified `subst` alias stops
  with `<input> escapes project root` even though the named input is the exact
  canonical file under the same workspace on `C:`.
- Cause: lexical `path.relative` containment compared an `X:` project root
  with a retained absolute `C:` source path. The alias and canonical path name
  the same storage, but drive-letter comparison alone cannot prove that.
- Prevention: use the short alias for path-budget checks and legacy consumers,
  but invoke builders whose locked manifests contain canonical absolute paths
  through the canonical project-root spelling. Before the first write, verify
  the alias target and canonical root resolve to the same workspace. Do not
  weaken containment checks or rewrite locked source paths.
- Recovery: preserve the partially copied candidate as `DIAGNOSTIC_ONLY`, do
  not reuse it as a parent, select a fresh output ID, and rerun the exact same
  hash-bound inputs using the canonical manifest path. This is orchestration
  identity only; do not modify detector, source images, masks, or feedback.

### `subst.exe X:` is not a valid single-drive query

- Signature: a non-mutating path preflight reports `Invalid parameter - X:`
  and then incorrectly says the verified short alias maps to the wrong root.
- Cause: Windows `subst.exe` lists mappings only when invoked without a drive
  argument. Supplying `X:` is interpreted as an incomplete mutation command,
  not as a query for that drive.
- Prevention: invoke `subst.exe` with no arguments, capture its bounded output,
  select exactly one line beginning with the required `X:\:` token, parse the
  target after `=>`, and compare that normalized target to the canonical
  workspace root before any write or launch.
- Recovery: verify that the failed target was still in `-Preflight` and that
  neither the executable nor output root exists. Correct only the alias-query
  logic, rerun the static wrapper gate, and repeat the same exact target
  preflight. Do not recreate the alias or alter detector, image, feedback, or
  training inputs when the existing mapping is already correct.

### `Start-Process` fails with duplicate `Path` / `PATH`

- Signature: `Item has already been added. Key in dictionary: 'Path' Key being
  added: 'PATH'`.
- Cause: Windows PowerShell's process environment construction encounters
  case-variant duplicate environment entries.
- Prevention: do not use `Start-Process` for the affected orchestration path.
  Use an isolated PowerShell job or an explicitly invoked process after
  normalizing its environment. Remember that a job then needs UNC paths, not
  session-only mapped drives.
- Recovery: verify that no output root was created; switch orchestration only.
  Do not modify the detector because the detector never ran.

### Free reviewer port falsely reported as in use

- Signature: a non-mutating launcher preflight reports `Reviewer port ... is
  already in use` while `Get-NetTCPConnection` shows no listener or owning
  process.
- Cause: an asynchronous `TcpClient.BeginConnect` wait handle also completes
  when connection is refused. Reading `Connected` without calling
  `EndConnect` can misclassify that completed failure as a successful probe.
- Prevention: initialize the result as closed; after the bounded wait, call
  `EndConnect` inside `try/catch`; only a successful `EndConnect` plus
  `Connected=true` means the port is occupied. Close the async wait handle and
  client in `finally`.
- Recovery: cross-check listener metadata, preserve the affected reviewer root
  as withdrawn, correct the source launcher, repeat wrapper and target
  preflights, and build a fresh root. Do not bypass the port ambiguity check.

### Bounded reviewer test leaves its listener running

- Signature: the bounded HTTP test reports completion, but the later exact
  launcher preflight correctly finds its port occupied. The listener returns
  HTTP 200 and serves the same review ID used by the completed test.
- Cause: stopping or completing an orchestration job is not proof that every
  descendant Windows PowerShell process and socket listener has exited.
- Prevention: record the test listener PID; after teardown, require both
  process exit and absence of a `LISTENING` row for the exact port. Treat this
  postcondition as part of the bounded runtime gate, not optional cleanup.
- Recovery: query health and the exact manifest URL first. Stop only the
  verified test listener whose served review ID, port, executable, and start
  time match the bounded run. Reconfirm that the port is free, then repeat the
  exact non-mutating launcher preflight. Never kill an unidentified listener
  or bypass the ambiguous-root refusal.

### Generated-source patch assumes one newline convention

- Signature: a fail-closed generated-reviewer build reports that a required
  JavaScript or HTML replacement anchor is missing even though the target line
  is visibly present.
- Cause: the replacement included CRLF characters while the copied source used
  LF, or vice versa. Text-mode reads do not guarantee one repository-wide
  newline convention.
- Prevention: use a unique semantic line or token as the required anchor when
  the newline itself is not part of the contract. Validate the resulting
  syntax and required controls separately. Never weaken the check to an
  unbounded or non-unique substring.
- Recovery: preserve the partially copied root as `DIAGNOSTIC_ONLY`, change
  only the source builder, repeat static and target preflights, and build into
  a fresh root. Never resume or complete the partially patched tree in place.

### False zero free-space report

- Signature: `Get-PSDrive C` reports zero free bytes while direct drive state
  and file creation remain healthy.
- Cause: provider/accounting behavior in the invoking shell can be stale or
  misleading.
- Prevention: authoritative check is
  `[IO.DriveInfo]::new('C').AvailableFreeSpace`; cross-check the workspace
  subtree footprint before concluding the disk is full.
- Recovery: pause writes while checking. Never delete based on the provider
  result alone. Resume only after direct measurement confirms the reserve.

### Windows path or nested extraction failure

- Signatures include `Illegal characters in path`, `The path is not of a
  legal form`, the installer opening as text, or scripts only working from an
  unexpected folder level.
- Causes: null/object-array values passed as paths, quoting mistakes,
  accidentally duplicated top-level ZIP directories, or excessive nesting.
- Prevention: normalize scalar strings with `GetFullPath` only after explicit
  null/type validation; apply `work/ARGOS_PATH_LENGTH_SAFETY.md`; run the path
  budget before creating the output root; when copying a prior tree, rebase
  and preflight every source child under the planned destination after all
  intended short-name mappings, rather than checking only newly generated
  files; keep release roots and filenames
  short; put the timestamp only at the run root; inspect the final ZIP's member
  layout; rehearse extraction of the exact final ZIP into a fresh tree; test
  both normal and one-extra-folder extraction discovery.
- Recovery: do not ask the operator to guess the correct nesting. Repair the
  package/discovery logic and rerun the final-ZIP rehearsal gate.

### PowerShell 5.1 invocation and parameter conversion failures

- Signatures include `-File '-Argument' does not have a .ps1 extension`,
  scripts-disabled errors, string-to-Boolean conversion failures, and
  object-array bitwise/operator errors.
- Causes: `-File` received an empty/non-scalar script path; an expression was
  incorrectly placed after `-File`; `$true/$false` was serialized as text;
  PowerShell operator precedence produced an array.
- Prevention: validate one scalar `.ps1` full path before launching; prefer a
  checked `.cmd` wrapper and the explicit
  `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile
  -ExecutionPolicy Bypass -File <absolute.ps1>` form; model optional Booleans
  as switches inside PowerShell or native JSON Booleans at a process boundary;
  carry arrays and other complex data in a bounded UTF-8 JSON manifest;
  parenthesize enum/bitwise expressions; run
  `utilities/Confirm-ArgosPowerShellWrapper.ps1`; then run the exact target's
  non-mutating preflight in Windows PowerShell 5.1. Unblock an intentionally
  carried package when policy marks downloaded files.
- Recovery: do not keep changing operator commands. Fix and rehearse the
  package entry point once.

### Inline compound statement followed by a pipeline parse failure

- Signature: `An empty pipe element is not allowed` when an inline inspection
  command places `| Format-*` or another pipeline immediately after a
  `foreach`, `if`, or `try/finally` block.
- Cause: a compound statement was serialized into one `-Command` string as
  though the block itself were a pipeline element. Windows PowerShell 5.1
  requires the block result to be captured or the statement to be completed
  before a later pipeline begins.
- Prevention: keep inline inspection commands short. Put non-trivial logic in
  a parsed `.ps1` with the wrapper preflight contract. When a bounded inline
  probe is unavoidable, assign compound-statement output to a variable,
  terminate the statement, and pipe the variable separately.
- Recovery: verify that the parser failed before mutation, simplify the probe,
  and rerun only the read-only query. Never change detector or feedback data to
  work around a shell parser error.
- Repeated observation: three C1D3 read-only probes on 2026-08-19 placed a pipe
  directly after an inline `foreach` block and failed with the same parser
  signature.  This is now statically covered by the exact-script parser in
  `utilities/Confirm-ArgosPowerShellHarnessSafety.ps1`; inline compound probes
  must assign `@(foreach (...){...})` or an explicit result array and pipe the
  variable separately.  The third occurrence was the bounded live-terminal
  checkpoint hash query, proving that this rule applies to ad-hoc diagnostic
  and checkpoint commands as well as packaged/file-backed scripts.  Before
  executing any multi-statement `shell_command`, visually reject a line whose
  first pipeline token follows the closing brace of `foreach`, `if`, or
  `try/finally`; the static file checker cannot protect an unsaved command.

### PowerShell automatic `$Matches` variable reused as an accumulator

- Signature: adding an object to `$matches` fails with `A hash table can only
  be added to another hash table`, or later JSON serialization reports a
  dictionary with unsupported/non-string keys.
- Cause: PowerShell variable names are case-insensitive, so `$matches` aliases
  the automatic regex-capture variable `$Matches`; each `-match` operation can
  replace it with a hash table instead of the intended collection.
- Prevention: never use `matches` in any casing as a script-owned variable.
  Use a task-specific name such as `$rasterEntries` and initialize it with an
  explicit array type before accumulation.
- Recovery: verify that the failed command was read-only, discard its partial
  in-memory result, rename the variable, and rerun only the bounded query. Do
  not change detector, feedback, or review artifacts.

Do not rely on native `powershell.exe -File` to preserve a PowerShell array
parameter supplied as comma-separated command text. For portable entry
points, accept one validated CSV string (or a file-backed list) and parse it
inside the script; otherwise multiple intended values may arrive as one
literal string and a skip/exclusion guard may silently fail.

The durable wrapper contract is `work/ARGOS_POWERSHELL_WRAPPER_SAFETY.md`.
Wrappers must not forward `%*`, use `-Command`, or add a `start`/
`Start-Process` hop. They resolve quoted `%~dp0` script and manifest paths,
refuse missing files, and pass one manifest path after `-File`. The static
validator does not execute the target; its PASS must be followed by the exact
target's non-mutating preflight.

When another PowerShell script must consume
`Confirm-ArgosPowerShellWrapper.ps1` programmatically, always request
`-AsJson`, capture the bounded text, and parse it with `ConvertFrom-Json`.
Without `-AsJson`, the validator intentionally emits formatting records for
human display; accessing `.state` on that stream fails even when the wrapper
itself is valid. Treat this signature as gate-plumbing failure before release,
preserve the incomplete output as diagnostic-only, and rerun into a fresh root.

The wrapper validator's command-wrapper parameter is `-CmdWrapper`, not
`-Wrapper`. Before invoking any safety utility, read its declared `param(...)`
block rather than inferring parameter names from prose. The signature
`A parameter cannot be found that matches parameter name 'Wrapper'` is a
non-mutating gate-invocation failure: verify that no output root was created,
rerun the same static check with `-CmdWrapper`, and do not change the target
script or reviewer data to compensate.

Before a build copies or renders a canonical reviewer, validate the exact
canonical-lock schema fields needed later in the release gate. Do not defer a
lock-property lookup until after large asset generation. The BowComp V1 lock
names its action list `requiredActions` and its control list
`requiredControlIds`; a missing or renamed property is a preflight hard stop,
not permission to weaken or skip canonical UI assertions.

When a derived reviewer rewrites an inherited data asset, updating the file is
not sufficient: rebind the derived manifest URL to that exact new file and
assert every expected tile mapping before writing a release PASS. A copied
manifest can otherwise keep loading predecessor CSVs while local derived CSVs
sit unused. The independent post-build audit must compare each manifest URL,
resolved file hash, and revision root; any predecessor binding withdraws the
candidate before presentation and requires a fresh output root.

### Installed predecessor unexpectedly rejected

- Signature: `Installed predecessor is not approved ... Actual: <SHA256>`.
- Cause: release construction used remembered or stale predecessor hashes
  instead of the actual installed revision, or tested a comparison
  reimplementation rather than the packaged installer's code path.
- Prevention: query and record the installed hash before package creation;
  include every explicitly approved predecessor; exercise every value using
  the exact final ZIP and packaged non-mutating preflight; verify rejection
  occurs before mutation for an unknown hash; verify target-hash idempotence.
- Recovery: never tell the operator to retry the same ZIP. Repair the approved
  set from evidence, rerun the mandatory release gate, then publish a new ZIP.

### Package construction must reconcile installed predecessors with continuity

- Signature: the JBOD SNR1 package refuses inventory predecessor SHA-256
  `7960B1E63BF691C2F521BF542B356C3C95B644A08023C995736DF1F4B908D533`
  even though that exact revision is the released C1D2 processor consumer.
- Cause: package construction copied the older `D171...` inventory predecessor
  from the immediate development staging set without reconciling it against
  the later installed C1D2 revision already recorded in filesystem continuity.
  The final-ZIP matrix was internally complete for the wrong predecessor set.
- Preflight: before build, resolve every changed installed leaf against both
  the current continuity/terminal response record and the exact locally saved
  installed payload bytes. Freeze their matching hashes and provenance, then
  exercise each approved value through the exact final ZIP. A mechanically
  nearby predecessor file is not evidence of current installed state.
- Recovery: do not approve an operator-reported hash alone and do not retry
  SNR1. Bind the exact C1D2 payload bytes at the reported hash, add that value
  without dropping other explicitly supported predecessor/target hashes,
  rerun all predecessor, idempotence, unapproved, rollback, and control cases,
  and publish a newly identified ZIP and fresh staging/log roots.
- First observed: SNR1 manual JBOD preflight on 2026-08-20. The installer
  refused at predecessor validation before stopping tasks or mutating any
  installed file. No image, wafer, XML, or production route ran.

### Reviewed-field count differs from stroke-bearing field count

- Signature: a feedback projection or categorization build reports a grouping
  mismatch such as `28 vs 43` even though the saved response hash and total
  stroke count are correct.
- Cause: `reviewedFields` includes explicitly completed fields with zero
  accepted strokes. Grouping only the stroke array silently drops those
  reviewed no-mark fields.
- Prevention: enumerate the authoritative `reviewedFields` object first, then
  left-join strokes by exact identity, tile ID, and review-field ID. Preserve
  zero-stroke reviewed fields with their decision and timestamp. Refuse any
  stroke whose exact field key is absent from `reviewedFields`.
- Recovery: preserve the incomplete output root as `DIAGNOSTIC_ONLY`; do not
  overwrite or reuse it. Correct the join, rerun wrapper and target preflights,
  and build into a fresh short output root. This is feedback-accounting logic,
  not permission to change detector masks or ask the operator to review again.

### Copied per-tile optional artifact assumed to be uniform

- Signature: a copied-tree build stops on a missing legacy per-tile table even
  though the authoritative source tree and manifest are intact.
- Cause: the build assumed that every tile carried every auxiliary artifact.
  In the D5 reviewer, all 11 tiles have the combined component table, while
  only 10 have a corrected-accepted table and only 10 have a crop-seam table.
- Prevention: inventory exact source filenames and counts before mutation.
  Require only contract-mandatory files per tile; rename optional files only
  when present; assert the final renamed count against the verified source
  inventory rather than a rectangular tile-by-file assumption.
- Recovery: preserve the partial root as `DIAGNOSTIC_ONLY`, correct the source-
  derived inventory rule, repeat wrapper/path/target preflights, and build into
  a fresh root. Do not synthesize an empty auxiliary table or alter masks.

### Live JSON/file-lock and schema drift failures

- Signatures include `file is being used by another process` and missing
  properties such as `outputRoot`, `stable`, `acquisitions`, or `authority`.
- Causes: monitor/importer read a file mid-replace, or assumed one schema
  version without a guard.
- Prevention: writers use temp-plus-atomic-replace; readers use a bounded
  retry and retain the last complete valid snapshot; inspect `schema` and
  property existence before access; treat an incomplete snapshot as deferred,
  not as state truth.
- Recovery: restart only the failed monitor/importer if necessary; do not stop
  the detector or scribe worker unless the failure actually belongs to it.

### `JavaScriptSerializer` JSON array rejected as the wrong CLR collection type

- Signature: an exact non-mutating executable preflight reports a cardinality
  error such as `Exactly two targets are required` even though the bounded JSON
  manifest visibly contains the required two target objects.
- Cause: deserializing into `Dictionary<string, object>` with .NET Framework
  `JavaScriptSerializer` can materialize a JSON array as `ArrayList` or another
  `IEnumerable<object>`, not as `object[]`. A direct `as object[]` cast returns
  null and makes a valid manifest look empty.
- Preflight: every new file-backed .NET manifest consumer must run its exact
  non-mutating mode before creating an output root. For untyped JSON arrays,
  accept `IEnumerable<object>`, materialize it once into a bounded array, then
  validate exact cardinality and every row schema. Keep the manifest size and
  target count bounded.
- Recovery: verify that the output root is absent, preserve the failed
  executable and hash as diagnostic evidence, correct only the CLR collection
  boundary, compile a fresh executable, and rerun the exact preflight. Do not
  alter detector inputs, feedback, masks, thresholds, or target cardinality to
  compensate for a deserializer type mismatch.

The same rule applies to analysis result parsers. Read and record the actual
result schema after a one-item proof; do not assume historical field names
such as `qualifiedPeers` when the locked result exposes `peerCount`. A status
parser failure after artifacts and a PASS result exist is an orchestration
failure, not a detector failure. Preserve and reuse the valid result rather
than rerunning it.

### Scheduled-task name drift or missing task

- Signature: `No MSFT_ScheduledTask objects found` or task start fails for a
  hard-coded historical name.
- Cause: the installed revision owns a different task name.
- Prevention: read task names from the installed result/config, then verify
  each resolved task exists before start/stop. Never infer a task name from an
  old revision.
- Recovery: discover the installed task contract read-only; do not create a
  duplicate task merely to satisfy a historical command.

## Long-run and review safety

- Use bounded tiles/lots and explicit concurrency limits. Keep a short text
  progress log; never embed image bytes or huge manifests in task history.
- Original lossless native images are scoring inputs. Display artifacts do
  not replace them.
- A wrapper/tooling error before source access is not a detector failure.
  Record which layer failed before changing any algorithm.
- Do not publish a reviewer until detector sensitivity and false-control gates
  pass. Derived feedback UI must come only from the locked canonical BowComp
  reviewer contract in `AGENTS.md`.
- Review-only remains review-only. No training, XML, production authority, or
  production routing follows from operational recovery.

### Codex task JSONL grows into multi-gigabyte session data

- Signature: the Codex task becomes slow or unopenable and its rollout JSONL
  reaches gigabytes. The two confirmed incidents were approximately 20.6 GiB
  and exactly 18,490,749,343 bytes; the latter contained 306 oversized
  binary/image records.
- Cause: screenshots, image-returning tools, Base64, `data:` URLs, or other
  binary payloads were serialized into task history. Repeated image-bearing
  calls multiplied the task file even though the useful project evidence was
  already stored on disk.
- Prevention: apply `work/ARGOS_CODEX_SESSION_SAFETY.md`; prohibit binary and
  image-returning tool output; run the metadata-only
  `utilities/Confirm-ArgosCodexSessionSafety.ps1`; checkpoint at 128 MiB,
  rotate at 256 MiB, and hard-stop at 512 MiB. Keep galleries file-backed and
  invoke the guard directly at mandatory checkpoints. Do not use a standalone
  Codex cron or an active-task heartbeat for the session-size guard.
- Recovery: quarantine the task without opening or forking it. Recover only
  bounded text records into a new directory, write a small handoff, and resume
  from authoritative filesystem checkpoints in a fresh task.

### Codex session-size cron floods the task list

- Signature: the sidebar accumulates repeated tasks titled
  `Argos Codex session size guard` at the configured interval and the app may
  become sluggish or appear frozen.
- Cause: a Codex cron automation is standalone project work and creates a new
  visible task for each run. The prior 15-minute guard created at least 256
  duplicate tasks. A heartbeat is not a safe substitute because it grows the
  active task being monitored.
- Preflight: reject any recurring automation definition for this guard. Run
  `Confirm-ArgosCodexSessionSafety.ps1` directly at the checkpoints required by
  `work/ARGOS_CODEX_SESSION_SAFETY.md`.
- Recovery: pause the exact automation first, then archive only tasks whose
  exact title and summary automation ID match the paused guard. Preserve pinned
  Argos work and verify zero matching unarchived entries before resuming.

### Reviewer save exists but verification searches a different server root

- Signature: the reviewer reports a save, but verification finds zero project
  saves. A later audit finds completed feedback under the workspace-level
  `human_feedback` directory while the check inspected
  `work\FRONTSIDE_INSPECTION_REVIEW_ONLY\human_feedback`.
- Cause: the reviewer service was restarted with a different `RootDirectory`.
  Its relative `/outputs` page and `human_feedback` destination therefore
  changed together, while the prior save remained under the original root.
- Prevention: record the absolute server root, page URL, manifest review ID,
  and returned save folder on every save. Verify the embedded `reviewId` in
  the coordinates JSON. Search every explicitly recorded candidate root; do
  not infer the save root from the currently running service.
- Recovery: keep D4 and D5 identifiers separate, inspect the completion marker
  and coordinates hash in each candidate root, and report the existing save.
  Do not ask the operator to repeat review or overwrite feedback.

## Multi-tile audit launch and Windows path normalization

- Before starting any audit that expects one artifact per tile, enumerate the
  exact tile IDs from the governing manifest and prove every expected input
  exists. Do not infer shortened tile folder names (for example `T02`) when
  the actual contract uses names such as `T02_R00C01`.
- Do not launch a partial multi-tile audit. A missing later tile can leave a
  native executable fault dialog after earlier tiles were read, which is an
  orchestration failure and not detector evidence.
- .NET Framework/Windows PowerShell 5.1 tools can still enforce legacy
  `MAX_PATH` even when Windows supports long paths. Compute the longest fully
  qualified input, output, and temporary-suffix path before launch. An
  effective length of 200 or more requires a verified `subst` alias to the
  unchanged workspace (or a short audited staging root) before the first
  write; 230 or more is a hard stop. Record that alias and verify it inside the
  exact consuming process context. Do not copy, resample, or rename detector
  evidence merely to hide a path error.
- For UNC paths passed to .NET file APIs, use `Resolve-Path.ProviderPath`, not
  the provider-qualified `.Path` value beginning with
  `Microsoft.PowerShell.Core\\FileSystem::`.

### Windows PowerShell 5.1 generated-UI encoding drift

- Signature: generated reviewer text displays sequences such as `aEUR`,
  `aEuro`, or other mojibake where an em dash, ellipsis, multiplication sign,
  middle dot, or squared-unit marker was intended. A copied UTF-8 file may
  look corrupted through legacy `Get-Content` even when `.NET ReadAllText`
  decodes the file correctly.
- Cause: a UTF-8-no-BOM builder or copied UI contains non-ASCII literals, and
  one Windows PowerShell 5.1 read/parse hop applies the legacy system code
  page. Visual labels can be corrupted even while detector data and images
  remain byte-correct.
- Prevention: keep PowerShell 5.1 builder source and generated control labels
  ASCII-only. Express any required Unicode code point numerically, normalize
  both real Unicode and known already-corrupted byte sequences, assert zero
  non-ASCII code points in generated `index.html` and `app.js`, and inspect
  the rendered status card and action controls before release.
- Recovery: stop before release, preserve the failed root as
  `DIAGNOSTIC_ONLY` or `WITHDRAWN`, correct the generator rather than the
  generated page, and rebuild from the locked parent into a fresh short root.

### Imported review strokes contaminate the default clean view

- Signature: old magenta, green, or other operator marks appear on native BF,
  DF, accepted, and held panels even though source-image and generated-PNG
  hashes are unchanged.
- Cause: the reviewer loads file-backed feedback correctly but initializes
  its runtime feedback canvas as visible and redraws every imported stroke
  over every local panel. The strokes are a canvas layer, not necessarily
  rasterized into the images.
- Prevention: imported local and full-wafer feedback must default to hidden,
  use explicit `Show imported feedback` controls, and pass a real browser
  toggle test on a stroke-bearing field. Record separately whether feedback
  coordinates informed rule development; hidden display does not make a
  same-wafer rule blind.
- Recovery: withdraw the reviewer, prove raw BF/DF and generated heatmap hashes
  and pixel lineage, then rebuild from the locked clean parent. Never erase or
  overwrite the operator's saved feedback merely to obtain a clean display.

### Broad technical exclusion rendered as the default defect heatmap

- Signature: an amber or cyan ring appears along the wafer edge, or a mostly
  empty field looks like an inverted/full-frame heatmap.
- Cause: a broad technical, holder, or edge-exclusion mask is composited into
  the default component-hold panel. A metadata-only URL/hash audit does not
  reveal the visual semantic error.
- Prevention: the default accepted and held panels may contain only their
  documented sparse component masks. Technical and edge exclusions must be a
  separately labeled optional layer, off by default. For every composited
  panel, assert that changed pixels are a subset of the source alpha mask and
  perform bounded rendered checks of an edge field, a zero-signal field, a
  feedback-bearing field, and a held-component field.
- Recovery: withdraw the presentation without changing detector truth,
  separate the optional technical layer, rerun the pixel-outside-mask audit,
  and visually inspect the actual browser result before release.

### Stale heatmaps or highlighter marks baked into reviewer raster assets

- Signature: a current reviewer shows defect heatmaps, arrows, scribbles, or
  colored regions from an older review even when imported feedback is hidden;
  the artifact persists after reload or appears directly in a nominally clean
  full-wafer/native image.
- Cause: a predecessor preview, marked review image, or already-composited
  heatmap was copied or reused as the current clean base; alternatively, a
  generated overlay was not traced to the current revision's exact masks.
  DOM/control checks and filename/hash inventories alone do not establish
  visual provenance.
- Prevention: apply `work/ARGOS_RASTER_PROVENANCE_SAFETY.md` before presenting
  any reviewer. Require every nominally clean raster to hash-match its locked
  clean source, keep current detector heatmaps and operator-feedback canvases
  as distinct layers, and record the exact source/mask/revision lineage of
  every generated heatmap. For composited artifacts, prove changed pixels are
  a subset of the documented current mask. Then inspect the actual browser
  rendering with imported feedback hidden and with each current heatmap toggle
  exercised on bounded full-wafer and native fields. Visual evidence remains
  file-backed; never return screenshot bytes to task history.
- Recovery: withdraw the contaminated reviewer and preserve it only as audit
  evidence. Do not erase operator feedback or alter detector masks. Rebuild in
  a fresh short root from the locked clean source and current masks, rerun the
  raster-lineage and changed-pixel gates, and visually verify the rendered
  full-wafer and native views before release.

### Non-ASCII text embedded in an inline PowerShell wrapper command

- Signature: the wrapper reports `The string is missing the terminator` or a
  quoting/parser error while a search pattern contains mojibake or copied UI
  punctuation.
- Cause: complex or non-ASCII diagnostic text was interpolated into a shell
  command instead of being represented by an ASCII file-backed argument.
- Prevention: keep wrapper command lines ASCII and literal, put complex
  values in the bounded invocation manifest, and use short ASCII search terms
  or numeric code-point inspection. Run the static wrapper guard and target
  preflight before the mutating wrapper.
- Recovery: classify the failure as orchestration-only, do not change detector
  inputs, replace the fragile inline argument with a file-backed or ASCII
  form, and rerun only the wrapper/preflight layer.

### Continuously running portal sender with an undrained downstream backlog

- Signature: Task Scheduler reports a long-running portal sender as `Running`
  (often `LastTaskResult=267009` / `0x41301`), while signed request directories
  accumulate under the sender's `pending` root and no downstream responses
  return. Upstream routing and same-node endpoint probes may still pass.
- Cause: task state proves only that the transport process exists. It does not
  prove that the downstream listener is reachable or that the queue is
  advancing. An unavailable receiver/firewall/link can leave the sender alive
  and retrying the oldest request indefinitely.
- Prevention: before publishing an urgent portal request, record the pending
  and sent counts and newest timestamps on every hop, test the exact downstream
  TCP listener from the sending host, and require the new request to leave
  `pending` within a bounded interval. Audit queued manifests before recovery;
  expired requests must not be replayed ahead of current work.
- Recovery: move only verified expired requests into a recoverable quarantine,
  preserve current signed requests, repair or restart the exact failed
  receiver/sender leg, and prove queue movement plus a signed round-trip
  response. Do not treat a scheduled-task `Running` state as recovery evidence.

### Insite unit container exists but the issue-history join returns no row

- Signature: a human can see an exact 12-character scribe in the Insite Portal
  `Unit Containers` table, but the automatic bridge emits
  `MES_LOOKUP_HOLD_NO_ROW` for that same scribe. Other wafers in the same lot
  may resolve normally.
- Cause: the bridge's exact-scribe path starts from EPI evidence and requires
  an inner `IssueActualsHistory` join. A current `Insite.Container` unit row can
  exist with the exact scribe even when that historical issue row is absent or
  incomplete, so the join removes a real current unit before WIP lookup.
- Prevention: query `Insite.Container.Substrate` independently by the exact
  human-confirmed scribe and treat its single three-digit unit-container row
  as a second exact lineage path. Preserve the EPI requirement. If multiple
  unit rows, multiple parents, or disagreement with issue history exists, emit
  an ambiguity hold. The lot and slot must never establish scribe identity.
  Gate the direct path against exact-only, agreeing, conflicting, multiple,
  missing-EPI, and missing-container fixtures under Windows PowerShell 5.1.
- Recovery: preserve the false no-row response as audit evidence, patch only
  the Argos read-only Insite query and its pinned resolver, and requeue the
  exact signed scribe request after quarantining its stale response
  recoverably. Verify that the returned record names the exact scribe, unit
  container, parent lot, product, and product family before allowing the JBOD
  metadata importer and processor to resume. Do not synthesize metadata from
  neighboring wafers or from acquisition slot position.

### Portal receiver partial package blocks every retry of that package ID

- Signature: the sender task remains `Running` but reports
  `SEND_RETRY_PENDING`; the receiver returns `PARTIAL_HOLD` with `A prior
  incomplete partial package requires review.` A directory named
  `<packageId>.partial` exists under the receiver inbox `pending` directory,
  while the matching `.ready` directory and receipt are absent. Later signed
  responses accumulate behind the blocked oldest package.
- Cause: a prior authenticated transfer created and populated the receiver's
  temporary extraction directory but did not complete the atomic
  `.partial`-to-`.ready` promotion and receipt write. The transport correctly
  refuses to overwrite, trust, or silently resume that uncommitted state.
- Prevention: monitor each response hop for bounded queue advancement, not
  merely a `Running` task. Treat any `.partial` directory as a fail-closed
  transport incident. Never promote it manually to `.ready`; its successful
  package-contract validation and final acknowledgement were not recorded.
- Recovery: verify the exact package ID, require matching `.ready` and receipt
  to be absent, inventory the partial without reading bulk payloads, and move
  only that exact partial into a timestamped recoverable quarantine within the
  same portal root. Do not delete it. Leave the original signed sender package
  in `pending`; the running sender must retransmit it and the receiver must
  create a fresh validated `.ready` package and receipt. Prove the backlog
  drains and signed responses reach the shared response queue before declaring
  recovery.

### Canonical request hash compared with raw JSON file hash

- Signature: an exact Insite request package is selected correctly, but a
  maintenance verifier stops with `Insite request content hash mismatch` even
  though the relay manifest and package were created normally.
- Cause: `requestContentSha256` is the semantic hash of a normalized request
  containing schema, state, lookup key, normalized scribes, and sorted unique
  acquisition keys. The relay manifest's `sha256` field is the byte hash of
  `PENDING_INSITE_REQUEST.json`. Comparing the raw file hash to
  `requestContentSha256` compares two deliberately different hash domains.
- Prevention: reproduce the installed JBOD worker's canonicalization function
  byte-for-byte. Verify the raw payload against manifest `sha256` and verify
  the normalized request against manifest `requestContentSha256` as separate
  checks. Every rehearsal and final-ZIP gate must use a production-shaped
  fixture whose two hashes are asserted to differ, plus negative cases proving
  that raw-payload and canonical-content mismatches are independently refused
  before queue mutation.
- Recovery: preserve the failed signed request and endpoint failure response,
  rely on the endpoint's maintenance rollback, correct only the verifier, and
  issue a new signed request ID. Never edit, replay, or republish the failed
  signed package. Reverify the live predecessor before the replacement applies.

### Gateway response extraction exceeds MAX_PATH before atomic commit

- Signature: the Gateway response receiver logs `RECEIVER_ERROR` with `The
  specified path, file name, or both are too long`, leaves a populated
  `<responseId>.partial`, and then reports `HOLD_PARTIAL_EXISTS` every two
  seconds. The signed response may be valid; extraction fails before atomic
  `.ready` promotion and receipt creation.
- Cause: the receiver prefix
  `C:\ProgramData\ArgosProjectPortalRO\responses_from_argos\pending\<id>.partial`
  is combined with legitimate nested DATA_PULL paths. In the observed case the
  longest relative path was 162 characters and the effective extraction path
  was 268. The gateway share bridge also watched that long inbox and would have
  archived the nested ready directory under another long root.
- Prevention: preflight every response manifest against the receiver partial
  prefix and the share bridge archive prefix before transport. Both effective
  paths must be at most 230 characters, preserving a 30-character reserve.
  Configure the TLS receiver inbox, share bridge `responseWatchRoot`, and share
  bridge `localResponseArchive` as one atomic short-root contract. Changing
  only the receiver strands committed responses outside the share bridge.
- Recovery: validate the blocked manifest without bulk-loading its payload,
  atomically change the receiver inbox to `C:\APR\R`, the share watch path to
  `C:\APR\R\pending`, and the local response archive to `C:\APR\A`; back up
  both configs; recoverably quarantine only the exact uncommitted partial;
  restart the exact receiver and share-bridge tasks; and let the original
  signed Argos sender retransmit. The observed maximum becomes 220 characters.
  Never manually promote a partial to ready and never delete the audit copy.

### Portal publisher temporary ZIP component exceeds the 80-character limit

- Signature: the short-root publication preflight reports
  `HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH` even though the request archive,
  share-ready name, and total effective paths are below 200 characters. The
  failing local component is `<full request>.ready.zip.partial.<32 hex>` and
  is 87 characters long.
- Cause: `Publish-SignedPortalRequest.ps1` formed its private local temporary
  archive by appending `.partial.` and a GUID to the complete final archive
  name. Moving the archive root cannot fix a component-length violation.
- Preflight: enumerate the exact local final archive, private local temporary
  archive, share `.upload`, and share-ready paths before ZIP creation. Require
  every new component to be at most 80 characters and retain the 32-character
  effective-length reserve.
- Recovery: require that no archive, `.upload`, or share-ready file exists,
  preserve the signed request directory unchanged, and change only the private
  local temporary name to a short fixed prefix plus GUID such as
  `P_<32 hex>.tmp`. Continue to publish the unchanged full request ID as the
  final archive and share-ready filename. Re-run signing verification, path
  budget, mapped-share sentinel hashing, and create-new publication. Never
  shorten or alter the signed request ID or manifest.

### Late metadata arrives after the live appearance-reference cohort disappears

- Signature: an exact-scribe frontside acquisition is
  `READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING`, but the processor emits
  `HOLD_FRONTSIDE_SCRATCH_TEST_REFERENCE_INSUFFICIENT`. The same acquisition
  originally contained ten physical wafers and nine completed result roots
  remain, while the current catalog contains only the late-arriving target for
  that acquisition timestamp.
- Cause: frontside appearance admission builds its cohort only from acquisitions
  present in the current live catalog. Completed jobs retain their original
  job configurations and clean BF/DF source bindings, but those bindings are
  not reconsidered after their raw acquisitions age out of the live inventory.
  A delayed MES/scribe correction can therefore strand the last wafer even
  though an exact-context target-excluded reference cohort was already used.
- Prevention: persist the exact context-family, acquisition identity, original
  BF/DF source paths and hashes, appearance-admission audit, and completed result
  binding as durable reference-candidate metadata. A catalog refresh must not
  silently erase completed exact-context reference availability.
- Recovery: admit historical peers only from `COMPLETED` ledger rows whose
  retained job configurations match the exact lot acquisition timestamp,
  product/revision/process context family, frontside route authority, and
  review-only safety contract. Revalidate the original clean BF/DF files and
  run appearance compatibility again with the target included for evaluation
  but excluded from its own reference. Require at least three mutually
  compatible physical wafers. Never use rendered output images, detector masks,
  slot identity, proximity, or a prior classification as reference authority.

### Diagnostic command prints an unbounded JSON/route-hold payload

- Signature: a nominal status check appears frozen or produces thousands of
  console lines that cannot be copied because `PROCESSOR_STATUS.json`, a route
  hold collection, a ledger message, or a PowerShell failure line was emitted
  raw or serialized recursively.
- Cause: the command delayed all output until after parsing and then returned an
  unbounded object or raw file. `-Tail` limits line count, not line length; one
  JSON or failure line can itself contain a very large nested payload.
- Prevention: never print raw processor status, catalog, ledger, route-hold,
  failure, or worker-log content. Print a start marker, select scalar fields,
  limit result cardinality, and cap every returned string by character count.
  Compute file length, timestamp, and hash without returning file contents.
  The operator-facing output budget for an interactive recovery check is twelve
  short lines unless a bounded file-backed report is explicitly requested.
- Recovery: cancel the read-only command with `Ctrl+C`, clear the console, and
  rerun a scalar-only query with explicit row and string caps. Treat the noisy
  output as an orchestration failure; it changes no detector or JBOD state.
- Repeated observation: a C1D3 search used recursive `Get-ChildItem` against the
  complete `work` tree.  Concurrently absent deep paths emitted hundreds of
  errors, the command timed out, and the returned output exceeded 10,000
  tokens.  Future searches must use `rg` or one exact bounded subroot, stop on
  errors, cap cardinality, and return only scalar paths/hashes.

### Invalid PowerShell regex repeats once per pipeline item

- Signature: a bounded file-list command emits hundreds of identical `parsing ... Unrecognized escape sequence` errors instead of paths.
- Cause: `-match` or `-notmatch` compiles an invalid regular expression for every object flowing through `Where-Object`; escaping a literal underscore or Windows separator incorrectly turns one syntax error into an output flood.
- Preflight: compile any nontrivial regex once before the pipeline with `[regex]::new(...)`, or use `-like`, `StartsWith`, `Contains`, and explicit path-prefix comparisons for literal path filtering. Apply `Select-Object -First` after a filter that cannot throw per item.
- Recovery: stop the command, treat it as read-only/no-state-change, and rerun with fixed-string or precompiled-regex filtering plus a strict output cap. Never retry the same inline expression across the full file list.
### Compact identity tokens versus formatted persisted timestamps

- Signature: an exact acquisition is present, but a recovery or routing gate reports zero matching historical jobs or a lot/acquisition/slot mismatch.
- Cause: `physicalIdentity` carries compact `yyyyMMddHHmmss` and `SlotNN` tokens while persisted `scanTimestampLocal` or `slot` fields may use formatted date/time or numeric representations.
- Preflight: bind the exact `physicalIdentity` first; normalize persisted scan and slot values to digits and require the normalized values to start with the compact 14-digit acquisition token and equal the numeric slot. Historical jobs must also match the exact lot/acquisition `physicalIdentity` prefix.
- Recovery: change only representation comparison. Preserve exact scribe, lot, product/revision, route authority, physical identity, source hashes, and target-excluded reference gates. Re-run the full Windows PowerShell 5.1 package rehearsal and final-ZIP gate before resubmission.

### Historical job schema boundary for context reference families

- Signature: a completed historical job is found by exact physical identity, but strict mode reports that `contextReferenceFamily` is absent.
- Cause: the V3.4.1 frontside job schema stored `FRONTSIDE_SCRATCH_TEST_LOT_ACQUISITION_<lot>_<compact scan>` in `referenceFamily`. Newer jobs separately store the scribe/MES context hash in `contextReferenceFamily`.
- Preflight: inspect the property through optional-property access. When present, require exact context-hash equality. When absent, require exact equality to the V3.4.1 lot/acquisition family formula and independently recover every peer's acquisition-keyed exact-scribe MES row from retained `metadata\verified\SCRIBE_MES_LIVE_*.json` snapshots. Require identical product, revision, family, process workflow/block/step, scan-time authority, and frontside route authority across all selected peers and the current target.
- Recovery: preserve the historical job and metadata files unchanged and bind through the version-appropriate representation. Never treat the legacy lot/acquisition token alone as context authority. Continue to require the completed ledger/result, original-source paths and hashes, and a fresh target-excluded appearance-admission result.

### Append-only metadata snapshots contain compatible enrichment

- Signature: an exact acquisition/scribe appears in more than one retained `SCRIBE_MES_LIVE_*.json` snapshot, and a recovery gate reports a snapshot conflict even though the authoritative values agree.
- Cause: later append-only snapshots can enrich an earlier row with fields that were previously absent. Comparing a serialized list that treats missing and populated values as different incorrectly rejects compatible metadata history.
- Preflight: first exclude rows that do not already carry the full exact-scribe lookup, MES lineage, exact prior-move-in, and confirmed frontside-route authorities; pending or unresolved historical states are chronology, not competing exact answers. Among the remaining authoritative rows, compare each field independently. Two non-empty values for the same acquisition, exact scribe, and field must be identical; a missing value may be superseded only by a populated value. Select one retained row with the highest field completeness and require that single row to pass the entire product/revision/family and process-step contract. Never synthesize authority by merging incomplete rows.
- Recovery: preserve every retained snapshot unchanged, ignore only pre-authoritative rows, reject any genuine non-empty disagreement among authoritative rows with the exact field named, and use only the most complete compatible authoritative row. Re-run the exact PowerShell 5.1 and final-ZIP gates before issuing a new signed request ID.

### Exact metadata overlay supersedes an older aggregate transport hold

- Signature: the current catalog and retained verified overlay carry exact-scribe MES and scan-time authority, while the hash-bound aggregate Insite transport record for that same scribe still says `VISUAL_STATE_HOLD_INCOMPLETE_MES_STATE` / `MES_LOOKUP_HOLD_NO_ROW` and contains older acquisition-context holds.
- Cause: a later direct-unit-container lookup can populate the acquisition-keyed verified metadata overlay without rewriting the earlier aggregate transport payload. The transport package remains valid audit evidence for what it originally returned, but it is not the authority for the later exact overlay.
- Preflight: validate the transport package only as immutable hash/request/import evidence. Separately require one retained authoritative overlay row for the exact acquisition key and 12-character scribe, with exact MES lineage, product/revision/family, process workflow/block/step, scan-time prior-move-in authority, confirmed frontside route, and `lotSlotIdentityAuthorityUsed=false` on the catalog target. Never relabel or edit the older transport hold.
- Recovery: preserve both histories. Use the exact acquisition-keyed overlay as processing metadata authority, record the older transport query/lineage state as non-authoritative audit context, and quarantine a pending transport copy only when its complete file binding is byte-identical to the processed copy and the import-state hashes agree.

### `System.Drawing` constructor receives a PowerShell `PathInfo`

- Signature: `[Drawing.Bitmap]::new((Resolve-Path $path))` reports that a
  `System.Management.Automation.PathInfo` value cannot be converted to
  `System.Drawing.Image`; later pixel calls fail on null bitmap variables and
  may still leave misleading zero-valued summary rows.
- Cause: `Resolve-Path` returns a `PathInfo` object, while the bitmap string
  overload requires the resolved path's scalar `.Path` value. A nonterminating
  constructor error can let the surrounding loop continue.
- Preflight: resolve once with
  `(Resolve-Path -LiteralPath $path).Path`, require a nonempty string, and use
  `-ErrorAction Stop` or an explicit null check before entering any pixel loop.
- Recovery: discard every summary row from the failed command, which is not
  image evidence. Dispose any successfully opened bitmap, rerun with the
  scalar resolved path, and require an explicit sampled-pixel count plus zero
  command errors before using the comparison.

### Legacy `csc.exe` drops directories from relative forward-slash source paths

- Signature: .NET Framework `csc.exe` emits `CS1504` for a source file shown
  only by its basename under the current directory, even though the supplied
  relative path included existing subdirectories such as
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/...`.
- Cause: legacy compiler command-line parsing can interpret a relative token
  containing forward slashes as option-like syntax and discard the directory
  portion before resolving the source file.
- Preflight: resolve every source and output through
  `(Resolve-Path -LiteralPath ...).Path` or an explicitly validated absolute
  Windows backslash path before invoking the Framework compiler. Require every
  resolved source to exist, and pass the output as an absolute backslash path.
- Recovery: treat the failed compile as no-build/no-run evidence, verify that
  no executable or analysis root was created, and repeat once with fully
  resolved absolute Windows paths. Do not change source logic or inspection
  gates to compensate for an invocation-path failure.

### Derived target-site records omit local pose objects

- Signature: a portable native diagnostic writes all raster sheets and then
  exits before writing its final JSON audit; the output directory contains
  only the rendered PNG files and no completion manifest.
- Cause: the accepted `TargetSites` helper creates reference
  `QcChannelSite` rows with absolute anchor, absolute angle, site, and pass
  state only. It intentionally does not populate `Coarse`, `Precise`, or local
  line-fit objects. A later diagnostic that dereferences
  `target.Precise.CorrectedX/Y/Angle` fails after rendering but before its
  final audit write.
- Preflight: before packaging a diagnostic that joins observed peer sites to
  derived target-site records, enumerate every target-site field the final
  audit will access and run a no-write serializer self-test with records shaped
  exactly like `TargetSites` output. Treat target absolute anchor/angle as the
  available authority; obtain any target local corrected frame from the locked
  accepted model audit or omit it explicitly. Require the final JSON audit to
  be written before declaring an end-to-end package rehearsal complete.
- Recovery: label the PNG-only directory `INCOMPLETE_NO_FINAL_AUDIT`; do not
  infer alignment or gate results from it. Remove the invalid target-local
  dereference, preserve all source hashes and thresholds, increment the
  diagnostic package revision, rerun compile/self-test/native proof/wrapper/
  ZIP/extraction gates, and require a fresh JBOD output directory containing a
  hash-verifiable final JSON audit before review.

### Unparenthesized PowerShell predicates consume `-or` as a cmdlet argument

- Signature: a preflight expression such as `Test-Path -LiteralPath $a -or
  Test-Path -LiteralPath $b` fails with `LiteralPath is specified more than
  once`, even though both paths and the surrounding publication workflow are
  otherwise valid.
- Cause: in PowerShell command mode, the unparenthesized `-or` expression is
  parsed as part of one `Test-Path` invocation rather than as a Boolean
  operator between two completed predicate calls.
- Preflight: require every cmdlet predicate participating in `-or` or `-and`
  to be individually parenthesized, for example `(Test-Path -LiteralPath $a)
  -or (Test-Path -LiteralPath $b)`. Set `$ErrorActionPreference='Stop'` in the
  orchestration scope so the syntax/binding failure cannot be followed by a
  mutation.
- Recovery: verify the publish or install call was not reached and that no
  create-new target exists; correct only the preflight expression, repeat the
  exact non-mutating gates, and then continue with the unchanged signed
  package or installer inputs.

### Portal payload root adds its own `payload/` prefix

- Signature: `New-SignedPortalPackage.ps1` refuses a maintenance request with
  `Maintenance entryPoint is absent from payload` even though a staging tree
  visibly contains `payload\<entrypoint>.ps1`.
- Cause: the signer treats the supplied `PayloadRoot` as the content root and
  adds the manifest prefix `payload/` itself. Supplying the parent of an
  already nested `payload` directory produces signed names beginning with
  `payload/payload/`, which cannot match an entry point declared as
  `payload/<entrypoint>.ps1`.
- Preflight: enumerate files relative to the exact planned `PayloadRoot`, add
  one and only one signer-owned `payload/` prefix, and assert that every
  maintenance `entryPoint` and `changes[].source` is an exact member of that
  projected set before signing.
- Recovery: verify no `.ready` request, manifest, or signature was emitted.
  The signer can leave an exact unsigned `REQ_*.partial` containing copied
  payload files when this check fails; move that one identified partial to a
  bounded diagnostic quarantine rather than treating it as a request. Keep
  the definition and payload bytes unchanged, and retry create-new signing
  with the directory *inside* the staging tree as `PayloadRoot`. Never edit an
  already signed request.

### One root alias cannot shorten long internal paths or filenames

- Signature: an exact JBOD preflight still reports
  `HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH` after the canonical source root
  has been replaced by a one-letter `subst` alias. The exposed paths can remain
  at effective length 230 or greater, and individual source filenames can
  still exceed the 80-character component gate.
- Cause: a root alias removes only the canonical root prefix. It cannot shorten
  nested legacy acquisition-directory names or the leaf filename component.
- Preflight: evaluate every final aliased source path, not just a representative
  sentinel. Separately inspect effective total length and longest component.
  When either remains a hard stop, reject the one-root plan before launching
  the image reader.
- Recovery: preserve the withdrawn request and unchanged frozen selection.
  On the same source volume, create a fresh bounded staging directory containing
  one short, deterministic hard-link name per exact frozen source. Verify every
  link target path, byte length, and prefix hash against its canonical source,
  run through only those short link paths, and remove the exact hard links and
  empty staging directory in `finally`. Never copy, rename, rewrite, or replace
  the canonical image bytes, and never use a junction when the leaf filename
  itself violates the component gate.

### Strict-mode review rendering requires one result schema for holds and successes

- Signature: a Windows PowerShell 5.1 review-only runner finishes its expensive
  upstream work, then fails while building CSV or HTML with `The property
  '<name>' cannot be found on this object`, such as a missing `processBlock`
  property on an explicit hold row.
- Cause: the runner collects heterogeneous result objects in one list. A hold
  constructor omitted descriptive fields that the success constructor included,
  while the later renderer dereferenced those fields under `Set-StrictMode`.
- Preflight: define one required result-row schema for every disposition,
  including explicit holds, and validate every constructed row against it before
  serialization or rendering. A synthetic hold plus a synthetic success row must
  both pass the same renderer-field check in the packaged rehearsal.
- Recovery: preserve the failed signed response as no crop or alignment evidence,
  add the missing fields to the hold constructor, retain strict mode, add the
  uniform-schema assertion, increment the package revision, and rerun the exact
  signed JBOD workflow into a fresh output root. Never weaken strict mode or
  silently drop the hold to make the gallery render.

### `Join-Path` cannot compose a planned path on an absent local drive

- Signature: a local path-budget rehearsal for a JBOD path such as `D:\...`
  emits `Cannot find drive. A drive with the name 'D' does not exist` before
  `Confirm-ArgosPathBudget.ps1` receives the candidate list.
- Cause: `Join-Path` resolves through the current PowerShell drive provider.
  The planned destination can be valid on the remote JBOD while that drive
  letter is intentionally absent on the rehearsal workstation.
- Preflight: construct not-yet-mounted Windows candidates with bounded string
  concatenation or `[IO.Path]::Combine` semantics that do not require the drive
  provider, then pass those complete strings to the metadata-only path-budget
  utility. Run the orchestration scope with terminating errors so a failed
  candidate constructor cannot yield a misleading gate summary.
- Recovery: discard the incomplete path-gate output, confirm no write or launch
  occurred, rebuild the same candidate list without `Join-Path`, and require a
  complete PASS row for every planned path before signing or launching.

### Windows PowerShell 5.1 can reject array-subexpression wrapping of a generic list

- Signature: a script that has already populated a
  `System.Collections.Generic.List[object]` fails at a later enumeration with
  the unlocalized `Argument types do not match` / `System.ArgumentException`
  under Windows PowerShell 5.1.
- Cause: forcing that generic list through an array subexpression, such as
  `@($resultRows)`, can invoke a Windows PowerShell 5.1 binder conversion that
  is not required for `foreach` and fails for the heterogeneous PSCustomObject
  payload.
- Preflight: when the consumer only needs enumeration, iterate the generic list
  directly (`foreach ($row in $resultRows)`). Use its explicit `.ToArray()`
  method only at a serialization boundary that genuinely requires an array.
  Exercise both a hold row and a success-shaped row under Windows PowerShell
  5.1 before signing the package.
- Recovery: preserve the failed signed run as no review evidence, remove only
  the unnecessary array-subexpression wrapper, retain the uniform-schema
  assertion and strict mode, increment the package revision, and rerun through
  a fresh install/staging/output namespace.

### Package-root path gate misses an overlong copied evidence leaf

- Signature: a package-level path gate passes its root, ZIP, extraction root,
  and planned output, but a later portal payload gate reports
  `HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH` because a copied evidence filename
  is longer than 80 characters. The first confirmed case was an 81-character
  R5P24 checkpoint leaf.
- Cause: the build preflight enumerated only representative roots and output
  artifacts. It did not construct and test every final package-relative leaf
  before creating the package.
- Preflight: before the first package write, enumerate every planned payload
  relative path after destination renaming, combine each with the exact package
  and extracted roots, and run `Confirm-ArgosPathBudget.ps1` on the complete
  list. Evidence may keep its authoritative long workspace name, but its
  portable copied name must be explicitly short and recorded in the manifest.
- Recovery: do not publish or patch the unsafe package. Mark it withdrawn and
  rebuild the unchanged detector contract in a fresh package/staging root with
  short copied evidence leaves. Require complete path, one-root extraction,
  manifest, wrapper, and final-ZIP gates again.

### Expected-request response import extracts unrelated archives first

- Signature: `Receive-SignedPortalResponses.ps1 -ExpectedRequestId <id>` fails
  while extracting an old response whose deep data path is unrelated to the
  requested ID.
- Cause: the importer must extract each not-yet-archived ZIP before it can read
  that response's signed manifest and compare `requestId`; the expected-ID
  filter therefore occurs after extraction.
- Preflight: for a single pending request, inspect only the bounded
  `PORTAL_RESPONSE_MANIFEST.json` entry through the ZIP central directory,
  select the exact matching response ZIP, and path-gate a short exact-response
  extraction root before writing.
- Recovery: do not retry the bulk importer against the same backlog. Extract
  only the selected exact ZIP to a fresh short root, verify its endpoint
  signature and declared payload hashes, and preserve the unrelated archive
  unchanged.

### One fail-closed pose hold must not erase unrelated batch results

- Signature: a multi-wafer review package returns a valid final audit with
  `HOLD_POSE_RESULT_MISSING` for every row, while the captured pose error names
  only the first physical wafer and no final pose manifest exists.
- Cause: the legacy pose helper throws immediately when any input's coarse or
  native notch gate holds. The exception prevents later independent BF/DF pairs
  from being evaluated and prevents the helper from writing its aggregate
  manifest, so the caller cannot distinguish one real hold from unattempted
  peers.
- Preflight: for heterogeneous review inventories, require per-input exception
  containment and a manifest row for every frozen BF/DF pair. Each row must be
  either a qualified native pose or an explicit hold with its reason and exact
  source hashes. Assert `manifest waferCount == frozen runnable count` before
  map projection or crop generation.
- Recovery: preserve the batch-wide missing result as diagnostic only. Use a
  fresh package revision whose pose helper catches and records each independent
  hold, continues through every frozen pair, and writes the complete fail-closed
  manifest. Do not relabel the first hold, reorder appearance-selected wafers,
  or treat unattempted peers as pose failures.

### Parent process timeout can bypass child `finally` cleanup

- Signature: a signed maintenance request fails with `Portal child timed out
  after 900 seconds`, empty child stdout/stderr, and no terminal package audit,
  after a long-running child created short hard-link staging and a `subst`
  output alias.
- Cause: the portal worker terminates the dispatcher process at its bounded
  timeout. Forced process termination does not guarantee that the dispatcher's
  PowerShell `finally` block runs, so temporary hard links, empty staging
  directories, and the session-level alias may remain even though installed
  maintenance files are transactionally rolled back.
- Preflight: estimate the worst-case per-item runtime and divide independent
  image work into separate signed requests that each finish well below the
  endpoint timeout. Record the exact staging root and alias target before
  launch. A timeout recovery must first inventory those exact targets and
  reject unexpected names or files.
- Recovery: preserve the partial output tree as diagnostic-only evidence. In a
  separately signed bounded recovery, remove only verified hard links under the
  exact timed-out staging root, remove only `subst` mappings whose normalized
  target equals the exact output parent, and remove only the resulting empty
  staging directories. Never recursively delete the partial output or a broad
  drive/root. Then resume with fresh chunk-specific install, staging, and output
  namespaces; never reuse the timed-out root.

### A long endpoint response path can poison the persistent request queue

- Signature: the engineering-share gateway continues moving signed requests to
  `requests\processed`, but no new response of any kind appears after one
  bounded `DATA_PULL`. Later requests are also accepted at the gateway and stay
  unanswered. The first confirmed trigger planned a 255-character endpoint
  work file and a 267-character response-partial file.
- Cause: the endpoint copies approved data under a preserved relative path in a
  deterministic work root, then `New-SignedResponse` copies the same tree under
  the longer response-outbox partial root. The response copy occurs after the
  per-request handler `catch`. A path failure therefore escapes the request
  failure-response path, leaves the incoming request and deterministic work
  root in place, and terminates the endpoint worker. Each scheduled restart
  selects the same request and exits at `Endpoint work root collision`; after
  the bounded restart count is exhausted, all later requests remain queued.
- Preflight: for every `DATA_PULL`, construct every final path beneath the exact
  endpoint work root, response partial root with a maximum-length response ID,
  response-sender sent root, gateway receiver/archive roots, and local receipt
  root. Run `Confirm-ArgosPathBudget.ps1` on every final leaf before signing.
  An effective length of 200 or more requires a verified short local root; 230
  or more is a hard stop. Checking only the source path or requested byte limit
  is insufficient.
- Recovery: the endpoint cannot repair itself through the poisoned queue. On
  the affected endpoint, stop only the portal endpoint and its response sender;
  verify the exact signed request ID, deterministic `JOB_` work leaf, and
  matching `R_<request-hash>_*.partial`; move only those exact incomplete
  artifacts to a recoverable quarantine. Atomically rebind both the endpoint
  response outbox and response-sender watch/sent roots to path-gated short local
  roots, then restart the two portal tasks and let the original queued request
  complete. Never delete or resend the signed request, and do not restart
  detector, scribe, Insite, or monitor tasks. A durable worker revision must
  also preflight response paths and convert response-construction failure into
  a compact fail-closed response without reusing a collided work root.

### A manual queue-recovery package can outlive the signed request it targets

- Signature: the non-mutating recovery preflight reaches the installed
  `Test-SignedPortalPackage.ps1` and stops with `Portal request is expired.`
  before any task stop, quarantine move, worker replacement, or config change.
  The same request was valid when the gateway and endpoint transport accepted
  it, but its signed `expiresUtc` passed while the endpoint queue remained
  poisoned.
- Cause: the recovery package correctly pinned the exact request identity but
  treated cryptographic validity and current-time eligibility as one gate. Its
  final-ZIP rehearsal used a freshly signed request and therefore never crossed
  the expiry boundary that the live, previously accepted request had crossed.
- Preflight: every recovery plan targeting an existing signed request must read
  the signed `createdUtc` and `expiresUtc` before package release, compare them
  with the earliest realistic operator launch time, and exercise both a fresh
  request and an already-expired request in the exact final-ZIP rehearsal. An
  expired request may be fully signature-, identity-, safety-, parameter-,
  payload-size-, and payload-hash-verified only to authorize its exact
  quarantine; it is not eligible for endpoint execution.
- Recovery: fail before mutation on any signature, identity, flag, parameter,
  payload, or path mismatch. Stop only the already approved portal tasks, move
  the exact expired request together with its exact incomplete work and
  response partial into recoverable short quarantine, install the queue-safe
  worker, and restart the portal tasks. Never add an expiry bypass or replay the
  expired package. Prove endpoint health with current signed work; only then
  issue a fresh signed request ID for still-required data. Preserve the expired
  package and record the replacement relationship explicitly.

### Gateway response publication can fail both component and total-path gates

- Signature: a complete round-trip preflight rejects two gateway publication
  paths before signing. The local response-ZIP staging leaf is one 92-character
  component because the current formula concatenates a 51-character
  `<response>.ready.zip` name, `.partial.`, and a 32-character GUID. The direct
  engineering-share `.upload` path is 212 characters before reserve and 244
  effective characters with the mandatory 32-character reserve.
- Cause: the gateway share bridge shortens neither its temporary ZIP leaf nor
  its configured direct UNC response root. The earlier `C:\APR\R` and
  `C:\APR\A` receive/archive repair fixed those two local roots only; it did not
  shorten the bridge's local staging filename or its final share-write path.
- Preflight: for every planned response, construct the exact gateway local-ZIP
  staging filename, including `.partial.` and the full GUID suffix, and apply
  both the 80-character component limit and the normal 32-character path
  reserve before signing the request. Evaluate the bridge's exact configured
  `shareResponseRoot`, not a laptop-only mapped-drive spelling. Checking only
  response directories, share filenames, or total path length is insufficient.
- Recovery: do not sign or publish the affected request. Install a separately
  rehearsed gateway-only bridge revision that uses a bounded short staging
  token derived from the signed response identity while preserving the exact
  final shared and archive ZIP names. It must also establish and verify a short
  share alias in the exact scheduled-task execution context and atomically
  rebind the bridge's share roots to that alias; a laptop-only mapping is not
  evidence. The repair must be idempotent, verify the exact installed
  predecessor and configuration hashes, refuse unapproved hashes before
  mutation, restart only the gateway share bridge, and prove response
  verification, staging, publication, archive, collision refusal, task-context
  alias visibility, and rollback under Windows PowerShell 5.1. A root alias
  alone cannot repair the separate 92-character component failure.

### Windows PowerShell 5.1 File.Replace requires an explicit backup path

- Signature: an isolated exact-predecessor rehearsal reaches
  `[IO.File]::Replace($stage,$destination,$null,$true)` and throws
  `The path is not of a legal form.` before replacing the destination. A
  rollback that assumes the replacement completed can then obscure the original
  failure unless each mutation flag is set only after its exact operation
  returns.
- Cause: the Windows PowerShell 5.1/.NET Framework overload normalizes the
  third `destinationBackupFileName` argument and does not accept the null value
  used by this invocation, even though newer runtime documentation may suggest
  that no backup is allowed.
- Preflight: every PowerShell 5.1 atomic replacement rehearsal must exercise
  the exact `[IO.File]::Replace` call against fresh files on the intended
  volume. Require an explicit, path-budgeted, collision-free backup filename;
  never infer compatibility from source parsing or a newer .NET runtime.
- Recovery: retain the separately copied approved predecessor, call
  `File.Replace` with an explicit bounded backup path inside the repair audit
  root, and preserve that replaced file for rollback evidence. Set the
  replacement-complete flag only after `File.Replace` returns. Exercise an
  injected post-replacement failure and prove exact predecessor restoration,
  alias cleanup, task restart, and untouched sibling-task state before release.

### Double-clicked operator wrappers must persist output and remain open

- Signature: the operator launches a passing or failing `.cmd` preflight from
  Explorer, the console closes immediately when PowerShell exits, and the
  result is lost even though the underlying preflight is non-mutating. The
  workflow then wrongly depends on the operator catching transient text and
  launching a second command manually.
- Cause: the wrapper had no persistent log, no terminal hold, and split the
  validated preflight and authorized apply into two separate operator actions.
  Source and functional rehearsals validated the PowerShell target but did not
  exercise the actual Explorer-launched operator experience.
- Preflight: every operator-facing Windows package must have one primary
  launcher that writes a create-new bounded log before invoking the target,
  records both stdout and stderr, verifies the exact required preflight state,
  and automatically continues to apply only on that state. Static wrapper
  checks must also assert an unconditional terminal hold after the child exits.
  Rehearse passing, failing, and already-applied launcher flows from the exact
  final ZIP.
- Recovery: withdraw the wrapper-defective package even when its underlying
  repair logic is sound. Issue a fresh package/revision with a single launcher,
  persistent known log root, fail-closed preflight-to-apply chaining, and a
  window that remains open on every exit path. A vanished preflight is not an
  apply result and authorizes no inference about installed state.

### A live UNC symbolic link must not be verified with rehearsal-only `DirectoryInfo.Target` semantics

- Signature: the gateway repair creates `C:\APR\S`, then fails immediately
  with `New response alias verification failed in the repair process`; its
  rollback also fails with `Refusing to remove an alias whose target is not
  exact.` The failure occurs before the replacement bridge or share config is
  installed and leaves the share task stopped plus the newly created alias in
  place.
- Cause: the rehearsal created a local junction while live execution created
  a UNC directory symbolic link. The gate compared Windows PowerShell 5.1's
  `DirectoryInfo.Target` presentation as though both reparse-point types had
  identical target semantics. That does not prove the live UNC symbolic link's
  substitute and print names, and the same brittle check then blocked rollback.
- Preflight: exercise the exact live reparse-point type and UNC-target
  representation under Windows PowerShell 5.1. Record the reparse tag,
  substitute name, print name, attributes, and a bounded create/read/delete
  probe through the alias. A rehearsal junction is not coverage for a live UNC
  symbolic link. Rollback eligibility must use the independently pinned
  created path plus the actual reparse record, not only the verifier that
  triggered the failure.
- Recovery: do not rerun the failed package and do not manually delete the
  alias. First pin the interrupted state: exact predecessor bridge/config
  hashes, unchanged receiver hash, stopped share task, exact `C:\APR\S`
  reparse record, and fresh `C:\GWR` backup hashes. A separately rehearsed
  create-new recovery may then either recognize the exact intended alias and
  continue transactionally or remove only that verified reparse point, restart
  the predecessor task, and emit a persistent audit. Any unrecognized target,
  installed-file hash, or task state is a hard stop before mutation.

### A WinRM listener that appears when the service starts may be Group Policy state

- Signature: a live JEA rehearsal snapshots no `WSMan:\localhost\Listener`
  provider while WinRM is stopped, starts WinRM, then sees an HTTP listener.
  Cleanup treats the after/before delta as test-created and fails with
  `WS-Management does not allow changes to a listener created automatically by
  the group policy`.
- Cause: the stopped service hid the WSMan listener provider. Domain Group
  Policy materialized or exposed its managed listener when WinRM started. A
  listener-state delta across service startup is not creation provenance.
- Preflight: capture the WinRM service state and policy configuration, start
  the service only when the bounded rehearsal requires it, then query existing
  listeners before any explicit listener-creation call. Track a listener as
  owned by the rehearsal only when the exact `New-Item` call succeeded and its
  returned identity is recorded. Never infer ownership from a pre-start versus
  post-start inventory difference.
- Recovery: leave every policy-managed listener unchanged. Remove only the
  exact rehearsal endpoint, certificate, module version, and fixture root;
  restore the prior WinRM service start mode and running state. If an explicit
  test listener was created, remove only its recorded WSMan identity. A cleanup
  refusal against a policy listener must not be bypassed or converted into a
  broad listener delete.

### WinRM hostname rehearsal can select an unbound IPv6 address

- Signature: `Test-WSMan localhost` succeeds, but the same machine's DNS
  hostname returns `the requested HTTP URL was not available`. DNS publishes
  both A and AAAA records, while the Group Policy WinRM listener reports the
  IPv4 addresses in `ListeningOn` and its configured `IPv6Filter` is empty.
- Cause: the hostname client can select the AAAA address even though WinRM is
  not bound for IPv6. HTTP.sys then returns an HTTP response that is not the
  WS-Management endpoint. This is not proof that the registered JEA endpoint
  or its role capability is invalid.
- Preflight: record A and AAAA results, the exact listener `ListeningOn`
  addresses, `IPv4Filter`, `IPv6Filter`, and both localhost and hostname
  `Test-WSMan` results. For production, test the exact gateway hostname from
  the actual authorized remote client; a workstation-local hostname failure
  caused by an unbound AAAA record is not a remote gateway Kerberos test.
- Recovery: do not disable IPv6, edit hosts, broaden TrustedHosts, weaken JEA,
  or change Group Policy to manufacture a local pass. A bounded local endpoint
  functional rehearsal may use authenticated loopback Negotiate and must label
  that limitation explicitly. Production release still requires the actual
  client-to-gateway Kerberos session after the endpoint is installed; if that
  fails, keep the endpoint constrained and repair DNS/listener binding through
  the authorized infrastructure path.

### Windows PowerShell 5.1 JEA role discovery requires the role at the module root

- Signature: PSSC validation and endpoint registration succeed, but the first
  authenticated connection fails with `Could not find the role capability,
  'ArgosGatewayMaintenance'` when the manifest and `RoleCapabilities` folder
  are installed beneath `...\Modules\ArgosGatewayMaintenance\1.0.0`.
- Cause: the Windows PowerShell 5.1 JEA role-capability resolver used here does
  not discover the role through the versioned module subdirectory even though
  ordinary module discovery supports version folders. Static PSSC and module
  manifest validation do not exercise this lookup.
- Preflight: install the rehearsal module as
  `<PSModulePath>\ArgosGatewayMaintenance\ArgosGatewayMaintenance.psd1`, with
  the PSM1 beside it and the PSRC at
  `ArgosGatewayMaintenance\RoleCapabilities\ArgosGatewayMaintenance.psrc`.
  Register the exact PSSC and establish an authenticated session that invokes
  every intended visible function. A successful registration without a
  successful session is not a JEA gate.
- Recovery: before publication, replace the proposed versioned install layout
  with the unversioned JEA module-root layout and rerun the exact live endpoint
  rehearsal. If a failed rehearsal created only the pinned version directory,
  remove that exact test directory during rollback; never delete a shared
  PowerShell module root or another installed version by inference.

### JEA does not guarantee normal-shell module auto-loading

- Signature: an authenticated constrained session loads the custom role and
  exported function, but the first status calls fail with
  `Get-ScheduledTask is not recognized` and then `Get-FileHash is not
  recognized`, even though both commands work in the administrator shell.
- Cause: the JEA module depended on normal-shell auto-loading of the built-in
  `ScheduledTasks` module. The constrained session did not auto-import it.
  Parser checks, manifest checks, endpoint registration, and command discovery
  did not execute the dependency.
- Preflight: declare every non-core module used by an exported JEA function in
  the custom module manifest's `RequiredModules`, then establish the exact
  authenticated session and invoke all exported functions. Confirm that the
  dependency is available internally without exporting its general cmdlets
  through the role capability.
- Recovery: add only the pinned built-in dependency that cannot be replaced by
  a bounded internal primitive. Use a file stream plus .NET SHA-256 inside the
  module instead of exposing a general path-taking `Get-FileHash`. Preserve the
  PSRC's five-function visible surface with empty visible cmdlet and
  external-command lists. Do not solve an internal dependency failure by
  broadly exposing `Get-ScheduledTask`, a shell executable, or general
  management cmdlets to the remote caller.

### JEA virtual-account identity is not the connected caller identity

- Signature: the authenticated endpoint call succeeds, but a module helper
  that reads only `PSSenderInfo` at parent scope records
  `WinRM Virtual Users\WinRM VA_...` instead of `AMER\joshua.conn`.
- Cause: the exported module function executes through the JEA virtual
  administrator account, and the connected-client automatic variable is in
  the remoting session's global scope rather than the helper's immediate
  parent module scope. Falling back to `WindowsIdentity.GetCurrent()` records
  the execution identity, not the authenticated caller.
- Preflight: establish the exact authenticated session and require its bounded
  status and upload audit to record the authorized connected identity. Also
  record the virtual execution identity separately when useful. A successful
  call with a misattributed audit identity is not a complete endpoint gate.
- Recovery: resolve `PSSenderInfo.ConnectedUser` from the remoting global scope
  before considering the virtual identity fallback. Do not weaken the PSSC
  role definition or infer authentication from the virtual-account name.

### A JEA virtual administrator cannot prove a scheduled task's share ACL

- Signature: a signed gateway maintenance patch reaches its bounded verifier
  but an alias write probe beneath `C:\APR\S\requests` fails with `Access to
  the path ... is denied`; the share bridge itself runs as `AMER\fab.op` and
  remains healthy. The maintenance handler returns a signed `FAILED` response
  and restores the exact predecessor configuration.
- Cause: the constrained endpoint executes its verifier as a JEA virtual
  administrator. Local administrative authority does not reproduce the SMB
  credentials or share ACL of the separately scheduled interactive `fab.op`
  bridge task. A probe in the JEA identity is invalid evidence about task-
  context access.
- Preflight: keep local configuration, alias-target, hash, path-budget, task-
  definition, and rollback checks in the JEA verifier. Prove share request
  read/archive access only by a signed review-only request consumed by the
  actual scheduled bridge identity. Prove response write publication by the
  matching signed terminal response. Do not substitute a virtual-account
  write probe for either task-context proof.
- Recovery: require the signed failure response and independently verify that
  the predecessor config hash and both task states were restored. Withdraw the
  failed patch request; create a fresh signed revision that changes only the
  short request roots and restarts only the share bridge. Then run the complete
  signed STATUS round trip. If the task cannot consume it, recover through the
  constrained endpoint without another operator-local bootstrap.

### A package root beneath `work` must not skip the `work` directory

- Signature: the live rehearsal reaches signed-package construction but looks
  for the signer at `ArgosEdgeLab\PROJECT_PORTAL_REVIEW_ONLY\...` and reports
  it missing, while the authoritative signer is at
  `ArgosEdgeLab\work\PROJECT_PORTAL_REVIEW_ONLY\...`.
- Cause: the harness applied `Split-Path -Parent` twice to
  `...\work\GWR12`, skipping the shared `work` root before appending the
  portal path.
- Preflight: resolve the exact package root first, derive `work` with one
  parent operation, and require the signer, identity state, and response
  verifier to exist before endpoint registration or package signing. An exact
  final-ZIP extraction beneath an unrelated short root cannot derive the
  workspace portal-tool location from its package parent; that rehearsal must
  receive the already resolved portal-tool root as an explicit bounded path.
- Recovery: correct only the test's derived work root and rerun from a fresh
  fixture after its exact cleanup, or supply the explicit authoritative tool
  root for a portable final-ZIP extraction. Do not copy signing keys or create
  a second portal tool tree to satisfy a wrongly derived path.

### Compression assemblies are process-local in Windows PowerShell 5.1

- Signature: final-ZIP creation succeeds in one PowerShell process after
  loading `System.IO.Compression.FileSystem`, but extraction in a later process
  fails with `Unable to find type [IO.Compression.ZipFile]` before creating the
  planned extraction root.
- Cause: `Add-Type` state does not persist between Windows PowerShell 5.1
  processes. A prior successful archive operation is not evidence that the
  static compression type is loaded in a new gate process.
- Preflight: every standalone archive script or gate must load
  `System.IO.Compression.FileSystem` in that same process before its first
  `ZipFile` call, then require a fresh path-budgeted extraction root.
- Recovery: confirm that the failed call created no extraction root or entries,
  load the assembly in the current process, and repeat the exact extraction.
  Never treat a zero-file comparison after a type-load error as ZIP evidence.

### `$PSScriptRoot` may be empty in Windows PowerShell 5.1 parameter defaults

- Signature: a file-backed script declares a default such as
  `param([string]$OutputRoot=(Join-Path $PSScriptRoot 'build'))` and Windows
  PowerShell 5.1 fails before the script body with `Cannot bind argument to
  parameter 'Path' because it is an empty string.`
- Cause: in this execution path, `$PSScriptRoot` was not populated while the
  parameter default expression was evaluated. It became available only after
  parameter binding, so the otherwise file-backed invocation still failed.
- Preflight: default path parameters to an empty scalar. Immediately after the
  `param` block, resolve an empty value from `$PSScriptRoot`, then validate the
  resulting absolute path before the first write. Exercise the exact script
  with its default arguments under Windows PowerShell 5.1.
- Recovery: confirm the failure occurred before the planned output root was
  created, move the `$PSScriptRoot`-dependent default resolution into the
  script body, rerun the path gate, and repeat the exact file-backed command.

### Array splatting does not preserve named PowerShell parameters

- Signature: a test builds an array containing strings such as `-Rehearsal`,
  `-PortalRoot`, and their values, invokes `& $script @arguments`, and Windows
  PowerShell reports `A positional parameter cannot be found that accepts
  argument '-RehearsalShareTaskStatePath'`.
- Cause: array splatting supplies positional arguments. It does not reinterpret
  dash-prefixed array elements as named binder tokens in the same way as a
  literal command line.
- Preflight: use a hashtable for reusable named script arguments and splat that
  hashtable. Keep switches as Boolean values, arrays as arrays, and paths as
  scalar values. Exercise the exact harness under Windows PowerShell 5.1.
- Recovery: verify the target script never began its body, replace only the
  array splat with a named hashtable splat, and rerun the same bounded fixture.

### Windows PowerShell 5.1 `Import-PSSession` uses `-CommandName`, not `-Function`

- Signature: a constrained Kerberos session is established successfully, but
  proxy import stops before any remote function call with `A parameter cannot
  be found that matches parameter name 'Function'`.
- Cause: the Windows PowerShell 5.1 `Import-PSSession` parameter set filters
  imported commands with `-CommandName`; it does not provide the newer or
  assumed `-Function` parameter.
- Preflight: query the local command syntax or use the Windows PowerShell 5.1
  compatible `-CommandName` filter when importing the bounded JEA surface.
  Confirm the remote upload/invoke function was not called before retrying.
- Recovery: dispose the unused session, replace only `-Function` with
  `-CommandName`, preserve the exact signed package and request ID, and retry
  once. Do not create a second signed request for this local proxy-import
  failure.

### A bare backslash alternative can invalidate a PowerShell regex

- Signature: a non-mutating ZIP preflight reaches a traversal check and fails
  with `parsing "(^|\)\.\.(\|$)" - Not enough )'s.` before creating an
  extraction or result root.
- Cause: the regex used a bare backslash immediately before a closing group.
  The regex engine treated it as escaping the `)`, leaving the expression
  structurally incomplete. PowerShell single-quoted strings do not make that
  regex construct safe.
- Preflight: express path separators in traversal checks with an explicit
  character class such as `[\\/]`, and run the exact file-backed non-mutating
  preflight under Windows PowerShell 5.1 before extraction.
- Recovery: verify that all planned output roots remain absent, replace only
  the separator alternatives with character classes, rerun the wrapper gate,
  and repeat the same preflight against the same pinned ZIP hash.

### Path-budget maxima belong to candidate rows, not the top-level result

- Signature: a non-mutating build preflight receives
  `PASS_PATH_BUDGET` and then fails under strict mode with `The property
  'maximumEffectiveLength' cannot be found on this object.`
- Cause: `Confirm-ArgosPathBudget.ps1 -AsJson` reports each candidate's
  `effectiveLength` and `longestComponentLength` inside the `candidates`
  array; it does not expose aggregate maximum properties at the top level.
- Preflight: after requiring `state=PASS_PATH_BUDGET`, derive any reported
  maximum with `Measure-Object -Maximum` over the exact returned candidate
  fields. Keep the gate's configured warning, hard-stop, and component limits
  separate from observed maxima.
- Recovery: verify the preflight performed no mutations, correct only the
  summary-property access, rerun the wrapper gate, and repeat the same exact
  non-mutating preflight before building.

### Exact source transforms must normalize line endings before matching

- Signature: a pinned-source build reaches its first exact multi-line
  replacement and fails with `Expected exactly one ... replacement; found 0`,
  even though the displayed source lines visibly match the requested text.
- Cause: the parent source is LF-only while the Windows PowerShell transform
  literal contains CRLF. String replacement is byte-sensitive, so visually
  identical multi-line text does not match across newline encodings.
- Preflight: verify the pinned parent hash first, then normalize the in-memory
  source and every multi-line old/new transform literal to one explicit
  newline convention before counting matches. Continue to require exactly one
  match for each bounded transform.
- Recovery: confirm the failed build created only its planned fresh package
  staging root, remove that exact guarded staging root, normalize only the
  in-memory transform inputs, rerun the wrapper and non-mutating build
  preflights, and rebuild from the unchanged pinned parent.

### `Join-Path` cannot plan against an alias drive that does not yet exist

- Signature: a non-mutating short-alias preflight fails at its first
  `Join-Path R:\ ...` with `Cannot find drive. A drive with the name 'R' does
  not exist`, before it can report the planned alias or path budget.
- Cause: `Join-Path` resolves through the PowerShell drive provider. A planned
  `subst` drive is intentionally absent during a non-mutating preflight, so it
  cannot be used as a provider path yet.
- Preflight: construct not-yet-created alias paths with
  `[IO.Path]::Combine`; separately verify that the letter is unused. Create
  and exact-target-verify the `subst` mapping only after the preflight passes
  and immediately before the first write.
- Recovery: confirm no alias or output root was created, replace only the
  planning-time `Join-Path` calls with provider-independent path composition,
  rerun the wrapper gate, and repeat the same non-mutating preflight.
- Repeated observation: C1D3A publication preflight on 2026-08-19 repeated the
  same failure with planned `U:` before `New-PSDrive`.  No mapping, upload, or
  request was created.  `Confirm-ArgosPowerShellHarnessSafety.ps1` now rejects
  `Join-Path` use of a drive-letter variable when the same script declares that
  drive through `New-PSDrive`; provider-independent composition is mandatory.
  D2S3 then inherited the same defect from its legacy D2S2 publisher, but the
  static guard rejected it before the publisher or its preflight executed.
  The corrected publisher enumerates the exact UNC queue during preflight,
  composes the planned `U:` leaf without provider resolution, and defers mapping
  creation and the second zero-pending check to `-Apply`.
- Repeated observation: D3A2 response collection repeated the same defect in a
  newly handwritten collector because only the wrapper gate, not the
  harness-safety gate, was run before its first response-aware preflight. The
  signed response was found, but no response file was copied or extracted.
  Every new publisher, collector, and response-route script must pass both
  static gates before first execution.
- Repeated observation: the new D2S6 publisher-provider rehearsal initially
  used `Join-Path` for three planned `V:` leaves before `New-PSDrive`. The
  static harness guard rejected all three lines before preflight or rehearsal;
  no mapping, share directory, upload, gate, portal request, or JBOD state was
  created. The same provider-independent composition rule applies to test
  harnesses as well as publishers.

### Family-name replacement does not update embedded revision identifiers

- Signature: the exact extracted dispatcher rehearsal fails with
  `Unexpected <family> package manifest` even though the manifest schema and
  package family name are correct; the dispatcher still expects a predecessor
  revision such as `FM7V17R5P24` instead of the successor revision.
- Cause: a mechanical `FM7P24` to `FM7P25` family-token replacement does not
  match an embedded revision token whose spelling is `FM7V17R5P24`.
- Preflight: after mechanical family replacement, explicitly replace and
  assert every semantic schema, revision, parent revision, run ID, and required
  PASS state. The exact extracted dispatcher rehearsal must inspect the final
  package before publication.
- Recovery: confirm no request was published, remove only the exact fresh
  package, portal, extraction, and rehearsal roots, correct the reproducible
  builder plus the semantic revision assertion, and rebuild from the same
  pinned parent hashes.

### Rectangular crop validity must not outrun the physical composite domain

- Signature: a bounded native-tile composite run completes every requested
  field but emits millions of `unassigned` pixels concentrated in perimeter
  tiles. The count nearly equals the number of rectangular crop pixels outside
  the fitted wafer disk, with a smaller remainder along partial edge cells.
- Cause: the crop code marked every rectangle pixel valid while the canonical
  contribution grid created only cells whose center was at least eight pixels
  inside the fitted wafer. Pixels outside the physical wafer were incorrectly
  charged as missing inspection coverage, and physical pixels in disk-edge
  cells whose center fell outside the disk had no grid cell.
- Preflight: define the physical inspection domain explicitly, enumerate every
  planned control rectangle analytically, and require every in-domain pixel's
  route cell to exist before loading or scoring images. Include every grid cell
  that intersects the physical disk and choose its spatial representative
  inside the disk. Report outside-domain pixels separately from unassigned
  valid pixels, and render them with a distinct documented color.
- Recovery: preserve the failed output and signed response as withdrawn
  diagnostic evidence. Use a fresh revision and output root; mark only fitted
  physical-wafer pixels valid, retain every in-domain edge pixel, require zero
  direct-native/unassigned valid pixels, and never reinterpret outside-wafer
  crop corners as inspected Normal pixels.

### Exact source-transform insertion anchors must be structurally unique

- Signature: a fresh package build stops before compilation with `Expected
  exactly one <label> replacement; found N`, where `N` is greater than one.
- Cause: the proposed insertion anchor is a common syntax prefix, such as a
  generic `Console.WriteLine` expression, that occurs in several methods even
  though the intended insertion belongs to only one method.
- Preflight: count every exact transform match before mutation and require one.
  Anchor insertions to a revision-specific state token, method signature, or
  an adjacent multi-line block that uniquely identifies the intended method;
  never weaken the exactly-one assertion.
- Recovery: verify that only the exact planned fresh staging root was created,
  remove that guarded staging root, replace the ambiguous anchor with a unique
  structural anchor, rerun the parser, wrapper, path, and non-mutating build
  preflights, and rebuild from the unchanged pinned parent.

### Parenthesize archive-entry normalization and stop on validation errors

- Signature: a PowerShell archive-path audit prints a regex parse error such
  as `Not enough )'s`, but later statements still run and the host command can
  exit zero.
- Cause: an unparenthesized `-replace` expression was combined directly with
  `-match`, so operator precedence fed malformed text to the regex engine; the
  ad-hoc shell retained the default non-terminating error policy.
- Preflight: set `$ErrorActionPreference='Stop'` before archive validation,
  assign the normalized entry name to a scalar first, and then separately test
  rooted paths, parent traversal, destination-prefix containment, component
  lengths, and the complete planned extraction path budget.
- Recovery: do not trust the earlier path check. Reopen the unchanged pinned
  signed archive read-only, require the exact expected entry set and count,
  re-run every normalized path and destination-prefix assertion with stopping
  errors, reject reparse points, and reverify every extracted length and hash.
  Preserve or remove the extraction only according to that corrected audit.

### Do not aggregate ordered-dictionary keys with `Measure-Object -Property`

- Signature: a manifest builder stops with `The property "<name>" cannot be
  found in the input for any objects` while aggregating a list of
  `[ordered]` rows whose keys appear to contain that name.
- Cause: `OrderedDictionary` keys are not a stable PowerShell object-property
  contract for `Measure-Object -Property`, especially when some rows carry a
  null optional value.
- Preflight: either emit `[pscustomobject]` rows with a fixed schema or compute
  bounded totals with an explicit checked loop that tests key presence and
  converts every included value to the required integer type.
- Recovery: confirm the failure occurred before the planned output root or
  request was created, replace only the aggregation method, repeat the exact
  source-row count/uniqueness/hash checks and path preflight, then write the
  fresh definition.

### Do not assume a generic `System.Math.Add` accumulator exists

- Signature: a PowerShell manifest builder stops with `System.Math does not
  contain a method named 'Add'` before writing its output.
- Cause: `System.Math` provides numeric functions but no generic integer
  addition method.
- Preflight: convert each bounded value to `Int64`, reject negative values,
  explicitly test `current -le Int64.MaxValue - value`, and then use ordinary
  PowerShell addition with an `Int64` cast.
- Recovery: confirm the planned fresh output root is absent, retain the exact
  frozen input rows, replace only the accumulator expression, and repeat the
  full row-count, uniqueness, hash, byte-bound, and path preflight.

### Use the path guard's declared suffix-reserve parameter name

- Signature: the path-planning preflight stops with `A parameter cannot be
  found that matches parameter name 'SuffixReserve'` before any output root is
  created.
- Cause: an ad-hoc invocation abbreviated the contract concept into a switch
  name that the installed guard does not declare. The exact parameter is
  `ReservedSuffixCharacters`.
- Preflight: inspect the checked-in guard parameter block or use the documented
  exact invocation before the first write. Pass every planned source and
  longest output path with `-ReservedSuffixCharacters 32` unless the governed
  workflow requires a larger reserve.
- Recovery: confirm the planned fresh output root is absent, rerun the same
  candidate set with the declared parameter name, and require the JSON path
  gate to pass before creating any directory or launching .NET work.

### Do not cast `JavaScriptSerializer` JSON arrays directly to `object[]`

- Signature: a .NET Framework manifest builder stops with `Unable to cast
  object of type 'System.Collections.ArrayList' to type 'System.Object[]'`
  while reading a JSON array.
- Cause: `JavaScriptSerializer.Deserialize<Dictionary<string,object>>` may
  materialize nested arrays as `ArrayList`; a direct `object[]` cast is not a
  stable deserialization contract.
- Preflight: normalize every JSON sequence through non-string `IEnumerable`
  enumeration into a new bounded `object[]`, then enforce its expected count
  and element schema. Apply the same rule to numeric coordinate arrays.
- Recovery: preserve the partial output root as diagnostic evidence, confirm
  the builder failed before reviewer files were written, correct the shared
  array-normalization helper, assign a fresh review ID/output root, repeat the
  path gate, and rebuild the projection and reviewer from the unchanged signed
  sources.

### Confirmation-only reviewers must qualify tiles in every queue mode

- Signature: the rendered native reviewer contains all expected tiles, each
  with a confirmation count, but the work bar reports only `eligible tile
  1/1` and next/previous navigation cannot traverse the complete review set.
- Cause: the inherited `all` queue predicate considered only
  `ownedComponents`; a class-neutral comparison revision intentionally has
  zero classified components while still carrying one confirmation field per
  tile.
- Preflight: exercise both `awaiting` and `all` queue modes in the real page.
  Require the eligible-tile denominator to equal the signed manifest tile
  count and require edge/interior tile selection to load the exact current
  mask, clean BF, and clean DF dimensions.
- Recovery: preserve the rendered-audit failure root as diagnostic evidence,
  use a fresh review ID/root, make `awaiting` the default for confirmation-only
  work, and let the `all` predicate include either owned components or owned
  confirmations. Do not invent a classified component merely to enter the
  queue.

### Source transforms must match template construction, not rendered prose

- Signature: a fail-closed reviewer builder reports `Expected 1 exact
  replacement(s), found 0` for prose that is visibly present in the browser.
- Cause: the JavaScript source constructs that browser sentence from adjacent
  template/string fragments, so the rendered sentence is not one contiguous
  source substring.
- Preflight: inspect the exact normalized source around every planned
  explanatory-text transform. Match stable literal fragments or the complete
  multi-line template block, and assert the exact expected occurrence count
  before any reviewer file is written.
- Recovery: preserve the display-only partial root, use a fresh review ID/root,
  replace the transform anchor with the actual source construction, and rerun
  the static and rendered-page gates. Never weaken an exactly-one assertion to
  a silent best-effort replacement.

### Revision-ledger withdrawal rows must contain each exact artifact path

- Signature: the project-continuity guard reports `Withdrawn artifact is not
  recorded in the revision ledger` even though a combined ledger row names the
  corresponding review IDs.
- Cause: the continuity contract verifies the literal path recorded in
  `withdrawnArtifacts`; a conceptual or abbreviated revision name is not an
  exact artifact-path record.
- Preflight: for every newly added `withdrawnArtifacts` entry, require the exact
  normalized path string to appear in a `WITHDRAWN` ledger row before running
  the continuity guard.
- Recovery: do not remove the withdrawal from continuity state. Amend the
  append-only ledger description with every exact withdrawn path, rerun the
  continuity guard, and only then present the successor.

### Protected-edge accounting expands to the complete connected component

- Signature: a front-metal residual diagnostic stops with `T16
  protected-edge count changed` even though the source residual, route rasters,
  dimensions, and predecessor hashes are unchanged.
- Cause: the diagnostic counted only residual pixels whose own physical-boundary
  distance was at most the protected band width. The governing snow/edge
  contract instead protects every pixel in an eight-connected residual
  component when the minimum boundary distance of that complete component is
  within the band.
- Preflight: reconstruct eight-connected source-residual components, compute
  each component's minimum physical-boundary distance, expand the protection
  flag to the complete component, and require the locked per-field protected
  count before creating an output root.
- Recovery: verify that the failed run created no output root, correct only the
  diagnostic edge-accounting implementation, compile a fresh executable, and
  repeat the exact non-mutating preflight. Do not narrow edge protection,
  change the source masks, or reinterpret the mismatch as detector evidence.

### `powershell.exe -File` comma text is not an array-valued path argument

- Signature: a path-budget preflight receives two intended candidate paths as
  one literal value containing a comma, reports a fabricated overlong path, and
  hard-stops even though each path is individually within budget.
- Cause: text following `-File` crosses a process command-line boundary.
  Comma-separated text is not reconstructed as a PowerShell array; it remains
  one scalar string. This differs from a native in-session PowerShell array.
- Preflight: never serialize an array-valued `.ps1` parameter as comma-joined
  command-line text. Use one scalar candidate per exact process invocation, or
  place the bounded array in a UTF-8 JSON invocation manifest consumed by the
  script. Assert that the received candidate count and each exact normalized
  value match the planned input before evaluating them.
- Recovery: confirm the failed preflight performed no writes, discard its
  fabricated combined-path result, and rerun one exact candidate per process
  or through the approved file-backed manifest. Do not weaken path thresholds
  or create a short alias merely to accommodate the accidental comma string.
- Repeated observation: on 2026-08-19, D2S4 planning passed an in-session
  PowerShell array variable to `powershell.exe -File` as the value of
  `-CandidatePath`. Native argument expansion emitted multiple positional
  scalars; the first bound to `CandidatePath` and the second was then
  misbound to integer `WarningEffectiveLength`. The utility rejected before
  reading content or writing any D2S4 artifact. Future external path-budget
  calls must loop one candidate per exact Windows PowerShell 5.1 process (or
  use a separately approved file-backed manifest) even when the caller starts
  with a genuine in-session array.

### A single fully gated short edge outranks broad fiducial topology support

- Signature: a bounded native fiducial search moves to the edge of its allowed
  center/angle window and reports one perfect short line while most required
  lines have zero direct support, even though the nominated development site
  was operator-locked from exact pixels.
- Cause: the pose-search comparator ranked the count of fully gated line fits
  before total accepted samples and distributed line support. With five- to
  nine-sample lines and a 95% support gate, an accidental 5/5 boundary could
  outrank the correct pose when several real lines each had one missing sample.
- Preflight: exercise a synthetic or exact-development comparison in which one
  candidate has one perfect short line and another has direct support spread
  across the complete declared topology. Require distributed topology support
  and total accepted native samples to win before individual pass count. Keep
  the final per-line quality gates separate from pose-candidate ordering.
- Recovery: preserve the affected run as `DIAGNOSTIC_ONLY`, do not freeze its
  model or consume the holdout, revise the search comparator in a new tool/run
  revision, repeat no-write preflight, and rerun only the development site.
  Do not lower final quality gates merely to force the correct nomination to
  win, and do not inspect or tune against the untouched holdout.

### Rotated integer-length guidance loses its final native sample

- Signature: a line declared as five or nine one-pixel-spaced samples reports
  only four or eight expected samples after a rigid rotation, even though
  rotation must preserve its exact geometric length.
- Cause: floating-point sine/cosine evaluation can produce a length infinitesimally
  below the integer, and `Floor(length / spacing) + 1` then drops the final
  sample.
- Preflight: exercise every declared horizontal and vertical guidance length
  at the exact development angle and at both search-angle bounds. Require the
  expected sample count to equal the declared endpoint-inclusive native count.
  Add only a bounded numerical epsilon before `Floor`; never round a genuinely
  nonintegral model length into a different sampling contract.
- Recovery: preserve the affected run as diagnostic-only, consume no holdout,
  correct the sampler in a new tool/run revision, rerun no-write preflight,
  and repeat development from the unchanged native sources and line inventory.

### A crop-center XML bin is assigned to an unrelated operator-selected topology

- Signature: a same-wafer fiducial holdout lands on an ordinary die feature
  even though the source crop was created around a valid product-map bin and
  the transported pixel offset is numerically exact.
- Cause: the crop manifest identifies the XML bin used to center a broad native
  crop; it does not bind every structure visible inside that crop to that bin.
  Treating an operator-selected topology elsewhere in the crop as a fixed
  within-bin offset, then transporting that unexplained offset to another
  occurrence of the bin, creates a precise but semantically false location.
- Preflight: before naming any operator-selected topology with a map X/Y or
  transporting it between sites, require an explicit topology-to-map binding
  from authoritative product data or independent native evidence that the
  complete nonrepeating topology recurs at both locations. Record the crop
  anchor, selected topology coordinate, their displacement, nearest XML die
  coordinate/bin, and whether the map establishes only a crop window. A map
  bin or repeating displacement may nominate a search window but cannot prove
  topology or pose.
- Recovery: preserve the wrong-location output, input, and audit; label them
  `WITHDRAWN_INVALID_LOCATION`; withdraw every frozen/holdout conclusion that
  depended on the transported offset; retain only exact-pixel development
  measurements as diagnostic evidence; and restart location enumeration from
  the operator-designated topology. Do not tune a detector against the random
  feature or call it a consumed holdout.

### A rendered corner-ignore layer is not an enforced scoring exclusion

- Signature: a fiducial guidance image shows yellow ignored inner/outer
  corners, while detected line support still approaches or responds to those
  corners in the scored overlay.
- Cause: the line inventory shortens endpoints, but the native scorer does not
  load the displayed ignore mask or reject samples whose complete gradient
  profile footprint intersects it. Endpoint trim alone does not establish zero
  corner influence, especially with rounded/blurred corners and a profile that
  extends several pixels normal to the line.
- Preflight: require the exact corner-vertex list and ignore mask/hash in the
  scoring manifest. For every candidate sample, test the complete interpolation
  and gradient-profile footprint against that mask and reject any overlap.
  Audit rejected sample counts per corner and prove that changing ignored
  pixels cannot change pose, support, residual, or line selection.
- Recovery: preserve the affected scorer and outputs as diagnostic-only or
  withdrawn, revoke any zero-corner-weight claim, and create a new tool/model
  revision that consumes the locked exclusion mask. Refit development before
  reserving a fresh untouched holdout; never patch the old overlay or reuse its
  frozen model.

### Framework `csc.exe` cannot create its resource temporary file when the output parent is absent

- Signature: legacy Framework `csc.exe` exits with `CS1567: Error generating
  Win32 resource: The system cannot find the path specified` and warns that it
  cannot delete a `CSC<token>.TMP` under the requested output directory. No
  executable is created.
- Cause: the absolute `/out:` path is valid and path-budgeted, but its parent
  directory does not yet exist. The compiler tries to create its default
  Win32-resource temporary file beside the requested executable before it can
  emit the executable.
- Preflight: after path-budget approval and before invoking `csc.exe`, resolve
  the exact output parent, require that it exists as a directory, and require
  that the target executable and any deterministic temporary target are
  absent. If a new parent is intended, create that exact bounded directory
  before launch and repeat the read-only existence assertions.
- Recovery: verify that neither the executable nor the named compiler
  temporary file exists, create only the exact path-gated output parent, and
  retry the unchanged absolute-source/absolute-output compiler invocation
  once. Do not change source logic or inspection parameters to compensate for
  the orchestration failure.

### Per-line floating fits make a reported rigid fiducial pose non-identifiable

- Signature: a fiducial overlay labels one color as a fitted rigid solution,
  but its relative order against the prior-pose color reverses around the
  structure; the direct edge runs remain offset from that reported solution,
  and many per-line intercepts sit exactly on the outer profile limit.
- Cause: every candidate X/Y/theta pose independently refits an intercept and
  slope for every line before the candidate is ranked. Those local degrees of
  freedom absorb the pose change, so the selected candidate is not the joint
  rigid least-squares solution to the accepted native edge samples. Accepting
  a first crossing at the outermost profile sample also fails to prove clean
  outside margin and can turn profile clipping into apparently perfect line
  support.
- Preflight: freeze line geometry before pose solving. Require at least one
  unused gradient sample beyond every accepted outside-to-interior crossing;
  reject outer-limit hits. Build one explicit normal-equation system from all
  accepted samples with only global X, Y, and theta unknowns, and report its
  rank, condition, residual, and per-line signed residuals. Perturb the
  starting pose, reorder lines, and perform line/sample leave-outs; the same
  physical solution must return within fixed tolerances. A renderer may call
  a line `rigid` only when it is drawn from that verified joint solution.
- Recovery: withdraw the mislabeled review and every pose conclusion derived
  from it while preserving the direct native edge evidence as diagnostic.
  Widen and guard the native profile, calibrate fixed channel-local line
  coordinates from development evidence as required, solve the joint rigid
  system without per-candidate line refits, and validate the frozen geometry
  on separate complete fiducial instances before presenting another overlay.

### Template-correlation refinement can leave the coarse scan's safe image domain

- Signature: a bounded native template search completes its coarse grid, then
  throws `IndexOutOfRangeException` in the correlation sampler during local
  subpixel/pixel refinement of a border peak. The fresh output root exists but
  contains no terminal audit.
- Cause: coarse candidate centers honor the template-radius margin, but the
  later `+/- coarseStep` refinement is applied without rechecking the full
  template footprint. A safe coarse border center can therefore move outside
  the image by the refinement radius.
- Preflight: before every refined correlation evaluation, require
  `centerX-templateRadius >= 0`, `centerY-templateRadius >= 0`,
  `centerX+templateRadius < width`, and
  `centerY+templateRadius < height`. Exercise all four safe-domain corners and
  all four one-pixel-outside cases before scanning native data.
- Recovery: preserve the empty/no-audit output root as a failed diagnostic,
  add only the explicit footprint bounds check, compile a new executable, and
  rerun the unchanged detector/calibration contract into a fresh output root.

### Truncated text capture is not a valid source-file copy path

- Signature: a newly sealed source copy contains a literal UI/tool-output
  truncation marker such as `tokens truncated`, and compilation fails near the
  marker even though the intact on-disk parent compiled previously.
- Cause: source text was reconstructed from bounded or rendered command output
  rather than copied from the complete local file. The output transport
  abbreviated a long line and the abbreviation became source text.
- Preflight: create source copies only from complete on-disk files through a
  file-preserving operation or a reviewed exact patch. Before hashing or
  compiling, search the complete destination text for `tokens truncated`, the
  Unicode ellipsis character, and replacement-character mojibake; reject any
  match. Compare source structure or an intended byte hash against the local
  parent when the copy is meant to be exact.
- Recovery: do not execute the malformed artifact. Preserve it as a failed
  build input, make a new byte-preserving copy from the intact on-disk parent,
  repeat the truncation scan, then bind a new source hash and compile into a
  fresh bounded executable path. No detector result from the malformed source
  may be used.

### A pose-perturbation replay must preserve both the start and reference conventions

- Signature: a frozen fiducial model still passes all 12 BF and all 12 DF
  lines, polarity, cross-validation, width, support, and rigid-residual gates,
  but a replay reports larger perturbation return-angle errors than the parent
  qualification.
- Cause: the replay adds the test deltas separately to the already-converged
  BF and DF channel-local fixed points. The parent test added the same deltas
  to one common nominal development pose, then measured each returned solution
  against its own channel-local fixed point. These are different experiments.
- Preflight: bind both arrays in the audit contract: the exact common nominal
  start pose and every delta, plus the exact BF and DF return-reference poses.
  Reject a replay that substitutes a return reference for the perturbation
  origin. Compare the constructed absolute starts before scoring native data.
- Recovery: preserve the mismatched replay as a failed diagnostic, do not
  change detector thresholds, and create a fresh source/input/output revision
  that restores the parent start convention while retaining the frozen model,
  polarities, geometries, gates, and return tolerances unchanged.

### Fiducial leave-out stability must be gated in geometry space

- Signature: every remaining BF/DF line passes after a one-line leave-out and
  the maximum movement of the modeled native line geometry is well below one
  sampling step, but the run fails because a raw theta difference barely
  exceeds a borrowed angular threshold.
- Cause: translation and rotation parameters are correlated, and an angular
  delta has no model-independent pixel meaning. The same theta difference can
  move a small fiducial by a fraction of a pixel or move a large model much
  farther. A perturbation-return angle tolerance is not automatically a valid
  leave-out stability gate.
- Preflight: define leave-out boundedness before execution as the maximum
  native-pixel displacement of the complete frozen geometric model between the
  full and leave-out poses. Bind the evaluated line samples or endpoints and a
  fixed pixel limit derived from the sampling contract. Report X, Y, and theta
  differences as diagnostics only.
- Recovery: preserve the angle-only run as a failed diagnostic. Without
  changing frozen lines, polarity, response gates, or native evidence, create
  a fresh verifier revision that applies the predeclared geometry-space bound,
  binds the failed predecessor, and reruns every conformance case.

### A short supervising timeout may race a successfully committed local audit

- Signature: the command supervisor reports exit 124 at its timeout boundary,
  while the child has already printed a terminal result and committed its
  hashed audit; an immediate process inventory shows no surviving child.
- Cause: the supervision deadline can expire during process teardown or output
  collection just after the child finishes its own work.
- Preflight: size the supervisor timeout above the measured native run time and
  treat the process exit state, audit contract, audit hash, and absence of a
  surviving child as separate evidence. Never infer failure or success from
  captured stdout alone.
- Recovery: do not rerun into the existing output root. Confirm the exact child
  is absent, parse and validate the committed audit, verify its hash and
  terminal state, and retain the supervisor timeout as execution metadata. If
  any of those checks fail, preserve the root as diagnostic and use a fresh
  revision/output root.
## Maintenance entrypoint required-state must match normal execution output

- Failure signature: a signed `MAINTENANCE_PATCH` response is terminal
  `FAILED` with `Maintenance verifier did not emit required state`, while the
  captured maintenance stdout proves that the entrypoint completed its real
  bounded job and emitted a different terminal state plus a durable audit.
- Cause: `rehearsal.requiredState` in the maintenance definition is checked
  against the entrypoint's normal no-argument stdout. It is not a declaration
  of the separate `-Rehearsal` result. Pinning a rehearsal-only state there
  makes a completed normal run fail the endpoint's post-entrypoint verifier
  and triggers rollback of the declared installed changes.
- Preflight: before signing, execute the exact entrypoint in both modes. The
  packaged rehearsal must pass independently. The maintenance definition's
  `rehearsal.requiredState` must be a state guaranteed to appear in normal
  no-argument terminal stdout for every allowed success/hold outcome, or the
  entrypoint must emit one stable normal-completion marker after validating
  its terminal audit. Assert the two strings separately.
- Recovery: trust only the signed terminal response for endpoint disposition.
  Preserve captured stdout and the exact durable audit hash as direct endpoint
  evidence, but retrieve and verify the audit before interpreting per-target
  outcomes. A later request is allowed only after the signed terminal response
  exists and the next request has its own complete route and queue-safety gate.
- First observed: PFC004LT1A request
  `REQ_20260818T210021153Z_402EC2BDA20F`. Normal stdout recorded audit
  `D:\A19\PFC004LT1A_20260818T203500Z\AUDIT.json`, SHA-256
  `A1018988FF413C1C02AD0D90AC79C2657EFDAED689A99D700C6AE8191A70728E`,
  with 6/7 qualified poses and 2/7 frozen-model passes; the endpoint response
  remained terminal `FAILED` because the definition required
  `PASS_PFC004LT1A_PORTAL_INSTALL_REHEARSAL`.

## `-LiteralPath` never expands a wildcard source

- Failure signature: `Copy-Item -LiteralPath 'root\\*.cs'` returns without
  copying the expected children, and later hash verification reports every
  destination file missing.
- Cause: `-LiteralPath` treats `*` as an ordinary filename character. It does
  not enumerate wildcard matches.
- Preflight: when seeding a bounded source tree, enumerate the exact source
  files first and assert the received count and names. Then call `Copy-Item
  -LiteralPath` once per resolved file. Use `-Path` only when wildcard
  expansion is explicitly intended and the resolved set is immediately
  verified.
- Recovery: preserve the fresh empty destination, enumerate the exact source
  files, copy each resolved file individually, and hash-compare every source
  and destination before editing or building.
- First observed: the local GWQ4 transport-source rehearsal seed on
  2026-08-19; no production or gateway file was touched.

## Property-name comparison requires a `Where-Object` script block

- Failure signature: `Where-Object Source -ne Copy` selects every row even
  when the `Source` and `Copy` properties are equal, causing a false hash-gate
  failure. A following `throw'Message'` may then surface as an unrecognized
  command because `throw` was not separated from its string expression.
- Cause: the simplified `Where-Object` syntax compares `Source` with the
  literal string `Copy`; it does not dereference the row's `Copy` property.
  PowerShell also requires whitespace between the `throw` keyword and a
  quoted expression.
- Preflight: use `Where-Object { $_.Source -ne $_.Copy }`, assert the row
  count explicitly, and parse changed scripts with the wrapper/static gate
  before using their result as release evidence.
- Recovery: retain the already copied files, rerun the comparison with the
  explicit script block, and continue only when every exact source/destination
  hash pair matches.
- First observed: the local GWQ4 transport-source seed verification on
  2026-08-19; all six copied hashes actually matched and no remote state was
  touched.

## Conditional assignment can unwrap a one-item collection under StrictMode

- Failure signature: a bounded diagnostic succeeds while a directory is empty
  or has multiple files, but terminates with `The property 'Count' cannot be
  found on this object` when exactly one file is returned.
- Cause: PowerShell enumerates output from an `if` expression before assigning
  it. Writing `$files = if ($exists) { @(Get-ChildItem ...) } else { @() }`
  does not guarantee that `$files` remains an array; a single emitted object is
  assigned as that object, and StrictMode correctly rejects `$files.Count`.
- Preflight: place the array subexpression around the complete conditional:
  `$files = @(if ($exists) { Get-ChildItem ... })`. Rehearse the zero-, one-,
  and two-item cases under `Set-StrictMode -Version Latest` before signing a
  diagnostic or queue worker that depends on cardinality.
- Recovery: preserve the signed terminal failure, fix only the collection
  boundary, create a fresh signed request, and confirm the exact failed request
  cannot remain at the head of the affected queue.
- First observed: gateway response-route diagnostic GWQ5 request
  `REQ_20260819T003358422Z_24974D0D6C56` on 2026-08-19. The constrained
  maintenance endpoint returned a signed terminal failure; no portal task or
  production artifact was changed by the diagnostic.

## Rehearsal preflight must branch before creating its fixture root

- Failure signature: `-Preflight -Rehearsal` reports PASS but creates the
  declared fresh rehearsal tree, so the immediately following exact rehearsal
  fails with `Fresh ... rehearsal root required`.
- Cause: the rehearsal branch created and populated its fixture before the
  shared preflight return was reached. A preflight label does not make earlier
  statements non-mutating.
- Preflight: parse and validate the file-backed rehearsal invocation, assert
  the declared fixture is absent, verify package/source hashes, and return the
  preflight result before the first `New-Item`, copy, config write, or task
  operation. Assert the fixture remains absent after the preflight process.
- Recovery: verify the exact created root is the bounded disposable rehearsal
  target, remove only that root, update the packaged script and manifest hash,
  and repeat preflight followed by the fresh exact rehearsal.
- First observed: local JBQ1 rehearsal root `C:\J1T1` on 2026-08-19. No JBOD,
  gateway, Argos, share, portal, or inspection state was touched.

### Completed-lot button is enabled but the viewer silently exits

- Signature: the JBOD tray's `Open completed lot review` control is enabled and
  clickable, but no review window remains open and no error is shown.
- Cause: enablement proves only that `dashboard_manifest.json` and
  `ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe` exist. The tray launches the
  viewer with `Start-Process` without capturing its exit code or standard error.
  The viewer validates the entire manifest before creating a window, catches a
  startup exception only at the process boundary, writes it to console standard
  error, and exits `1`. A GUI launch discards that diagnostic, making a catalog,
  referenced-artifact, or schema failure appear to be a dead button.
- Preflight: before releasing an inventory, dashboard-manifest, or completed-lot
  change, run the exact installed viewer against the exact current installed
  manifest with `--catalog-check`, capture exit code and standard error to a
  persistent create-new log, and require exit `0`. Also exercise the actual tray
  launch path and require the viewer process to remain alive with its main window
  visible. File existence and button enablement are insufficient.
- Recovery: preserve the exact current manifest and referenced artifacts. Capture
  the exact installed viewer's `--catalog-check` error before modifying either.
  Repair only the proven producer/viewer contract or missing referenced artifact,
  rerun catalog and real-launch gates, and make the tray surface any future
  nonzero viewer exit with its persistent log path. Do not delete or regenerate
  completed inspection evidence merely to make the window open.

### Operator-package transcript is lost when an extracted Downloads tree is cleaned

- Signature: a local JBOD recovery reports a persistent transcript beneath the
  extracted package, later the operator clears Downloads, and the original log
  can no longer be retrieved even though the live apply already completed.
- Cause: the launcher derived its `logs` root from `$PSScriptRoot`. An extracted
  package under the operator's Downloads directory therefore stored its only
  transcript in an intentionally disposable location. Live installed files and
  archives under `C:\ProgramData` survive, but the operator-action evidence does
  not.
- Preflight: an operator-local launcher must write its create-new transcript to a
  pinned durable short root under the installed product's `C:\ProgramData` state,
  and may optionally mirror it beside the launcher. The preflight must print and
  verify that durable path before apply. A Downloads-relative log is not durable.
- Recovery: do not rerun a successful package merely to recreate a transcript.
  Preserve any exact operator-pasted transcript in the project record, then verify
  installed hashes, archives, task states, listener state, and downstream signed
  queue movement independently. Treat the pasted transcript as recovered evidence,
  not as proof of later end-to-end delivery.

### Protected scheduled tasks must be snapshotted, not forced to a stale principal

- Signature: a non-mutating recovery preflight stops with `Task principal
  changed: <protected task>` before its bounded portal repair begins, even
  though the named task is deliberately outside the package's mutation
  allowlist.
- Cause: one task-state helper was reused for both authorized portal targets
  and protected inspection tasks. It correctly required the portal targets to
  retain their pinned `SYSTEM` principal, but incorrectly imposed that same
  build-time principal assumption on unrelated protected tasks. A legitimate
  pre-existing principal change therefore became a false safety failure.
- Preflight: keep authorization and preservation separate. Require the exact
  pinned principal only for tasks the package may start or stop. For every
  protected task, dynamically capture its actual principal and exported task
  definition hash before apply. Wrap every task mutation in a literal-name
  allowlist, then require the protected principal and definition hash to remain
  identical afterward. Record runtime state as evidence, but do not treat a
  natural `Ready`/`Running` transition as proof that the recovery changed it.
  Rehearse a protected task under both `SYSTEM` and an ordinary user principal.
- Recovery: preserve the failed preflight as proof that no mutation occurred,
  withdraw that package, and issue a fresh distinct package revision. Never
  bypass the check by changing the protected task or by adding it to the
  mutation allowlist.
- First observed: JBQ2 on 2026-08-19 for
  `ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2`; the package stopped during its
  non-mutating preflight, before any portal or inspection task operation.

### A compact response must not be followed by a create-new collision on the poisoned ledger

- Signature: starting the queue-safe endpoint produces and returns one signed
  compact `FAILED` response for an older request with detail `Portal request
  ledger exists without its ready response`, but the request remains at the
  queue head and the intended later request never receives a terminal response.
  The supervising recovery eventually exits `1` after its bounded wait.
- Cause: the endpoint correctly caught the pre-existing ledger/no-ready-response
  condition and committed a signed compact failure, then unconditionally called
  the create-new ledger writer at the already existing ledger path. That second
  collision escaped the per-request boundary before the request could be
  archived. In addition, restart replay searched only the response-sender
  pending outbox; a promptly sent response was no longer visible there, so the
  same poisoned request could be failed again instead of replay-archived.
- Preflight: rehearse an exact request whose ledger exists both with no response
  and with its response already in the sender `sent` root. Require the endpoint
  to preserve the prior ledger in a short path-gated quarantine, commit or
  recover one terminal ledger, archive the exact request, and continue to a
  second queued control request in the same worker lifetime. The endpoint must
  search both configured pending and sent response roots, validate the signed
  response identity before replay, and never overwrite evidence silently.
- Recovery: preserve the already returned signed compact response. Patch the
  endpoint through a separately rehearsed manual/admin installer that pins the
  exact installed predecessor and config. On restart, replay-archive the
  poisoned head using its signed sent response, then drain subsequent requests.
  Do not keep issuing single-request restart packages or publish another portal
  request behind the poisoned head.
- First observed: JBQ2A on 2026-08-19. Signed response
  `R_D997CDF11F4B_20260819131136555_07d20bb8` terminally failed older request
  `REQ_20260818T231924045Z_B5BF14D98D13`; exact PFC004 request
  `REQ_20260818T232640487Z_591E16C31AD5` remained without a signed response.

### Windows PowerShell 5.1 `File.Replace` requires a legal backup path in this installer contract

- Signature: the exact Windows PowerShell 5.1 installer rehearsal reaches the
  worker replacement and fails with `Exception calling "Replace" with "3"
  argument(s): "The path is not of a legal form."` No production tree is
  touched.
- Cause: the installer called `[IO.File]::Replace(source, destination, $null)`.
  Although a null backup may be accepted by some runtime descriptions, the
  Windows PowerShell 5.1/.NET runtime used by the Argos rehearsal rejected it.
- Preflight: exercise the exact packaged installer under Windows PowerShell 5.1
  against the exact predecessor. Give `File.Replace` a fresh, path-gated legal
  backup filename and verify that the emitted backup hash is the approved
  predecessor hash. Exercise the same contract during injected-failure
  rollback and retain the displaced target as recoverable evidence.
- Recovery: do not fall back to delete-and-move or an unverified overwrite.
  Use the already planned create-new predecessor archive as the atomic replace
  backup path, verify installed and backup hashes, and rerun predecessor,
  idempotence, unapproved-refusal, and rollback cases from the beginning.
- First observed: JBQ2B source-package rehearsal on 2026-08-19 at the bounded
  `C:\B2IT` fixture. Production portal files and scheduled tasks were not
  accessed.

### A PowerShell 5.1 rehearsal harness must capture expected child-process refusal without promoting stderr

- Signature: an installer matrix reaches its intentional unapproved-predecessor
  case and the child exits nonzero with the expected refusal text, but the
  parent harness aborts with `NativeCommandError` instead of asserting the
  captured exit code and message.
- Cause: the parent harness used `$ErrorActionPreference = 'Stop'` while
  invoking `powershell.exe`. Windows PowerShell 5.1 wrapped the child's stderr
  as an error record, so the expected fail-closed case terminated the harness
  before its refusal assertions ran.
- Preflight: around a child-process call whose nonzero exit is part of the test
  matrix, temporarily use `Continue`, capture the merged output and
  `$LASTEXITCODE`, restore the prior preference in `finally`, and make the test
  assert the exact refusal text, nonzero code, and unchanged installed hash.
- Recovery: patch only the rehearsal harness; do not soften the installer or
  redirect away the refusal. Rerun the entire predecessor, target-idempotence,
  unapproved-refusal, and injected-rollback matrix from a fresh fixture.
- First observed: JBQ2B exact installer rehearsal on 2026-08-19. The installer
  correctly refused synthetic hash
  `935A53F0CC039B382476F71AC3F1DFDDE21ABCF75F91BC8796D35204AE4F397C`;
  no production state was accessed.

### An exact-resume verifier must not require its deterministic extraction root to be fresh

- Signature: a queue repair completes and the exact retried maintenance request
  returns a valid signed terminal `FAILED` response with stderr `Fresh package
  extraction root required: C:\P21E`, even though the prior attempt already
  completed the bounded detector run and left its pinned successful audit.
- Cause: the retry verifier was output-resume-aware but not extraction-resume-
  aware. It always expanded the pinned ZIP to the same deterministic
  `C:\P21E` before reaching its exact-existing-output audit branch. The first
  attempt legitimately left that extraction tree, so the retry failed at the
  earlier freshness check without evaluating or changing detector results.
- Preflight: for a retry after any prior execution, enumerate both output and
  extraction/install roots. Accept an existing install root only after every
  package-manifest file count, byte count, and SHA-256 matches the pinned ZIP
  contents. Rehearse the exact retry against the preserved install tree and
  pinned successful output audit. A fresh extraction rule is valid only for a
  genuinely create-new run, not for an exact resume.
- Recovery: preserve the signed failed response and do not delete or overwrite
  `C:\P21E`. Use the verifier's bounded `-InstallRoot
  C:\P21E\PFC004SB2` path so it revalidates all package files, then require the
  pinned `D:\A21\PFC004SB2_20260818T231500Z\AUDIT.json` SHA-256 and semantic
  contract before emitting the normal terminal state. Because the earlier
  request now has a signed terminal response and the endpoint queue is healthy,
  a separately signed, fully rehearsed exact-resume request may be published;
  never rerun detection or issue an unpinned delete command to manufacture a
  fresh root.
- First observed: signed JBOD response
  `R_84F944855C1A_20260819134655003_0ae692cd` on 2026-08-19 for exact PFC004
  request `REQ_20260818T232640487Z_591E16C31AD5`. Response ZIP SHA-256 is
  `7D3CC30EF55C6F2B91EF7D8D85CEDFAF96E77934081E7DABEEDF93C24F85DE10`;
  no inspection task or detector output was changed by the refusal.

### A post-failure maintenance resume must not assume its changed verifier remains installed

- Signature: a signed exact-resume follow-up reaches the healthy JBOD endpoint
  and fails with `Exact-resume prerequisite absent: ...\Invoke-PFC004SB2Portal.ps1`.
  The request itself and its response are validly signed and terminal.
- Cause: the follow-up assumed the verifier installed by the earlier failed
  maintenance request persisted. The endpoint maintenance handler correctly
  rolls every declared change back when the verifier exits nonzero or misses
  its required state. Because the original verifier was an `allowCreate`
  change, rollback moved that created file into failure quarantine and left no
  installed verifier at the destination.
- Preflight: after any terminal maintenance failure, treat every declared
  changed destination as rolled back unless direct exact-endpoint evidence
  proves otherwise. A resume request must either audit the actual installed
  predecessor state or carry every executable it needs inside its own signed
  payload. Rehearse the payload from a fresh extracted signed package; never
  infer persistence from the earlier request manifest.
- Recovery: preserve the signed failed follow-up. Publish a distinct revision
  only after that response is terminal. Carry the exact pinned verifier bytes
  as a sibling signed payload file, verify its SHA-256 before execution, and
  call it with the existing verified install root. Do not reinstall or depend
  on a rollback-removed path, rerun detection, delete `C:\P21E`, or change an
  inspection task.
- First observed: signed response
  `R_7E5EACBB6C9F_20260819135831804_c77ab3d3` on 2026-08-19 for request
  `REQ_20260819T135450748Z_C4AD415BFD64`. The response was terminal `FAILED`;
  no detector output or inspection task changed.

### Never use a case variant of PowerShell's automatic `$Matches` variable for output records

- Signature: an exact Windows PowerShell 5.1 rehearsal completes its read-only
  collection but `ConvertTo-Json` fails with `The type
  'System.Collections.Hashtable' is not supported ... Keys must be strings`,
  localized to a record collection that was intended to be an array.
- Cause: PowerShell variables are case-insensitive. A local variable named
  `$matches` is the automatic `$Matches` variable used by the `-match`
  operator. Each successful regular-expression test replaces it with a
  hashtable whose capture-group keys include integers. The collector then
  embeds that automatic hashtable in its result instead of the intended array.
- Preflight: run the exact packaged script under Windows PowerShell 5.1 and
  require full result serialization. Treat `$Matches` and every case variant
  as reserved. When a script combines regular-expression matching with a
  result collection, name the collection for its domain, such as
  `$lineMatches`, and optionally serialize each top-level result property to
  localize any future type leak.
- Recovery: rename the collection and all of its references; do not weaken or
  bypass JSON serialization. Rerun the exact PowerShell 5.1 rehearsal and
  verify the expected array content, required terminal state, and zero
  mutations.
- First observed: local `JBOD_STORAGE1` read-only storage-inventory rehearsal
  on 2026-08-19. No JBOD request had been signed or published and no external
  state was accessed or changed.

### Materialize generic lists before embedding them in Windows PowerShell 5.1 JSON objects

- Signature: an exact Windows PowerShell 5.1 rehearsal reaches construction of
  a result object and terminates with `Argument types do not match` when an
  array subexpression such as `@($genericList)` is embedded in that object.
- Cause: Windows PowerShell 5.1's dynamic binder can fail while converting a
  closed generic `System.Collections.Generic.List[object]` containing ordered
  dictionaries through an array subexpression. The data is valid; the binder
  conversion is not reliable.
- Preflight: exercise the exact result-construction and `ConvertTo-Json` path
  under Windows PowerShell 5.1 with a nonempty multi-record list. Do not assume
  that a list which enumerates in a pipeline can be embedded through `@(...)`.
- Recovery: call the list's typed `ToArray()` method before assigning it to the
  result property, then rerun exact JSON serialization and validate the record
  count. Do not suppress the diagnostic records or weaken serialization.
- First observed: local `JBOD_STORAGE3` Completed Lot diagnostic rehearsal on
  2026-08-19. No request had been signed or published and no JBOD or inspection
  state was accessed or changed.
## 2026-08-19 — Scheduled-task executable literals must be pinned exactly before maintenance verification

- Failure signature: a non-mutating monitor-task verification reported `Monitor task action changed` even though the task name and argument string matched the signed inventory.
- Cause: the installed task stores `Actions[0].Execute` as the literal `powershell.exe`; the verifier constructed `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`. Both can resolve to Windows PowerShell 5.1 at launch, but they are not the same task-definition field.
- Required preflight: pull and pin the exact installed `Execute`, `Arguments`, `WorkingDirectory`, principal, and exported task-definition hash. Do not substitute a resolved executable path for a literal stored action when proving definition invariance.
- Recovery: accept only the signed-inventory literal `powershell.exe` with the exact pinned argument string; keep task-definition verification read-only. The failed portal request returned a signed terminal failure and the endpoint rolled back all installed-file changes before the corrected request.

### An overrideable rehearsal install root does not rewrite absolute production paths inside a config payload

- Signature: an exact local hotfix rehearsal installs the byte-for-byte target
  config into a short fixture root, then its verifier fails with
  `appRoot changed` because it compares the config's pinned production
  `appRoot` to the fixture install directory.
- Cause: the installer destination root and the application paths encoded in
  the config are separate contracts.  An overrideable rehearsal install root
  proves predecessor/change mechanics without authorizing mutation of the
  target config's absolute production paths.
- Preflight: classify each path as an installer path or a payload-semantic
  path.  Verify the installed target config byte-for-byte at the fixture
  destination, but validate `appRoot`, `stateRoot`, output, dashboard, cache,
  metadata, raw, and relay values against their pinned production meanings.
  When live behavior must be rehearsed, create a separate derived runtime
  config under the fixture root and invoke the exact installed executable
  against only that derived file.
- Recovery: keep the signed target config unchanged.  Correct the verifier to
  compare its encoded paths with the production contract, then derive a
  fixture-only runtime config for the cooperative-hold acknowledgement test.
  Never point a rehearsal at the installed production processor or mutate the
  packaged config merely to make fixture paths agree.
- First observed: local `JBOD_STORAGE_CUTOVER_H1` rehearsal on 2026-08-19.
  No request was signed or published, no JBOD path was accessed, and no
  inspection task or wafer was changed.

### Do not read `$LASTEXITCODE` after invoking a PowerShell script in a fresh strict-mode process

- Signature: an exact Windows PowerShell 5.1 rehearsal successfully invokes a
  sibling `.ps1`, then fails with `The variable '$LASTEXITCODE' cannot be
  retrieved because it has not been set`.
- Cause: `$LASTEXITCODE` is populated by native-program execution, not by a
  normal PowerShell script call.  In a fresh `Set-StrictMode -Version Latest`
  process there may be no prior native exit code to read.
- Preflight: classify every child invocation as native executable or
  PowerShell command.  For a `.ps1` call, rely on terminating-error propagation
  and validate its returned contract; consult `$LASTEXITCODE` only immediately
  after a native process invocation that is guaranteed to set it.
- Recovery: remove the `$LASTEXITCODE` check around the PowerShell-script call,
  retain terminating-error behavior, and assert the exact generated
  acknowledgement and result fields.  Do not weaken the child script or hide
  errors.
- First observed: local `JBOD_STORAGE_CUTOVER_H1` Windows PowerShell 5.1
  rehearsal on 2026-08-19.  No request was signed or published and no JBOD or
  inspection state was touched.

### Do not keep a maintenance transaction open while waiting for a long cooperative processing boundary

- Signature: a signed hold-config maintenance request installs a valid
  cooperative-hold config, waits for the current wafer to finish, and reaches
  its bounded verifier timeout before an acknowledgement appears.  The signed
  terminal response is `FAILED` with `cooperative-hold acknowledgement did not
  arrive`, and the endpoint rolls the config change back.
- Cause: endpoint maintenance changes are transactional.  Any nonzero verifier
  exit rolls every declared change back.  A verifier message claiming that the
  installed config "remains fail-closed" is therefore false after the endpoint
  completes rollback.  Wafer duration is not a safe upper bound for a portal
  maintenance transaction.
- Preflight: separate hold installation from boundary acknowledgement.  The
  maintenance verifier must validate the exact target config, installed
  processor hash, hold ID, C:-path preservation, no task mutation, and
  no-abort semantics, then return success immediately so the hold config
  persists.  A later signed read-only diagnostic must prove an acknowledgement
  with the exact hold ID and config SHA-256 before final delta or cutover.
- Recovery: preserve the signed failed response and rely on endpoint rollback
  to restore the approved predecessor.  Publish a distinct, fully rehearsed
  hold-request revision only after the failure is terminal.  Do not lengthen
  the transaction timeout, stop the task, abort the wafer, or claim a hold is
  active without a matching signed acknowledgement.
- First observed: signed JBOD response
  `R_62358767A0EE_20260819164538350_24540c15` for H1 request
  `REQ_20260819T162949614Z_207E99212DB1` on 2026-08-19.  Exact stderr SHA-256
  is `E02E2399B911816C2991C299B4513E845827E8432D5AE57C14C98F97B5CFC9E7`.
  No wafer was aborted and no D: cutover or source deletion occurred.

### A config-schema upgrade must preflight every ordered loop consumer, including consumers before the intended feature

- Signature: a persisted processor config upgrade is visible on disk, the
  monitor continues refreshing an old `IDLE_WATCHING` detector status with
  `Current: none` and `Waiting: 0`, and the new cooperative hold never writes
  its acknowledgement.  The outer processor loop remains alive but never
  reaches the processing-pass script that implements the hold.
- Cause: `Run-JbodAllWaferProcessor.ps1` invokes
  `Update-JbodScribeIdentityQueue.ps1` before
  `Invoke-JbodAllWaferProcessingPass.ps1`.  The live scribe-queue predecessor
  accepted only `argos_jbod_all_wafer_processor_config_v2`; the newly persisted
  config was safe v3.  Its schema refusal was caught by the outer loop and
  written to `processor\PROCESSOR_LOOP_FAILURE.txt`, then the loop slept and
  retried.  Because the detector status file was not rewritten after the
  exception, the monitor displayed a stale idle state as though the detector
  pass were still healthy.
- Preflight: before publishing any config-schema revision, enumerate every
  consumer in execution order from the exact installed runner, including
  inventory, scribe, processing, dashboard, reference, monitor, and watchdog
  paths.  Run the exact safe target config through each consumer's schema gate
  and require the first idle loop to reach the intended processing boundary.
  A refreshed monitor window is not liveness evidence; require a newer status
  timestamp or the expected acknowledgement plus an empty current identity.
- Recovery: patch the exact installed scribe-queue predecessor to accept only
  the pinned safe v2/v3 schemas while preserving all existing review-only and
  XML-disabled checks.  Patch the runner to re-read and validate the current
  safe config at every loop boundary, use that same snapshot for ordered
  arguments, and record the failing consumer explicitly.  Rehearse v2, v3
  idle-hold, malformed-schema, and downstream-failure cases under Windows
  PowerShell 5.1.  Do not stop the task, abort a wafer, clear the hold, switch
  output paths, or infer health from a stale detector status.
- First observed: signed read-only DATA_PULL response
  `R_9EBAC5F8F607_20260819170002715_d119467e` for request
  `REQ_20260819T165935051Z_ACF83BE2DC9A` on 2026-08-19.  The exact live
  `PROCESSOR_LOOP_FAILURE.txt` SHA-256 is
  `EE726E49685C130E50213641738D8D98056A6D11E5B686330FA7C739834C3436`;
  the live scribe-queue script SHA-256 is
  `DAE5FB32E08E5D972F6572845CD5C7F481FCF5609219B2831F1C2F3F429F3E90`.
  No wafer was active, stopped, or aborted, and no D: cutover or source
  deletion occurred.

### Maintenance atomic-backup names must not prepend a GUID to the installed basename

- Signature: the prepublication path gate for a valid short-ID maintenance
  request reports a hard stop even though the signed request, installed
  destination, response, and state roots are individually short.  The derived
  maintenance backup component is longer than 80 characters; for
  `Invoke-JbodAutomaticInsiteBridgeWorker.ps1`, the existing
  `<32-hex>_atomic_<installed-basename>` scheme produces an 82-character
  component.
- Cause: the endpoint maintenance handler constructs `prior`, atomic-replace
  backup, failed-current, and rollback names by concatenating a GUID and prose
  with the full installed basename.  Component length therefore grows with
  the installed filename and is not bounded by shortening the request ID or
  state root.
- Preflight: for every declared maintenance change, enumerate the endpoint's
  exact derived staged, prior, atomic-backup, rollback, and failed-current
  leaves, including suffix reserve.  Gate both total effective path length and
  each component before signing.  Do not infer safety from the destination or
  request ZIP alone.
- Recovery: do not publish the affected maintenance request.  First deploy a
  separately rehearsed queue-safe endpoint revision that uses short indexed or
  hashed maintenance evidence names while recording the original destination
  and basename in its ledger/result metadata.  The endpoint self-update must
  use a short declared bootstrap destination or the separately rehearsed
  manual/admin path, exercise predecessor, idempotent, rollback, queue-head,
  and response-construction cases, and return signed terminal evidence before
  the blocked request is rebuilt.  Never waive the 80-character component
  gate or hide the long basename by omitting provenance.
- First observed: local C1D complete-path preflight on 2026-08-19 before
  publication.  No request was published, no JBOD file or task changed, the
  cooperative storage hold remained active, and no wafer was stopped or
  aborted.

### Portal response extraction must use a path-gated short physical root

- Signature: a complete round-trip prepublication gate passes every installed
  endpoint, relay, and share hop but reports
  `SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH` for the laptop response
  extraction leaf.  The response directory token and
  `PORTAL_RESPONSE_MANIFEST.json` are bounded, but nesting them under the long
  workspace and maintenance-revision path reaches an effective length of 200
  or more after the mandatory suffix reserve.
- Cause: response extraction was planned beneath the source-work directory
  merely because the signed request was built there.  Request provenance does
  not require returned container bytes to be expanded under the same long
  path.
- Preflight: enumerate the exact maximum response ID, `.ready` directory,
  response manifest, stdout/stderr/result leaves, ZIP name, and suffix reserve
  at the laptop hop.  Run `Confirm-ArgosPathBudget.ps1` before creating the
  extraction directory.  A ZIP path that passes is not evidence that its
  extracted leaves pass.
- Recovery: use a short physical extraction root such as `C:\A1E`, verify it is
  absent or bound to the exact request, and preserve request/response IDs and
  hashes in the workspace gate/checkpoint.  Do not silently shorten response
  identifiers or filenames, and do not rely on a mapped/subst drive that the
  consuming context cannot see.
- First observed: local C1E complete-route preflight on 2026-08-19 before
  publication.  No request was published, no JBOD file or task changed, the
  cooperative storage hold remained active between wafers, and no wafer was
  stopped or aborted.

### Exact endpoint rehearsals must use the installed approved-root set

- Signature: a signed maintenance request passes source, package, behavior,
  and exact endpoint-worker rehearsals, but the live endpoint returns signed
  terminal `FAILED` before mutation with `Maintenance destination is outside
  approved roots` for a real installed consumer.
- Cause: the local exact-endpoint harness constructed a config whose
  `approvedMaintenanceRoots` included both the processor and Insite bridge
  roots.  The installed JBOD `endpoint_jbod.json` authorizes only the
  processor root.  Testing the exact worker bytes with a broader invented root
  set therefore did not test the installed endpoint contract.
- Preflight: before signing a maintenance request, bind the exact installed
  endpoint-config hash and enumerate its literal approved maintenance roots.
  Require every destination to fall under that frozen installed set.  A local
  harness may replace physical fixture prefixes only through an explicit
  one-to-one mapping of the installed roots; it must never add a root merely
  because the requested destination is expected.
- Recovery: preserve the signed failure and do not retry the same request.
  First use a separately rehearsed bounded helper inside an already approved
  root to retrieve the exact installed config hash and sanitized root set.
  If the additional root is operationally required, deploy a distinct atomic
  config revision with predecessor pin, exact semantic-field preservation,
  rollback, path, queue, and task-invariance gates; require its signed terminal
  response.  Only then rebuild the blocked maintenance request under a new ID
  and rerun the exact installed-config rehearsal.
- First observed: C1D request `REQ_C1D`, signed response
  `R_90F9FB102714_20260819184434022_54dbca9e` on 2026-08-19.  Failure JSON
  SHA-256 is
  `94400F67B19DF0863FA6A3D08A5B7C77A6800684A30C2F2F4651685E69ACA861`.
  The endpoint refused before changing any of the five consumers; no task,
  hold, D: path, source tree, or wafer changed.

### A root-aware leaf script is not enough when its interactive caller omits the root

- Signature: config-v3 cutover preflight proves that inventory and the
  automatic Insite bridge use `metadataSnapshotRoot`, but the tray's manual
  Insite export/import actions would silently fall back to
  `<stateRoot>\metadata\verified` after metadata is cut over to D:.
- Cause: `Export-JbodPendingInsiteRequest.ps1` and
  `Import-JbodLiveInsiteSnapshot.ps1` gained an optional
  `MetadataSnapshotRoot` parameter, while the installed tray continued to call
  both scripts with only `StateRoot`.  Updating a leaf consumer does not update
  every direct caller automatically.
- Preflight: enumerate every direct and indirect caller of each newly
  configurable root.  For config-v2, require the historical fallback.  For
  config-v3, require the exact configured root to reach every call site and
  exercise both the automatic bridge and interactive tray paths with distinct
  C: and D: fixtures.  Source-token checks alone are insufficient; the exact
  generated target must run under Windows PowerShell 5.1.
- Recovery: patch the tray to resolve the same bounded, safety-validated
  `metadataSnapshotRoot` from `PROCESSOR_CONFIG.json` and pass it explicitly to
  both manual operations.  Preserve Completed Lot observability, dynamic review
  output resolution, review-only/XML-disabled authority, and config-v2
  compatibility.  Install without clearing the hold or changing a task; load
  the new tray only during the separately gated monitor restart associated
  with final cutover validation.
- First observed: local post-C1D2 consumer audit on 2026-08-19 before D3 or
  cutover.  The Stage 1 copy continued independently; no request was published,
  no JBOD file or task changed, no path was cut over or deleted, and no wafer
  was active, stopped, or aborted.

### Path reserve must include the longest temporary leaf before package build

- Signature: a package build preflight stops with
  `SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH` even though the intended final
  payload leaf itself is below the 200-character effective-length threshold.
- Cause: the deterministic temporary/partial form of the payload leaf plus the
  required suffix reserve crosses 200.  Checking only the final payload path
  would miss the actual longest write-time leaf.
- Preflight: before creating a package directory or payload, run
  `Confirm-ArgosPathBudget.ps1` separately against the source, final target,
  longest deterministic temporary/partial target, and each with the required
  suffix reserve.  Record the individual result so the failing leaf is
  explicit.  An effective length of 200 or more requires a verified short
  physical staging root before the first write.
- Recovery: leave the rejected long target absent.  Select an explicit short
  physical staging root, gate the same complete leaf set there, then build and
  validate in that root.  Copy a completed, hash-verified artifact back to the
  workspace only when its own final and temporary paths pass; never depend on
  a mapped drive that may disappear across execution contexts.
- First observed: C1D3 local build preflight on 2026-08-19.  The final target
  had effective length 163, while its deterministic partial leaf plus reserve
  reached 204.  `C:\A3\C1D3` was evaluated as the proposed short physical
  staging root with maximum effective length 121.  The preflight stopped
  before creating the payload; no JBOD state, task, hold, C:/D: data root,
  source tree, or wafer changed.

### External PowerShell output is text, not the caller's structured object

- Signature: an exact final-ZIP gate successfully creates and extracts the ZIP,
  then fails under strict mode with `The property 'State' cannot be found on
  this object` while checking a verifier result.
- Cause: the harness invoked a PowerShell verifier through a separate
  `powershell.exe` process and assigned its stdout to a variable.  Across that
  process boundary, PowerShell objects are rendered as text lines; their
  properties are not preserved.  Treating the returned text as the verifier's
  original object caused the property lookup failure.
- Preflight: classify every child-script result by invocation boundary.  When
  the caller needs typed properties and the trusted script is compatible with
  the current host, invoke it in-process and assert its returned type and
  required properties.  If process isolation is required, make the child emit
  bounded JSON and parse it explicitly; never assume native stdout preserves a
  PowerShell object.
- Recovery: quarantine the exact partial final-build root as a failed attempt,
  leaving its files and hashes recoverable.  Patch the harness to invoke the
  signed-package verifier in-process (or parse explicit JSON), require a fresh
  final/output root, rerun wrapper and non-mutating preflight, and rebuild from
  the unchanged signed request.
- First observed: local C1D3 final-ZIP gate on 2026-08-19.  The failed attempt
  contained five files totaling 58,465 bytes under `C:\A3\C1D3\final`; the
  extracted-package endpoint rehearsal had not started.  No package was
  published, no JBOD state or task changed, the storage hold remained active,
  and no C:/D: inspection source or wafer changed.

### A signed maintenance RESULT may omit the optional detailed `changes` array

- Signature: response signature, endpoint state, `changedFiles`, entry point,
  exit code, and signed stdout all pass, but a strict collector fails with
  `The property 'changes' cannot be found on this object`.
- Cause: the live compact maintenance `RESULT.json` schema may omit the
  detailed `changes` array even when the exact endpoint rehearsal emitted it.
  Strict mode turns an optional-property read into a collector failure.
- Preflight: freeze mandatory versus optional response fields explicitly.
  Always require signed endpoint state, exit code, entry point, changed-file
  count, and exact entry-point stdout/invariant hashes.  Test optional property
  presence through `PSObject.Properties.Name` before reading it; when present,
  validate it fully.  Never weaken the mandatory signed stdout hash proof to
  compensate for an absent optional detail array.
- Recovery: preserve the verified but uncommitted extraction as a failed
  collector attempt, patch only optional-field handling, rerun wrapper/harness
  and non-mutating response preflight, then extract into a fresh root and commit
  the terminal gate only after every mandatory signed invariant passes.
- First observed: live C1D3A response
  `R_D09055C8EA34_20260819202009938_d199559a` on 2026-08-19.  `RESULT.json`
  contained `changedFiles=1` and `entryPoint=payload/C1D3.ps1`; signed stdout
  pinned the target tray hash and both manual metadata bindings.  No terminal
  gate was committed by the failed collector attempt.

### A preflight switch must not write its own gate artifact

- Signature: a script named and invoked as `-Preflight` reports
  `mutationsPerformed=false` but creates a route-gate JSON file on disk.
- Cause: the script treated "no JBOD mutation" as equivalent to
  "non-mutating preflight."  It calculated the route correctly, then wrote the
  result unconditionally before returning.
- Preflight: every changed harness must pass
  `Confirm-ArgosPowerShellHarnessSafety.ps1`.  When a script has top-level file,
  ZIP, process, mapping, or task mutations, it must contain a `Preflight`
  branch that returns before the first reachable mutation.  Use a separate
  `-Gate`, `-Build`, `-Test`, or `-Apply` action for durable evidence.
- Recovery: quarantine the artifact created by the invalid preflight and every
  downstream final gate that consumed it.  Add an explicit mutating action,
  rerun wrapper/harness preflight, execute the non-mutating preflight, then
  generate evidence and dependent packages in fresh roots.
- First observed: `Test-C1D3Routes.ps1` on 2026-08-19.  The new harness guard
  caught `PREFLIGHT_HAS_NO_RETURN_BEFORE_MUTATION` with two top-level mutations
  before publication.  No JBOD state or inspection data changed.

### A typed parameter name cannot be reused as a local result variable

- Signature: a corrected PowerShell 5.1 route preflight fails before writing
  with `Cannot convert value PSCustomObject to type SwitchParameter`.
- Cause: the script added a `[switch]$Gate` parameter while an existing local
  `$gate` variable held a parsed path-budget object.  PowerShell variable names
  are case-insensitive, so both names identify the same typed parameter slot.
- Preflight: `Confirm-ArgosPowerShellHarnessSafety.ps1` must reject every
  assignment to a declared parameter variable under any case variant with
  `PARAMETER_VARIABLE_REASSIGNED`.  Use semantic local names such as
  `$pathBudgetResult`, `$endpointResult`, or `$routeResult`.
- Recovery: verify the conversion failed before mutation, rename the local
  variable, rerun wrapper and harness safety checks on the changed bytes, and
  rerun the truly non-mutating preflight before generating evidence.
- First observed: corrected C1D3 route harness on 2026-08-19.  No route gate,
  ZIP, external request, JBOD state, or inspection data was created or changed.

### Freeze installer invariants and rollback design before the first signature

- Signature: a locally signed request draft is withdrawn and signed again
  because the exact post-swap rollback injection mechanism and an installed
  invariant were designed only after the first signature.
- Cause: payload behavior was frozen before the full installer-test design was
  frozen.  A valid signature does not prove that the package has a practical,
  exact way to exercise entry-point failure after swap.
- Preflight: before the first signature, write a package-design freeze record
  pinning entry point and payload hashes, all predecessor hashes, normalized
  installed roots, task-action allowlist, invariant hashes, the exact
  post-swap failure-injection mechanism, response leaves, route revision, and
  review/production authority.  Run unsigned helper behavior and failure
  rehearsal as far as possible first.  The signer must refuse a package whose
  freeze record is absent or whose hashes differ.
- Recovery: mark the premature signed draft `WITHDRAWN` and never publish it.
  Finalize the invariant and rollback design, rerun wrapper/path/helper gates,
  issue a new request identity, then run the signed exact-endpoint and
  extracted-final-ZIP matrix.
- First observed: unpublished local `REQ_C1D3` on 2026-08-19.  It was replaced
  by `REQ_C1D3A` only after pinning the Completed Lot launcher invariant and
  defining exact post-swap rollback injection.  No external request or JBOD
  mutation occurred for the withdrawn draft.

### Width-dependent PowerShell formatting is not hash or gate evidence

- Signature: `Select-Object`, `Format-Table`, or default console rendering
  shows paths but drops or wraps lengths and hashes, leaving the returned
  evidence ambiguous even though the underlying command succeeded.
- Cause: host-width formatting is presentation, not serialization.  Long paths
  consume the available columns and hide the fields needed to decide whether a
  gate passed.
- Preflight: gate scripts must emit bounded JSON or explicit scalar rows such
  as `<sha256> <absolute-path>`.  Ban `Format-Table`, `Format-List`, and other
  rendered formatting from machine gate harnesses.  Limit row count and save
  larger results file-backed.
- Recovery: disregard the ambiguous rendering, rerun a read-only scalar/JSON
  query, and bind the exact values in the durable gate.  Never reconstruct a
  hash or length from a wrapped table.
- First observed: C1D3 local payload/final-ZIP inspections on 2026-08-19.  The
  hash queries were rerun as scalar rows before any package publication.

### One fragile multi-file checkpoint patch must not control all state updates

- Signature: a combined patch for continuity JSON, active state, and revision
  ledger rejects atomically because one ledger anchor contains mojibake or no
  longer matches, even though the other edits are valid.
- Cause: a large multi-file patch used a full rendered ledger row as an exact
  anchor.  Encoding-damaged punctuation made the anchor brittle and coupled
  unrelated state-file updates to it.
- Preflight: update one authority file at a time using short stable ASCII
  anchors.  Never anchor to mojibake, rendered console text, or a full long
  ledger row.  The revision ledger must retain the literal EOF marker
  `<!-- ARGOS_REVISION_LEDGER_APPEND_SENTINEL -->`; insert each new row directly
  before that marker and preserve the marker as the final line.  A ledger
  append without that sentinel is a hard stop.  Parse continuity JSON and
  recompute the checkpoint hash after every edit before advancing to the next
  file.
- Recovery: verify whether the patch was atomic.  If it rejected before any
  write, leave the authoritative state unchanged, split the edits, and reapply
  them independently.  If partial state is ever possible, stop and reconcile
  hashes before continuing.
- First observed: the unactivated C1D3A checkpoint update on 2026-08-19.  The
  patch rejected before changing continuity, active state, or the ledger; the
  prior D2S2 checkpoint remained authoritative.
- Repeated observation: the C1D3A terminal ledger append was correctly isolated
  to one file but still tried to match the complete preceding row and rejected
  before mutation because of a one-space difference.  The ledger now has the
  permanent ASCII append sentinel above so the preventive action is structural,
  not dependent on remembering to copy a long row exactly.

### A broad recursive drive scope is never an inspection-storage migration plan

- Signature: an operator reasonably asks whether "move C: to D:" means the
  entire drive because the implementation status does not repeat the exact
  source allowlist and exclusions.
- Cause: shorthand described a bounded Argos migration as a drive-level move.
  Even when the code is scoped correctly, ambiguous language is unsafe for a
  later cutover or recovery step.
- Preflight: every copy, cutover, recovery, or delete manifest must enumerate
  exact source and destination roots and an explicit excluded-root set.  Reject
  `C:\`, Windows, user profiles, Downloads, portal/relay state, processor
  state, `C:\P21E`, historical outputs, identity, hotfixes, and every
  undeclared tree.  Require the operation set to equal the allowlist; never use
  a drive-wide recursive command or an unresolved root variable.
- Recovery: stop before mutation, restate and hash-lock the exact scope, then
  rerun path, source-set, destination-set, and deletion-authorization gates.
- Current locked scope: only the Argos `cache`, `metadata`, and
  `dashboard_outputs` source trees are in Stage 1, with future review output at
  `D:\A2\o`.  Historical outputs, identity, and hotfixes remain excluded.

### Optional developer tools must be discovered before use

- Signature: a diagnostic command continues after `git` is not recognized,
  obscuring the intended change inventory with a tool-availability error.
- Cause: the harness assumed an optional executable was on `PATH` without a
  discovery preflight.
- Preflight: use `Get-Command <tool> -ErrorAction SilentlyContinue` before an
  optional executable.  If absent, use explicit file hashes and bounded file
  enumeration; do not make the optional tool a hidden dependency of a safety
  gate.
- Recovery: treat the failure as read-only and non-authoritative, choose the
  bounded fallback, and do not rerun the same unavailable command.
- First observed: local C1D3 change-inventory check on 2026-08-19.  No file or
  external state changed.

### A gate caller must not guess the utility's PASS state token

- Signature: a bounded safety utility returns a valid zero-violation PASS
  object, but its caller throws because it compares `state` with a similar
  invented token.
- Cause: the caller assumed a naming convention instead of reading the exact
  utility contract.  C1D3/D2S3 preparation expected
  `PASS_POWERSHELL_HARNESS_SAFETY` while the actual state was
  `PASS_ARGOS_POWERSHELL_HARNESS_SAFETY`.
- Preflight: obtain the exact state from the utility's file-backed contract or
  a first metadata-only invocation, then assert that literal plus the actual
  violation/error counts.  Do not infer PASS names from filenames or nearby
  utilities.  Record the exact expected token beside the invocation.
- Recovery: confirm the target was not executed and no mutation occurred,
  correct only the caller assertion, then rerun the same metadata-only gate.
  Never weaken the utility or skip its violation-count checks to make the
  caller pass.

### A mechanically cloned harness can reintroduce a prohibited predecessor contract

- Signature: a newly generated revision parses and hash-matches its pinned
  predecessor, but the harness-safety gate rejects it before execution for a
  known contract such as a mutating `-Preflight`.
- Cause: the predecessor was treated as a safe template because its historical
  run passed, even though it predates a newer mandatory static guard.  The D2S3
  mechanical clone inherited D2S2's route script that wrote its durable gate
  from `-Preflight`.
- Preflight: run `Confirm-ArgosPowerShellHarnessSafety.ps1` against every source
  template before cloning and against every generated output before execution.
  If a source violates current policy, freeze an explicit remediation map and
  implement that change during generation before the first output write; do
  not create a knowingly noncompliant clone and plan to repair it afterward.
  Parser success and pinned hashes are necessary but insufficient.
- Recovery: confirm the generated script was never executed or consumed by a
  signature, change `-Preflight` to a truly non-mutating return and use a
  separate `-Gate` action, rename any case-insensitive parameter collision,
  then rerun wrapper and harness safety before any rehearsal.
- First observed: D2S3 preparation on 2026-08-19.  The static guard caught the
  inherited route violation before route execution, signing, publication, or
  JBOD mutation.

### A narrow documentation patch can leave an orphaned continuation line

- Signature: a new bullet reads correctly, but a fragment of the prior bullet
  remains immediately below it as duplicated or grammatically orphaned text.
- Cause: the patch replaced only the first lines of a wrapped logical bullet
  without including its final continuation line in the context.
- Preflight: when editing wrapped Markdown prose, include the entire logical
  bullet or paragraph in the patch context.  Immediately reread a bounded
  window around every policy/memory edit before hashing or checkpointing it.
- Recovery: remove only the orphaned fragment, reread the bounded window, and
  recompute the artifact hash.  Do not let malformed policy text become an
  authoritative checkpoint.
- First observed: the D2S3 predecessor-template prevention addition on
  2026-08-19; bounded inspection caught and removed the orphan before any gate
  or checkpoint consumed the document.
- Repeated observation: the later AGENTS clone-gate insertion spliced after the
  first wrapped line of a sentence and briefly left a stray `Freeze`.  Bounded
  readback again caught it before hashing.  Policy edits must replace the full
  logical sentence or paragraph, even when only one wrapped line appears to be
  the intended anchor.

### A new rehearsal revision must not reuse its predecessor's fixed temporary roots

- Signature: the new revision's exact non-mutating preflight refuses a
  pre-existing test root whose name belongs to the predecessor revision.
- Cause: request/revision tokens and filenames were transformed, but embedded
  ephemeral paths such as `C:\S2E`, `C:\S2D`, and `C:\S2B` were omitted from
  the clone remediation map.
- Preflight: before generating a new revision, inventory every literal test,
  fake-drive, extraction, partial, quarantine, and response root in all source
  templates.  Assign revision-specific fresh roots, run the path budget on
  them, and assert they are absent before the first rehearsal write.  Treat
  unchanged predecessor-root tokens as a generation failure.
- Recovery: preserve the predecessor roots untouched, select new path-gated
  revision-specific roots, patch the generated invocation and harness files,
  then repeat wrapper, harness, and exact non-mutating preflight.  Never delete
  or reuse an unidentified prior rehearsal tree merely to make the test pass.
- First observed: D2S3 endpoint preflight on 2026-08-19 inherited `C:\S2E`
  and refused it before mutation.  D2S3 moved to fresh `C:\S3E`, `C:\S3D`,
  and `C:\S3B`; the preserved S2 roots were not changed.
- Repeated observation: the D2S3 response collector still inherited `C:\A1S`
  and refused that existing D2S2 extraction tree before mutation.  This proved
  a prose checklist and manual literal search were insufficient.  The mandatory
  `utilities/Confirm-ArgosCloneLiteralRemediation.ps1` gate now inventories the
  drive/UNC root literals in every declared source/generated pair and requires
  each to be an explicit replacement or allowed unchanged root.  D2S3 uses
  fresh `C:\A3S`; `C:\A1S` remains untouched.

### A script-scoped PSDrive may be invisible inside a module cmdlet and strand an exact upload

- Signature: `Copy-Item` succeeds through a temporary PowerShell drive, then
  `Get-FileHash` fails inside `Microsoft.PowerShell.Utility` because its
  internal `Resolve-Path` reports that the drive does not exist.  An exact
  `<request>.ready.zip.upload` remains, with no ready file or local publish
  gate.
- Cause: the publisher created the drive with `-Scope Script`.  Provider-native
  commands in the caller saw it, while a module-scoped cmdlet did not reliably
  resolve that drive.  Verification occurred after the first external write,
  and the publisher had no exact-resume state machine.
- Preflight: when a module cmdlet must consume a temporary PSDrive path, create
  the mapping only in `-Apply` with the minimum scope that is demonstrably
  visible to that module (for this workflow, a tracked temporary global
  PSDrive), exact-root verify it, and remove only the mapping the script
  created.  Rehearse the actual post-copy hashing command, not only `Copy-Item`.
  Publishers must classify their queue transaction as exactly `NEW`,
  `EXACT_UPLOAD`, or `EXACT_READY`; verify own-name artifacts by pinned length
  and SHA-256; reject every foreign, ambiguous, or mismatched artifact; and
  repeat the classification immediately before commit.
- Recovery: enumerate the exact queue through UNC read-only, verify the orphan
  against the pinned signed ZIP, and resume only an exact own upload by moving
  it to ready.  If exact ready already exists, recover only the missing local
  gate.  Never delete, overwrite, or republish blindly.  A state change between
  preflight and apply is a hard stop.
- First observed: `REQ_D2S3` publication on 2026-08-19.  The orphan upload was
  exactly 3,036 bytes with SHA-256
  `50A4C92A09DD4CDFE2290AF7C3DEA58E3E8EDC1FCFCE4970700432E30FC19881`;
  no ready request or local publish gate existed at diagnosis.

### A static preflight-mutation guard must include provider and mapping mutations

- Signature: a collector creates `New-PSDrive` before its `-Preflight` return,
  yet the static harness reports PASS because its mutation command set covers
  files, processes, and tasks but omits drive/mapping commands.
- Cause: mutation classification was narrower than the actual Windows state
  surface.  Nested `try` detection was working; `New-PSDrive` and
  `Remove-PSDrive` simply were not classified as mutations.
- Preflight: the guard's mutation set must include `New-PSDrive`,
  `Remove-PSDrive`, `New-SmbMapping`, and `Remove-SmbMapping`.  After changing
  the guard, run it against itself, the corrected target as a positive control,
  and a preserved legacy script with mapping before the preflight return as a
  negative control.  Require `MUTATION_BEFORE_PREFLIGHT_RETURN` from the
  negative control.
- Recovery: do not execute the falsely passed target.  Extend and self-check
  the guard first, move all mapping creation after the preflight return, and
  rerun wrapper/harness safety before target preflight.
- First observed: D2S3 collector review on 2026-08-19.  The corrected collector
  passed; preserved D2S2 collector was rejected at its `New-PSDrive` line.

### A throwing JSON gate may not populate its enclosing assignment on failure

- Signature: a negative-control gate emits valid failure JSON and then throws,
  but `$result = & <gate>` or `$rows += & <gate>` remains unset because the
  enclosing assignment never completes.
- Cause: PowerShell streams output before the terminating error, while the
  assignment expression commits only after command completion.
- Preflight: do not rely on variable assignment or `Tee-Object -Variable` to
  retain output from an in-process command that terminates the pipeline; both
  failed in the observed host.  A metadata-only guard may expose an explicit
  regression switch such as `-ReturnFailureResult` that returns the exact
  failure object without throwing.  Default production behavior must still
  throw on violations.
- Recovery: rerun only the metadata guard with the explicit regression switch,
  parse the returned JSON, and assert both the failure state and exact
  violation code.  Never use the switch in a production release gate or weaken
  the default throwing contract.

### A native crop does not make thumbnail-derived wafer pose native

- Signature: a workflow opens the full-resolution BF/DF source and refines an
  edge candidate in native pixels, but its center, radius, crop location, or
  angular search window was obtained by scaling a thumbnail fit.  A chipout or
  other physical indentation can bias the thumbnail circle or win the coarse
  candidate score, shifting every downstream notch, scribe, and fiducial
  coordinate even though the final crop is full resolution.
- Cause: coarse localization was allowed to become geometric authority.  The
  implementation scaled the thumbnail center/radius into source coordinates
  and searched only near the thumbnail-selected candidate instead of fitting
  the complete physical perimeter independently from full-resolution BF and DF.
  Calling the second stage `native refinement` concealed the inherited pose
  dependency.
- Preflight: trace the provenance of every final center, radius, angle, crop,
  and search bound.  Require the final circle to be robustly fitted from
  distributed full-resolution BF/DF boundary samples around the circumference;
  require the final candidate scan to cover that measured native circumference;
  and prove that thumbnail geometry and candidate rank can be removed or
  deliberately perturbed without changing the native result.  Preserve BF/DF
  physical competitors and unsupported angular spans.  A thumbnail may reduce
  I/O only by nominating broad read regions; it must have zero weight in final
  pose or candidate eligibility.
- Recovery: withdraw the dependent integration before execution, add an
  unconditional fail-closed guard so it cannot be launched accidentally, and
  replace it with a direct full-resolution BF/DF perimeter engine.  Regression
  must include the known giant-chipout control, verify selection of the
  manufactured 89.9-degree notch rather than the 85.5-degree chipout, and fail
  closed on multiple plausible physical candidates or unresolved
  pattern-interrupted evidence.  Do not repair this by widening the coarse
  search window or loosening morphology thresholds.
- First observed: patterned-wafer notch recovery V2 design review on
  2026-08-19.  Its exact preflight was non-mutating and created no result; the
  integration was guarded and withdrawn before its 15-wafer regression ran.

### An incomplete radial sample window can manufacture an image-border edge

- Signature: a direct native perimeter fit retains too few circle inliers or
  drifts toward the raster boundary even though the physical wafer edge is
  present.  Candidate radii near an image side have inside/outside averaging
  windows that partly leave the raster.
- Cause: the sampler silently divided only by the remaining in-bounds pixels,
  and returned zero when none remained.  Comparing a valid inside mean with a
  missing outside mean created an artificially strong transition at the image
  border.  A robust circle fit cannot safely repair systematically fabricated
  boundary points.
- Preflight: calculate the complete pixel count for every radial averaging
  window and mark the candidate unsupported unless every requested sample is
  in bounds.  Transition ranking must skip non-finite/incomplete windows.  Test
  this with a circle whose broad search interval extends beyond at least one
  raster side; require the physical circle rather than the image rectangle.
- Recovery: preserve the failed output as diagnostic, reject incomplete
  windows in the low-level sampler, recompile, and rerun from a fresh output
  root.  Do not loosen circle inlier or residual gates to make a border-biased
  fit pass.
- First observed: native-pose synthetic chipout control `SYNTH_V1` on
  2026-08-19.  It held at native perimeter qualification before any real-wafer
  run or pose result was accepted.

### Rejecting residuals only after a global circle fit is not chipout-robust

- Signature: complete radial windows correctly find the physical silhouette,
  but the first all-point least-squares circle shifts toward a broad chipout.
  Residual gates are then calculated around that already-corrupted circle and
  discard normal perimeter evidence instead of recovering it.
- Cause: the supposed robust fit initialized from an ordinary global
  least-squares solution.  Iterative residual trimming is not robust when the
  initial estimator has a poor breakdown point and the outlier is a coherent
  physical arc rather than isolated noise.
- Preflight: include a broad/deep BF+DF chipout in the direct-pose synthetic
  control.  Initialize from many deterministic, widely separated three-point
  circle hypotheses (or an equivalently high-breakdown estimator), select by
  whole-circumference native inlier support, then refine only the winning
  inliers.  Require the manufactured notch to remain selected while the
  chipout remains recorded as a physical indentation.
- Recovery: preserve the failed regression root, replace the global
  least-squares initializer with a deterministic distributed robust estimator,
  keep the residual/inlier qualification gates unchanged, and rerun from a
  fresh root.  Do not raise residual limits or lower the inlier fraction to
  manufacture a pass.
- First observed: corrected-window synthetic chipout control `SYNTH_V2` on
  2026-08-19, before any real-wafer execution.

### Do not infer normal-session failure from catastrophic embedded-media growth

- Signature: a text-only Codex task crosses a conservative checkpoint size and
  is rotated automatically even though continuity and interaction health are
  intact, causing avoidable task-start overhead and lost working context.
- Cause: the original size policy treated two approximately 18-20 GiB JSONL
  failures caused by serialized image/binary payloads as evidence for a much
  lower universal reliability cutoff. It did not separately measure normal
  text-only growth, abnormal per-turn growth, or actual interaction health.
- Preflight: keep the binary-content wall absolute; inspect session metadata
  only; checkpoint at 128 MiB; run deterministic continuity/authority and
  observed-interaction probes at 256 MiB and 384 MiB; and measure adjacent size
  deltas. A 16 MiB or larger unexpected single-turn increase is a provisional
  immediate alarm regardless of total size.
- Recovery: preserve the current filesystem checkpoint, stop any
  payload-producing action on abnormal growth or at 512 MiB, and resume in a
  fresh task without opening or attaching JSONL. Do not rotate a healthy
  text-only task merely because it crossed 128 MiB.
- First formalized: session-health calibration V2 on 2026-08-19 after operator
  approval of the staged empirical policy.

### Formatted PowerShell output is not a capturable raw result object

- Signature: a caller captures `& <checker.ps1>` and then fails under strict
  mode because an expected property such as `.State` is absent, even though
  the checker visibly printed that field and completed successfully.
- Cause: the checker ended with `Format-List` or another formatting cmdlet.
  PowerShell emitted formatting records for the host, not the original object
  the caller expected to inspect.
- Preflight: inspect the exact callee output contract before dereferencing a
  captured result. A display-oriented checker may be used as a success/failure
  boundary, while exact machine fields must come from its JSON mode or the
  separately locked source record. Add a strict-mode rehearsal of the exact
  caller.
- Recovery: do not parse rendered table/list text. Require the checker to
  complete without throwing, discard its formatting stream, and read the exact
  continuity fields from `ARGOS_CONTINUITY_STATE.json`; alternatively add an
  explicit raw-object or JSON output mode to the checker in a later revision.
- First observed: session-health probe V1 rehearsal on 2026-08-19. No task
  content, detector output, JBOD state, or authority changed.
- Repeated observation: during D2S4 terminal-failure activation on 2026-08-19,
  a caller piped the display-oriented continuity checker directly to
  `Select-Object`, producing repeated blank selected rows despite a zero exit.
  No state changed. Future callers must run the checker only as an exit-code
  boundary, discard its formatting stream when compact output is desired, and
  read exact fields from `ARGOS_CONTINUITY_STATE.json`.
- Repeated again immediately before C2T3 publication on 2026-08-19.  The same
  blank formatting rows were recognized before publication; the checker was
  rerun directly and returned `PASS_ARGOS_PROJECT_CONTINUITY`.  Treat the exact
  command form `Confirm-ArgosProjectContinuity.ps1 ... | Select-Object` as
  prohibited, not merely discouraged.

### An interrupted Chocolatey Visual Studio workload can leave an orphaned elevated setup helper

- Signature: Chocolatey successfully installs its prerequisite packages and
  Visual Studio Build Tools bootstrapper, then the workload step exits with
  Windows status `-1073741510` (`0xC000013A`). Chocolatey terminates abnormally,
  but an elevated `setup.exe` remains after its recorded parent process is gone;
  the Visual Studio instance is incomplete and the helper consumes no CPU over
  a bounded progress sample.
- Cause: the package-manager command window or controlling process was closed
  or interrupted while the separately elevated Visual Studio modifier was
  active. The wrapper lost its terminal result and cleanup path while the child
  helper remained alive.
- Preflight: run only one Windows installer chain at a time; keep a persistent
  transcript; do not close or interrupt the controlling terminal; record the
  exact installer PID and install root; verify free space and path budget; and
  wait for a terminal package-manager result before starting another install.
  Treat a bootstrapper success as distinct from workload success.
- Recovery: read the Chocolatey terminal log rather than partial console text.
  If it proves `0xC000013A`, verify that the recorded parent is absent and sample
  the exact remaining helper for progress. Stop only that exact zero-progress
  orphan, then inspect the instance with `vswhere` and either resume the one
  intended workload or remove the incomplete instance through Visual Studio
  Installer. Do not rerun the whole Chocolatey package chain or kill unrelated
  installer processes.
- First observed: local Argos development-tool setup on 2026-08-19. Python
  3.14.7 and the Build Tools bootstrapper completed, but the VCTools workload
  did not receive a successful terminal result. No JBOD, detector, wafer,
  inspection, storage, XML, training, or production state changed.

### A compiler startup probe must not use source-free `cl /Bv` as a zero-exit smoke test under stop-on-stderr

- Signature: the repaired Visual Studio C++ compiler prints its correct x64
  version banner, but the PowerShell verifier terminates with
  `NativeCommandError` and reports the startup probe as failed.
- Cause: source-free `cl.exe /Bv` prints the compiler banner but also exits
  nonzero because no input source was supplied. With
  `$ErrorActionPreference = 'Stop'`, PowerShell promotes that expected native
  stderr/nonzero behavior before the verifier can inspect the banner and exit
  code. This is the same stderr-promotion mechanism already documented for
  expected child-process refusal cases, exposed through a new compiler-probe
  invocation.
- Preflight: for a startup/version-only qualification, initialize the exact
  target developer environment and run `cl.exe /?`, which returns zero while
  printing the compiler version. Capture merged native output and
  `$LASTEXITCODE` with a bounded nonterminating preference, then restore
  stop-on-error before assertions. If `/Bv` is required, compile a bounded
  real source or explicitly treat its source-free nonzero exit as expected.
- Recovery: do not reinstall or modify Visual Studio based on this probe
  failure. Rerun only the read-only startup verification with `cl.exe /?`,
  require the expected version, zero exit code, exact VCTools-qualified
  instance root, and successful MSBuild startup.
- First observed: post-repair local Argos development-tool verification on
  2026-08-19. The corrected `cl.exe /?` probe and MSBuild version probe both
  passed; no JBOD, detector, wafer, inspection, storage, XML, training, or
  production state changed.

### A live storage-status snapshot may omit informational fields under strict mode

- Signature: a fresh signed JBOD maintenance response is terminal `FAILED`
  even though the status request payload itself is unchanged and previously
  passed. Exact stderr reports `PropertyNotFoundStrict` because property
  `updatedUtc` cannot be found while evaluating `D2S.ps1`.
- Cause: the status verifier treated informational fields on the live
  `STATUS.json` object as structurally mandatory and read them directly under
  `Set-StrictMode -Version Latest`. The live status schema can change as the
  copy/hash task advances and may omit `updatedUtc`; direct access aborts
  before the verifier can report task, result, hold, or terminal status. This
  endpoint failure is not evidence that the storage transfer failed or passed.
- Preflight: freeze mandatory proof separately from optional display fields.
  Read every live JSON property through explicit `PSObject.Properties`
  presence checks. Require the cooperative hold's identity and a parseable
  hold timestamp for `taskLastRunAfterHold`; require the exact result/manifest
  contract for terminal authority. Treat absent status `updatedUtc`,
  `completedFiles`, or `completedBytes` as explicit missing/zero informational
  values, not as a script exception. Rehearse old in-progress, terminal, and
  observed missing-field status shapes before signing a fresh request.
- Recovery: preserve and verify the matching signed failure response. Do not
  infer transfer completion from the missing property, do not retry the same
  request identity, and do not publish D3. Patch only the status reader, assign
  a fresh request identity, repeat behavior/endpoint/queue/package/route gates,
  then require a new matching signed response.
- First observed: signed D2S4 response
  `R_EE86E4BCC38C_20260819225731829_41d7e174` on 2026-08-19. The failure
  occurred before a status result was emitted; no cutover, deletion, hold
  clearance, inspection-task change, or wafer abort was authorized.

### PowerShell keywords and command arguments require lexical separation in compact probes

- Signature: a read-only inline preflight fails in the parser with `Missing
  'in' after variable in foreach loop` before executing its first statement.
- Cause: compact source concatenated the keyword and collection expression as
  `foreach($p in$paths)`. PowerShell tokenized `in$paths` instead of `in` plus
  `$paths`.
- Preflight: preserve spaces around every PowerShell control keyword and its
  following expression (`foreach ($p in $paths)`, `if ($condition)`, and
  `while ($condition)`). Parse changed inline probes or move reusable logic to
  a file-backed, statically gated script before execution.
- Recovery: confirm the parser failure made no writes, correct only lexical
  separation, and rerun the same non-mutating preflight. Do not bypass the
  rejected gate.
- First observed: D2S4 signed-failure collection path planning on 2026-08-19;
  no output path, portal request, JBOD file, task, hold, or wafer changed.
- Repeated observation: D2S5 source-hash inventory compacted
  `Join-Path $root $_` into `Join-Path$root$_`; PowerShell treated the whole
  token as an unknown command and produced no hashes. No file changed. The
  prevention applies to command names and every following argument as well as
  control keywords: do not remove syntactic whitespace to shorten probes.

### Maintenance idempotence requires the target hash in the approved predecessor set

- Signature: an exact endpoint rehearsal passes the create-from-approved-old
  case, then the idempotent-target case returns a signed terminal `FAILED`
  response stating `Installed predecessor is not approved`, with the actual
  installed hash exactly equal to the request's `installedSha256` target.
- Cause: the installed endpoint worker applies `approvedPredecessorSha256` to
  every destination that already exists. It does not implicitly accept
  `installedSha256` as an idempotent predecessor. The request definition listed
  only the old installed hash, so correct target bytes were rejected on the
  second application.
- Preflight: before design freeze or the first signature, parse every
  maintenance change and require its target `installedSha256` to appear in
  `approvedPredecessorSha256`, in addition to every explicitly authorized old
  predecessor. Exercise create/old-to-target, target-to-target idempotence, and
  unapproved-predecessor refusal against the exact endpoint worker and exact
  signed package.
- Recovery: preserve the failed signed draft and its rehearsal tree, withdraw
  that request identity before publication, and rebuild under a fresh request
  identity and fresh output/rehearsal roots. Add the target hash to the
  approved set without removing the old approved predecessor, repeat the
  design freeze and every static/behavior/endpoint/package/route gate, and do
  not reuse or delete the failed fixture.
- First observed: local D2S5 exact endpoint rehearsal on 2026-08-19. Preserved
  response `R_D2BA95ACEDBC_20260819230950298_d621bdc4` proves the fixture
  installed the correct target hash
  `18AD997119BD0A8BE370A76576BAE6E7A697D2F3E004904E1FD7AA45B429289E`;
  the earlier preliminary claim that old payload bytes were seeded was wrong.
  The failure was local and made no JBOD, portal-share, storage-copy, task,
  hold, cutover, deletion, inspection, or wafer mutation.

### Successor names that extend predecessor names require boundary-aware residue checks

- Signature: a clone workspace preflight reports that predecessor token
  `D2S5` or `REQ_D2S5` remains even though inspection shows it occurs only as
  the prefix of intended successor token `D2S5A` or `REQ_D2S5A`.
- Cause: a raw case-sensitive `String.Contains` residue check cannot
  distinguish a complete predecessor identifier from that identifier embedded
  in a longer valid successor name.
- Preflight: when a successor deliberately extends the predecessor token, use
  identifier-boundary-aware matching for logical IDs and exact literal checks
  for path roots. Add a positive control containing only the successor token
  and a negative control containing the complete predecessor token.
- Recovery: confirm the failed preflight returned before generating any file,
  replace only the logical-token checks with boundary-aware expressions, keep
  exact root-literal checks unchanged, rerun static wrapper/harness gates, and
  rerun the same non-mutating workspace preflight before apply.
- First observed: D2S5A workspace preflight on 2026-08-19. The fresh root
  contained only its already path-gated builder and clone manifest; no package,
  signature, rehearsal fixture, portal request, JBOD file, task, hold, cutover,
  deletion, inspection, or wafer state was created or changed.

### Sequential overlapping clone replacements can transform a successor twice

- Signature: a mechanical clone intended to produce `REQ_D2S5A` instead emits
  `REQ_D2S5AA` throughout the generated scripts, even though no predecessor
  token remains and every generated PowerShell file parses.
- Cause: the transform first replaced the specific token `REQ_D2S5` with
  `REQ_D2S5A`, then replaced the broader token `D2S5` with `D2S5A`. The second
  pass matched inside the already transformed successor and appended the
  suffix a second time. Parser and predecessor-residue checks cannot detect a
  semantically wrong but syntactically valid successor identifier.
- Preflight: use non-overlapping predecessor/successor tokens or one-pass
  placeholder substitution. Freeze the expected request ID separately and
  assert exact equality in every generated signer, route, endpoint, builder,
  publisher, and collector before any signature. Never rely only on absence of
  the predecessor token.
- Recovery: preserve and withdraw the generated workspace without patching or
  signing it. Build the next revision under a fresh non-overlapping identity
  and fresh roots, repeat source guards, clone remediation, exact request-ID
  assertions, wrapper/harness checks, and every downstream gate.
- First observed: generated D2S5A workspace inspection on 2026-08-19. No
  signature, endpoint rehearsal, portal publication, JBOD change, storage
  mutation, task action, hold clearance, cutover, deletion, inspection change,
  or wafer action occurred.

### A hold acknowledgement update timestamp may be a heartbeat, not hold entry

- Signature: a completed scheduled task remains permanently reported as
  `taskLastRunAfterHold=false` because the hold acknowledgement `updatedUtc`
  advances on every held processor loop while the task `LastRunTime` remains
  fixed. Consecutive signed D2 status responses showed the same task launch at
  `2026-08-19T17:24:39Z` while hold `updatedUtc` advanced from 19:35 to 20:44
  to 23:37 UTC.
- Cause: the status gate treated a mutable hold-heartbeat field as an immutable
  hold-entry timestamp. Comparing task launch time to the latest heartbeat can
  never prove a completed task ran after hold entry.
- Preflight: determine every timestamp field's writer semantics before using it
  for causal ordering. Exercise at least two held-loop updates and require an
  immutable `holdEnteredUtc`, or bind the task to a separately signed held
  launch response plus exact task last-run identity and result-manifest lineage.
  Search every downstream status, verification, cutover, and cleanup script for
  comparisons against hold `updatedUtc`; fixing only the first status reader is
  insufficient. A D3 verification draft was caught before publication because
  it repeated both the task-last-run and result-created comparisons against the
  mutable heartbeat.
- Recovery: do not rerun a completed 232.9 GB copy merely to chase a moving
  heartbeat. Preserve the signed held-launch response, verify its signature and
  exact task launch, then require the completed result manifest to bind to that
  launch and require the task Ready/result-zero and hold-match invariants in a
  fresh signed status request. A future hold schema should add immutable
  `holdEnteredUtc` separately from mutable `updatedUtc`.
- First observed: signed D2S2, D2S3, and D2S6 status sequence on 2026-08-19.
  D2S6 proves 93,709 files and 232,912,232,897 bytes complete with an intact
  result/manifest contract; no D: cutover, C: deletion, hold clearance,
  inspection-task change, or wafer abort occurred.

### Cloned endpoint rehearsals may retain an obsolete worker hash pin

- Signature: a newly signed request's exact endpoint preflight refuses before
  rehearsal because its cloned harness still pins an older portal endpoint
  worker hash, even though the current continuity-authoritative worker is the
  one the package must exercise.
- Cause: request payload cloning and endpoint-harness cloning have different
  provenance. Literal-root remediation proves paths, but it cannot prove that
  a versioned worker hash copied from an older request still names the current
  installed/source endpoint worker.
- Preflight: before signing or rehearsing any cloned endpoint harness, compare
  its worker pin to both the current endpoint source hash and the continuity
  record for the installed worker. Require an exact three-way match and rerun
  parser, wrapper, clone-literal, and exact-endpoint gates after changing it.
- Recovery: do not loosen or omit the hash. Update the harness to the exact
  current pinned worker, preserve the signed request bytes unchanged when the
  harness is outside the request, and write a new versioned clone-literal gate.
- First observed: D3A2 exact endpoint preflight on 2026-08-19. It failed before
  test-root creation, endpoint execution, portal publication, JBOD mutation,
  task action, cutover, deletion, hold clearance, or wafer action.

### Maintenance runtime failure detail is in the attached stderr artifact

- Signature: an exact endpoint negative-control rehearsal returns the expected
  signed `FAILED` response, but a harness searching `FAILURE.json.detail` for
  the verifier's exact error text reports a false assertion failure.
- Cause: the portal failure record intentionally contains a bounded generic
  summary (`Maintenance verifier failed with exit code 1`); the exact verifier
  text is preserved in the signed `MAINTENANCE.stderr.txt` response artifact.
- Preflight: freeze both response contracts. Assert the signed response state
  and generic failure class from `FAILURE.json`, then assert the exact expected
  verifier signature from the declared, hash-verified stderr artifact.
- Recovery: do not change the payload or rerun a live request. Correct only the
  local harness assertion, use a fresh rehearsal root, repeat wrapper and clone
  gates, and exercise a following control request.
- First observed: D3A2 wrong-held-launch negative-control rehearsal on
  2026-08-19. The payload failed closed as intended; no portal publication,
  JBOD mutation, task action, cutover, deletion, hold clearance, or wafer action
  occurred.

### A path-budget PASS does not prove a response extraction root is fresh

- Signature: a signed-response route gate refuses because the planned short
  laptop extraction root already contains an older response, even though the
  earlier complete-route path-budget gate passed.
- Cause: path length, component length, and route completeness were checked,
  but root freshness was not. A cloned `C:\A3S` root belonged to an earlier
  D2S3 response and was therefore unsafe for D3A2 extraction.
- Preflight: every planned local extraction, rehearsal, final, partial, and
  work root must have an explicit expected existence disposition. New roots
  must be proven absent both when the complete route is frozen and immediately
  before the first write. Clone-literal remediation does not prove freshness.
- Recovery: never merge, overwrite, or delete the older evidence. Select a
  newly path-gated short root, rerun parser/wrapper/harness checks, and create a
  supplemental exact response-recovery route gate bound to the signed response
  ID and ZIP hash before extraction.
- First observed: D3A2 signed-response route gate on 2026-08-19. It refused
  before route-gate creation, response copy, extraction, JBOD mutation, task
  action, cutover, deletion, hold clearance, or wafer action.

### Windows evidence probes must not use statement pipelines or wildcard roots

- Signature: an inline `foreach (...) { ... } | ConvertTo-Json` fails with
  `An empty pipe element is not allowed`, or `rg work/JBOD_*` fails because
  PowerShell passes the wildcard directory token literally to ripgrep.
- Cause: a PowerShell statement was piped without first materializing its
  output, and Unix-style wildcard-root assumptions were reused on Windows.
- Preflight: assign statement results first, for example
  `$rows = @(foreach (...) { ... })`, then pipe `$rows`. Invoke `rg` with one
  literal existing root and `--glob` filters; never put a wildcard in a root
  path argument. Keep file inventory and text search as separate probes so a
  no-match exit cannot invalidate already collected evidence.
- Recovery: correct the read-only probe and rerun it. Do not change, rebuild,
  republish, or rerun an operational artifact because a diagnostic shell probe
  failed.
- Repeated during the D2S6 response audit on 2026-08-19. Both failures were
  read-only and changed no request, response, JBOD file, task, hold, storage,
  inspection, or wafer state.
- Repeated during the C2T2 terminal-failure hash inventory on 2026-08-19 when
  an inline `foreach` was piped directly to `ConvertTo-Json`.  The parser
  refused the read-only probe before hashing.  Use an explicit `$rows =
  @(foreach (...) { ... })` assignment even for short one-line inventories;
  command brevity is not an exception to this rule.

### Clone residue checks must account for serialized path escaping

- Signature: a clone reports zero old-root residue, but `rg` finds an old path
  such as `C:\\S6B` inside JSON. The transform and residue check searched only
  for the runtime literal `C:\S6B`, while JSON stored the same path with escaped
  backslashes.
- Cause: text-level clone validation treated serialized JSON text as though it
  were an already parsed runtime string.
- Preflight: parse JSON and compare normalized runtime path values, or check
  both escaped serialized and runtime literal forms. After cloning, run one
  bounded identifier/root search across every generated text file and require
  zero predecessor hits before changing payload logic, signing, or packaging.
- Recovery: patch the unsigned generated JSON to the fresh root, repeat the
  bounded predecessor search, and keep the clone unsigned until every exact
  source/generated pair passes the literal-root remediation gate.
- First observed: unsigned D2S7 workspace clone on 2026-08-19. No signature,
  portal publication, JBOD file, task, hold, cutover, deletion, inspection, or
  wafer state changed.

### New literal roots in a successor require an explicit added-root contract

- Signature: clone-literal preflight reports
  `UNDECLARED_GENERATED_LITERAL_ROOT` for a deliberate new safety-evidence root
  that does not exist in the predecessor, even though every replaced and
  unchanged predecessor root is correct.
- Cause: the original remediation schema represented only `REPLACED` and
  `UNCHANGED_ALLOWED`; it could not distinguish a deliberate new literal root
  from accidental clone residue.
- Preflight: declare each deliberate new root with disposition `ADDED`, an
  empty source root, and the exact generated root. The checker must prove that
  the root is absent from the source and present in the generated file. Do not
  omit the source/generated pair or mislabel the addition as unchanged.
- Recovery: extend the metadata-only checker with fail-closed `ADDED` support,
  rerun its prior-manifest regression, then rerun the successor preflight and
  persisted gate before package construction.
- First observed: D2S7 collector added exact completed-result root `D:\A2` so
  local response verification can pin the signed result-manifest lineage. No
  portal, JBOD, task, hold, cutover, deletion, inspection, or wafer mutation
  occurred.

### Invoke the exact declared action switch, not a guessed apply synonym

- Signature: a gated rehearsal script rejects `-Apply` with `A parameter
  cannot be found that matches parameter name 'Apply'` because its mutually
  exclusive action switches are `-Preflight` and `-Rehearsal`.
- Cause: the caller guessed a conventional mutation-switch name instead of
  using the exact parameter set already reported by wrapper preflight.
- Preflight: read and assert the wrapper gate's `declaredParameters` before the
  action call. Bind only the exact declared action switch and record it in the
  invocation evidence; do not infer that every script uses `-Apply`.
- Recovery: confirm parameter binding failed before target execution and that
  no output/share root exists, then rerun once with the exact declared switch.
- First observed: D2S7 mapped-share provider rehearsal on 2026-08-19. The
  failed call created neither its share rehearsal root nor its local gate and
  changed no portal request, JBOD file, task, hold, storage, inspection, or
  wafer state.
### Strict-mode cutover verifier directly reads an optional config property

- Signature: a fresh Windows PowerShell 5.1 cutover rehearsal stops before
  creating its planned output root with `The property
  'productionRoutingEnabled' cannot be found on this object`.
- Cause: the verifier enabled `Set-StrictMode -Version Latest` and directly
  dereferenced an optional property that is absent from the pinned processor
  config-v3 representation.  Review-only, XML-disabled, and
  production-ineligible state was otherwise preserved.
- Preflight: every new strict-mode config/result/acknowledgement consumer must
  enumerate the exact pinned object's property set and use one bounded
  optional-property helper for fields that are not required by that schema.
  Required properties remain direct fail-closed checks; an absent optional
  production-routing flag defaults only to the safe `false` value.  Exercise
  the exact representation with the property both absent and explicitly
  false under Windows PowerShell 5.1 before signing.
- Recovery: preserve the failed fresh rehearsal root, create a distinct fresh
  root, patch only the representation boundary, rerun wrapper and harness
  safety checks, and repeat every behavior and exact-endpoint case.  Do not
  change the target paths, hold state, detector authority, or inspection
  settings to compensate.
- First observed: C2A local behavior rehearsal at `C:\C2AB` on 2026-08-19.
  No signed request, portal queue, JBOD file, scheduled task, hold, wafer,
  cutover, source, or inspection state changed.
### Compressed PowerShell comparison joins the property name and operator

- Signature: a non-mutating Windows PowerShell 5.1 request-signing preflight
  reports `Where-Object: The input name "path-eq..." cannot be resolved to a
  property`.
- Cause: source compression removed the syntactic whitespace between a
  `Where-Object` property name, the `-eq` operator, and its operand.  The
  parser accepted the script, but the runtime bound the joined text as one
  property name.
- Preflight: never remove whitespace around PowerShell comparison operators or
  parameter tokens to shorten a script.  Use an explicit script block such as
  `Where-Object { $_.path -eq 'value' }` for all package-cardinality and hash
  selections, then execute the exact non-mutating preflight under Windows
  PowerShell 5.1 in addition to AST parsing.
- Recovery: prove that the preflight created neither partial nor ready output,
  patch only the comparison expression, rerun wrapper/harness checks, and
  repeat the same preflight before signing.
- First observed: C2A request-signing preflight on 2026-08-19.  The C2A signed
  and partial roots remained absent; no portal, JBOD, task, hold, wafer,
  cutover, deletion, or inspection state changed.

### Exact endpoint package extraction must preserve the `.ready` queue basename

- Signature: the exact final-ZIP endpoint rehearsal exits cleanly but produces
  zero response directories; the first case remains in `incoming` under a
  generic directory name such as `extract`, and the harness reports a response
  count of zero.
- Cause: the endpoint queue enumerates request directories by the `*.ready`
  contract.  Extracting the exact ZIP contents directly into a directory named
  `extract` preserved the bytes and signature but removed the queue-visible
  `REQ_*.ready` basename, so the endpoint correctly ignored it.
- Preflight: include the request-directory basename in the final extraction
  plan.  Extract an exact request ZIP into a fresh directory whose leaf is the
  signed request ID plus `.ready`, assert that exact basename before invoking
  the endpoint, and prove the first request advances from incoming to one
  signed terminal response.  Content, signature, and path-budget checks do not
  replace this queue-discovery assertion.
- Recovery: preserve the ignored incoming tree and failed final partial as
  evidence.  Do not rename or reuse them.  choose a fresh extraction,
  endpoint-test, gate, and partial root; patch only the extraction layout; then
  repeat parser, wrapper, harness, path, and exact-endpoint gates before
  publication.
- First observed: C2A final extracted-package rehearsal at `C:\C2AF` on
  2026-08-19.  The laptop processor config was restored to its original pinned
  hash.  No portal publication, JBOD file, scheduled task, hold, wafer,
  cutover, deletion, or live inspection state changed.

### A command invocation used as a comparison operand requires parentheses

- Signature: a rehearsal reports that a copied file hash changed even though
  direct hashing proves the source and copy are byte-identical.  Source text
  has the form `if (Get-Sha $path -ne $expected)`, and the script parses with
  no AST errors.
- Cause: PowerShell command-mode parsing binds `-ne` and the expected value as
  additional arguments to `Get-Sha`; it does not necessarily compare the
  command's returned hash.  A syntactically valid script can therefore execute
  a semantically different command invocation.
- Preflight: whenever a function, cmdlet, or native command supplies one side
  of a comparison, fully materialize or parenthesize its result first, for
  example `$actual = Get-Sha $path; if ($actual -ne $expected)` or
  `if ((Get-Sha $path) -ne $expected)`.  Exercise the exact positive fixture
  under Windows PowerShell 5.1; parser and static harness passes alone do not
  prove command-mode comparison semantics.
- Recovery: preserve the failed rehearsal tree, patch only the command-result
  boundary, select a fresh rehearsal root, rerun parser/wrapper/harness gates,
  and repeat the same behavior matrix before signing.
- First observed: C2T local tray-restart behavior rehearsal at `C:\C2TB2` on
  2026-08-19.  It failed before task simulation or Completed Lot probing.  No
  portal, JBOD file, scheduled task, hold, wafer, cutover, deletion, or live
  inspection state changed.

### Completed Lot fixtures must be self-contained and catalog-valid

- Signature: a copied viewer and `dashboard_manifest.json` have valid hashes,
  but the launcher's `--catalog-check` fails because a manifest row references
  BF/DF review artifacts that were not copied into the rehearsal root.
- Cause: the fixture selected a historical dashboard directory as though the
  executable and manifest alone formed a complete behavior fixture.  Completed
  Lot catalog validation resolves every declared artifact relative to the
  state root; a manifest can be syntactically valid yet incomplete there.
- Preflight: select a previously sealed self-contained launcher fixture whose
  catalog, UI, and side-selector probes all passed.  Copy its complete bounded
  top-level evidence set, including every manifest-referenced artifact, and
  verify the prior persistent launch record before using it as a new control.
  Never infer fixture completeness from filenames or hashes alone.
- Recovery: preserve the failed fixture and launcher log, choose a fresh test
  root, replace only the fixture source with the sealed self-contained control,
  and rerun the same three Completed Lot probes before signing.
- First observed: C2T local behavior rehearsal at `C:\C2TB3` on 2026-08-19.
  The persistent log identifies missing historical BF/DF artifacts for a
  manifest row.  No portal, JBOD file, scheduled task, hold, wafer, cutover,
  deletion, or live inspection state changed.

### Do not normalize an installed processor evidence root from memory

- Signature: an exact local endpoint matrix passes with a synthetic fixture,
  but the matching signed live response fails before task action because the
  payload requests
  `...\AllWaferProcessorV2\state\processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json`.
  The installed processor writes the acknowledgement under
  `...\AllWaferProcessorV2\processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json`.
- Cause: a new payload invented a conventional `state\processor` nesting even
  though the immediately preceding signed C2A payload and live response had
  already pinned the installed `processor` root.  The local fixture reproduced
  the invented path and therefore could not expose the live mismatch.
- Preflight: source every installed evidence path from the latest matching
  signed live pass or a separately signed exact-path diagnostic.  Require a
  three-way literal equality among the prior live payload, successor payload,
  and complete-route gate.  Synthetic fixtures must be generated from that
  pinned literal; they may not define it independently.
- Recovery: collect and checkpoint the matching signed failure, preserve its
  exact stderr, withdraw that request identity, and build a fresh successor
  using the signed-live `processor` root in payload, behavior fixture, endpoint
  fixture, and route gate.  Repeat all exact gates and do not reuse the failed
  request identity.
- First observed: signed C2T response
  `R_76C805E3EB90_20260820011809952_b83cbb04` on 2026-08-19.  Failure occurred
  before any tray task stop/start or Completed Lot probe.  The C2A config and
  cooperative hold remain active; no wafer, deletion, inspection task, or
  production-routing state changed.
- Repeated prevention hit: C2T2 final-builder preflight retained predecessor
  laptop extraction root `C:\A10S` while the successor route gate pinned
  `C:\A11S`.  The fail-closed preflight made no writes.  Before rerunning a
  successor builder, search every operational script and manifest for all
  predecessor request IDs, test roots, response roots, gate names, and ready
  basenames; require zero undeclared predecessor literals rather than relying
  on the individually edited route script.

### Safety-utility switches must come from the exact installed param block

- Signature: a local guard invocation stops with `A parameter cannot be found
  that matches parameter name ...` before the intended preflight runs.  Two
  examples were guessing `-PowerShellPath`/`-RequireModes` for the wrapper
  validator and guessing `-AsJson` for the continuity validator.
- Cause: related Argos utilities intentionally expose different contracts.
  `Confirm-ArgosPowerShellWrapper.ps1` accepts `-PowerShellScript` and
  `-RequirePreflightSwitch`; `Confirm-ArgosProjectContinuity.ps1` accepts only
  `-ProjectRoot`; `Confirm-ArgosCodexSessionSafety.ps1` does accept `-AsJson`.
  A familiar switch on one utility is not evidence that another supports it.
- Preflight: before composing any multi-utility command, read the exact local
  script's bounded `param(...)` block and construct each invocation from only
  those declared names.  Run utilities as separate statements whose output is
  bounded; do not infer switches from prose, a neighboring tool, or memory.
- Recovery: confirm the intended target did not execute, rerun the failed
  static guard with its declared parameters, and make no target-code or live
  state change to compensate for a caller-side binding error.
- First observed: C2T2 response-collector static validation on 2026-08-19.
  Both binding failures occurred before the collector preflight, response
  extraction, endpoint mutation, scheduled-task action, hold change, wafer
  action, or portal publication.

### A singleton tray process is not equivalent to its scheduled-task state

- Signature: `Start-ScheduledTask` briefly reaches `Running`, but a later task
  snapshot is `Ready` and a restart payload fails with `tray task is not
  Running after restart`.  The tray can nevertheless remain visible because
  another process already owns its named singleton mutex.
- Cause: `Show-JbodAllWaferTray.ps1` owns
  `Local\ArgosEdgeLabAllWaferTrayReviewOnlyV2`; a second scheduled instance
  signals the existing process and exits successfully.  Task Scheduler then
  reports `Ready`, so task state alone neither proves that the tray is absent
  nor proves that the intended task-owned instance replaced the predecessor.
- Preflight: inspect the exact installed tray source and task action, enumerate
  only PowerShell processes whose normalized command line contains that exact
  script and state root, and bind process ID plus creation time to the restart.
  Record both task state and exact-process evidence.  Rehearse the states of no
  process, one task-owned process, one singleton process while the task is
  Ready, and ambiguous multiple exact processes.
- Recovery: stop only the exact tray process and/or exact tray task authorized
  by the request; never touch processor, scribe, Insite, inspection, or portal
  tasks.  Wait for the old exact process to exit, start the pinned tray task,
  then require one fresh exact process with a later creation time and a stable
  health observation.  Do not require permanent task state `Running` when the
  singleton contract can legitimately return the launcher task to `Ready`.
- First observed: signed C2T2 response
  `R_D2B0F0F9AD8A_20260820012815352_53bbbbef` on 2026-08-19.  The response is
  terminal and signed; its exact stderr SHA-256 is
  `1F3C60F5DC9DB29777493BF6998341E9F97DE676C1F8860048FAE9F189DBAF43`.
  The cooperative hold remained active and no C: source deletion, inspection
  task change, or production routing was authorized.  Because failure occurred
  after the restart call, exact tray-process outcome requires the successor's
  direct audit rather than inference from task state.

### Wrap conditional collection output at the assignment boundary

- Signature: strict mode reports `The property 'Count' cannot be found on this
  object` only in the exactly-one fixture case, while zero and multiple rows
  were intended to use the same collection contract.
- Cause: `$rows = if (...) { @($value) } else { @(Get-Rows) }` does not preserve
  the branch's inner array wrapper; PowerShell enumerates the branch output and
  scalarizes one row at assignment.  The later `$rows.Count` is therefore read
  from the row object instead of an array.
- Preflight: put the array boundary outside the conditional:
  `$rows = @(if (...) { @($value) } else { @(Get-Rows) })`.  Exercise zero,
  exactly one, and multiple rows under strict-mode Windows PowerShell 5.1.
- Recovery: preserve the failed rehearsal root, patch only the outer collection
  boundary, choose a fresh root, and rerun the complete behavior matrix.
- First observed: C2T3 exact-tray-process behavior rehearsal at `C:\C2TB6` on
  2026-08-19.  Direct replay of the preserved one-process fixture proved the
  correction.  No portal, JBOD, scheduled-task, hold, wafer, storage, or live
  inspection state changed.

### Rehearsal filesystem overrides must not replace production config literals

- Signature: a positive short-root rehearsal fails with `outputRoot changed:
  D:\A2\o` even though the signed target config correctly contains the required
  production D: path.
- Cause: the verifier compared a production config property to the synthetic
  rehearsal directory override.  Those values serve different contracts: the
  config must remain pinned to its live literal, while the verifier's file
  existence and wait probes may be redirected into a bounded fixture tree.
- Preflight: assert config properties against fixed approved production paths;
  separately path-gate and probe the invocation-supplied rehearsal roots.
  Include a positive short-root fixture so accidental coupling fails locally.
- Recovery: preserve the failed rehearsal root, patch only the comparison
  target, choose a fresh root, and repeat the complete behavior matrix.
- First observed: C2B hold-release behavior rehearsal at `C:\C2BB1` on
  2026-08-19.  It failed before portal publication, JBOD config replacement,
  hold clearance, processor activation, task action, wafer action, or deletion.

### Freeze endpoint-driven rehearsal transport before signing a payload

- Signature: a new maintenance payload passes direct `-Rehearsal` behavior
  tests and is signed, but the exact endpoint rehearsal cannot redirect the
  packaged entry point into its fixture because the endpoint intentionally
  invokes maintenance entry points without command-line arguments.
- Cause: the payload supported only its explicit `-InvocationManifest`
  parameter.  The installed endpoint's exact rehearsal contract supplies the
  file-backed manifest through a request-specific process environment variable
  while invoking the signed entry point with no arguments.  Signing occurred
  before that endpoint transport contract was exercised, so the signed copy
  became stale as soon as the missing environment-variable support was added.
- Preflight: before the first signature, exercise the same no-argument entry
  point call the installed endpoint makes, with the exact request-specific
  environment variable and schema.  Require the direct behavior gate, exact
  endpoint gate, route gate, and payload hash to be final before signing.  A
  signature freezes the payload; no source edit after signing may reuse that
  request identity.
- Recovery: retain the unpublished signed directory as `WITHDRAWN`, choose a
  fresh request identity, rerun every gate against the final payload hash, and
  sign only after those gates pass.  Never overwrite or silently reuse the
  earlier signed artifact.
- First observed: unpublished local `REQ_C2V` during the lot `62631-586`
  D-path validator build on 2026-08-19.  Nothing was published; no portal,
  JBOD, config, task, wafer, storage, hold, or production state changed.

### PowerShell keywords require lexical whitespace even when the parser passes

- Signature: Windows PowerShell 5.1 reaches a previously unexercised branch
  and reports `The term 'return$v' is not recognized`, even though the file
  has zero parser errors and the main positive fixture passed.
- Cause: compact source fused a language keyword with the following variable
  or quoted expression, for example `return$v` or `throw'Message'`.  These can
  parse as command invocations and therefore escape a parser-only gate until
  that exact branch executes.
- Preflight: reject keyword-token fusion statically for at least
  `return$`, `return@`, `throw'`, `throw\"`, `break$`, and `continue$` in
  every packaged PowerShell file.  Keep ordinary whitespace after keywords,
  and exercise every conditional return/throw branch that can consume live
  schema variants, including normalization fallbacks that synthetic happy
  paths do not enter.
- Recovery: collect and preserve the matching signed terminal failure, patch
  only the lexical defect, rerun the static fusion scan plus the full behavior,
  exact-endpoint, boundary, route, and final extracted-package gates, and use a
  fresh request identity.  Never overwrite or republish the failed identity.
- First observed: signed live `REQ_C2V1` response
  `R_62BFE69D6B2E_20260820022810235_25bed068` on 2026-08-19.  The failure
  occurred in read-only lot-key normalization.  The request authorized zero
  task actions and no source deletion, wafer action, hold change, XML, or
  production routing.

### A config-schema cutover requires an executable gate for every config consumer

> **2026-08-19 chronology correction:** the v2-only hashes below came from a
> signed snapshot created at `2026-08-19T17:29:54Z`.  Signed request `REQ_C1C`
> subsequently installed v2/v3-compatible replacements at
> `2026-08-19T17:47:13Z` and returned terminal
> `PASS_MAINTENANCE_PATCH`.  Therefore the later lot-admission failure is not
> evidence that these source patches were absent.  The remaining operational
> failure signature is a long-running scheduled worker that was not restarted
> after its entry-point file changed.  Always order signed evidence by its
> `createdUtc` before inferring current installed state.

- Signature: after a config-v3 storage cutover, inventory continues cataloging
  a newly scanned lot and the main processor status remains visible, but the
  exact lot has zero ledger rows, jobs, results, dashboard sessions, Completed
  Lot wafers, and verified-metadata matches.  Exact installed source shows the
  scribe worker, detector watchdog, and reference-registry updater still
  reject every schema except config v2.
- Cause: the cutover initially exposed strict schema guards in secondary
  scheduled workers and an end-of-pass updater.  `REQ_C1C` corrected those
  guards, but it intentionally changed no tasks.  A continuously running
  worker can therefore retain the old script in its process even after the
  on-disk replacement is correct.  Separately, inspecting an older signed
  snapshot after a newer terminal patch can make an already-fixed source
  defect look current.  Both cases leave plausible but stale `WATCHING`
  evidence unless heartbeat and process creation times are compared with the
  patch time.
- Preflight: before signing any config-schema revision, enumerate every exact
  installed caller that reads the config, freeze its predecessor hash, and run
  it or a branch-complete behavior harness against both the installed schema
  and the target schema.  Require all scheduled-worker entry points, watchdogs,
  tray/manual callers, bridge callers, dashboard/reference updaters, and the
  main processor to accept the target without weakening review-only, XML-off,
  task, identity, or routing authority.  A fresh heartbeat must be causally
  newer than the config swap and must include each worker's own status or
  exact process/task evidence; a pre-existing status file is insufficient.
- Recovery: if exact current hashes are still incompatible, patch every
  incompatible consumer together under exact predecessor and
  idempotent-target gates, including unapproved refusal and rollback.  If a
  newer signed terminal response already proves the compatible targets are
  installed, do not repatch them: restart only the explicitly authorized
  affected worker task.  In either case prove fresh per-worker heartbeats and
  a queued control acquisition.  Do not invent confirmed scribe, Insite
  history, detector eligibility, or result rows to manufacture a pass.
- First observed: exact signed data pull
  `R_9C9A50CA5769_20260819172954641_91cd3509` and corrected signed lot
  validation `R_1119FD3C6D32_20260820024358415_934723df` on 2026-08-19.
  Config v3 was live while `Run-JbodScribeProposalWorker.ps1`
  (`5887855A27709A1893328F1B0A7183749B76CD8BCB3BA2513350F94E5EAAFC43`),
  `Invoke-JbodDetectorStallWatchdog.ps1`
  (`A3A1C3A372F56147A6E8DA47E833230A6A5F95BE7340F2336EEC75ED727B8864`),
  and `Update-JbodReferenceRegistry.ps1`
  (`F92A16500C8F4B03BF85F772029EA0F59542C331C1848C53FA4150092ED80990`)
  retained v2-only guards.  Lot `62631-586` had 20 catalog acquisitions and
  zero processing rows.  The read-only diagnostic made no task, source, wafer,
  XML, or routing change.

### Admission assertions must distinguish current-scan rows from cumulative history

- Signature: a bounded worker restart succeeds far enough to emit a fresh
  queue, but its terminal verifier fails because it expects exactly ten lot
  rows and the cumulative queue contains fifty rows for five scans of that
  lot.
- Cause: the verifier filtered only by lot prefix.  `SCRIBE_IDENTITY_QUEUE`
  intentionally retains acquisition rows across scan timestamps, so lot-wide
  cardinality is not the current-scan wafer count.  The rehearsal fixture had
  only one scan and therefore did not expose this dimensional mistake.
- Preflight: every lot-cardinality assertion must pin the exact scan timestamp
  or exact expected physical-identity set as well as the lot.  Include a
  multi-scan same-lot fixture in behavior and exact-endpoint rehearsals.  A
  current scan passes only when all and only its expected slot identities are
  present; additional historical scans are reported separately and are not a
  failure.
- Recovery: preserve the signed terminal failure, do not infer that the worker
  itself failed, and issue a fresh idempotent health validator.  If the exact
  process, heartbeat, and queue are already fresh, the validator must skip a
  second restart.  Otherwise it may restart only the explicitly authorized
  task.  Never delete historical queue rows to manufacture the expected
  cardinality.
- First observed: signed live `REQ_C2S` response
  `R_CC2C4FE80991_20260820030947036_f33da7d2` on 2026-08-19.  The verifier
  found fifty cumulative `62631-586` rows after the scribe worker restart; the
  current scan expected ten.  The endpoint returned a signed terminal failure
  and advanced the request queue.  No source, wafer, XML, production route, or
  non-scribe task was changed.

### Incomplete deterministic proposal output must not poison the scribe queue

- Signature: the scribe worker emits a fresh `FAILED_RETRYING` heartbeat every
  cycle with `Refusing incomplete existing scribe proposal output: <path>`.
  The named directory exists but its terminal `SCRIBE_PROPOSAL.json` does not,
  so the first pending acquisition is selected again and every later
  acquisition remains blocked.
- Cause: the deterministic-output collision check ran before the per-wafer
  failure boundary.  An interrupted prior attempt therefore survived as an
  incomplete directory, and the collision exception escaped the whole pass
  instead of becoming a preserved, terminal, review-only hold or a fresh
  attempt.  Scheduled-task restart cannot repair this state.
- Preflight: classify every deterministic proposal path as terminal,
  recoverably incomplete, or an explicit unsafe hold before processing.  Run
  an injected-interruption fixture, a pre-existing incomplete-output fixture,
  a quarantine-name collision fixture, and a later queued control wafer.
  Require the exact interrupted tree to remain recoverable, the next attempt
  to use a clean output root, and the control wafer to receive a terminal
  proposal or review hold without restarting unrelated tasks.
- Recovery: atomically move only the exact incomplete proposal directory to a
  short, path-gated quarantine root and write a provenance record there; never
  delete or silently reuse its raster artifacts.  Recreate the deterministic
  output and keep all subsequent processing inside the per-wafer failure
  boundary.  If quarantine itself cannot complete, write a fail-closed
  operator-visible terminal hold without erasing the existing evidence, then
  continue the queue.  A completed proposal remains idempotent and is never
  regenerated.
- First observed: signed bounded `REQ_C2Q` audit response
  `R_4DB628986CE6_20260820032431411_f65450ed` on 2026-08-19.  The exact poison
  directory was
  `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals\dev-01-post-8-19_20260819164148_Slot01`.
  The live queue contained 965 rows, the current `62631-586` scan contained ten
  rows, and the worker status was `FAILED_RETRYING`.  Six current wafers had
  confirmed scribes waiting on Insite and four awaited operator proposal
  confirmation; none of those identities was inferred or changed by the
  audit.

### Live queue validators must not freeze an in-progress state count at package-build time

- Signature: a signed activation package reaches the exact endpoint safely but
  returns a terminal verifier failure because the number of current-scan rows
  in one valid workflow state increased while the package was being rehearsed,
  signed, routed, and executed.
- Cause: the verifier correctly pinned the lot, scan, and total ten acquisition
  identities, but incorrectly froze the transient confirmed-scribe/Insite-wait
  subset at six.  The scribe worker continued doing authorized work during the
  package round trip and promoted a seventh current identity, so the stale
  subset count rejected healthier live state.
- Preflight: freeze identity cardinality and safety invariants, not a transient
  progress count.  Read the exact current-scan queue once at endpoint execution,
  derive the eligible subset from that snapshot, require it to be nonempty and
  bounded by the pinned identity set, and require request coverage to equal that
  derived subset.  Rehearse progress from N to N+1 between build and execution.
- Recovery: preserve and verify the signed terminal failure, make no attempt to
  delete or demote the newly advanced row, and publish a fresh request only
  after the earlier request has a signed terminal response.  The replacement
  verifier must accept the live derived subset and still fail closed on missing,
  extra, duplicated, wrong-scan, or uncovered identities.
- First observed: signed `REQ_C2I` response
  `R_7F5BDFCA851E_20260820040001556_076dcd96` on 2026-08-19.  Six
  `62631-586_20260819173317` identities were waiting when C2I was designed;
  seven were waiting when the endpoint executed.  The endpoint terminalized
  the failure before task activation and did not poison the portal queue.

### Task-action validation must respect installed launcher defaults

- Signature: an exact task is present with its protected definition and
  principal unchanged, but an activation verifier rejects its action because
  it expects default root arguments to be repeated explicitly on the command
  line.
- Cause: the bridge worker itself defines the approved processor and bridge
  roots as parameter defaults.  The installed scheduled-task contract only
  requires the approved worker entry point; the validator added an unsupported
  requirement that both default roots also appear in `Actions.Arguments`.
- Preflight: pin the exact task name, principal, definition hash, action count,
  full approved worker path, and on-disk worker hash.  Validate the roots from
  the pinned worker defaults/config contract.  Rehearse the real launcher form
  with omitted default arguments as well as a wrong-worker negative control.
  Do not require redundant command-line text that the installed contract never
  promised.
- Recovery: preserve the signed terminal failure and publish a fresh request
  only after the earlier request is terminal.  Narrow the action assertion to
  the exact approved worker entry point while retaining protected-task
  before/after comparison and exact-process singleton checks.
- First observed: signed `REQ_C2I2` response
  `R_993CEA2F91A6_20260820040548438_a028e685` on 2026-08-19.  The request
  failed before restart with `C2I2 exact bridge task action changed`; no task,
  wafer, source, XML, or production-route mutation was accepted.

### Bounded Insite hold attempts must count distinct response packages, not changed payload bytes

- Signature: a current confirmed-scribe row remains in an Insite wait across
  retry epochs; the hold's `nextRetryUtc` advances, but `attemptCount` can stay
  at one indefinitely when Insite returns the same unresolved snapshot bytes.
- Cause: `Import-JbodLiveInsiteSnapshot.ps1` increments `attemptCount` only
  when `lastResponseSha256` changes.  A legitimate new lookup response with
  unchanged unresolved evidence has the same payload hash, so every import
  refreshes the six-hour delay without ever reaching the configured terminal
  attempt bound.
- Preflight: identify a response attempt by the exact signed response package
  identity (the resolved snapshot parent package), while retaining the payload
  hash as evidence.  Replaying the same package must be idempotent; importing a
  distinct response package must increment the attempt even when its payload
  bytes are identical.  Rehearse same-package replay, new-package/same-bytes,
  new-package/changed-bytes, legacy hold rows without an attempt ID, and the
  terminal-at-maximum transition.
- Recovery: install the corrected importer from an approved predecessor with
  rollback.  Preserve existing hold evidence.  A bounded recovery may make
  nonterminal holds immediately retry-eligible without deleting them; terminal
  holds remain explicit operator-visible holds unless separately reauthorized.
- First confirmed by installed source hash
  `9B1B5BD4DF1D2EFE97A9D3F2DC99D69BBB523FF08529FCD0AA36B530DB61E6A2`
  and signed `REQ_C2I3` response
  `R_45DB9F94FD56_20260820041305971_2b85dcfa` on 2026-08-19.  The fresh bridge
  process could not produce one request covering all seven current waits,
  consistent with explicit hold deferral; no source or wafer was deleted.

### Optional config property read directly under strict mode poisons every worker cycle

- Signature: the review-only processor remains `WATCHING`; confirmed scribe
  rows exist, verified metadata remains empty, the active retry-hold overlay is
  empty, and no pending/sent Insite request covers the current confirmed set.
  A worker restart does not help.
- Cause: `Invoke-JbodAutomaticInsiteBridgeWorker.ps1` accepted both processor
  config v2 and v3 but directly evaluated optional property
  `productionRoutingEnabled` under `Set-StrictMode -Version Latest`. The active
  v3 D-root config safely omits that property, so every `Queue-Request` cycle
  failed inside `Get-MetadataSnapshotRoot` before the exporter ran.
- Preflight: every config reader under strict mode must classify required and
  optional properties explicitly. Exercise the exact current config shape,
  including absence of every optional safety Boolean, and require absence to
  resolve only to its fail-closed default. Also exercise an explicit unsafe
  `true` value and require refusal.
- Recovery: patch the worker to test property presence before reading the
  optional Boolean; preserve refusal for explicit `true`. Restart only the
  exact pinned review-only bridge task after the worker hash is installed, and
  require a validated pending/sent package that covers the complete current
  confirmed acquisition set before calling the recovery successful.
- First observed: signed `62631-586` C2V3 snapshot on 2026-08-19. The lot had
  20 current catalog acquisitions, six scribe-confirmation route holds,
  fourteen metadata route holds, seven confirmed physical acquisitions, zero
  verified metadata matches, zero active Insite retry holds, and zero ledger
  rows. No source, task, wafer, XML, or production route changed during
  diagnosis.
### Installed PowerShell consumer changes do not refresh an already resident runner

- Signature: a signed patch installs the correct worker or ordered-consumer
  script, and a downstream artifact is updated at the new configured root, but
  the long-running catalog continues to emit the exact pre-patch route state.
  File hashes alone appear correct while the resident `powershell.exe` process
  still executes the script body loaded before the install.
- Cause: Windows PowerShell parses and loads a file-backed long-running runner
  at process start. Replacing that `.ps1` atomically changes the next launch,
  not the code already resident in the current process. A separate child script
  may also fall back to its old default root when invoked by the stale runner.
- Preflight: for every installed long-running PowerShell entry point, bind the
  exact process by command line and require exactly one process. Compare its
  creation UTC with the entry-point file `LastWriteTimeUtc` and every installed
  revision boundary that changes arguments or root propagation. A process
  older than any required boundary is stale even when its scheduled task is
  `Running` and its heartbeat is current.
- Recovery: restart only the exact authorized task at an idle/no-current-wafer
  boundary; prove a new exact PID whose creation UTC is at or after all required
  file boundaries; keep every protected task definition and principal fixed;
  then require a downstream semantic refresh (for example, metadata-matched
  catalog rows leaving `HOLD_INSITE_*`) before declaring the patch active.
  Scheduled-task state, an on-disk hash, or a fresh generic heartbeat alone is
  insufficient.
- First proven live on 2026-08-19: C2I4 replaced Insite bridge PID `18228`,
  created before worker revision
  `4F60B9C9D5AE3CC6EABE8983A6A27D5EB391D6101C07E94406CDD570748B02B2`,
  with revision-fresh PID `21096`. The same gate is mandatory for the
  all-wafer runner before accepting its D-root metadata-consumer behavior.

### The all-wafer runner repeated the strict-mode optional-property crash

- Signature: restarting `ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2`
  terminates the exact processor process immediately; the signed maintenance
  verifier later reports `expected one exact processor process after
  activation; found 0`.
- Cause: installed runner revision
  `6B61A415DF2F6852C290ABD0F794E86BE13B270A91E9E86E005B76A468404F1C`
  directly reads optional `productionRoutingEnabled` inside
  `Read-SafeProcessorConfig` under `Set-StrictMode -Version Latest`.  The
  active pinned config safely omits that property.  This is the same already
  documented representation-boundary bug previously found in the cutover
  verifier and Insite worker, but the runner was not included in the prior
  static/config-shape regression inventory.
- Preflight: before installing or restarting any strict-mode PowerShell
  consumer, enumerate every direct property dereference in the complete
  resident process entry point and its ordered children.  Execute each reader
  against the exact live config representation with every optional safety
  Boolean (a) absent, (b) explicitly `false`, and (c) explicitly unsafe
  `true`; require absent/false to run and `true` to fail before mutation.  A
  sibling worker passing this test is not evidence that the runner passes it.
- Recovery: atomically install a runner that tests property presence before
  evaluating the optional Boolean and still refuses explicit `true`; then
  restart only the exact review-only all-wafer task at an idle/no-current-wafer
  boundary.  Require exactly one revision-fresh process and downstream proof
  that all fourteen overlay-matched catalog rows leave `HOLD_INSITE_*` while
  all six scribe holds remain.  Do not restart unrelated tasks or compensate
  by changing the config schema, hold state, detector settings, or routing
  authority.
- First observed: signed C2R failure response
  `R_2C5FF0DF0894_20260820050900952_276a760c` on 2026-08-20.  The exact stderr
  SHA-256 is
  `EDFCC1F6A26C38F8137D0AF05FF89CF9C4DC8A699E3D44E24030F16860B83E7B`.
  The request reached a signed terminal failed state; it changed no protected
  task definition/principal, source wafer, XML output, or production routing.

### Checked-in guards do not share a common parameter surface

- Signature: an otherwise non-mutating guard call stops during parameter
  binding with `A parameter cannot be found that matches parameter name`, for
  example `-AsJson` on `Confirm-ArgosProjectContinuity.ps1` or `-ProjectRoot`
  on `Confirm-ArgosCodexSessionSafety.ps1`.
- Cause: the caller inferred a common switch set from a different Argos guard
  instead of reading the exact checked-in `param(...)` block. The continuity
  guard currently accepts only `-ProjectRoot`. The session-safety guard accepts
  `-AsJson` but no `-ProjectRoot`. Likewise, Windows PowerShell 5.1 does not
  support newer convenience switches such as `Get-Date -AsUTC`.
- Preflight: before every direct utility invocation, parse or inspect the exact
  current script parameter block and construct only declared parameters. Keep
  the invocation beside the exact script hash when it is part of a release
  gate. Use `[DateTime]::UtcNow` for portable UTC timestamps. Do not reuse a
  parameter list merely because two guards have similar output.
- Recovery: treat parameter binding as no execution and no evidence. Confirm
  that no output, endpoint, task, or source mutation occurred, rerun once with
  the exact declared contract, and retain only the successful result as gate
  evidence. Do not weaken or edit the guard to make an invented switch work.
- Reinforced on 2026-08-20 after the C2V6 prepublication continuity call. The
  invalid call failed before guard execution; the exact `-ProjectRoot` call
  then returned `PASS_ARGOS_PROJECT_CONTINUITY`.

### A declared task action must exactly match the payload behavior

- Signature: a signed maintenance request declares a broad task action such as
  `RESTART:<task>`, while its payload is intentionally idempotent and only
  starts the task when the exact process is absent.
- Cause: the package reused the nearest action token accepted by an older
  endpoint contract and treated it as an upper bound instead of an exact
  description. The behavioral rehearsal verified the payload but did not
  compare its action semantics with the signed declaration.
- Preflight: freeze one canonical action verb before packaging and require the
  definition, signed manifest, payload branch inventory, behavior-gate cases,
  and terminal collector to name and prove that exact verb. `START_IF_ABSENT`
  is not `RESTART`. A constrained endpoint that cannot express the required
  exact verb must be revised and rehearsed before the request is signed.
- Recovery: do not replay, clone, or use the mismatched package as a successor
  parent. Preserve a matching signed terminal response as evidence of the
  bounded action actually performed only when before/after process counts and
  protected-task invariance prove it. Mark the artifact non-reusable and make
  exact task-action equality mandatory for the next revision.
- First disclosed by the 2026-08-20 history audit: C2O1 declared
  `RESTART:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2`, but `C2O.ps1` performed
  start-if-absent. Signed response
  `R_8C013ED39A25_20260820115958213_b3ab02d5` proves a zero-to-one start and no
  protected task mutation or restart. The result remains valid review-only
  evidence; the request ZIP is non-reusable.

### A continuity checkpoint must follow the no-repeat audit

- Signature: a technically correct checkpoint is appended immediately after
  a live result, and only afterward does the broader history review expose a
  package-contract conflict or repeated execution mistake.
- Cause: terminal-result verification and continuity promotion were treated as
  one operation. The narrower terminal gate did not require a cross-history
  conflict inventory or proof that every recurring failure class had an
  executable prevention.
- Preflight: keep a new checkpoint provisional until the current machine-
  readable history audit and a fresh pre-action contract pass
  `Confirm-ArgosZeroRecurrencePreaction.ps1`. Require exact dependency hashes,
  clone-residue checks, action-semantic equality, and explicit disposition of
  every disclosed legacy exception before changing `currentPhaseCheckpoint`.
- Recovery: preserve the premature checkpoint as immutable evidence, label it
  provisional in the superseding record, block any non-reusable artifact it
  referenced, and promote only the post-audit checkpoint. Do not edit history
  to make the ordering appear correct.
- First applied on 2026-08-20: the C2O1 inspector-open checkpoint was treated
  as provisional pending the operator-requested full-history audit.

### PowerShell 7 can misbind the path-component separator array

- Signature: `Confirm-ArgosPathBudget.ps1` reports an existing short
  `R:\...` path below the effective-length warning boundary as
  `HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH`, with
  `longestComponentLength` equal to the entire path length. The same exact
  script and candidate pass under Windows PowerShell 5.1 with the real
  longest component.
- Cause: in PowerShell 7.6.5, the untyped separator expression passed to
  `String.Split` is `System.Object[]`. Overload binding does not coerce that
  array to `char[]`, so the path is returned as one unsplit component. An
  explicit `[char[]]` cast splits correctly. Windows PowerShell 5.1 binds the
  existing expression to the character-array overload as intended.
- Preflight: Windows path gates for Windows PowerShell 5.1/.NET Framework
  work must run under the exact required Windows PowerShell 5.1 host. Assert
  the reported longest component against a separately calculated bounded
  scalar for at least the maximum planned candidate. Treat a PowerShell 7
  result whose component length equals the full multi-component path as a
  guard-host incompatibility, not path evidence.
- Recovery: confirm the failed guard was metadata-only and performed no
  writes. Rerun the unchanged exact candidate under Windows PowerShell 5.1
  using one scalar path per invocation, require the correct component count
  and a terminal `PASS_PATH_BUDGET`, and retain only that host-qualified
  result. Do not weaken the component limit or ignore a genuine Windows
  PowerShell 5.1 hard stop.
- First observed on 2026-08-20 during the fresh-task FS15 direct-native notch
  preflight. The longest aliased source was 153 characters plus the required
  32-character reserve; Windows PowerShell 5.1 correctly reported a
  52-character maximum component and effective length 185. No FS15 output
  root or detector result existed when the incompatible-host result was
  discarded.

### A synthetic native-pose pass does not qualify channel-independent real-wafer transfer

- Signature: the frozen direct-native notch engine passes its synthetic
  chipout control, but all 15 sealed FS15 acquisitions terminate at
  `FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NATIVE_PERIMETER_NOT_QUALIFIED`. Twelve of
  15 BF perimeter fits qualify, zero of 15 DF fits qualify, and the remaining
  three DF fits are never attempted because the implementation conditions DF
  fitting on BF qualification.
- Cause: the synthetic control did not cover the real FS15 channel-response
  population. On the 12 BF-qualified wafers, the frozen DF fits retained only
  0.501389 through 0.696927 of their candidate boundary samples, below the
  unchanged 0.70 gate. The V3 implementation also searches DF only inside a
  BF-derived center/radius window and, if both channels qualify, averages the
  BF and DF circle parameters before the full-profile scan. Those behaviors
  contradict the declared independent native BF/DF transform contract; a
  synthetic pass cannot waive that mismatch.
- Preflight: before any held-set or peer fanout, require a sealed real-wafer
  multi-acquisition regression and statically trace both channel fits. BF and
  DF must each fit the complete full-resolution perimeter without being
  conditioned on the other channel's qualification or pose. Channel agreement
  is a diagnostic gate only; transforms must not be averaged. Require the
  source implementation, machine contract, and summary to state the same
  behavior.
- Recovery: preserve the exact failed FS15 root and hashes as review-only
  terminal hold evidence. Do not tune thresholds or morphology from the
  exposed FS15 outcomes, do not run the nine V1E holds or 77 peers, and do not
  reuse V3 as a successor parent. A corrected revision must use an explicitly
  partitioned development set, keep FS15 exposure recorded, and reserve a new
  independent paired BF/DF validation set before any fanout claim.
- First observed in `work/PNR3/FS15_NATIVE_V1` on 2026-08-20. Summary SHA-256
  is `2FCC3DB1D76E245FDEA81E84CDCFD231AAC239536B9C8EBB94BA67FA65BF2219`.
  The run created exactly 15 hashed audit files plus the summary, with no
  missing or unexpected output, and retained review-only, training-ineligible,
  XML-ineligible, and production-ineligible authority.

### Static portal request IDs must be unique across the response archive

- Signature: a newly published signed request remains in the gateway request
  share while a response collector immediately finds a signed response with
  the same `requestId` whose archive timestamp predates the new publication.
  A collector keyed only by `requestId` can therefore mistake historical
  terminal evidence for the current round trip.
- Cause: the request used a short static identifier without first checking
  all accessible request, processed/archive, response, and endpoint-ledger
  namespaces. The collector matched only `requestId`; it did not bind the
  candidate to the exact newly signed request manifest hash and publication
  boundary.
- Preflight: generate a high-entropy timestamp/GUID request ID and prove it is
  absent from every accessible request/archive/response namespace before the
  first signature. Freeze the exact signed request-manifest hash. A response
  candidate must be newer than the recorded publication boundary and, where
  the installed response schema exposes it, must carry the exact request
  manifest hash. Reject any pre-existing response candidate before publish.
- Recovery: do not delete or overwrite the pending request and do not publish
  another request to the endpoint. Preserve the stale response as historical
  evidence only. Wait for a signed terminal response created after the exact
  publication; validate its signature and request binding before extraction.
  If the static-ID collision prevents terminalization, use only a separately
  rehearsed manual/admin recovery path after proving the exact queue and
  ledger state.
- First observed on 2026-08-20 after publishing the bounded read-only C2R
  scribe-evidence request at `2026-08-20T13:25:58.0307719Z`. The new request
  ZIP SHA-256 is
  `01DEE943F479F059BA3DF596C160CBC2D708C40FCE212DFBDDFC8EBB05CD4B8D`.
  The collector refused terminalization because the current request remained
  pending while an older response with `requestId=REQ_C2R` already existed.
  No stale payload was extracted, no task action was authorized, and no JBOD
  processor or wafer state was changed.

### Windows PowerShell 5.1 cannot directly array-wrap a generic object list in a result manifest

- Signature: a bounded Windows PowerShell 5.1 image-analysis harness completes
  all expensive per-hypothesis result files, then terminates with `Argument
  types do not match` before writing its aggregate JSON. The failure occurs
  when an ordered result object assigns `@($genericObjectList)` directly.
- Cause: Windows PowerShell 5.1 can fail its dynamic conversion of a
  `System.Collections.Generic.List[object]` inside an array-subexpression even
  though piping the same list enumerates its members correctly. The failure is
  in result aggregation, not the C# image reader or a detector threshold.
- Preflight: for every generic list stored in JSON or a PSCustomObject, first
  enumerate it through a bounded pipeline such as
  `@($list | ForEach-Object { $_ })`. Reject direct
  `@($genericObjectList)` assignments in Windows PowerShell 5.1 harnesses.
  Keep the aggregate write create-new so this late failure cannot overwrite a
  prior result.
- Recovery: preserve the failed fresh output root as terminal diagnostic
  evidence and never reuse or patch it. Replace only the incompatible list
  materialization, rerun wrapper/harness/path gates on the changed exact
  bytes, and execute into a new path-gated root. Confirm that the already
  generated per-hypothesis JSON remains diagnostic-only.
- First observed on 2026-08-20 in the local multi-channel/polarity scribe
  regression at `R:\smc\g1`. All four normal-case reader JSON files were
  produced before aggregate construction failed. No JBOD, portal, scheduled
  task, production, XML, training, or wafer state changed.

### A nested forced module import can remove a caller-visible command in Windows PowerShell 5.1

- Signature: a Windows PowerShell 5.1 regression imports module A, then imports
  module B whose initialization executes `Import-Module -Force` for module A.
  A command exported by module A is no longer visible to the calling script,
  which fails with `The term '<command>' is not recognized` before the gate
  result is written.
- Cause: forcing the same module from inside another module replaces the
  caller-visible module instance with a nested-scope instance. The dependency
  remains callable inside module B, but a command that the caller imported
  before B may disappear from the caller's command table.
- Preflight: nested modules must not force-reimport a dependency that callers
  may also invoke. Import the dependency without `-Force`, or use an explicit
  module-qualified call and test caller visibility after all module imports.
  Regression harnesses that call both modules must import them in the exact
  production order and assert every required command before mutation.
- Recovery: preserve the failed output root or absent-output result as
  diagnostic evidence. Remove only the nested `-Force`, rerun exact harness,
  wrapper, and path gates, and use a fresh create-new output path. Do not
  reinterpret the missing command as an image or MES failure.
- First observed on 2026-08-20 in the local current-image/MES identity-overlay
  regression targeting `R:\smc\identity-overlay-g1.json`. Preflight passed,
  no result file was created, and no JBOD, portal, task, production, XML,
  training, detector, or wafer state changed.

### A module cannot call a command imported only by one of its nested dependencies

- Signature: module C imports module B; module B imports module A; a function
  defined in C calls an exported command from A and fails under Windows
  PowerShell 5.1 with `The term '<command>' is not recognized`, even though B
  can call A and all three module imports succeeded.
- Cause: nested module imports are scope-local dependencies, not transitive
  command exports. Importing B does not make A's commands directly visible to
  functions defined in C unless C imports A itself or B re-exports a bounded
  wrapper.
- Preflight: every module must directly import each module whose exported
  commands it calls. After the exact production-order imports, assert each
  directly called command with `Get-Command` before mutation. Do not rely on a
  dependency-of-a-dependency being caller-visible.
- Recovery: preserve the failed or absent output as diagnostic evidence,
  directly import the missing dependency without `-Force`, rerun harness,
  wrapper, and scalar Windows PowerShell 5.1 path gates, and use a fresh
  create-new output path.
- First observed on 2026-08-20 in the candidate snapshot-envelope regression
  targeting `R:\smc\candidate-envelope-g1.json`. Preflight passed, but the
  gate created no result because the envelope module called the candidate
  contract command imported only by its canonical-hash dependency. No JBOD,
  MES, portal, source image, task, wafer, XML, training, or production state
  changed.

### Add-Member metadata on an ordered dictionary is not serialized as dictionary content

- Signature: a Windows PowerShell 5.1 producer builds request rows as
  `[ordered]` dictionaries, attaches required provenance fields with
  `Add-Member`, writes JSON successfully, and the readback object lacks those
  fields. A downstream exact-contract test then fails under strict mode with
  `The property '<name>' cannot be found on this object`.
- Cause: `Add-Member` adds an adapted PowerShell member to the dictionary
  wrapper, not a key/value entry enumerated by `ConvertTo-Json` as dictionary
  content. The in-session object can appear augmented while the serialized
  request silently omits the required field.
- Preflight: whenever a JSON row is an `IDictionary`, add required serialized
  fields by key assignment (`$row['name']=$value`) and verify JSON readback.
  Reserve `Add-Member` for PSCustomObject rows, and include an exact property-
  presence plus hash readback assertion before a request may leave staging.
- Recovery: retain the failed create-new regression root as diagnostic-only,
  change only the insertion mechanism, rerun exact harness/wrapper/path gates,
  and write to a fresh root. Do not patch the already written request.
- First observed on 2026-08-20 in the local pending-Insite V2 exporter gate at
  `R:\smc\exporter-v2-g1`. The candidate request was local only; no JBOD,
  portal, task, detector, wafer, XML, training, or production state changed.

### A shorter direct-client timeout can strand a gateway-maintenance work root before its ledger

- Signature: a signed request uploaded through the constrained gateway
  maintenance endpoint begins processing, the direct client times out first,
  and no endpoint ledger is initially visible. Resuming the exact request then
  produces a signed terminal `FAILED` response with `Maintenance request work
  root already exists.`
- Cause: the direct caller timeout was shorter than the endpoint function's
  child-worker timeout. The client cancellation occurred after the installed
  endpoint worker created its deterministic request work root but before it
  committed the ledger. That installed worker treats the pre-existing work
  root as fatal instead of an exact resumable attempt or quarantined failed
  attempt.
- Preflight: make every diagnostic enumeration bounded before signing, and set
  the direct caller and shell timeouts beyond the endpoint's declared worker
  timeout. Before any retry, query the exact request ledger/response through
  the constrained endpoint. Never upload the same signed request twice.
- Recovery: preserve the exact signed failed response and stranded work root;
  do not delete, rename, or reuse either. Only after the exact request has a
  signed terminal ledger may a new high-entropy request ID be issued. Shorten
  the audit so it cannot enumerate an accumulated queue/hold tree, run fresh
  path/harness/pre-action/final-ZIP gates, and use a fresh local output root.
- First observed on 2026-08-20 for constrained gateway audit request
  `REQ_20260820T151509479Z_CD8C812DA38C`. Its signed terminal response is
  `R_DBCD5AAEBC3E_20260820151921269_520ddcc6`, response-manifest SHA-256
  `417E665F84D68345C015E179D203E8FCD849B718EB3CE64AEBFB9CDD6543CFB1`.
  The portal request queue and all scheduled tasks were unchanged.

### A JEA virtual-account maintenance child can block indefinitely on an authenticated share alias

- Signature: a bounded read-only gateway maintenance payload produces no
  stdout or stderr and reaches the full child-worker timeout when it reads or
  hashes paths beneath the gateway share alias, even though the same paths are
  immediately readable by the interactive or scheduled-task account.
- Cause: the constrained endpoint launches its child under a JEA virtual
  account. That identity cannot authenticate to the share behind the alias;
  storage capacity and path existence do not grant network-share credentials.
  A direct file call may block instead of returning a prompt access-denied
  exception.
- Preflight: every payload sent through `ArgosGatewayMaintenance` must pass an
  exact-byte execution-boundary gate that rejects the configured share alias,
  UNC paths, mapped drives, share-root variables, and share-tree enumeration.
  The payload may inspect gateway-local status, logs, outbox, sent, ledger, and
  installed-code paths only. Share-side evidence must be acquired separately
  under the authorized share identity, hashed, frozen in the request contract,
  and correlated by request ID and manifest hash. A declaration that the
  action is read-only is not an access preflight.
- Recovery: never retry or re-upload the timed-out request. Wait for and retain
  its signed terminal response. Mark that package non-reusable. Build a new
  high-entropy request whose source and signed payload contain no share access,
  run the new execution-boundary gate plus the existing path, wrapper, harness,
  zero-recurrence, and final-ZIP gates, and keep all queue/task mutations at
  zero until the local-only audit proves the exact state.
- First observed on 2026-08-20 for request
  `REQ_20260820T152233410Z_53444CCF466F`. It terminalized as signed `FAILED`
  response `R_D1F41FA9B0B9_20260820154017558_64ce5cd6`; response-manifest
  SHA-256 `7BE87F393EAC8B6A9E1BEE33C8E81048525EF85352C1C8472C30455170C27D1D`
  and failure SHA-256
  `3FC7192C38FD4CA8E09F75837CC39E0D1C07D6721011A1E47A833DA8EF2A5BF3`.
  The child timed out after 900 seconds with zero stdout/stderr. No portal
  queue or scheduled-task mutation was authorized or performed.

### Windows PowerShell 5.1 CodeDOM compilation can fail when TEMP and TMP are mapped-share paths

- Signature: `Add-Type -Path` under Windows PowerShell 5.1 fails with
  `A device attached to the system is not functioning` when both `TEMP` and
  `TMP` point to a mapped SMB drive, even though ordinary files on that drive
  are readable and writable.
- Cause: the Windows PowerShell 5.1 CodeDOM compiler requires a local
  filesystem temporary workspace for intermediate compiler files. A writable
  mapped share is not an interchangeable compiler temporary root.
- Preflight: before source compilation, resolve `TEMP` and `TMP`, classify
  local versus mapped/UNC storage, and compile a bounded probe under the exact
  runtime. If only a mapped/UNC root is authorized for durable outputs, use a
  proven local compiler-temporary root or a precompiled assembly; never infer
  compiler compatibility from ordinary share access.
- Recovery: preserve the failed create-new compiler/output roots, do not reuse
  them, and use a fresh root after choosing a proven compilation boundary.
  Keep durable and resource-heavy artifacts on the operator-approved drive.
- First observed on 2026-08-20 while validating the exact current
  `62631-586` Slot01/03/04 scribe crops. Failed evidence roots
  `I:\C2R_MANUAL\a1` and `I:\C2R_MANUAL\t1` are retained. No source image,
  slot folder, JBOD task, portal queue, wafer, or production state changed.

### PowerShell 7 Add-Type explicit reference lists replace defaults and can expose forwarded-assembly failures

- Signature: PowerShell 7 `Add-Type` compilation first reports missing LINQ
  types when `-ReferencedAssemblies System.Drawing` is supplied, then reports
  a missing forwarded drawing assembly when `System.Drawing.Common` is merely
  loaded before compiling with the default reference set.
- Cause: an explicit PowerShell 7 reference list replaces rather than augments
  the compiler defaults, while loading an assembly into the runtime does not
  necessarily add its forwarded compile-time reference to Roslyn.
- Preflight: do not mechanically reuse Windows PowerShell 5.1 `Add-Type`
  reference arguments under PowerShell 7. Pin the exact runtime and compiler,
  enumerate every compile-time reference, and run a bounded compile/load probe
  before the real build. Prefer the established .NET Framework compiler for
  unchanged .NET Framework source when that exact route is already proven.
- Recovery: preserve failed probe roots, select a fresh output root, and rerun
  the exact compiler/load probe before building the target. Do not alter the
  image reader or its thresholds to work around a compiler-boundary failure.
- First observed on 2026-08-20 at `I:\C2R_MANUAL\t2\probe` and
  `I:\C2R_MANUAL\t3\probe`. The successful exact-source assembly was produced
  separately with the .NET Framework compiler. No slot source or runtime state
  was changed.

### PowerShell 7 can bind the path-budget component Split overload differently from Windows PowerShell 5.1

- Signature: `Confirm-ArgosPathBudget.ps1` reports an entire otherwise short
  absolute path as one component and returns
  `HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH` under PowerShell 7, while the
  same path splits into its real components under Windows PowerShell 5.1.
  If the gate and target are placed in one outer command, later commands may
  still run despite the gate's non-PASS state.
- Cause: the script's `[string]::Split` overload binds differently in the
  observed PowerShell 7 host when passed the separator array. The governing
  path utility is a Windows PowerShell 5.1 gate. A rendered result is not a
  control-flow assertion, and a compound caller must not assume that the
  child script's `exit` prevents every later outer-host statement.
- Preflight: invoke `Confirm-ArgosPathBudget.ps1` under the explicit Windows
  PowerShell 5.1 executable, pass exactly one scalar candidate path per
  process, and require both process exit code zero and exact state
  `PASS_PATH_BUDGET` before making a separate target-preflight call. Never put
  the gate and target in the same outer command or rely on displayed JSON.
- Recovery: preserve any output created after the failed ordering as
  non-reusable diagnostic evidence. Change the invocation manifest to a fresh
  create-new output path, run each scalar path gate separately under Windows
  PowerShell 5.1, assert the result, then run target preflight and execution as
  later independent calls.
- First observed on 2026-08-20 for candidate-lot resolver output
  `R:\smc\mes-lot-resolver-g1.json`. The six resolver checks passed, but that
  result is non-reusable because its PowerShell 7 path gate had already
  returned a hard stop. No JBOD, MES, source image, task, portal, wafer, XML,
  training, or production state changed.

### A create-on-install runtime component cannot be declared as a required installed predecessor

- Signature: a fully rehearsed maintenance installer reaches the exact live
  endpoint and fails before mutation with `predecessor missing` for a runtime
  file that the revision is intended to introduce.
- Cause: the installer specification set `allowAbsent=false` for the new
  multi-channel scribe reader. Rehearsal fixtures always seeded the legacy
  reader, so the exact deployed state in which no reader existed was omitted.
- Preflight: classify every destination as required-existing, optional-existing,
  or create-on-install from signed endpoint evidence. Exercise the exact absent
  case for every create-on-install destination in both source and final-package
  rehearsals. A predecessor matrix that tests only present-current and target
  states is incomplete.
- Recovery: retain the signed terminal failure, change only the mistaken
  destination admission flag, add the absent-reader fixture, rerun refusal,
  rollback, idempotence, source, final-package, path, signature, and pre-action
  gates, then publish a new high-entropy request. Never retry the failed request.
- First observed on 2026-08-20 for JBOD request
  `REQ_20260820T195806165Z_790A283864B6`; signed terminal response
  `R_601B7C22DA7F_20260820195953845_2984ae9a` had response-manifest SHA-256
  `12C46262CF25B4879724C19143A3A07CBB1244ECEA4C1996D6AB8168B8500172`
  and failure SHA-256
  `13BA993F1FD237AF2B65E7E13804EC00A79B463F9DB00ACCFF77F8DEAAF259EF`.
  The endpoint failed before stopping either protected task or changing any
  installed file.

### Candidate-first Insite export can starve both later candidate pages and confirmed-scribe metadata

- Signature: the scribe queue keeps operator-confirmation proposals while
  confirmed scribes accumulate in `SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING`;
  the bridge continues cycling and its request ledger grows, so the condition
  looks like slow external response handling rather than deterministic local
  starvation.
- Cause: `Export-JbodPendingInsiteRequestV2.ps1` returned immediately whenever
  any unconfirmed current-image candidate existed. It always selected the
  first ten proposal directories. An unresolved first page therefore hid all
  later candidates and prevented the confirmed-scribe branch from ever being
  exported. Six-hour retry hashing prevented duplicate packages but did not
  advance the page or execute the lower-priority branch.
- Preflight: every combined queue exporter/worker revision must exercise zero,
  one, and many rows in both queue classes at the same time. With more than one
  candidate page and a nonempty confirmed queue, require bounded disjoint
  candidate pages, complete candidate coverage, at least one confirmed-scribe
  request in the first cycle, and idempotent no-growth after every row is
  covered for the current retry epoch. A moving worker counter is not fairness
  evidence.
- Recovery: preserve pending, sent, processed, failed, proposal, confirmed,
  metadata, and ledger evidence. Do not clear holds or hardcode identities.
  Page current-image candidates by acquisition key while excluding keys
  already present in signed relay packages for the current retry epoch, and
  independently attempt the confirmed-scribe request every worker cycle.
  Restart only the exact pinned bridge task after exact predecessor,
  rollback, idempotence, route, and final-package gates pass.
- First observed on 2026-08-20 after the normal-location scribe install. The
  live signed JD1 snapshot contained 26 proposal confirmations and 33
  confirmed-scribe Insite waits while the bridge had one pending request. A
  26-candidate/33-confirmed local regression demonstrated that the corrected
  scheduler produces three bounded candidate pages plus one confirmed request
  and stops growing on the fourth cycle.

### Portal maintenance authorization must match every exact destination root

- Signature: a correctly signed `MAINTENANCE_PATCH` is accepted and returned
  as a signed terminal failure before mutation with `Maintenance destination
  is outside approved roots` for one destination in an otherwise bounded
  multi-file repair.
- Cause: source and route rehearsals declared the intended destination root,
  but the installed endpoint's actual `approvedMaintenanceRoots` did not
  include it. A local rehearsal configuration broader than the installed
  endpoint cannot prove live authorization.
- Preflight: before signing, derive the exact installed approved-maintenance
  root set from signed endpoint evidence or a bounded direct endpoint audit.
  Require every normalized `changes[].destination` to be beneath that exact
  set. A planned root, a source-harness root, or an adjacent Argos service
  root is not authorization.
- Recovery: retain the signed terminal failure and do not retry its request.
  Redesign the narrow fix so every changed file remains under an actually
  authorized root, or use a separately rehearsed existing admin path. Publish
  only a new request after the exact installed-root matrix passes. Never ask
  the operator to run a manual package merely to bypass this check.
- First observed on 2026-08-20 for `REQ_SQ1`; signed response
  `R_78D6F8A27F86_20260820211048461_474b5c43` rejected
  `C:\ProgramData\ArgosInsiteBridgeRO\Invoke-JbodAutomaticInsiteBridgeWorker.ps1`
  before changing either file or restarting a task.

### A signed early portal failure may legitimately contain no maintenance stdout or stderr

- Signature: the response collector verifies a signed terminal response and
  then throws `expected one response entry: MAINTENANCE.stdout.txt` before it
  records the endpoint's actual `FAILURE.json`.
- Cause: the collector read maintenance stdout and stderr unconditionally.
  Authorization and other failures raised before the entry point starts may
  declare only `FAILURE.json`, the response manifest, and its signature.
- Preflight: exercise both handler-started failure responses and early
  pre-handler failure responses. Read only files declared in the signed
  manifest; require `FAILURE.json` for `FAILED`, but treat stdout and stderr as
  optional unless they are declared.
- Recovery: do not republish or modify the returned response. Patch only the
  collector, rerun its source/generated harness and clone-remediation gates,
  verify the same response signature and declared hashes, and commit the
  terminal failure gate from the original response.
- First observed on 2026-08-20 while collecting the signed `REQ_SQ1` failure
  above. No endpoint retry, source deletion, task restart, wafer abort, XML,
  or production action occurred.

### A live worker process is not proof that its invoked exporter completed

- Signature: a maintenance verifier observes the exact scheduled worker
  process alive and fresh for the full observation window, but the expected
  candidate and confirmed-request packages remain at `0/N`; the signed
  terminal response therefore reports incomplete queue coverage rather than a
  dead worker.
- Cause: the resident worker catches exporter exceptions inside its cycle,
  writes them to its own bounded state log, and continues running. Process
  liveness and task freshness therefore conceal an exporter invocation failure.
  The exact exporter exception remains unknown until that worker log is
  collected; do not infer it from the zero-coverage symptom.
- Preflight: any worker-driven exporter patch must exercise both a successful
  exporter call and an injected exporter exception through the exact installed
  worker. The verification result must include a bounded tail of the worker's
  own log and must reject a fresh process with no output as a failure with that
  exact diagnostic evidence. Liveness alone is never completion evidence.
- Recovery: preserve the signed terminal failure and do not retry or guess a
  replacement. Use the existing signed endpoint to collect only the bounded
  worker-log tail, installed hashes, and exact task/process evidence without a
  task restart. Diagnose the logged exception, then build one fresh revision
  that passes the exact worker-mediated regression before publication.
- First observed on 2026-08-20 for `REQ_SQ2`; signed response
  `R_5A06BB33A584_20260820213202227_fb210e24` reported
  `SQ2 queue coverage incomplete: candidate 0/26, confirmed 0/33` after the
  full 150-second verifier window. The endpoint rollback contract preserves
  the approved predecessor after this failed verification.
- Re-observed on 2026-08-20 for `REQ_SQ5J3`: its fairness harness recreated
  the worker's export/package cycle instead of invoking the exact frozen worker,
  and its endpoint fixture began with already-created receipts. Those tests
  proved the exporter and receipt format but did not prove worker-mediated
  activation. The signed live response
  `R_B16BBAD6A92F_20260821011657710_51565f37` therefore retained the same old
  `6/26` and `0/33` coverage with no new receipt evidence. The J3 package and
  its broader gates are non-reusable; a successor must call SHA-256
  `5DC7E9F1...` with `-Once` in a fresh fixture and require its exact log,
  ready-package, and durable-receipt effects before publication.

### A missing optional field in a shared completeness module can poison every export cycle

- Signature: the resident Insite worker remains alive but logs the same strict
  property error every cycle, and both candidate and confirmed-request output
  remain at zero: `The property 'frontsideScratchTestRouteState' cannot be
  found on this object.`
- Cause: `ArgosVerifiedMetadataCompleteness.psm1` directly dereferenced the
  newer frontside route field on verified metadata rows created before that
  field existed. Under strict mode, one legacy row aborted the exporter before
  it wrote either queue class.
- Preflight: shared completeness and admission modules must test missing,
  present-empty, present-valid, and present-invalid optional properties under
  strict mode. A missing route field must mean unconfirmed route for a
  frontside acquisition, not an exception, and must not prevent unrelated
  candidate or confirmed rows from being exported.
- Recovery: preserve the legacy row and all queue evidence. Make only the
  property read presence-safe, retain fail-closed frontside completeness, pair
  it with the already-rehearsed fair exporter, restart only the exact bridge
  task, and require live coverage of both queue classes before declaring the
  repair complete. Never backfill or hardcode wafer identity.
- First proven on 2026-08-20 by signed diagnostic response
  `R_EC7773C4B068_20260820214604903_75e9e735`, which returned a bounded
  80-line worker-log tail with SHA-256
  `7A8BF21B9DB0E88586DD02910459E1AEFD930C57DA1D6132E52F4118E434C9B7`.

### SQD1 local publication evidence declared an action absent from the signed request

- Signature: the immutable local publication gate reported
  `RESTART:ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1`, while the exact
  signed `REQ_SQD1` manifest contained zero allowed task actions.
- Cause: a mechanically cloned publisher's evidence-only field was not changed
  with the signed maintenance definition. The endpoint behavior remained
  bounded by the exact signed manifest, but the local gate was semantically
  broader and is not reusable.
- Preflight: compare `allowedTaskActions` in the exact signed manifest,
  maintenance definition, final gate, publisher source, and publication gate
  before publication. Literal-root remediation alone does not prove semantic
  action equality.
- Recovery: do not replay the request. Preserve the original publication gate
  as non-reusable evidence, create a superseding correction bound to its hash
  and the signed manifest hash, patch the publisher for future use, and make
  the response collector depend on the corrected evidence.
- First observed on 2026-08-20 for `REQ_SQD1`. The exact signed request and
  terminal response both prove zero task restarts; the original local gate hash
  is `9175BFD30F7799B7B8157C241C64782D32E2C90C0F586D66E508B85EAB84EF3D`.

### A bulk clone command can continue after non-terminating copy/path errors and print a false PASS

- Signature: a compound clone command prints its final `PASS_*` token even
  though `Resolve-Path` and file-read errors occurred earlier and the generated
  harnesses do not exist.
- Cause: the outer PowerShell process did not set `$ErrorActionPreference` to
  `Stop`, and the clone loop transformed destination files without first
  performing and asserting each source-to-destination copy. Non-terminating
  errors allowed the final status string to execute.
- Preflight: every bulk mechanical clone must run from a file-backed harness or
  a process with terminating errors, copy and hash-assert each pair before any
  transformation, assert the exact generated-file count, and emit PASS only
  after all rows succeed.
- Recovery: withdraw the partial output root and do not repair or publish it.
  Use a fresh root, explicit copy-then-transform rows, terminating errors, exact
  count/hash assertions, then rerun source and generated harness guards plus
  clone-literal remediation.
- First observed on 2026-08-20 in the partial local-only `work/SQD2` diagnostic
  clone. It was never signed, published, or executed on Argos/JBOD.

### Hash-name-first queue caps can hide every current-epoch package on a long-lived bridge

- Signature: the live worker log proves a new current-epoch request was queued,
  but the verifier reports `candidate 0/N, confirmed 0/N`; the exporter also
  stops advancing candidate pages after an exact duplicate check.
- Cause: both exporter coverage and verifier coverage sorted package directories
  by hash-derived name and selected the first 1,000 before checking retry epoch.
  On a long-lived queue, all recent packages can sort outside that arbitrary
  name prefix. The worker's exact package-name dedup then suppresses repeated
  output without advancing pagination.
- Preflight: bounded queue-history reads must order by `LastWriteTimeUtc`
  descending with name as a deterministic tie-breaker, then take the bounded
  window. Regressions must contain more than 1,000 historical hash-named
  packages plus current-epoch candidate and confirmed packages and prove both
  current classes remain visible.
- Recovery: retain history and do not clear the queue. Change only the bounded
  selection order, keep the 1,000-package cap, retain current-epoch filtering
  and exact hash validation, and require live coverage of both queue classes.
  Attach a bounded worker-log tail automatically on any coverage failure.
- First proven on 2026-08-20. During the SQ3 target window the signed diagnostic
  log recorded `QUEUED INSITE_REQ__98A003CF11D0FCFD88A40A6B64789826
  scribes=271 acquisitions=738`, while the SQ3 verifier returned 0/26 and 0/33.

### A cloned rehearsal verifier can retain the predecessor payload hash

- Signature: the exact endpoint rehearsal installs the intended new payload,
  then the entry verifier rejects it as `installed exporter hash changed` and
  the maintenance endpoint correctly rolls back both installed files.
- Cause: the cloned entry script retained its predecessor revision's frozen
  exporter hash even though the maintenance definition, payload file, and
  signer were updated to the successor hash.
- Preflight: before signing, extract every frozen payload hash from the entry
  verifier and require exact equality with the signer contract, maintenance
  definition, and actual payload bytes. The exact endpoint matrix must exercise
  every approved installed predecessor and the target-idempotent case.
- Recovery: preserve the failed local rehearsal as non-reusable diagnostic
  evidence, correct the verifier hash, issue from a fresh signed-output root,
  and rerun signing, endpoint, route, clone, harness, preaction, and final-ZIP
  gates. Never publish the rejected signed package.
- First observed on 2026-08-20 in the unpublished local SQ4 predecessor-case
  rehearsal. No Argos or JBOD state was touched.

### A maintenance rehearsal fixture must model the post-swap installed tree

- Signature: the endpoint correctly swaps the real rehearsal destination to
  the target payload, but the verifier is redirected to an isolated fixture
  that still contains a predecessor payload and reports an installed-hash
  mismatch.
- Cause: the harness populated the isolated verifier fixture from an older
  baseline and refreshed only one of two files changed by the maintenance
  definition. The endpoint's real swap and rollback behavior was correct, but
  the verifier fixture did not represent post-swap installed state.
- Preflight: for every maintenance change, assert that the rehearsal verifier's
  installed-root projection contains the exact target hash before invoking the
  entry verifier. Compare the projected file set to the complete maintenance
  change set; partial fixture refresh is a hard stop.
- Recovery: preserve the failed rehearsal, update only the fixture projection,
  choose a fresh rehearsal root, rerun harness and clone guards, and execute the
  complete predecessor/idempotence/rollback/control matrix again. Do not alter
  or resign package bytes when the signed payload and definition were already
  correct.
- First observed on 2026-08-20 in the local-only `C:\Q4H2` SQ4 rehearsal.
  No Argos or JBOD state was touched.

### Candidate request schemas must be accepted by the exact installed relay contract

- Signature: the exporter creates current-image candidate request packages, but
  the installed relay rejects each one with `Insite request payload schema is
  invalid`; confirmed-scribe packages continue through the same relay.
- Cause: the candidate exporter and importers introduced a candidate request
  schema, state, and lookup key, while the installed V2_1 relay still accepts
  only `argos_jbod_pending_insite_request_v1`,
  `PENDING_CONFIRMED_SCRIBE_READ_ONLY_INSITE_LOOKUP`, and `confirmed
  12-character wafer scribe`. The same legacy lookup-key restriction applies
  to response-package validation.
- Preflight: run the exact installed relay binary's non-mutating
  `--package-check` against every request and response envelope class that a
  changed exporter/query/importer can produce. Assert both candidate and
  confirmed paths, their exact payload schema/state/lookup keys, and rejection
  of malformed or provenance-mismatched compatibility envelopes.
- Recovery: do not clear queues or hard-code wafer identities. Either deploy a
  relay revision through an already approved maintenance root or use a bounded
  compatibility envelope whose outer contract is byte-semantically valid for
  the installed relay and whose nested candidate request/response is strictly
  validated end to end. Preserve candidate provenance, retry epoch, acquisition
  keys, and exact outer/inner row equality.
- First proven on 2026-08-20 by the exact V2_1 relay
  `ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe`: a confirmed SQ4 package
  returned exit 0, while all three candidate SQ4 packages returned exit 1 with
  the payload-schema exception. The signed SQ4 endpoint attempt rolled back.
- Rehearsal recurrence observed 2026-08-20: an SQ5J4 rehearsal consumer called
  the frozen relay as `inspect <path> <bytes>` even though this binary's exact
  non-mutating package interface is `--package-check <path>`. The worker had
  already queued a valid package, then the consumer received the relay's usage
  error and the signed endpoint case failed. Guard the literal command shape in
  the changed entry and harness before signing. Preserve the failed signed ZIP
  as non-reusable evidence, correct only the rehearsal command, and sign a fresh
  request ID; never patch or publish the failed signed artifact.

### Exporter fairness tests must include exact installed relay package validation

- Signature: a fairness/pagination rehearsal passes with current candidate and
  confirmed packages visible beyond 1,000 historical directories, but the live
  endpoint later reports zero candidate coverage because those packages are
  rejected before relay transfer.
- Cause: the rehearsal stopped after exporter output and queue-window coverage;
  it did not submit every generated request class to the exact installed relay
  binary and therefore could not detect an incompatible schema.
- Preflight: every exporter fairness regression must validate at least one
  package of every emitted class through the exact installed relay binary, then
  validate the corresponding response class through the same binary. Exporter
  creation, fairness visibility, and relay acceptance are separate required
  assertions.
- Recovery: preserve the passing fairness result as exporter-only evidence,
  withdraw it as an end-to-end route gate, add exact relay request/response
  checks, and rerun from a fresh short rehearsal root before publication.
- First proven on 2026-08-20 after the SQ4 signed terminal failure. The local
  SQ4 fairness gate correctly proved newest-first selection but omitted the
  relay contract boundary that rejected every candidate package.

### A PowerShell function call used in a comparison must have an explicit argument boundary

- Signature: the exact signed request is copied to the portal queue and its
  local archive is created, but the publisher then reports a nonexistent path
  whose leaf contains the comparison text, for example
  `REQ_SQ5A.ready.zip-ne<EXPECTED_SHA256>`, and no publication gate is written.
- Cause: `if(Sha $archive-ne$requestSha)` is parsed as a call to `Sha` with one
  concatenated scalar argument rather than as a hash result comparison. The
  non-mutating preflight did not execute that apply-only archive verification
  branch.
- Preflight: every function result used in a comparison must be parenthesized,
  for example `if((Sha $archive) -ne $requestSha)`. Publisher rehearsal must
  exercise the exact create-new apply branch against an isolated queue and
  assert the final archive hash and gate commit, not only the preflight branch.
- Recovery: never republish an accepted or already-consumed request. Verify the
  exact local archive bytes, locate the exact downstream processed artifact or
  signed terminal response, and write the missing publication gate only from
  that bounded exact evidence. Correct the publisher and use a fresh clone,
  harness, and preaction gate before any later request.
- First proven on 2026-08-20 for `REQ_SQ5A`. The portal consumed the exact
  11,860-byte ZIP while the local archive retained SHA-256
  `D26C4D8C5F037FB3B6C716F01988990C197FC00AF7EA1CC7820186E41DE45801`;
  the failure occurred after publication and before the publication gate.

### Endpoint worker revisions must be pinned independently for each portal role

- Signature: an exact maintenance request passes a local rehearsal against the
  upgraded JBOD endpoint worker but the live Argos endpoint returns an older
  response-ID shape and a stack trace whose handler/process line numbers match
  a different endpoint-worker revision.
- Cause: the route and endpoint gates assigned the JBOD C1E worker hash to both
  roles without direct exact-role evidence. Argos still ran the 297-line
  endpoint worker while JBOD ran the newer 552-line queue-safe worker.
- Preflight: freeze each endpoint role independently from signed response
  evidence or direct exact-endpoint evidence. Bind response-ID grammar, handler
  stack locations, endpoint worker hash, approved roots, and queue-safety
  authority per role. Never infer the Argos endpoint revision from JBOD.
- Recovery: retain the signed terminal response and rollback evidence, do not
  publish the JBOD successor, and rehearse the Argos successor against the
  exact older endpoint bytes. Keep the newer JBOD queue-safety gate scoped to
  JBOD only. If endpoint upgrade is required, deploy it as its own separately
  authorized change rather than hiding it inside the requested application
  patch.
- First proven on 2026-08-20 by signed Argos response
  `R_015CA4EE7DFA_20260820231456750`: its response ID has no GUID suffix and
  its stack cites maintenance line 186 and dispatch line 264, exactly matching
  SHA-256 `AA8CF83463E9C1850AB0D2CE1D639EC8E9A0EA1FEEFA43BA57207C50A1637842`,
  not JBOD C1E SHA-256 `244A5ECD...`.

### Path-component parsing must bind the character-array Split overload explicitly

- Signature: a path-budget check reports the entire normalized Windows path as
  `longestComponentLength`, so a safe nested path can be rejected solely because
  its total path length exceeds the component limit.
- Cause: PowerShell bound `.Split(@(char1,char2), options)` to the wrong .NET
  overload instead of the intended `char[]` separator overload. The directory
  separators therefore remained in one unsplit string.
- Preflight: include a nested Windows path whose total length exceeds 80 while
  every individual component remains below 80, and assert that the reported
  longest component equals the actual longest leaf/directory name rather than
  the full path length.
- Recovery: bind the overload explicitly with
  `.Split([char[]]@(...), [StringSplitOptions]::RemoveEmptyEntries)`, rerun the
  exact path gate, and do not launch the affected harness until it passes.
- First proven on 2026-08-20 when the SQ5A2 endpoint rehearsal path was safely
  rejected before write: an 88-character full path was incorrectly reported as
  one 88-character component even though no actual component exceeded 80.

### Scheduled-worker identity must use the installed task action path, not a stale root-level copy

- Signature: one verifier reports a root-level worker hash mismatch and a later
  verifier reports that same root-level worker missing, while the registered
  worker task and installer place the authoritative script below `query`.
- Cause: the package modeled `Invoke-ArgosAutomaticInsiteBridgeWorker.ps1` at
  the bridge root even though the installed task action is pinned to
  `query\Invoke-ArgosAutomaticInsiteBridgeWorker.ps1`. A stale non-task copy
  happened to exist during the first attempt and disappeared before the second.
- Preflight: derive the worker path from the exact installed task definition or
  the pinned installer action, require the verifier process filter to use that
  same path, and make the rehearsal fixture reproduce the same directory layout.
  A non-task file with the same name is never worker identity evidence.
- Recovery: retain each signed terminal failure, do not publish the downstream
  request, correct only the authoritative worker path and fixture layout, then
  rerun all exact allowed-worker, refusal, rollback, collision, and control cases
  before signing a fresh request ID.
- First proven on 2026-08-20 by signed responses for `REQ_SQ5A` and
  `REQ_SQ5A2`; the installer registers the worker task with the script under
  `C:\ProgramData\ArgosInsiteBridgeRO\query`.

### Patch preflight must inventory exact live hashes for every unchanged runtime dependency

- Signature: the corrected maintenance request reaches the authoritative worker
  path but fails on an unchanged helper such as `visual` because its live hash
  differs from the historical package hash.
- Cause: the verifier pinned unchanged runtime dependencies from an earlier
  package projection instead of obtaining a signed live inventory from the
  exact endpoint. The target files were rolled back safely, but the request
  could not establish compatibility.
- Preflight: before a patch depends on unchanged worker/helper/relay bytes,
  obtain their exact live paths and hashes in a signed terminal response. The
  diagnostic must restart no tasks and may use only exact idempotent same-byte
  maintenance changes when the installed portal exposes no read-only route to
  the approved query root.
- Recovery: retain the signed terminal failure, keep the downstream request
  blocked, issue one bounded dependency-inventory request, and bind the next
  verifier and preaction contract to every returned exact hash. Do not widen to
  an unknown-hash or API-shape-only acceptance rule.
- First proven on 2026-08-20 by signed `REQ_SQ5A3` response
  `R_77AC1B2D7294_20260820235403213`, which reported exact failure
  `SQ5A3 installed hash mismatch: visual` before any committed patch.

### One zero-candidate proposal must not poison the whole Insite export queue

- Signature: the bridge queues several valid current-image candidate packages,
  then logs the same `Current-image reader produced no MES-query candidate`
  identity every poll; no later eligible proposal or confirmed-scribe request is
  exported, and a bounded coverage verifier reports only a small prefix covered.
- Cause: the combined exporter passed every proposal reader summary into one
  fail-closed candidate-contract call. A single operator-visible proposal with
  zero canonical MES-query candidates threw before the valid rows could be
  packaged, so the worker retried the same poisoned batch indefinitely.
- Preflight: exercise a mixed proposal set containing a zero-candidate row
  before and after valid canonical rows. Require the zero-candidate row to stay
  explicitly deferred for operator review, require every valid row to remain in
  the signed relay request, then prove confirmed-scribe export and a second
  control cycle still run. Never hardcode an acquisition identity or convert a
  zero-candidate row into Normal, confirmed, or discarded evidence.
- Recovery: retain the signed terminal failure and rollback evidence. Update
  only the exporter/verifier so zero-candidate proposal rows are excluded from
  the automated MES request for the current cycle and counted as explicit
  review holds; keep all other contract violations fail-closed. Rehearse the
  exact installed JBOD endpoint, rollback, collision, and control cases before
  a fresh request ID.
- First proven on 2026-08-20 by signed JBOD response
  `R_A72575D121B7_20260821002535283_e33ab92d`: three valid 10-acquisition
  packages were queued before `62625-907_PRE_20260709123021_SLOT14` repeatedly
  blocked the remainder. The identity is evidence of the failure only and must
  not be encoded in the fix.

### Fast relay movement must not erase exporter coverage evidence

- Signature: the worker log proves that multiple candidate pages and a large
  confirmed-scribe request were queued after a patch, but an endpoint verifier
  that enumerates only `request_queue\pending` and `request_queue\sent` reports
  partial or zero coverage and rolls the patch back.
- Cause: the relay can move a ready package out of those transient roots before
  the verifier samples them. The same transient enumeration is also unable to
  suppress a later duplicate page after the package has moved. A worker-log
  `QUEUED` count proves activity, but not the exact acquisition-key set.
- Preflight: rehearse an exact relay that immediately removes each accepted
  ready package from both transient roots. Require a create-new, content-hashed
  export receipt to retain the exact normalized acquisition keys, request kind,
  retry epoch, and request hash. Prove complete candidate and confirmed coverage
  from receipts after every ready package is gone, then prove the next exporter
  cycle does not duplicate already receipted candidate keys.
- Recovery: retain the signed terminal failure and rollback evidence. Add a
  short, path-gated, append-only per-export receipt root under the existing
  bridge state root; commit each receipt only after the exact request output is
  durably written. Make coverage and same-epoch candidate suppression use the
  receipts plus any still-visible legacy packages. Never treat a log line,
  filename, package count, or disappearing queue directory as exact-key
  coverage.
- First proven on 2026-08-20 by signed JBOD response
  `R_6B38DFC5513A_20260821005102434_455cc854`: the worker logged candidate
  packages of 10, 10, 10, and 3 acquisitions and a confirmed package of 738
  acquisitions, while the transient-root verifier observed only `6/26`
  candidate and `0/33` confirmed keys.

### Multi-predecessor rehearsal mode must apply per case, not reject unchanged sibling files

- Signature: an exact endpoint rehearsal passes the first approved predecessor
  case, then stops before invoking the second endpoint with
  `destination mode invalid: intermediate`.
- Cause: the harness selected the intermediate predecessor correctly for the
  changed exporter at index zero, but its sibling-file branch accepted only the
  `old` case name even though those unchanged siblings must use their ordinary
  first predecessor in both `old` and `intermediate` cases.
- Preflight: enumerate every case-mode/file-index pair before endpoint launch.
  Require the intermediate mode to select the intermediate artifact only for
  the changed file and the pinned base predecessor for every unchanged sibling.
- Recovery: preserve the failed rehearsal root, change only the harness branch,
  use a fresh test root and gate name, and retain the exact signed package bytes
  when the package itself passed the prior endpoint case and was not changed.
- First observed on 2026-08-20 in the local SQ5J4R2 endpoint rehearsal after
  `approved_exporter_a8` passed. No live portal request was published.

### Proposal queue eligibility must require a current non-empty reader summary

- Signature: the exact live worker queues a bounded candidate package and the
  durable coverage count advances, but the maintenance entry stops on the next
  cycle with `exact worker made no durable coverage progress`. The queue can
  contain proposal rows whose current reader summary is missing, while only a
  smaller subset has current MES-query candidates.
- Cause: the entry began with every `PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED`
  row and removed only rows whose existing summary explicitly contained zero
  candidates. Rows with no current summary were left in the required set even
  though the exporter correctly cannot emit them.
- Preflight: derive eligibility from the intersection of proposal queue keys
  and current reader-summary keys having at least one normalized candidate.
  Treat zero-candidate and missing-current-summary proposal rows as explicit
  deferred holds. Rehearse both cases beside eligible rows and require complete
  exact-worker coverage only for the eligible intersection.
- Recovery: retain the signed terminal failure and rollback evidence. Change
  only entry-side eligibility/coverage accounting, preserve every queue row and
  proposal artifact, sign a fresh request ID, and prove eligible candidate plus
  confirmed coverage from an empty receipt fixture. Never invent a scribe or
  copy a prior wafer identity into a missing summary.
- First proven live on 2026-08-20 by signed response
  `R_BD5E1D47F021_20260821015701657_b9e2069d`: the worker queued five current
  candidate acquisitions before the broader required set caused failure.

### Candidate export must be bounded by the active proposal queue, not every retained reader summary

- Signature: the exact worker queues a valid candidate package, but the
  maintenance coverage set advances by zero and stops with
  `exact worker made no durable coverage progress`; the package contains
  retained reader-summary identities that are not active
  `PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED` queue rows.
- Cause: entry-side coverage correctly used the active proposal queue, while
  the exporter enumerated every retained proposal-directory reader summary.
  Stale or otherwise inactive summaries could consume the bounded export page,
  so the exact worker performed real work without covering any currently
  required acquisition.
- Preflight: add non-empty stale reader summaries that have no active proposal
  queue row before and after active eligible rows. Require the exact installed
  worker to export only the intersection of active proposal queue identities
  and current non-empty reader summaries, retain missing/zero-candidate active
  rows as explicit holds, and prove every emitted page advances exact coverage.
- Recovery: retain the signed terminal failure and rollback evidence. Restrict
  exporter candidate rows to normalized identities currently present in the
  active proposal queue; do not delete retained summaries, invent identities,
  or hardcode a lot. Rehearse the exact worker, relay, endpoint rollback,
  collision, compact failure, and control cases before a fresh request ID.
- First proven live on 2026-08-20 by signed response
  `R_DF1A9550CE6B_20260821021203507_06a1f128`: the worker queued five
  candidate acquisitions while entry-side active-proposal coverage advanced by
  zero.

### PowerShell return statements require a token boundary before a type literal

- Signature: Windows PowerShell parses the file but execution fails with
  `The term 'return[pscustomobject]@' is not recognized` before the intended
  typed object can be returned.
- Cause: a compact mechanical rewrite removed the mandatory whitespace between
  the `return` keyword and the following `[pscustomobject]` type literal. The
  AST parser accepted the text as a command token, so parser-only harness
  safety did not prove executable command semantics.
- Preflight: execute the exact non-mutating `-Preflight` path after parser,
  wrapper, clone, and path gates, and require its bounded JSON state before any
  apply. Reject `return[` and `throw[` token adjacency in changed PowerShell.
- Recovery: preserve the failed rehearsal root, add the token boundary, rerun
  all source/generated harness and clone gates, and use a fresh rehearsal root
  and preaction contract. Do not reuse a partially created rehearsal root.
- First proven on 2026-08-20 by the local SQ5J4R4 publisher rehearsal; the
  signed request had not been copied to the live portal queue.

### Entry coverage and exporter eligibility must use the same live predicates

- Signature: the maintenance entry reports uncovered active work, invokes the
  exact worker, the worker emits no new `QUEUED` or `ERROR` line, and entry
  fails `exact worker made no durable coverage progress`. The exporter has
  legitimately skipped rows that entry still counted as required.
- Cause: entry coverage used queue state plus reader presence, while the
  exporter additionally filtered retained confirmed-overlay rows, completed
  verified metadata, terminal holds, and future retry holds. Retained overlay
  rows could also suppress an active proposal even when they were not active
  confirmed-queue identities. Two independently approximated eligibility sets
  drifted on live state.
- Preflight: build proposal and confirmed eligibility from the same normalized
  active queue partitions and the same current overlay/completeness/hold
  predicates. Rehearse an inactive retained confirmed row sharing an active
  proposal key, a confirmed queue row missing its overlay, a terminal hold, and
  a future retry hold beside eligible controls. Require exact worker pages to
  cover only the common eligible set and count every other row as deferred.
- Recovery: retain the signed terminal failure and rollback evidence. Filter
  exporter confirmed rows by active confirmed queue state and make entry
  coverage mirror the exporter predicates; preserve all retained overlays and
  holds. Do not hardcode identities or interpret a no-op worker cycle as proof
  of success without exact common eligibility closure.
- First proven live on 2026-08-20 by signed response
  `R_AAA89F914BD4_20260821022834168_fc139800`: the exact worker produced no
  new log event while entry-side coverage remained incomplete.

### Active frontside route-incomplete rows must not disappear when the scribe queue advances

- Signature: the catalog retains current `FRONTSIDE` acquisitions on
  `HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED`, but the exact exporter
  reports zero confirmed acquisitions required even though their verified
  metadata lacks a confirmed frontside scratch-test route.
- Cause: the prior recurrence repair intersected every confirmed-overlay row
  with only `SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING`. Once a successful older
  metadata import advanced the scribe queue, a still-incomplete active
  frontside route row became invisible to re-query even though the catalog
  continued to expose the unresolved route hold.
- Preflight: distinguish retained historical overlay rows from catalog-active
  frontside route holds. Require a confirmed-overlay row to remain eligible
  when either its queue row is actively pending or its current catalog row is
  a frontside Insite/appearance hold and the common verified-metadata
  completeness predicate requires re-query. Bound and prioritize re-queries by
  acquisition timestamp, and rehearse completed historical rows, active route
  holds, missing overlays, terminal holds, future retry holds, and queue-active
  controls together.
- Recovery: preserve the signed R5 terminal response as bounded installation
  evidence but withdraw that package from replay/template use. Extend the same
  eligibility predicate in both exporter and maintenance entry, keep all
  overlay and queue history, issue no identity assignment, and publish only a
  fresh signed successor after exact worker, relay, endpoint, path, rollback,
  collision, compact-failure, and control cases pass.
- First proven on 2026-08-20 by the combination of signed R5 live result
  `R_2797AB186D64_20260821024228418_57c21b08` (`confirmedRequired=0`) and the
  signed C2V6 catalog evidence retaining current lot `62631-586` frontside
  appearance-route holds.

### A new collector role must be added to every coupled success-state map

- Signature: the endpoint response is signed with `PASS_MAINTENANCE_PATCH` and
  its maintenance stdout contains the exact required PASS state, but the local
  terminal-response gate is written as `FAIL_*_SIGNED_TERMINAL_RESPONSE`.
- Cause: the collector's role-to-root, request, publish, route, terminal, and
  preaction maps were extended, but the separate role-to-expected-stdout map
  omitted the new role and selected its legacy fallback state.
- Preflight: inventory every role predicate and role-indexed map in the exact
  collector before adding a role. Exercise the new role with a fixture whose
  signed endpoint state and stdout state are both correct, and assert that the
  derived terminal state is PASS. A role extension is incomplete if any
  coupled map still falls through to a default branch.
- Recovery: retain the signed response package, extracted ready directory,
  route gate, and misclassified derived terminal gate unchanged. Correct the
  missing expected-stdout branch, then create a fresh explicitly superseding
  terminal-classification gate from those exact signed bytes; do not republish
  or rerun the already successful endpoint request.
- First observed on 2026-08-20 for collector role `JBOD8` and response
  `R_461C8F5B0079_20260821031130088_4463755e`.

### Diagnostic readers must classify polymorphic request rows before strict-property access

- Signature: a signed read-only endpoint diagnostic fails under `Set-StrictMode`
  with `The property 'acquisitionKeys' cannot be found on this object` while
  inspecting a bounded request queue that legitimately contains more than one
  request-row schema.
- Cause: the diagnostic treated every request containing `rows` as a confirmed-
  scribe request whose rows expose `acquisitionKeys`. Direct candidate requests
  instead expose a scalar `acquisitionKey`; strict-property access failed before
  the diagnostic could return the live queue evidence.
- Preflight: rehearse every supported request envelope and row shape together:
  legacy-relay candidate envelope, direct candidate rows with `acquisitionKey`,
  and confirmed-scribe rows with `acquisitionKeys`. Require explicit property-
  presence classification before reading either field, plus an unknown-shape
  diagnostic row that is skipped or reported without terminating the request.
- Recovery: retain the signed terminal failure and extracted stderr, withdraw
  that diagnostic ZIP from reuse, add property-presence branches for both row
  shapes, rerun parser/harness/clone/endpoint gates from a fresh revision and
  fresh roots, then publish only after the earlier request has a signed terminal
  response. Do not loosen `Set-StrictMode` or delete the unexpected queue row.
- First observed on 2026-08-20 in signed C2V8 response
  `R_1D9C83B07160_20260821034609754_36d7f593`.

### Never use `$matches` as an application accumulator around `-match`

- Signature: Windows PowerShell 5.1 reaches final JSON serialization and fails
  with `System.Collections.Hashtable` and `Keys must be strings`, even though
  the application assigned an array of matching acquisition keys.
- Cause: PowerShell variable names are case-insensitive and `$Matches` is the
  automatic regex-capture hashtable. The diagnostic stored acquisition keys in
  `$matches`, then evaluated a valid SHA-256 with `-match`; that operator
  replaced the application array with `$Matches`, whose integer capture key
  could not be serialized as the intended string array by Windows PowerShell
  5.1.
- Preflight: exercise at least one queue row whose acquisition key matches and
  whose manifest contains a valid 64-hex hash under the exact Windows
  PowerShell 5.1 payload. Require final JSON serialization to succeed, require
  `matchingAcquisitionKeys` to deserialize as a string array, and reject
  application assignments to `$matches` in code that also uses regex
  operators.
- Recovery: retain the failed C2V9 rehearsal root and signed request as
  non-reusable evidence. Rename the application accumulator to an unreserved
  name such as `$matchingKeys`, repeat parser/harness/clone and the complete
  exact endpoint rehearsal under fresh revision and roots, and publish only
  that fresh successor. Do not weaken the valid-hash check or special-case the
  fixture.
- First observed on 2026-08-20 in the local exact C2V9 endpoint rehearsal;
  signed response `R_64BFC8718502_20260821035951285_cfa9f1e7` failed before
  any request was published to JBOD.

### A bounded post-sort sample does not bound directory enumeration

- Signature: a read-only diagnostic that succeeds quickly against a small
  exact rehearsal tree produces no stdout or stderr on the live endpoint and
  receives a signed `Portal child timed out after 900 seconds` terminal
  response.
- Cause: the diagnostic added `Get-ChildItem` over entire accumulated request
  and response queue directories and only applied `Select-Object -First 200`
  after enumeration and sorting. The sample size bounded JSON reads but did not
  bound directory traversal or sorting; the unchanged catalog/ledger portion
  had already completed live in the predecessor diagnostic.
- Preflight: a live-state diagnostic must begin from exact atomic state
  pointers such as `LAST_QUEUED_REQUEST.json` and
  `LAST_IMPORTED_RESPONSE.json`, then open only the named package under a
  finite explicit list of queue states. A post-enumeration `First N` is not a
  bounded queue scan. Exact endpoint rehearsal must include many irrelevant
  queue entries and prove the result does not enumerate them.
- Recovery: retain the signed C2V10 timeout response and ZIP as non-reusable
  evidence. Build a fresh diagnostic that reads the two exact state pointers,
  the named request package, metadata overlay, catalog rows, and bounded log
  tail only. Do not recursively enumerate bridge queues, retry C2V10, restart
  inspection tasks, or process images.
- First observed on 2026-08-20 in signed C2V10 response
  `R_32EF638D6E89_20260821042407960_02a3aa27`.

### `Get-Content -Tail` is not a bounded read of an accumulated Windows log

- Signature: a live read-only endpoint diagnostic containing no directory,
  catalog, ledger, dashboard, job, or historical-root enumeration still emits
  no stdout or stderr and receives a signed `Portal child timed out after 900
  seconds` response, while the same payload completes quickly against small
  exact rehearsal logs.
- Cause: `Get-Content -Tail N` limits returned lines, not the work needed by
  Windows PowerShell 5.1 to locate those lines in a very large accumulated text
  file. Treating a tail count as an I/O bound allowed the production worker log
  to dominate the child process. C2V12 proved that all other remaining reads
  were exact JSON pointers or a single size-capped request body.
- Preflight: time-critical endpoint diagnostics must omit accumulated logs
  unless the file size is first bounded to a rehearsed maximum and the exact
  production-size behavior is proven. Begin with small atomic state JSON files;
  obtain logs later through a separate byte-bounded seek reader or rotated log
  segment. A returned-line count is never a file-read budget.
- Recovery: retain signed C2V11 and C2V12 timeout responses and ZIPs as
  non-reusable evidence. Publish a fresh successor that reads only
  `LAST_QUEUED_REQUEST.json` and `LAST_IMPORTED_RESPONSE.json`, compares their
  bounded hashes, and performs no request-body or log read. Do not retry either
  timed-out request or restart inspection tasks.
- First isolated on 2026-08-20 by signed C2V12 response
  `R_06D630E688DB_20260821051429971_e0b06211` after C2V11 independently timed
  out with the same accumulated-log tail still present.

### Environment-provided rehearsal manifests must control reported rehearsal state

- Signature: an exact Windows PowerShell 5.1 endpoint rehearsal uses the
  file-backed `ARGOS_*_REHEARSAL_MANIFEST`, correctly redirects every path to
  the fixture, and produces the expected result, but the result incorrectly
  reports `rehearsal: false` because only the unbound command-line switch was
  serialized.
- Cause: the payload consumed the environment-provided invocation manifest but
  emitted `[bool]$Rehearsal` instead of a single effective rehearsal variable
  set from either the switch or the validated manifest.
- Preflight: every payload supporting both an explicit `-Rehearsal` switch and
  an environment-provided invocation manifest must calculate one
  `$isRehearsal` value, set it from the validated manifest when present, use it
  for all behavior and result fields, and assert `rehearsal: true` in the exact
  packaged Windows PowerShell 5.1 endpoint rehearsal.
- Recovery: withdraw the failed local rehearsal root, update the payload to use
  the effective value, re-run harness and clone guards, create a fresh signed
  request root and fresh endpoint rehearsal root, and publish nothing until the
  corrected exact package passes.
- First observed on 2026-08-21 in the unpublished local C2R0 `pending` endpoint
  rehearsal. No portal request or endpoint mutation occurred.

### Portal transport tokens must be fresh across both live and processed share queues

- Signature: a newly signed request remains indefinitely in the engineering
  share `requests` root even though its package signature and payload validate,
  while a different historical ZIP with the same transport filename already
  exists under `requests\processed`.
- Cause: the publisher checked only the live request root. The gateway share
  bridge derives both its local destination and processed archive name from the
  outer ZIP token and refuses an existing processed archive, so reusing a short
  request ID from a prior day creates a deterministic queue-head collision.
- Preflight: before signing or publishing, require the outer request token to
  be absent from the live request root, processed archive, gateway destination
  inventory when available, and local publication archive. Bind the manifest
  request ID and outer transport token separately and use a fresh revisioned
  token for every new signed request.
- Recovery: verify both conflicting ZIPs by exact size, SHA-256, signed manifest
  request ID, target role, job class, and creation epoch. Move only the older
  processed artifact to a recoverable collision archive with its hash in the
  name, leave the current signed request byte-for-byte unchanged, and require
  the gateway to move it to processed before collecting its signed response.
  Never delete or overwrite either artifact and never republish the request.
- First observed on 2026-08-21 when current request ZIP `REQ_C2R3.ready.zip`
  (`B5644B0F...`, 6,626 bytes) was blocked by the distinct 2026-08-20 processed
  ZIP with the same token (`BE7AC010...`, 8,640 bytes).

### Dynamic queue postconditions must tolerate intended movement between existence and hash reads

- Signature: a recovery moves the exact historical collision successfully and
  the live consumer immediately advances the current request, but the recovery
  script fails because `Test-Path` saw the live file and `Get-FileHash` ran
  after that same file moved to processed.
- Cause: the postcondition performed separate existence and content reads on a
  directory watched by a two-second consumer and treated an intended transition
  as a missing-file error.
- Preflight: postconditions for live queues must read each possible state inside
  a bounded retry/exception boundary, then validate the union of exact candidate
  locations. A path disappearing during inspection is a state transition to
  re-sample, not evidence of changed bytes.
- Recovery: inspect the exact live, processed, and recoverable-archive paths as
  a fresh bounded snapshot. Continue only when the historical hash is present
  solely in the recoverable archive and the current hash is present in the
  processed path; do not rerun or republish the request.
- First observed on 2026-08-21 after the C2R3 historical processed-archive
  collision was moved and the gateway immediately imported the current C2R3
  request byte-for-byte.

### Synthetic queue fixtures must use disjoint deterministic identity sets

- Signature: a multi-case endpoint rehearsal completes earlier cases but its
  later control case fails during fixture construction because a generated
  invalid package and a separately generated valid control package resolve to
  the same deterministic directory name.
- Cause: the invalid-package loop derived identities from successive repeated
  digits while the valid-control fixture independently used one of those same
  repeated-digit identities. Increasing the invalid case cardinality exposed
  the collision before the endpoint worker ran.
- Preflight: freeze disjoint deterministic identity ranges for every fixture
  class, assert uniqueness of all planned package paths before the first
  fixture write, and include the maximum-cardinality control case in the exact
  rehearsal.
- Recovery: withdraw the incomplete rehearsal root, change only the synthetic
  valid-control identity to a disjoint value, re-run harness and clone guards,
  bind the corrected hashes in a fresh pre-action contract, and use a fresh
  rehearsal root. Do not publish the package built from the failed harness.
- First observed on 2026-08-21 in the unpublished C2R5 exact endpoint
  rehearsal `control_after_failure`; no portal or JBOD mutation occurred.

### Relay configuration safety must use the installed relay contract fields

- Signature: an otherwise valid bounded response-queue recovery stops before
  mutation with `A10 relay configuration safety contract changed.`
- Cause: the recovery guard required `reviewOnly=true` in `relay.json`, while
  the installed `argos_bound_relay_config_v1` contract uses `testOnly=true`
  together with `productionRoutingEnabled=false`. The package contract and
  executable were pinned correctly; the config-field assumption was not.
- Preflight: before freezing a relay-config guard, read the exact relay config
  validator source and require its actual schema and safety fields. For
  `argos_bound_relay_config_v1`, require `testOnly=true` and
  `productionRoutingEnabled=false`; never substitute a manifest's
  `reviewOnly` field for the installed configuration contract.
- Recovery: preserve the signed failed response as terminal evidence, change
  only the config-field guard, rerun the exact Windows PowerShell 5.1 fixture
  suite and all clone/harness/pre-action gates under fresh roots, then publish
  a new uniquely identified request. Do not rerun the failed request.
- First observed on 2026-08-21 in signed Argos response
  `R_543B4A055C6E_20260821075850911` for request
  `REQ_A10_0821_0748_X1`; the endpoint failed before moving any queue package.

### Identifier replacement must never rewrite embedded SHA-256 text

- Signature: a freshly cloned rehearsal refuses an unchanged installed
  dependency even though the copied dependency file has the approved hash.
  The expected hash itself differs by one request-number substring, for
  example `...C010A10C773` becoming `...C010A11C773`.
- Cause: a broad textual `A10` to `A11` identifier replacement also modified
  the coincidental `A10` byte sequence inside a pinned SHA-256 value in the
  payload and maintenance definition.
- Preflight: after every identifier rewrite, independently hash each unchanged
  dependency and compare every embedded expected, installed, and approved
  predecessor SHA-256 value to that file's actual 64-hex hash. Treat all hash
  fields as opaque and exclude them from identifier replacement.
- Recovery: restore the exact dependency hash in every affected unsigned file,
  rerun clone and harness gates, bind the corrected hashes in a fresh pre-action
  contract, and use a fresh rehearsal root. Never relax predecessor checking.
- First observed on 2026-08-21 in the unpublished A11 rehearsal; no portal,
  Argos, JBOD, task, queue, inspection, or wafer mutation occurred.

### Relay queue validation must reproduce the installed JSON parser limit

- Signature: a bounded recovery reports every pending response package valid,
  yet the live relay remains `SEND_RETRY_PENDING` on one package with
  `JavaScriptSerializer` reporting that the input exceeds `maxJsonLength`.
- Cause: the recovery used PowerShell `ConvertFrom-Json`, which accepted a JSON
  payload that the installed .NET relay's default `JavaScriptSerializer`
  rejects. The package was below `sender.maxPackageBytes`, so byte limits alone
  did not reproduce the consumer's parse contract.
- Preflight: validate candidate relay JSON with the same installed parser and
  default maximum-character behavior used by `PackageContract.ReadDictionary`,
  in addition to file count, byte limit, hashes, safety flags, and authority.
  Include a below-byte-limit but above-default-`maxJsonLength` fixture.
- Recovery: preserve the signed diagnostic, classify every package that fails
  the installed parser as invalid, move such packages intact to deterministic
  recoverable quarantine, verify tree hashes before and after the move, and
  leave valid packages including the exact target untouched. Do not increase
  parser or relay limits merely to make an obsolete package send.
- First observed on 2026-08-21 in signed A12 diagnostic response
  `R_67EB2C93C813_20260821081712244`; the blocking package was
  `INSITE_RESP__180BE22F63197D262ABFA3B109D8701B.ready`, while target
  `INSITE_RESP__A5E8615D8C4F3B81EE2A4DE1BF8B2E83.ready` remained intact.
### JBOD Insite response diagnostics must use the worker's `response_inbox`, not the relay's `response_queue`

- Signature: an exact Argos response is independently proven in the Argos
  relay `sent` root, while a later JBOD diagnostic reports that response absent
  from every checked package state and leaves `LAST_IMPORTED_RESPONSE.json`
  unchanged.
- Cause: the JBOD diagnostic modeled the Argos-side relay layout and checked
  `C:\ProgramData\ArgosInsiteBridgeRO\response_queue\{pending,processed,failed}`.
  The installed JBOD scheduled worker imports from
  `response_inbox\pending` and moves packages to
  `response_inbox\processed` or a timestamp-suffixed directory under
  `response_inbox\failed`. The diagnostic's negative location result was
  therefore non-authoritative; its catalog and dashboard readings remain valid.
- Preflight: derive bridge queue roots from the exact installed scheduled-worker
  action bytes or their hash-matching locked source before signing a diagnostic.
  Assert the literal `response_inbox` roots in both the payload and its Windows
  PowerShell 5.1 rehearsal. Never infer endpoint queue names from the opposite
  host or from the transport binary's terminology.
- Recovery: retain C2V18 as signed terminal evidence for ten catalog rows and
  zero GUI frontside assets, but withdraw its target-package-location claim.
  Use a fresh signed successor pinned to the C2V18 terminal response, read the
  exact target under `response_inbox\pending` and `response_inbox\processed`,
  and inspect only an exact target-prefixed failed leaf when necessary. Do not
  restart the worker, reprocess images, clear queues, or hardcode wafer
  identities.
- First proven on 2026-08-21 by comparison of C2V18 terminal response
  `D5EF01A0EEEAA17D968B54F281B332A2F12ED4E99D8D2F2E9567C3F4F3E9C196`
  with the locked JBOD worker source
  `4F60B9C9D5AE3CC6EABE8983A6A27D5EB391D6101C07E94406CDD570748B02B2`.
### One noncanonical acquisition key must not poison an entire Insite response batch

- Signature: a signed Insite response with many records is transferred to JBOD
  and then moved to `response_inbox\failed`; `IMPORT_FAILURE.json` names one
  unrelated acquisition key, while all other valid rows in the same response
  remain unapplied and their catalog routes do not advance.
- Cause: `Import-JbodCandidateInsiteSnapshot.ps1` places no row-level failure
  boundary around lot-context resolution. A strict base-lot parser exception
  from one request row escapes the loop and causes the worker to quarantine the
  complete response package.
- Preflight: candidate-importer regression must include a mixed response with
  one noncanonical or unsupported acquisition key between valid rows. Require
  the unsupported row to produce an explicit review hold while valid rows are
  resolved and committed atomically. Also exercise valid `LOT-`-prefixed and
  unprefixed acquisition-key forms before freezing parser semantics.
- Recovery: obtain exact live hashes for the importer and resolver, patch only
  the generic acquisition-key/row-failure behavior, run exact predecessor,
  idempotence, rollback, mixed-row, and control-after-failure rehearsals, then
  issue a new bounded retry epoch. Do not hardcode lot or wafer identities,
  silently drop a row, clear the failed queue, or replay the old response as if
  it were a fresh request.
- First proven on 2026-08-21 by failed package
  `INSITE_RESP__A5E8615D8C4F3B81EE2A4DE1BF8B2E83.ready.failed.20260821T082556695Z`:
  the exact failure was `Acquisition key does not expose an exact base lot:
  LOT-62546-481-POST2_20260713155808_SLOT23`.

### An importer hotfix does not create a new automatic Insite retry epoch

- Signature: the resolver/importer hotfix is installed and both scheduled tasks
  are running, but `LAST_QUEUED_REQUEST.json`, `LAST_IMPORTED_RESPONSE.json`, and
  the GUI inventory remain unchanged. The current request keys are already
  represented by a package in the worker's `sent` root for the active six-hour
  retry epoch.
- Cause: the automatic exporter treats keys in pending or sent packages with the
  current `retryEpochUtc` as covered, and the worker independently suppresses a
  request whose package hash is already pending or sent. Restarting either task
  does not advance that deterministic epoch and therefore cannot exercise the
  corrected importer.
- Preflight: after an importer or resolver repair, inspect the exact installed
  worker/exporter bytes, current `retryEpochUtc`, pending and sent package hashes,
  and last-queued/last-imported ledgers. Require the release plan to name how a
  fresh bounded epoch will be created; a task restart is not that mechanism.
- Recovery: add an explicit bounded retry-interval parameter to the worker while
  preserving the six-hour default, then run one exact worker pass with a shorter
  interval to create one new retry epoch. Verify a new request hash and complete
  signed round trip. Do not delete or move sent records, replay the failed
  response, or hardcode lot or wafer identities.
- Prevention: every importer hotfix acceptance gate must include a fresh retry
  epoch and the final consumer-visible GUI cardinality. Installed hashes and
  running tasks alone are insufficient.
- First proven on 2026-08-21 by C2V22: the installed resolver hash was corrected
  while `LAST_QUEUED_REQUEST.json` remained at `2026-08-21T08:26:36Z`,
  `LAST_IMPORTED_RESPONSE.json` remained at `2026-08-21T08:27:28Z`, and lot
  `62631-586` still had zero FRONT GUI assets.

### A maintenance verifier must not guess the processor task's action text

- Signature: an otherwise valid signed maintenance request fails before its
  intended worker swap with `task action refused` for
  `ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2`.
- Cause: a new verifier required the processor task action to contain a guessed
  inventory-script filename. The established SNR3 and F1 verifiers pin the
  exact task name, principal, and exported definition hash while leaving that
  processor action regex empty; only the Insite task has the proven worker
  filename predicate.
- Preflight: mechanically preserve the established task-snapshot call shape:
  empty processor action predicate and
  `Invoke-JbodAutomaticInsiteBridgeWorker.ps1` for the Insite task. Reject any
  newly invented processor action predicate unless exact endpoint inventory
  has first proven it.
- Recovery: retain the signed failed response as terminal evidence, create a
  fresh successor root, change only the processor predicate back to the
  established empty value, and rerun exact predecessor, rollback, control, and
  signed endpoint gates. Do not weaken task-name, principal, or definition-hash
  checks.
- First observed on 2026-08-21 in signed F2 response
  `R_5B5BB7B5C2B5_20260821101635550_a628c019`; no worker, queue, image, or wafer
  mutation occurred.

### Failed-response collectors must not assume maintenance stdout is JSON

- Signature: a signed endpoint response is verified and extracted, then the
  collector stops under strict mode because empty `MAINTENANCE.stdout.txt` has
  no `state` property. The local response root now exists, so a naive rerun is
  also refused as non-fresh.
- Cause: the collector parsed stdout unconditionally and dereferenced success
  properties before branching on the signed response manifest's terminal
  `FAILED` state.
- Preflight: exercise both PASS and FAILED signed response fixtures. For FAILED,
  require empty stdout, exact stderr and `FAILURE.json` validation, and terminal
  evidence construction without any success-property dereference. Make local
  extraction resumable only by exact response ID, ZIP hash, and manifest hash.
- Recovery: use the already signature- and file-hash-verified extracted response
  to write an explicit failed terminal gate; do not redownload, republish, or
  delete it. Success-property projection is allowed only after the endpoint
  state is proven `PASS_MAINTENANCE_PATCH`.
- First observed on 2026-08-21 while collecting the signed failed F2 response
  above. The response ZIP hash is
  `D65A5FB99D2EFA1DC8836B0AF5F62168E6AF6F3E788055A09CBC96D6FAC81492`.

### Insite response diagnostics must treat per-record context collections as optional

- Signature: a bounded read-only diagnostic succeeds in locating and validating
  the exact processed `INSITE_RESPONSE.json`, then stops under strict mode with
  `The property 'acquisitionContexts' cannot be found on this object` while
  iterating mixed response records.
- Cause: the diagnostic directly dereferenced `record.acquisitionContexts` even
  though the established response format permits records that do not carry that
  optional collection. A response-level `records` array is not evidence that
  every member has an acquisition-context property.
- Preflight: exact endpoint fixtures for any Insite response diagnostic must
  include at least one record with a valid target `acquisitionContexts` array
  and one record without that property. Require the target context to be
  returned and the optional-shape record to be skipped without failure.
- Recovery: retain the signed failed response as terminal evidence, create a
  fresh successor request, and replace the direct property dereference with an
  explicit property-presence read that defaults to an empty collection. Do not
  modify or replay the processed Insite response and do not weaken target-key
  or result-count bounds.
- First observed on 2026-08-21 in signed C2V24 response
  `R_ED4325FF7F3E_20260821104201376_9c8389ad`. The endpoint failed before any
  processor, task, queue, image, or wafer mutation.

### Scribe helper locations must come from the installed caller's path contract

- Signature: a read-only runtime inventory stops with
  `runtime dependency missing: multiChannelReader` even though the scribe
  proposal worker and its helper are installed and operating.
- Cause: the diagnostic guessed that every PowerShell consumer was installed
  directly under the processor state root. The established proposal pass
  resolves its multi-channel reader under
  `appRoot\runtime\scribe\Invoke-ScribeMultiChannelPolarityReader.ps1`.
- Preflight: before pinning an installed helper path, read the exact approved
  caller and derive the helper path using the caller's own root and relative
  path expression. The exact endpoint rehearsal must reproduce that nested
  layout; a flat fixture is insufficient.
- Recovery: retain the signed failed response as terminal evidence, use a fresh
  successor request, and change only the diagnostic inventory path to the
  caller-derived nested path. Do not move, copy, reinstall, or modify the live
  helper merely to satisfy a diagnostic path guess.
- First observed on 2026-08-21 in signed C2V25 response
  `R_53998EF67D26_20260821104917959_0fc91ec7`. No processor, task, queue,
  image, or wafer mutation occurred.

### Proposal diagnostics must bind exact catalog identities, not a lot-prefix directory set

- Signature: a bounded diagnostic stops with
  `target proposal directory bound exceeded` after a lot-prefix lookup returns
  more historical proposal directories than the target visit contains wafers.
- Cause: a lot can revisit the tool many times, so a top-level prefix match
  includes earlier and later acquisition identities. A lot prefix is not an
  exact scan-visit identity set and is both noisier and less safe than the
  catalog keys already in hand.
- Preflight: build the exact physical-identity set from the already bounded
  target lot and scan timestamp catalog rows, assert its expected cardinality,
  and probe at most one deterministic proposal path per exact identity. Include
  unrelated same-lot historical proposal directories in the endpoint fixture
  and prove they are never read or returned.
- Recovery: retain the signed failed response as terminal evidence and issue a
  fresh successor whose proposal lookup iterates only the exact catalog-derived
  physical identities. Do not raise the prefix bound, enumerate the whole
  proposal root, or delete historical proposals.
- First observed on 2026-08-21 in signed C2V26 response
  `R_F6DF51741F7B_20260821105436703_783b4d26`. No processor, task, queue,
  image, or wafer mutation occurred.

### Scribe-reader candidate summaries are versioned shapes with optional evidence fields

- Signature: an exact-identity proposal diagnostic reaches an installed
  `MULTI_CHANNEL_READER_SUMMARY.json` and then fails under strict mode because
  a nested candidate does not expose `supportCount` (or another newer evidence
  field).
- Cause: historical reader summaries preserve their creation-time schema. The
  summary-level state and candidate string can be present while optional
  scoring/support fields differ across revisions.
- Preflight: mix current and historical candidate objects in the exact endpoint
  fixture, including one candidate with only its string. Every projected nested
  field must use the established optional-property reader and a bounded default.
- Recovery: retain the signed failed response as terminal evidence, issue a
  fresh successor, and change only the diagnostic projection. Do not rewrite
  historical summaries, synthesize evidence counts, or treat a missing optional
  field as proof of a failed or accepted scribe.
- First observed on 2026-08-21 in signed C2V27 response
  `R_9217865715BB_20260821105945466_3e8719f2`. No processor, task, queue,
  image, or wafer mutation occurred.

### A forced retry epoch cannot act after a freshness-filtered exporter returns zero rows

- Signature: a bounded one-shot Insite retry accepts and installs its exact
  worker successor, but then fails with `one-shot worker did not create a new
  request hash` even though the forced retry timestamp would differ from the
  prior request.
- Cause: the worker applied the fresh retry epoch only after the normal exporter
  ran. When the last response snapshot was newer than the exporter's minimum
  retry interval, both confirmed-scribe and candidate exports returned zero
  rows, so there was no request object on which to apply the new epoch.
- Preflight: the exact Windows PowerShell 5.1 rehearsal must include a zero-row
  fresh-snapshot export while a hash-verified last confirmed-scribe request
  exists in exactly one pending/sent queue location. A forced refresh must
  validate and reuse that complete latest request contract, replace only its
  retry epoch, and require a different canonical hash.
- Recovery: retain the signed failed response as terminal evidence. Publish a
  fresh successor that performs the bounded latest-confirmed-request fallback;
  do not delete old queue artifacts, invent identities, lower normal snapshot
  freshness, or change the six-hour background default.
- First observed on 2026-08-21 in signed F5 response
  `R_217841C5FC29_20260821124928853_bc06e944`. The failed entry restored the
  approved predecessor worker; no old request/response package was deleted.

### Failed Insite-response payloads do not guarantee successful-response fields

- Signature: a read-only route validator finds its exact response under the
  JBOD `response_inbox\failed` root, then strict mode raises `The property
  'requestRows' cannot be found on this object` while projecting diagnostic
  acquisition keys.
- Cause: `INSITE_RESPONSE.json` in a failed import leaf can be a compact or
  legacy failure shape. It is not contractually required to expose the
  `requestRows` field present on successful current-image-candidate responses.
- Preflight: the exact endpoint fixture must include an exact failed response
  leaf whose payload omits `requestRows` while `IMPORT_FAILURE.json` is
  present. The validator must return the failed-package snapshot and bounded
  import failure without dereferencing the optional field.
- Recovery: retain the signed failed validator response as terminal evidence,
  issue a fresh successor, and change only the failed-payload diagnostic
  projection to use the established optional-property reader with an empty
  default. Do not rewrite or delete the failed import leaf and do not generate
  another Insite query.
- First observed on 2026-08-21 in signed C2V34 response
  `R_855ADBEE8B70_20260821133157640_d29f4a2a`. No processor, task, queue,
  image, or wafer mutation occurred.

### Bound-relay package verification requires the inspected directory itself to end in `.ready`

- Signature: a recovery entrypoint constructs an exact response replay in a
  directory ending `.partial.<revision>` and the installed bound relay rejects
  it with `Relay package directory must end with .ready` before import.
- Cause: the relay's directory contract validates both package contents and the
  suffix of the directory passed to `--package-check`. A partial directory is
  intentionally ineligible even when its manifest and payload hashes match.
- Preflight: the exact endpoint rehearsal must use the real installed-version
  relay checker, not a return-zero stub, and verify the package in a fresh
  staging directory whose leaf ends `.ready` before atomically moving it into
  the endpoint's pending root.
- Recovery: retain the signed failed endpoint response and preserved failed
  Insite response. Build a fresh successor that stages outside the watched
  pending root under an exact `.ready` leaf, validates it with the real relay,
  then moves that verified directory to the final pending name. Do not weaken
  the relay check or expose a partial directory to the watcher.
- First observed on 2026-08-21 in signed R3C response
  `R_D78A05394352_20260821140345679_d65f6c06`. The maintenance endpoint rolled
  back the importer; no task was restarted and the failed response was retained.
### Latest numbered nitride anchor selection must accept the qualified CVD tool family, not one tool ID

- Failure signature: a repeated scratch-test lot whose latest numbered `SACRIFICIAL NITRIDE DEP {n}` cycle ran `NITRIDE_DEP` on `6-4-CVD-01` was classified as `HOLD_FRONTSIDE_SCRATCH_TEST_POST_ANCHOR_MATERIAL_TOOL_PRESENT`; the route evidence incorrectly selected an older `{1}` anchor on `6-4-CVD-02` and marked the complete newer `{2}` flow as disallowed post-anchor processing.
- Cause: the A15 route classifier required exact resource equality with `6-4-CVD-02` when selecting the latest qualifying numbered nitride-deposition anchor. The process family has more than one qualified `6-4-CVD-*` deposition tool, so exact single-tool equality made valid later cycles invisible.
- Mandatory preflight: route-classifier rehearsals must include the same numbered nitride process block and `NITRIDE_DEP` step on at least `6-4-CVD-01` and `6-4-CVD-02`, prove that the latest qualifying numbered cycle wins, preserve refusal for a non-CVD material tool, and audit the provider for lot, slot, and scribe identity text.
- Recovery: use a bounded `6-4-CVD-[0-9]+` resource-family predicate only in the numbered `SACRIFICIAL NITRIDE DEP {n}` plus exact `NITRIDE_DEP` anchor test; keep post-anchor same-selected-block and approved inspection-tool rules unchanged. Re-query through a fresh signed request and import a new response package; do not rewrite the preserved old response or hardcode affected identities.
- First observed: the signed V36 post-R4 validator for request `REQ_V36_0821_1420_X1` proved all ten `62631-586` FRONT catalog rows and exact confirmed scribes, while every processed 086C target context carried the false post-anchor hold because the real latest `{2}` `NITRIDE_DEP` rows used `6-4-CVD-01`.

### File-backed publisher rehearsal manifests must use the guarded `InvocationManifest` parameter

- Failure signature: `Confirm-ArgosPowerShellWrapper.ps1` rejects a cloned publisher with `PowerShell script must declare InvocationManifest when a manifest is supplied` before its local create-new publication rehearsal.
- Cause: the cloned publisher accepted its bounded JSON through a legacy parameter named `RehearsalManifest`. The JSON was file-backed, but the governing wrapper guard can mechanically validate that boundary only through the standard `InvocationManifest` parameter.
- Mandatory preflight: before running any cloned publisher, pass its exact rehearsal JSON to `Confirm-ArgosPowerShellWrapper.ps1 -InvocationManifest ... -RequirePreflightSwitch`; require the publisher to declare `InvocationManifest`, parse that exact bounded JSON, and pass the wrapper and harness gates before execution.
- Recovery: rename only the publisher's JSON-path parameter and its internal references to `InvocationManifest`, regenerate the clone-literal and harness evidence for the changed exact bytes, refresh dependent preaction hashes, and repeat the non-mutating wrapper preflight. Do not bypass the wrapper gate or convert the JSON into command-line expressions.
- First observed on 2026-08-21 while guarding the A18 local publisher rehearsal. The wrapper guard stopped before the publisher executed, so no queue, archive, endpoint, task, or wafer state changed.

### A local publisher rehearsal requires an explicitly prepared empty queue fixture

- Failure signature: the publisher wrapper and zero-recurrence gates pass, but both publisher `-Preflight` and `-Apply` stop with `request queue unavailable` because the fresh rehearsal root has no `queue` directory.
- Cause: a fresh rehearsal output root is supposed to be absent, while the production publisher correctly requires its queue root to pre-exist. The local fixture setup step that creates only the empty rehearsal queue was omitted.
- Mandatory preflight: path-gate the exact fresh rehearsal root and its `queue`, `processed`, `archive`, and publish-gate leaves; verify the root is absent; then create only the empty queue directory under a separately declared fixture-setup preaction. Re-run publisher preflight and require queue state `NEW` before apply.
- Recovery: retain the failed no-mutation attempt, choose a new short rehearsal root, build the bounded empty queue fixture, and rerun the same exact publisher. Do not create, clear, or alter any production queue and do not make the production publisher silently manufacture a missing endpoint queue.
- First observed on 2026-08-21 during A18 local publisher rehearsal R2 at `C:\A18P2`. The root remained absent and no queue, archive, endpoint, task, or wafer state changed.

### Revision-token replacement must never rewrite opaque hashes

- Failure signature: a mechanically cloned successor changes a pinned SHA-256 literal because the predecessor revision token also appears coincidentally inside the hexadecimal digest, for example `...F3...` becoming `...F8...`.
- Cause: an unrestricted text replacement was applied to complete harness and definition files instead of separating semantic revision tokens from opaque digests and signatures.
- Mandatory preflight: after every revision-token transform, compare every 64-hex literal with the guarded source; classify each difference as either an explicitly recomputed hash of changed bytes or an error. Freeze payload hashes only after that audit and run the exact clone-remediation, parser, harness, and packaged-endpoint gates on the corrected bytes.
- Recovery: before signing or executing anything, restore all unchanged dependency hashes from the guarded source, recompute only hashes whose referenced bytes intentionally changed, update their exact consumers, and repeat the gates. Never derive a successor digest by textual substitution.
- First observed on 2026-08-21 during unexecuted F8 source construction from F3. Review caught the altered entrypoint and predecessor hash literals before signing, packaging, endpoint rehearsal, publication, or any endpoint mutation.

### Rehearsal fixture roots must match the publisher's exact authorized prefix

- Failure signature: a guarded publisher rejects a fresh local queue with `rehearsal path escaped` even though the path is short and local.
- Cause: the invocation manifest used a sibling such as `C:\F8P1` while the exact publisher authorizes only descendants of its pinned `C:\F8P\` rehearsal prefix.
- Mandatory preflight: extract the literal authorized rehearsal prefix from the exact publisher, path-gate that exact root and all leaves, and require the manifest's normalized queue, archive, and gate paths to be descendants of that prefix before creating the empty fixture.
- Recovery: retain the rejected no-mutation attempt, use a fresh exact authorized root, rebuild only the empty local fixture, and rerun the same publisher. Do not widen the publisher prefix merely to accept an incorrectly named fixture.
- First observed on 2026-08-21 in the F8 local rehearsal manifest using `C:\F8P1`; the publisher stopped before any queue or archive write and no production path was touched.

### Harness safety applies to harnesses and entry points, not an unchanged installed target script

- Failure signature: `Confirm-ArgosPowerShellHarnessSafety.ps1` reports two violations when it is incorrectly run against the byte-identical `Update-JbodDashboardManifest.ps1` installed target, even though the actual package entry point and all builder, signer, endpoint-test, publisher, and collector harnesses pass.
- Cause: the installed updater is ordinary product code invoked through the guarded `JD1.ps1` maintenance entry point; it is not itself a builder, signer, route test, endpoint rehearsal, response collector, publisher, operator launcher, or package entry point and therefore does not expose the harness-only `-Preflight` contract.
- Mandatory preflight: classify every packaged `.ps1` before invoking the harness guard. Run it against every new or changed harness and the exact maintenance entry point. For an unchanged installed target, require byte identity with its released source and target hash, include it in clone-literal and exact endpoint/predecessor/idempotence tests, and do not misclassify it as a harness.
- Recovery: withdraw the affected staging root, retain the failed preflight as no-mutation evidence, use a fresh root, and repeat the clone and harness gates with the unchanged target covered by byte-identity and exact endpoint gates instead of the inapplicable harness-only check.
- First observed on 2026-08-21 in unexecuted `work/JD2`; no request was signed, no package was built or published, and no endpoint, task, dashboard, source, or wafer state changed.

### Revision transforms must include lowercase machine-schema tokens

- Failure signature: a cloned publisher passes parsing and harness safety but rejects its bounded rehearsal JSON with `rehearsal manifest changed` because the script still expects the predecessor's lowercase schema token (for example `argos_c2v37_publish_rehearsal_v1`) while the new manifest correctly declares the successor token.
- Cause: the mechanical revision transform replaced uppercase `V37` labels and paths but did not replace the distinct lowercase `v37` embedded in the machine-readable schema.
- Mandatory preflight: after every revision transform, enumerate both case-sensitive human revision tokens and lowercase machine-schema tokens in the generated script, and compare the exact expected schema with the exact rehearsal JSON before creating the fixture root. The wrapper and harness gates remain required but are not sufficient for cross-file schema agreement.
- Recovery: retain the rejected no-mutation attempt, patch only the exact lowercase schema and a fresh authorized local rehearsal prefix, regenerate clone/harness/preaction hashes for the changed publisher, and use a new empty rehearsal root. Do not widen schema acceptance or reuse the prior fixture root.
- First observed on 2026-08-21 in the V38 local publisher rehearsal at `C:\V38P1`; only the empty local queue fixture existed, and no publisher queue, archive, endpoint, task, dashboard, source, or wafer state changed.

### Classify an Insite response from its signed payload shape, not from an earlier request stage

- Failure signature: a planned importer repair assumes a preserved response is a
  `ARGOS_CURRENT_IMAGE_CANDIDATE_OVER_LEGACY_RELAY_V1` envelope even though the
  later signed validator records a normal confirmed-scribe snapshot with no
  `transportEnvelope` property.
- Cause: the response was mentally associated with the candidate-identification
  stage that preceded it. The authoritative F8 response is the later normal
  `confirmed 12-character wafer scribe` snapshot; it was processed before the R4
  importer learned the V3 route contract and therefore needs exact replay through
  that already-released importer, not a speculative candidate-branch code change.
- Mandatory preflight: before changing an importer or worker, inspect the signed
  terminal validator's exact root-property set, lookup key, transport-envelope
  value, payload hash, and installed-importer chronology. Rehearse the smallest
  action supported by those exact facts.
- Recovery: withdraw the unexecuted draft that changed the candidate branch,
  retain it only as diagnostic evidence, and use a fresh root for an entrypoint-
  only exact replay of the preserved response through the byte-identical released
  importer. Do not publish the speculative edit.
- First observed on 2026-08-21 while planning unexecuted `work/R5`; signed V38
  evidence proved the F8 payload hash
  `C816B8EFF451940F0B85FDF59BC43D2031FCB9FF5DDAF8DC895CDFFA209B05B1`
  had no transport envelope. No request was signed or published and no endpoint,
  task, metadata, image, or wafer state changed.

### Validator projections may flatten response acquisition contexts

- Failure signature: an exact endpoint rehearsal writes ten verified rows, but
  all carry `HOLD_FRONTSIDE_SCRATCH_TEST_ROUTE_NOT_INCLUDED` even though the
  validator's projected `targetRecords` each expose one valid
  `acquisitionContext.frontsideScratchTestRoute`.
- Cause: the signed validator intentionally flattens each selected context into
  a convenient diagnostic `acquisitionContext` property. The live Insite payload
  retains the provider schema: each MES record contains an
  `acquisitionContexts` array. A replay harness built directly from the flattened
  projection did not reconstruct that source-schema array, and an entrypoint
  precheck that read the flattened name would also reject the real payload.
- Mandatory preflight: freeze both the signed root-property shape and the
  provider record schema. Endpoint fixtures derived from validator projections
  must explicitly reconstruct `acquisitionContexts`, and replay entrypoints must
  enumerate that array exactly. Require the released importer to write ten rows
  with the V3 route state and fingerprint before publication.
- Recovery: retain the signed-but-unpublished request and failed local rehearsal
  as withdrawn evidence, use a fresh revision and all fresh output roots, and
  correct only the fixture reconstruction and source-schema enumeration. Do not
  publish or patch the signed predecessor.
- First observed on 2026-08-21 in the local R5R2 `create` endpoint case. The
  endpoint returned a signed local failure and rolled back the create-only
  entrypoint. Only `C:\R5R2E1` rehearsal state was mutated; no portal request was
  published and no JBOD task, image, metadata, or wafer state changed.

### Metadata replay must use the processor-configured snapshot root

- Failure signature: a signed replay reports ten verified route rows, but the
  live catalog retains its old route holds and the processor does not schedule
  them.
- Cause: the importer was invoked without `-MetadataSnapshotRoot`, so it used its
  legacy fallback under the state root on `C:`. The installed v3 processor config
  authoritatively points to `D:\A2\m\verified`; inventory reads that configured
  root and therefore never saw the fallback overlay.
- Mandatory preflight: every direct metadata import must hash-verify and parse the
  installed `PROCESSOR_CONFIG.json`, require its review-only safety fields, bind
  the exact configured `metadataSnapshotRoot`, pass that value explicitly to both
  importer preflight and apply, and prove the resulting active-overlay path is
  under that root.
- Recovery: retain the signed response and importer unchanged, replay the same
  exact response through a fresh entrypoint-only request with the explicit
  configured root, then let the existing inventory/processor consume it. Do not
  copy or infer metadata between the fallback and configured roots.
- First observed on 2026-08-21 after signed R5R3 and V39: R5R3 wrote 10/10 rows
  to `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\metadata\verified`, while
  V39 proved the catalog still held all ten FRONT rows and the live config hash
  `CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8`
  points to `D:\A2\m\verified`. No task was restarted and no image was deleted.

### Live v3 processor configs may omit optional production-routing fields

- Failure signature: a strict-mode maintenance entrypoint fails before import
  with `The property 'productionRoutingEnabled' cannot be found on this object`
  while validating the installed processor config.
- Cause: the review-only v3 config predates that optional field. Direct property
  access under `Set-StrictMode` is invalid even though absence safely means false.
- Mandatory preflight: exercise both present-false and absent optional-property
  cases in the exact endpoint fixture, and use an explicit property-presence test
  with a false default before evaluating optional safety flags.
- Recovery: retain the signed failed response, use a fresh successor, and change
  only the optional-property read. Do not add or rewrite the live config.
- First observed on 2026-08-21 in signed R6 response
  `R_5068CB9AF5B6_20260821160227763_91f52969`. The endpoint rolled back the
  create-only entrypoint before import; the configured D: overlay, tasks, images,
  and wafers were unchanged.

### Legacy rehearsal harnesses must pass the current guard before cloning

- Failure signature: the current harness-safety preflight rejects a legacy
  predecessor test harness before any successor is created; here the retired
  `Test-C2RBehavior.ps1` reported three violations.
- Cause: the predecessor was released before the current non-mutating-preflight
  and bounded-evidence rules. Prior release evidence does not make its obsolete
  harness structure a valid template under the current policy.
- Mandatory preflight: guard every selected source script individually before
  cloning. Treat a rejected source as non-clonable; select only independently
  passing source scripts and unchanged locked assets, then run clone-literal and
  generated-harness gates on a fresh successor root.
- Recovery: do not copy, patch, or execute the rejected legacy behavior harness.
  Build the fresh successor only from the source signer, packager, publisher,
  collector, route test, exact endpoint test, and entrypoint scripts that pass
  the current guard, and rely on the current exact packaged endpoint rehearsal.
- First observed on 2026-08-21 before creating `work/R8`. The rejected source was
  not copied; no R8 root existed at the time, and no portal, JBOD task, image,
  catalog, or wafer state changed.

### Processor-refresh catalog cardinality must come from the current signed validator

- Failure signature: an activation entrypoint refuses before task restart with
  `expected ten confirmed physical acquisitions and twenty side-specific
  overlay-matched catalog rows`, while the current signed validator proves ten
  FRONT catalog rows for ten physical wafers.
- Cause: a legacy refresh package expected both FRONT and BACK catalog rows for
  each physical identity. The current inventory contract emits the relevant
  FRONT acquisition once; carrying the old factor-of-two invariant forward is
  invalid.
- Mandatory preflight: bind refresh cardinality to the immediate signed
  validator predecessor: confirmed rows, verified rows, FRONT catalog rows,
  distinct identities, and slots. Do not multiply physical identities by an
  assumed side count.
- Recovery: retain the signed failed request as terminal evidence, use a fresh
  successor, and change only the catalog/matched/not-ready cardinalities from 20
  to the signed current value of 10. Keep the task identity, hashes, safety
  checks, and idle-boundary behavior unchanged.
- First observed on 2026-08-21 in signed R8 response
  `R_0FE56F0676DA_20260821163245034_fbc68fa1`. The entrypoint failed its bounded
  pre-action state check before task restart; the exact runner remained
  unchanged and no image, catalog, ledger, or wafer was modified.

### A successor is not remediated until every executable assertion is closed

- Failure signature: a successor is described and checkpointed as correcting a
  stale invariant, while another executable copy of that exact stale invariant
  remains in the successor payload. Here R9 was described as the ten-row FRONT
  correction even though `C2R.ps1` still contained
  `if($catalogRows.Count-ne20)`.
- Cause: the change was treated as a local text edit instead of a dependency-
  closure operation. Fixture values and later assertions were changed, but the
  earlier live catalog-cardinality assertion was not included in a mechanical
  semantic inventory. Packaging/hashing work then continued before proving
  that every predecessor count, name, hash, state token, and assertion had been
  eliminated or explicitly retained.
- Mandatory preflight: before creating, checkpointing, signing, or publishing a
  successor, enumerate every executable occurrence of each changed semantic
  value across payload, fixtures, signer, builder, endpoint rehearsal,
  publisher, collector, manifests, and gates. Require zero undeclared legacy
  occurrences and run a positive ten-row case plus a negative non-ten-row case
  against the exact payload. Describing the intended delta is never evidence
  that the implementation contains it.
- Recovery: stop at the last committed checkpoint. Record the incomplete
  successor as unsigned, unrehearsed, unpublished, and unexecuted. Pin any
  post-checkpoint edits as unvalidated; do not resume packaging until a fresh
  task performs the complete semantic inventory and dependency closure from the
  committed baseline.
- First observed on 2026-08-21 after safe checkpoint commit
  `100add177e24d035c133f78169cbfd9c8d583706`. The stale R9 assertion was found
  by bounded source inspection. R9 had not been signed, published, or executed,
  and no Argos/JBOD task, image, catalog, ledger, or wafer state changed.

### Cardinality bindings must preserve the signed validator's exact population predicate

- Failure signature: a live successor bound to a signed validator's ten FRONT
  rows fails before task restart with `C2R expected ten current FRONT catalog
  rows; found 20.`
- Cause: the signed V40 validator counted
  `catalog.acquisitions` only when `domain == 'FRONTSIDE'`, in addition to the
  exact lot and scan predicates. R9 copied the scalar result `10` but selected
  every catalog acquisition whose `physicalIdentity` matched the ten wafers;
  it omitted the FRONT domain predicate and therefore evaluated a broader
  20-row population. The earlier recovery statement that changing the scalar
  cardinalities from 20 to 10 was sufficient was incomplete: a cardinality is
  not portable without its exact selection predicate and population semantics.
- Mandatory preflight: for every count imported from a signed validator, bind
  and mechanically compare the complete selector, including lot, scan,
  physical identity, domain/side, uniqueness key, and grouping semantics. The
  exact endpoint fixture must include the ten intended FRONT rows plus bounded
  non-FRONT competitors sharing the same physical identities, prove the
  competitors are excluded, and include missing, duplicate, and wrong-domain
  FRONT negative cases. A scalar-only fixture field such as `catalogRows = 10`
  is not sufficient evidence of selector equivalence.
- Recovery: retain R9 and its signed terminal failure as withdrawn evidence.
  Use a fresh successor that selects the exact ten rows with the signed V40
  FRONT predicate before applying matched, hold, not-ready, and route-state
  assertions. Keep the declared exact RESTART action and all safety boundaries;
  do not publish until the packaged endpoint rehearsal exercises both the ten
  FRONT rows and the same-identity non-FRONT competitors. Do not reinterpret the
  raw 20-row count as twenty FRONT rows.
- First observed on 2026-08-21 in signed R9 response
  `R_A5A427490F0D_20260821174144370_961e73de`. The response signature and all
  three declared files verified. The verifier failed before any scheduled-task
  restart; the endpoint returned a terminal signed failure, and no source was
  deleted, no other inspection task was changed, and no wafer was aborted.
