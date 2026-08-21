# Argos C1D3 continuation failure-prevention audit — 2026-08-19

Disposition: `APPROVED_BASELINE` for engineering workflow prevention only.
This does not authorize JBOD mutation, detector output, cutover, deletion,
training, XML, or production routing.

## Why this audit exists

The C1D3 continuation exposed several avoidable local harness defects after
work had already begun.  Most were caught before external mutation, but they
still caused repeated commands, a withdrawn local signature, or a fresh build.
The operator requires these failures to be rejected during planning and
preflight instead of rediscovered during implementation.

The governing prevention sources are now:

- `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`;
- `work/ARGOS_POWERSHELL_HARNESS_SAFETY.md`;
- `utilities/Confirm-ArgosPowerShellHarnessSafety.ps1`;
- the mandatory harness gate added to `AGENTS.md`.

## New or repeated issues and enforced prevention

| Issue | What happened | Planning/preflight prevention | Enforced by |
|---|---|---|---|
| Caller graph was incomplete | The root-aware Insite leaf scripts were correct, but the tray's two manual callers omitted `MetadataSnapshotRoot`. | Enumerate all direct/indirect automatic and interactive callers whenever a root/parameter changes; test v2 fallback and v3 propagation end to end. | Failure memory + exact C1D3 behavior gate. |
| Longest temporary leaf was omitted from the first plan | The final payload path passed, while its `.partial` form plus reserve reached 204. | Gate source, final, longest temporary, quarantine, extraction, and response leaves before the first write; use a short physical root at effective length 200. | Path policy + failure memory. |
| Inline `foreach` was piped directly | Three read-only probes repeated `An empty pipe element is not allowed`; the third was the live-terminal checkpoint hash query. | Capture compound output in `@(...)` or an explicit result array before piping; parse every file-backed harness under PowerShell 5.1 and visually reject this token pattern in ad-hoc multi-statement commands before execution. | Existing memory section + wrapper/harness parser gate; ad-hoc pre-execution checklist because an unsaved command is outside static-file coverage. |
| External PowerShell stdout was treated as a typed object | Final-ZIP extraction completed, then `.State` failed because `powershell.exe` returned rendered text. | Invoke trusted scripts in-process for typed results or emit/parse bounded JSON explicitly. | Harness static check `EXTERNAL_POWERSHELL_TEXT_USED_AS_OBJECT`. |
| First signature preceded full installer-test design freeze | `REQ_C1D3` was signed locally, then withdrawn when the Completed Lot invariant and exact rollback injection were added. | Freeze entry point, payload, predecessor, roots, task allowlist, invariants, rollback injection, response leaves, route revision, and authority before the first signature. | AGENTS + harness safety workflow; signer must require the freeze record for future packages. |
| A `-Preflight` wrote durable evidence | `Test-C1D3Routes.ps1 -Preflight` created the route gate; later, the D2S3 mechanical clone inherited the same prohibited contract from legacy D2S2, but the guard stopped it before execution. | Preflight may calculate and print only; a separate `-Gate`/`-Build`/`-Test`/`-Apply` action creates output. Guard every source template before cloning, freeze remediation for any legacy violation before the first generated write, and guard every output before execution. | Harness static check `PREFLIGHT_HAS_NO_RETURN_BEFORE_MUTATION` + strengthened harness workflow. |
| Typed parameter/local variable collision | Adding `-Gate` collided case-insensitively with the existing local `$gate` path result, producing a `SwitchParameter` conversion failure. | Never assign to a declared parameter under any case variant; use semantic result names. | Harness static check `PARAMETER_VARIABLE_REASSIGNED`. |
| Broad recursive workspace search was used | Recursive `Get-ChildItem work` hit concurrently absent deep paths, timed out, and emitted more than 10,000 tokens. | Use `rg` first or one exact bounded subroot, stop on errors, cap rows/strings, and save large evidence file-backed. | AGENTS + harness broad-recursion static check for file-backed scripts. |
| Width-dependent output hid hashes/lengths | Long `Select-Object`/table output wrapped and omitted required fields. | Emit bounded JSON or explicit `<hash> <path>` scalar rows; never use `Format-*` as gate evidence. | Harness `RENDERED_TABLE_IS_NOT_GATE_EVIDENCE`. |
| Narrow wrapped-prose patch left an orphan line | Adding the clone-template rule replaced only part of a wrapped bullet; the later AGENTS clone-gate insertion repeated the issue and briefly left a stray `Freeze`. Both were caught by bounded readback. | Patch the entire logical Markdown sentence/bullet/paragraph, not a visually convenient wrapped line, and immediately reread bounded context before hashing/checkpointing. | Failure memory + mandatory post-patch bounded readback. |
| Failed output root risked collision/reuse | A failed final build left a ZIP/extraction tree behind. | Preserve it under a path-gated failed-attempt quarantine and require a fresh output root. | Failure memory + build fresh-root assertions. |
| Checkpoint/ledger append used a fragile full-row anchor | The combined checkpoint patch first rejected atomically on a mojibake row; the later isolated terminal-ledger append still rejected before mutation on a one-space mismatch. | Edit one authority file at a time; require the permanent EOF marker `<!-- ARGOS_REVISION_LEDGER_APPEND_SENTINEL -->` and insert each new row immediately before it; reject any ledger append that matches a rendered/full row. Parse and re-hash after every file. | Failure memory + structural append sentinel now present in the ledger. |
| Optional tool availability was assumed | `git` was not present on `PATH`, adding irrelevant diagnostic noise. | Discover optional tools with `Get-Command`; fall back to explicit hashes/bounded enumeration. | Failure memory + harness safety coding rules. |
| Gate caller guessed a PASS token | The D2S3 workspace safety guard returned zero violations and `PASS_ARGOS_POWERSHELL_HARNESS_SAFETY`, but the caller expected an invented shorter token and threw before target execution. | Read the exact file-backed utility contract or one metadata-only result; assert that literal and the violation/error counts. Never infer state names from filenames. | Failure memory + exact-state assertions in subsequent calls. |
| New revision reused predecessor rehearsal/extraction roots | D2S3 inherited `C:\S2E`, `C:\S2D`, and `C:\S2B`, then separately missed D2S2 extraction root `C:\A1S`; both exact preflights refused before mutation. | Require a complete machine-readable source/generated literal-root manifest. Every drive/UNC root must be classified as replaced or allowed unchanged; path-gate fresh targets and preserve prior roots. | New `Confirm-ArgosCloneLiteralRemediation.ps1` mandatory gate; D2S3 uses `C:\S3E`, `C:\S3D`, `C:\S3B`, and `C:\A3S`. |
| Planned alias path used `Join-Path` before the alias existed | C1D3A publication preflight repeated the documented missing-`U:` provider failure; D2S3 later inherited it from legacy D2S2, but the static guard stopped the cloned publisher before execution. | Compose not-yet-created alias leaves provider-independently, enumerate the exact UNC queue during preflight, and create/verify the mapping plus repeat zero-pending only in `-Apply`. Guard source templates before cloning. | Harness static check `JOIN_PATH_USES_NOT_YET_CREATED_DRIVE` + corrected publisher structure. |
| Script-scoped PSDrive was invisible to `Get-FileHash` and left an exact upload | D2S3 `Copy-Item` created the exact `.upload`, then the module's internal `Resolve-Path` could not see script-scoped `U:`; no ready file or publish gate was created. | Rehearse the actual post-copy module command; use a tracked temporary globally visible PSDrive only in apply; exact-root verify and remove only if created. Make publisher states `NEW`/`EXACT_UPLOAD`/`EXACT_READY`, hash-match own artifacts, reject all others, and resume without overwrite. | Failure memory + resumable corrected D2S3 publisher. |
| Static mutation set omitted drive mappings | The original guard passed a collector that created `New-PSDrive` before its preflight return because mapping commands were not classified as mutations. | Include PSDrive and SMB-mapping create/remove commands; require guard self-pass, corrected-target pass, and preserved legacy negative control yielding `MUTATION_BEFORE_PREFLIGHT_RETURN`. | Updated static guard + D2S2 collector negative control. |
| Throwing JSON gate output was lost by assignment and `Tee-Object` | The legacy negative control emitted correct failure JSON, then threw before either enclosing assignment or `Tee-Object -Variable` retained a parseable object in this host. | Use the metadata-only guard's explicit `-ReturnFailureResult` regression switch to assert exact failure JSON/codes; default production calls must still throw. | Failure memory + explicit regression-only guard contract. |
| Optional live maintenance result field was read under strict mode | The signed C1D3A `RESULT.json` omitted optional `changes` even though mandatory result fields and signed stdout passed. | Classify fields as mandatory/optional; presence-check optional properties and fully validate them when present while always requiring exact signed stdout hashes. | Failure memory + corrected response collector. |
| Migration scope wording was ambiguous | "Move C: to D:" could sound like a whole-drive move. | Every migration manifest must use exact root allowlists and explicit exclusions; reject drive roots and undeclared trees. | AGENTS/failure memory + locked storage scope below. |

## Repeated operational bugs already covered and still mandatory

These were not reimplemented in C1D3, but they remain part of the same
continuation and must not regress:

- Completed Lot must never be a fire-and-forget viewer launch.  Smoke probes,
  persistent logs, window-presence proof, and surfaced failure paths remain
  mandatory.
- Operator packages and logs must not rely on Downloads surviving cleanup.
  Durable logs belong under ProgramData/state or a locked workspace evidence
  root.
- Scheduled-task repair must snapshot the live principal/definition and patch
  only an explicit allowlist; a stale expected principal is not authority.
- One queue-head collision or malformed request must receive a compact signed
  terminal failure, be quarantined/ledgered, and never block the next control
  request.
- The live installed endpoint root set—not an invented rehearsal root set—must
  govern every maintenance rehearsal.
- Exact consumer validation must include automatic and manual Insite paths so
  an Scribe/Insite wait cannot remain pinned to stale C: metadata.
- No later request may be published while an earlier accepted request lacks a
  matching signed terminal response unless the bounded endpoint audit exception
  in `AGENTS.md` is satisfied.

## Locked inspection-storage scope

The active Stage 1 operation is not a C:-drive migration.  It is limited to the
Argos processor's `cache`, `metadata`, and `dashboard_outputs` trees, totaling
93,709 files and 232,912,232,897 bytes in the frozen snapshot.  Their short D:
roots are `D:\A2\c`, `D:\A2\m`, and `D:\A2\d`; Stage 1 worker state is
`D:\A2\x`.  Future review output is planned for `D:\A2\o`.  Raw acquisitions
remain `D:\KLARFExport`.

Explicit exclusions include the C: drive root, Windows, user profiles,
Downloads, portal/relay state, processor state, `C:\P21E`, historical
`outputs`, `identity`, `hotfixes`, and every undeclared tree.  No source may be
deleted until D3, cutover, real D: consumer validation, and exact recovery
authorization pass.

## C1D3 corrective actions required before checkpoint activation

1. Quarantine the route gate created by the invalid preflight and every final
   package gate that consumed it.
2. Use the corrected `Test-C1D3Routes.ps1` with separate `-Preflight` and
   `-Gate` actions.
3. Run wrapper and harness safety gates on every C1D3 script.
4. Run the truly non-mutating route preflight, then the explicit route gate.
5. Rebuild the final ZIP in a fresh root and repeat extracted-package endpoint
   cases.
6. Recompute all hashes and amend the unactivated checkpoint draft.
7. Only then update continuity, active state, and the ledger independently and
   run continuity/session safety.

Until these steps pass, `REQ_C1D3A` remains unpublished and the prior signed
D2S2 checkpoint remains authoritative.
