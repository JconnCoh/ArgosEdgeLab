# Argos Windows/JBOD Failure-Prevention Memory

### Rebased state counts must update both producer assertions and invoked consumer arguments

- Signature: a fresh local maintenance rehearsal proves the rebased producer
  split, then the real viewer projection check rejects the ready-row count.
- Cause: the entrypoint's producer assertion was rebased from five to three
  operator-review-ready rows, but its exact viewer command still passed the
  predecessor literal `--hold-projection-check 1532 190 5`.
- Preflight: search every entrypoint, test harness, and invoked consumer argument
  for predecessor cardinality literals; bind the consumer argument to the same
  frozen rebased count and exercise the actual compiled consumer.
- Recovery: retain the failed local roots, verify rollback, correct the
  still-DRAFT entrypoint argument, and rerun all controls on fresh roots.
- First observed: GUIHV5M1 local matrix on 2026-09-01. The entrypoint restored
  all installed and producer-output fixture predecessors before tray relaunch;
  no portal, JBOD, source-image, wafer, XML, or production state changed.

### A bounded post-failure DATA_PULL is an overlay, not a complete fixture tree

- Signature: a local package rehearsal extracts a successful post-failure
  DATA_PULL and then cannot find `PROCESSOR_CONFIG.json` while constructing its
  processor fixture.
- Cause: the observation deliberately returned only the changed queue and its
  two dashboard controls; the rehearsal incorrectly treated those three files
  as a replacement for the previously signed complete processor-tree fixture.
- Preflight: declare complete signed fixture evidence and current signed
  observation evidence separately. Build from the complete fixture first, then
  overlay only the exact current observation leaves and verify both ZIP hashes.
- Recovery: preserve the incomplete fixture roots, keep product/package bytes
  unchanged, correct the still-DRAFT harness, and rerun on fresh roots.
- First observed: GUIHV5M1 local matrix on 2026-09-01. The stop occurred before
  entrypoint execution; no portal, JBOD, task, process, installed Argos,
  source-image, wafer, XML, or production state changed.

### A final signed portal package does not retain its development definition file

- Signature: an exact-final-ZIP rehearsal extracts and verifies the signed
  request, then its local test harness stops while copying
  `MAINTENANCE_DEFINITION.json` from the extracted request root.
- Cause: the development source root contains the definition used to construct
  the signed manifest, but the final portal request correctly carries the
  entrypoint, changes, actions, and rehearsal contract in
  `PORTAL_REQUEST_MANIFEST.json`; the definition is not a signed request leaf.
- Preflight: a final-ZIP harness must require and verify the signed portal
  manifest and signature. It may copy a development definition only when the
  selected source is an unsigned development tree; it must not require that
  file from a signed request.
- Recovery: preserve the failed local package root, leave the signed ZIP bytes
  unchanged, correct the still-DRAFT harness, and rerun the exact extracted ZIP
  on fresh package and fixture roots.
- First observed: GUIHV5 exact-final-ZIP rehearsal on 2026-08-31. The stop
  occurred before fixture construction or entrypoint execution; no portal,
  JBOD, installed Argos, task, process, source-image, wafer, XML, or production
  state changed.

### Waiting before draining redirected child output can deadlock a successful PowerShell gate

- Signature: a locally launched Windows PowerShell 5.1 child remains in
  `WaitForExit` until the harness timeout even though the same exact child
  command completes in seconds when invoked directly, and the child made no
  gated mutation.
- Cause: the parent redirected stdout and stderr, waited for process exit, and
  only then called `ReadToEnd`. The child's valid JSON exceeded the bounded OS
  pipe buffer, so the child blocked writing while the parent blocked waiting.
- Preflight: for every redirected child, start asynchronous stdout and stderr
  drains immediately after `Start`, before `WaitForExit`; only consume the two
  completed results after the child exits. Exercise a positive control whose
  output is larger than 4 KiB.
- Recovery: retain the timed-out fixture/package roots as failed local
  evidence, do not reuse them, correct the still-DRAFT harness to drain both
  streams asynchronously, and rerun on fresh path-gated fixture/package roots.
- First observed: GUIHV5 local maintenance-package rehearsal on 2026-08-31.
  Direct non-mutating preflight returned `PASS` in 2.6 seconds; no portal,
  JBOD, installed Argos, source-image, task, process, wafer, XML, or production
  state was changed.

### A development target asserted as a proven control can discard the evidence needed to tune it

- Signature: a signed actual-wafer regression runs its earlier proven controls,
  reaches the intended fixture-ambiguity development wafer, and returns only a
  compact failure saying the expected unique result was not obtained; the
  candidate metrics and review images already produced before the assertion are
  absent from the signed response.
- Cause: the runner classified an unvalidated target outcome as `UNIQUE` and
  threw before serializing its bounded diagnostic result. A development target
  is evidence to observe, not a release control to assert before its first run.
- Preflight: divide every cohort manifest mechanically into frozen positive
  controls, frozen negative controls, and development observations. Assertions
  may abort only on the frozen controls. Every development observation must be
  serialized with its exact state, candidates, metrics, and review rasters even
  when its intended improvement does not occur.
- Recovery: preserve the signed failed package and compact response as terminal
  evidence. Use a fresh namespace and create-new output roots, keep the detector
  semantics unchanged for the evidence run, change the target case to
  `OBSERVE`, and return the complete bounded cohort. Tune only from those actual
  returned metrics; do not infer why the detector held from the assertion text.
- First observed: OCV-03 O3B10 R16 actual-wafer regression on 2026-08-29.
  Proven chipout, BowComp, split-channel, coverage, and width cases ran before
  the fixture target stopped the runner. The signed endpoint rolled back the
  create-only R16 install; no existing Argos task/process, source image, wafer,
  provider activation, hold, training, XML, or production state was changed.

### Casting a parsed JSON object to string before `ConvertTo-Json` destroys the predecessor bytes

- Signature: an exact predecessor rehearsal is refused because the fixture config hash differs from the pinned installed config even though its source evidence contains the correct parsed object.
- Cause: the fixture used `[string]$evidence.endpointConfig | ConvertTo-Json`; the cast occurred before serialization and converted the object to a display string rather than JSON object data.
- Preflight: pipe the parsed object itself to `ConvertTo-Json` under the exact installed Windows PowerShell host, then require the reconstructed byte count and SHA-256 to equal the signed installed-config evidence before launching the entrypoint.
- Recovery: preserve the failed fixture root and executed harness revision, create a fresh harness and fixture root, remove the premature string cast, and rerun all parser, harness, preaction, and predecessor gates. Do not loosen the production predecessor hash.
- First observed: OCV-03 O3B2 local entrypoint rehearsal R1 on 2026-08-28. The installer stopped before swapping either target file; no portal, JBOD, task, process, source, image, wafer, or production action occurred.

### Raster provenance and DOM gates do not prove that a detector contour is semantically correct

- Signature: a hash-complete, mask-bounded, real-browser-loaded gallery is
  visually rejected because the DF cyan trace walks repeating die-edge teeth
  around the crop, twenty-one periodic texture gaps are presented as candidate
  notches, and localized red marks do not hug the actual manufactured notch.
  The page nevertheless calls itself a contour-hugging gallery.
- Cause: the raster gate correctly proved current asset lineage and zero
  changes outside each provider mask, while the browser gate correctly proved
  URL, revision, cardinality, loading, and toggle isolation. Neither gate
  proved the detector's semantic claim. The returned detector had already
  failed closed with `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`, zero physical
  candidates, and zero eligible physical candidates; presenting its 21 DF
  channel-only responses under a contour-hugging review title overstated the
  evidence.
- Preflight: before any raster page is classified `RELEASED_REVIEW_ONLY`,
  separate lineage correctness from semantic correctness. When the detector
  returns zero reconciled physical candidates or a candidate storm, label the
  page diagnostic-only and keep it operator-visible only as failure evidence.
  Require operator visual review of the exact current revision before calling
  any contour notch-hugging, accepted, correct, or review-ready. A DOM/browser
  load pass and an outside-mask pixel count can never substitute for this
  semantic gate.
- Recovery: retain the presented R2 gallery unchanged as terminal rejected
  evidence, record the exact operator rejection and screenshot lineage in a
  separate create-new feedback root, withdraw the release classification, and
  keep `HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`. Do not hide cards, relabel the
  candidate storm, patch the presented root, tune thresholds/algorithms, or
  create a successor renderer without explicit authority and a fresh
  namespace.
- First observed: OCV-03 O3N1 Slot16 gallery R2 on 2026-08-27. Operator
  rejection identified DF candidates 19-21 as representative visible examples
  of the repeated-tooth trace and non-notch red marks. No provider, processor,
  task/process, source, threshold, algorithm, or production action followed.

### Raster overlays must be audited against their actual provider base, not a sibling clean asset

- Signature: an OpenCV raster-provenance audit fails closed with `Overlay
  changed pixels outside mask` on the first candidate even though the frozen
  renderer asserted its own overlay/mask invariant and no audit gate was
  written.
- Cause: the audit compared the returned overlay to the sibling `clean` crop.
  The frozen renderer writes four distinct assets: raw `clean`, processed
  `enhanced`, `overlay` composited on `enhanced`, and the overlay `mask`.
  CLAHE/enhancement changes nearly the entire crop relative to `clean`, so
  those legitimate base changes appear outside the annotation mask. The
  renderer's exact source shows both BF and DF overlays are derived from the
  enhanced base and verifies the mask against that base before writing.
- Preflight: trace and pin the exact overlay-construction base from the frozen
  provider before a pixel audit. Require `clean` to remain a separate locked
  `CLEAN_BASE`; audit `overlay` against the exact `enhanced` provider base and
  record that base path/hash explicitly in the current-layer lineage. Reject
  any audit that infers the base from a sibling filename or role label.
- Recovery: preserve the failed frozen audit provider, job, and preaction as
  withdrawn and non-reusable. Prove no audit gate or raster write occurred.
  Use a fresh provider/job/output namespace that verifies clean, enhanced,
  overlay, and mask hashes and computes outside-mask changes only between the
  overlay and its exact enhanced base. Do not modify, recompose, or rename any
  returned raster.
- First observed: OCV-03 O3N1 returned-raster audit R1 on 2026-08-27. The
  exact 90 returned rasters and signed review ZIP remained unchanged; the R1
  audit gate was absent.

### `System.IO.Compression.FileSystem` alone does not expose `ZipArchiveMode` in Windows PowerShell 5.1

- Signature: an exact Windows PowerShell 5.1 collector preflight reaches an
  in-memory ZIP boundary test and fails with `Unable to find type
  [IO.Compression.ZipArchiveMode]` before any extraction root or collection
  gate is created.
- Cause: the collector loaded only `System.IO.Compression.FileSystem`. The new
  zero/one/many byte-array test directly constructed `ZipArchive` objects and
  used the `ZipArchiveMode` enum, whose assembly was not explicitly loaded in
  that Windows PowerShell 5.1 process.
- Preflight: before invoking any function that constructs a `ZipArchive` or
  references `ZipArchiveMode`, explicitly load both `System.IO.Compression`
  and `System.IO.Compression.FileSystem`. Require the exact Windows PowerShell
  5.1 non-mutating preflight to execute the zero/one/many cases, not merely
  parse the type names.
- Recovery: preserve the failed frozen collector, invocation, preaction, and
  clone gate as withdrawn and non-reusable. Prove the response root, payload
  root, and collection gate are absent. Create a fresh collector namespace
  from the qualified source with both assemblies loaded before the test; rerun
  clone, wrapper, harness, zero-recurrence, and exact Windows PowerShell 5.1
  gates. Do not republish the request or alter the signed response.
- First observed: OCV-03 O3N1 DATA_PULL collector R1 on 2026-08-27. The signed
  response ZIP remained unchanged at SHA-256
  `4BCF17CDCB84EA06FAB931776763FE3966F87197089A688823796E6586481C28`;
  `C:\O3N1P`, `C:\O3N1D`, and the collection gate were absent.

### Adjacent parenthesized positional expressions are not valid PowerShell command arguments

- Signature: a frozen PowerShell harness is rejected by the static wrapper
  parser with repeated `Unexpected token '(' in expression or statement` and
  `Missing closing ')' in expression` errors before the target runs.
- Cause: a function was invoked in command argument mode with multiple
  adjacent parenthesized positional expressions, for example
  `Assert-PinnedJson (<path expression>) (<hash expression>) '<state>'`.
  PowerShell did not treat the second parenthesized expression as a new
  positional argument.
- Preflight: compute every non-scalar path/hash expression into a named local
  variable first, then invoke the function with named parameters whose values
  are simple variables. Require an exact Windows PowerShell 5.1 parser/wrapper
  pass before freezing or executing the successor.
- Recovery: preserve the rejected frozen harness, invocation, and preaction as
  withdrawn and non-reusable. Use a fresh namespace with precomputed argument
  variables; rerun wrapper, harness, zero-recurrence, and exact non-mutating
  preflight. Do not alter or republish the signed request/response.
- First observed: OCV-03 O3N1 render-response collector R2 on 2026-08-27. The
  wrapper rejected lines 99-103 before the collector executed; `C:\A3N1C` and
  the R2 collection gate remained absent.

### Empty byte-array function output can collapse to `$null` in Windows PowerShell 5.1

- Signature: a response collector's exact non-mutating preflight reads a
  zero-byte ZIP member successfully, then strict mode fails on `.Length` with
  `The property 'Length' cannot be found on this object.` No extraction root or
  collection gate is created.
- Cause: the helper returned `MemoryStream.ToArray()` through the PowerShell
  success-output pipeline. Windows PowerShell enumerated the empty byte array
  into no output, so assignment produced `$null` rather than a zero-length
  `[byte[]]`.
- Preflight: every helper that returns binary/text entry bytes must use an
  explicit non-enumerating output boundary and its exact Windows PowerShell
  5.1 gate must exercise zero-byte, one-byte, and many-byte ZIP members. Assert
  the result type and exact lengths `0`, `1`, and `N` before freezing the
  collector.
- Recovery: preserve the failed frozen collector, invocation, and preaction as
  withdrawn and non-reusable. Prove the failed preflight created neither its
  local extraction root nor its collection gate. Use a fresh collector
  namespace with the non-enumerating boundary and rerun wrapper, harness,
  zero-recurrence, exact preflight, and collection gates. Do not republish the
  request or modify the signed response.
- First observed: OCV-03 O3N1 render-response collector R1 on 2026-08-27. The
  exact response ZIP remained unchanged at SHA-256
  `5B292BCE4487ED8D5CC11DDD99C61F571F305837551A0839B9BAC8CC76AD373D`;
  `C:\A3N1C` and the collection gate were both absent after failure.

### PowerShell keyword adjacency can survive static parsing and fail only at runtime

- Signature: a Windows PowerShell 5.1 non-mutating preflight parses and passes
  the static harness gate, then stops because `return$Path.Replace(...)` is
  interpreted as a command name instead of the `return` keyword followed by an
  expression.
- Cause: removing optional whitespace during a compact mechanical rewrite
  joined a language keyword directly to a variable token. The PowerShell AST
  parser accepted the source and the existing harness adjacency checks covered
  simplified `Where-Object` operators but not keyword/variable boundaries.
- Preflight: before freezing any compact PowerShell publisher or launcher,
  scan exact source bytes for keyword-variable adjacency such as
  `return$`, `throw$`, `break$`, and `continue$`, then run the exact
  non-mutating path under Windows PowerShell 5.1. Static parser success alone
  is insufficient.
- Recovery: prove the failed preflight made no write, withdraw the frozen
  publisher bytes, preserve the unchanged signed request, and create a fresh
  publisher revision with explicit keyword whitespace. Do not edit or replay
  the frozen publisher revision.
- First observed: OCV-03 O3C2 publisher R1 preflight on 2026-08-27. The share
  target and upload path remained absent, no publication gate was written, and
  no JBOD, source, task, process, wafer, provider, training, XML, or production
  action occurred.

### Nested rehearsal exceptions require an explicit entrypoint failure contract

- Signature: an injected provider failure safely removes its temporary mapping
  and creates no output, but the outer entrypoint rehearsal gate fails because
  it assumes the provider's inner exception text will be preserved verbatim
  across a nested script invocation and pipeline assignment.
- Cause: the harness matched one raw inner message while the caller did not
  define an explicit wrapped failure token. Safe cleanup behavior was proved,
  but the test could not identify the exact intended injected branch.
- Preflight: wrap the provider invocation in the entrypoint, emit one stable
  revision-specific failure prefix followed by the bounded inner message, and
  require the failure test to match both that prefix and the intended injected
  token. Independently assert output absence and temporary-alias cleanup.
- Recovery: retain the failed rehearsal output namespace, change only the
  draft entrypoint exception contract and harness expectation, then use a fresh
  path-gated output namespace. Do not rerun or delete the prior rehearsal.
- First observed: OCV-03 O3C2 entrypoint R1 local rehearsal on 2026-08-27.
  The success output existed, the injected-failure output did not, `Q:` was
  absent after the failure, and no portal, JBOD, source, task, process, wafer,
  provider-activation, training, XML, or production action occurred.

### Failure-injection fixtures must satisfy the live entrypoint cardinality first

- Signature: an entrypoint's injected-failure rehearsal expects to reach the
  provider after one source hash, but the fixture contains one BF/DF pair while
  the exact live entrypoint requires ten. The rehearsal stops correctly at the
  earlier cardinality gate and never exercises the intended failure boundary.
- Cause: the provider's generic ONE collection control was reused as an exact
  live-entrypoint failure fixture. Provider breadth and live job cardinality
  are separate contracts.
- Preflight: bind success and injected-failure entrypoint cases to the same
  exact live cardinality and source-manifest schema. Vary only the create-new
  output path and explicit failure-injection field. Keep ZERO and ONE controls
  in the provider-local gate, not the live-entrypoint gate.
- Recovery: preserve the failed rehearsal namespace, leave the entrypoint and
  provider bytes unchanged, and execute the corrected fixture in a fresh
  path-gated output root. Never loosen the live cardinality guard to make a
  generic fixture reach the injected branch.
- First observed: OCV-03 O3C2 entrypoint R2 local rehearsal on 2026-08-27.
  Success completed, failure output was absent, and no portal, JBOD, source,
  task, process, wafer, provider-activation, training, XML, or production
  action occurred.

### Direct-control observations leaked fresh interactive PowerShell processes

- Signature: JBOD process inventory shows dozens of bare `powershell.exe`
  children with the same Windows Terminal console-host parent and creation
  times matching direct-control observations; protected Argos processes remain
  separately identifiable by full command line.
- Cause: the direct-control helper middle-clicked a fresh PowerShell for each
  action, but several observation commands copied their result without an
  in-command `exit`. Timeout and parse-error paths also left their console open.
- Preflight: every fixed remote observation command must parse locally and end
  with `;exit` in the same submitted command. After test execution, compare
  exact bare-child cardinality under the pinned terminal parent before and
  after; require no increase. Capture terminal errors before closing a failed
  current console.
- Recovery: pin the exact terminal parent and select only bare PowerShell child
  command lines created by this control session. Exclude the healthy processor,
  current tray, portal, sender, bridge, scribe, Insite, monitor, inspection, and
  every command line with an application script. Stop only the proved leaked
  interactive children under a file-backed mutation intent and verify the
  protected command-line set is unchanged.
- First observed on 2026-08-25 after exact JBOD process inventory returned 59
  script-host rows, including more than 50 bare children under parent PID 20648.

### Nested RustDesk/RDP SendKeys corrupted shifted PowerShell punctuation

- Signature: a command visible in the JBOD Windows Terminal differs from the
  locally parsed source: `2>&1` arrives as `2.71`, or the first pipeline `|`
  arrives as `\`, producing red parser/parameter-binding errors and no
  clipboard result.
- Cause: text-level `SendKeys` translation through the laptop RustDesk session
  and two nested RDP sessions does not reliably preserve shifted punctuation.
  Local parsing proves source syntax but cannot prove the remote keystrokes.
- Preflight: send `|`, `>`, and `&` with explicit virtual-key plus Shift
  down/up events, then exercise an exact hostname-gated scalar pipeline and
  capture the Windows Terminal buffer when the expected result marker is
  absent. Never infer focus loss from a missing clipboard result until the
  terminal text is inspected.
- Recovery: correct the still-draft direct-control transport, retain the
  console capture as diagnostic evidence, and rerun only the read-only query.
  No JBOD task, process, file, queue, ledger, source, wafer, provider, hold, or
  production state changed.
- First observed on 2026-08-25 while querying JBOD startup and drive metadata.

### Compact direct-control observation fused a property and comparison operator

- Signature: exact JBOD hostname proof passes, but the bounded scheduled-task
  inventory never updates the return clipboard and the caller times out.
- Cause: the fixed read-only command compacted `TaskPath -notlike` into the
  invalid token `TaskPath-notlike`. The control script parsed its own source
  but did not parse each constructed fixed remote command before input.
- Preflight: parse every exact fixed or constructed remote PowerShell command
  locally with the Windows PowerShell parser before focusing RustDesk or
  sending any keystroke. Preserve whitespace at every property/operator,
  keyword/operand, and statement/value boundary.
- Recovery: correct the still-draft read-only command in place, add the local
  command parse boundary to the direct-control helper, and rerun only the
  hostname-gated observation. No task, process, file, queue, ledger, source,
  wafer, provider, or production state changed.
- First observed on 2026-08-25 while inventorying non-Microsoft JBOD scheduled
  tasks through the direct RustDesk/nested-RDP observation route.

### The Insite exporter rejected a valid producer state and its modal exposed dynamic-scope label shadowing

- Signature: export stops on `Confirmed identity row contract failed` for an
  `IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY` row, while a
  separate .NET dialog reports that property `Text` is missing.
- Cause: the confirmed-overlay producer emits three qualified states but the
  exporter accepted only two. In the tray completion function, a local string
  named `$detail` dynamically shadows the status Label while a modal pumps a
  nested timer callback.
- Preflight: freeze the producer's complete state set and mechanically compare
  the exporter allowlist; require zero missing states. Audit callback-local
  names against UI control names across modal re-entry.
- Recovery: add only the missing qualified producer state to the exporter and
  rename only the child-output local variable. Restart only the tray; leave the
  processor and config untouched.
- First observed on 2026-08-22 after META01R2 exposed the real exporter result
  without a cascade.

### A modal GUI failure re-entered its own terminal operation every timer tick

- Signature: one timed-out tray child operation immediately produces a growing
  stack of identical error dialogs; later activity lines say the same
  `FAILED_GUI_CHILD_OPERATION.json` already exists.
- Cause: there are two exact defects. Timeout age subtracts a round-trip UTC
  string cast by Windows PowerShell as local wall time from `UtcNow`, making the
  first two-second tick appear roughly five hours overdue and killing the child
  immediately. Then `Complete-GuiChildOperationIfReady` shows a modal error
  before clearing `form.Tag.ActiveChildOperation`. The modal message loop
  continues dispatching the timer, so the same terminal operation is completed
  again, collides with its create-new result record, and opens another modal.
- Preflight: prove a fresh UTC start is below the deadline under the exact
  Windows PowerShell 5.1 timezone, then force one real child timeout in the
  exact WinForms timer path and hold the first dialog open across multiple timer
  intervals. Require exactly one terminal record, exactly one notification,
  and no second completion attempt.
- Recovery: parse the round-trip start timestamp with `RoundtripKind` and
  compare in UTC. Claim terminal completion before recording evidence or
  displaying UI, dispose it once, and make terminal notification non-reentrant.
  Stop/restart only the tray when required to clear an active cascade; never
  restart the independent inspection processor.
- First observed on 2026-08-22 immediately after the operator invoked the live
  META01R1 Insite export callback. The processor remained `WATCHING`.

### A relocated signer retained a same-directory validator assumption

- Signature: signing created a complete request directory, then failed because
  `Test-SignedPortalPackage.ps1` was looked up beside the relocated signer.
- Cause: the cloned signer moved out of the canonical portal scripts directory
  without remediating its validator path.
- Preflight: resolve and existence-check every sibling script invoked by a
  relocated signer before any signature is created.
- Recovery: withdraw the incomplete signed request identity and use the
  unchanged canonical portal signer from its qualified scripts directory with
  a fresh request identity and fresh output root.
- First observed on 2026-08-22 while preparing `META01R1`; no portal publish or
  JBOD mutation occurred.

### The tray repeated the optional production-routing property crash

- Signature: the installed review-only tray logs `Insite export validation
  failed: The property 'productionRoutingEnabled' cannot be found on this
  object` before launching the exporter or creating its declared output file.
- Cause: `Show-JbodAllWaferTray.ps1` function
  `Get-ConfiguredMetadataSnapshotRoot` directly evaluates
  `[bool]$config.productionRoutingEnabled` under strict mode. The exact live
  config is the approved review-only schema-v3 representation that safely
  omits this optional property. The automatic bridge and processor runner had
  already received the presence-check correction, but the tray consumer was
  omitted from that dependency inventory.
- Preflight: enumerate every strict-mode reader of `PROCESSOR_CONFIG.json`,
  including GUI callbacks, and exercise its actual caller path with the
  optional property absent, explicitly false, and explicitly unsafe true.
  Require absent/false to resolve to the configured metadata root and unsafe
  true to refuse before child launch. Source-token checks and a tray startup
  smoke that never invokes the callback are insufficient.
- Recovery: change only the tray's optional-property read to a false-default
  presence check, keep explicit true fail-closed, install from the exact live
  tray predecessor, and restart only the exact review-only tray task so the
  resident script refreshes. Prove the manual Insite export callback creates a
  schema-valid request for the current actionable cohort. Do not rewrite the
  live config, clear metadata holds, restart the processor, or change XML,
  training, or production routing.
- First observed on 2026-08-22 in the operator's live GUI after signed GUIR9C3
  installed tray SHA-256
  `CF8C229A9F0EC5C26D88F800849DF96C9EC6AAA3039FE81F01971E477F4A3828`.
  Exact signed GUIR9C3 terminal evidence pins those installed bytes, and the
  previously signed GUIR3 data pull pins exporter SHA-256
  `653E5B38208A4E4C2E8E848DB16FF6CCD49BA51AC748F62005F6C01D4B372F26`,
  which does not read the optional property.

### A ZIP or extra `.ready` wrapper is not an endpoint-ready request directory

- Signature: the JBOD endpoint returns the signed failure
  `Portal request manifest is missing.` and the response request identity has
  an unexpected trailing `.ready`, even though the signed inner request is
  valid.
- Cause: Windows Explorer presented a `.ready.zip` as a compressed folder and
  extraction created an additional directory ending in `.ready` above the
  signed request directory. The endpoint correctly consumed that outer
  wrapper, where `PORTAL_REQUEST_MANIFEST.json` was absent, and changed no
  installed target bytes.
- Preflight: in the endpoint `pending` root, require a normal filesystem
  directory—not a `Compressed (zipped) Folder`—whose name ends exactly once in
  `.ready`. Require `PORTAL_REQUEST_MANIFEST.json`,
  `PORTAL_REQUEST_MANIFEST.sig`, and `payload` immediately inside that
  directory before leaving it visible to the worker.
- Recovery: use the signed inner directory unchanged. If the worker already
  archived the wrapper, move only the inner directory from the exact
  `processed\failed` wrapper into `pending`; do not extract, rename, rebuild,
  resign, or edit it. Verify the resulting signed terminal response against
  the original manifest request ID.
- First observed on 2026-08-22 for outer-wrapper response
  `R_77AB97E22A6B_20260822221726887_78afc754`. Moving the untouched inner
  request produced signed `PASS_MAINTENANCE_PATCH` response
  `R_7C549BAAF87D_20260822222055187_069d4c50`.

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

### A similarly named count from another live document is not evidence for an executable assertion

- Failure signature: after the exact FRONT selector succeeds, a live successor
  refuses before task restart with
  `R10 signed V40 pre-refresh state is not the exact ten-row FRONT contract.`
- Cause: R10 correctly bound the signed V40 catalog selector, but then treated
  V40's ten `targetConfirmedRows` as authority for
  `confirmedPhysical == 10`. Those values come from different documents and
  predicates. V40's `targetConfirmedRows` are selected from
  `identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json`; R10's
  `confirmedPhysical` is selected from `identity\SCRIBE_IDENTITY_QUEUE.json`
  only when `state == SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING`. The signed V40
  validator never asserted that queue-state population. R10's raw fixture then
  hard-coded all ten queue rows to that state, so it proved its own assumption
  instead of the installed source semantics. The composite pre-refresh error
  also omitted field-by-field observed values, preventing the terminal response
  from identifying the exact divergent derived field without another audit.
- Mandatory preflight: every executable count must declare its exact source
  document, schema, selector, uniqueness key, and signed or direct evidence.
  Mechanically reject cross-document scalar substitutions even when labels such
  as `confirmed`, `matched`, or `rows` appear equivalent. Build fixtures from
  raw rows matching the exact evidence source, and add a wrong-source control
  that proves a confirmed-overlay count cannot satisfy a queue-state assertion.
  Composite assertions must emit bounded field-specific expected and observed
  values before any mutation so one signed terminal response is sufficient for
  diagnosis.
- Recovery: retain R10 and its signed terminal failure as withdrawn evidence.
  Do not reuse its package or fixture as a successor parent. Before any new
  restart request, obtain a bounded read-only signed or direct audit of the exact
  `SCRIBE_IDENTITY_QUEUE.json` target rows and states, then either bind the
  queue-state assertion to that evidence or remove it only after proving it is
  not an authorization invariant. Rebuild every fixture from the audited raw
  queue rows and rerun the complete FRONT-competitor and rollback matrix from a
  fresh root.
- First observed on 2026-08-21 in signed R10 response
  `R_1E567E7F3C79_20260821182419402_28a007a2`. The exact FRONT lot/date/domain
  selector and identity-set guards had already passed. The composite pre-refresh
  assertion failed before the declared task restart. The signed response and all
  three declared files verified; no source was deleted, no other inspection task
  was changed, and no wafer was aborted.

### PowerShell replacement maps cannot contain keys that differ only by case

- Failure signature: a file-backed or inline mechanical clone command fails at
  parse time with `Duplicate keys ... are not allowed in hash literals` when an
  ordered hashtable contains both upper- and lower-case replacement tokens.
- Cause: Windows PowerShell and PowerShell ordered hashtables use
  case-insensitive key equality. Tokens such as `C2V40` and `c2v40` are the same
  key even though the intended string replacements are case-sensitive.
- Mandatory preflight: represent mechanical replacement rules as an ordered
  array of explicit `{ from, to }` pairs, or use a single canonical-case token
  plus a separately asserted case-aware pass. Reject a hashtable-based rule set
  when any normalized key occurs more than once.
- Recovery: confirm that the parse-time failure created no target root or file,
  then rerun once with ordered replacement pairs. Preserve source-template
  hashes and repeat clone-literal and generated-harness gates before execution.
- First observed on 2026-08-21 while preparing the bounded RA1 read-only audit.
  The parser failed before the first statement executed; `work\RA1` did not
  exist and the Git worktree remained clean.

### Harness guard treats a CIM `powershell.exe` filter inside an assignment as external process output

- Failure signature: `Confirm-ArgosPowerShellHarnessSafety.ps1` reports
  `EXTERNAL_POWERSHELL_TEXT_USED_AS_OBJECT` for an assignment whose right-hand
  side is an in-process `Get-CimInstance Win32_Process` query containing the
  literal process name `powershell.exe`.
- Cause: the conservative AST guard searches command extent text for a
  PowerShell executable literal. A CIM query embedded directly in an assignment
  can therefore resemble an external `powershell.exe` invocation even though no
  child PowerShell process is launched.
- Mandatory preflight: isolate a live CIM process query in a file-backed typed
  helper function and assign only the helper's object output. Keep actual
  external PowerShell invocations JSON-bounded and explicitly rehydrated.
- Recovery: treat the failed generated root as withdrawn and non-executable.
  Create a fresh output root from the guarded source templates, use the helper
  boundary, and rerun parser, harness, wrapper, clone, exact-endpoint, and
  package gates before signing.
- First observed on 2026-08-21 in `work\RA1\pkg\payload\RA1.ps1`. The guard
  failed before the payload, signer, builder, publisher, collector, or endpoint
  ran. No portal request, task action, image read, queue change, source deletion,
  or wafer action occurred. `work\RA1` is withdrawn and must not be executed or
  used as a package parent.

### Pre-action collection-case claims require pinned machine evidence

- Failure signature: a zero-recurrence pre-action contract declares
  `zeroOneManyCollectionCasesPassed: true`, but the first exact Windows
  PowerShell 5.1 endpoint case fails with `The property 'Count' cannot be found
  on this object` for a conditional collection that was not exercised at zero,
  one, and multiple cardinalities.
- Cause: the pre-action validator accepted a Boolean declaration without a
  dependency on a machine-readable case gate. In RA1A, `$ledgerRows = if (...)
  { @(...) } else { @() }` repeated the already documented conditional-output
  scalarization defect. The fixture exercised zero ledger rows only and the
  contract nevertheless claimed complete zero/one/many evidence.
- Mandatory preflight: every true collection-cardinality control must pin a
  machine-readable gate naming each conditional collection assignment and its
  zero-, exactly-one-, and multiple-item Windows PowerShell 5.1 outcomes. Reject
  a pre-action contract whose dependency set does not contain that exact gate.
  Independently require the array boundary around the complete conditional,
  for example `$rows = @(if (...) { Get-Rows })`, before signature.
- Recovery: retain RA1A request `REQ_RA1A_0821_1910_X1`, its signed local
  terminal failure, and `C:\RA1AE` as withdrawn, non-replayable evidence. Do not
  publish or use RA1A as a successor parent. The temporary approved-root install
  was rolled back to the observed absent state. A future attempt requires a
  fresh namespace and a pinned zero/one/many collection gate before signing;
  do not iterate while the systemic pre-action premise is unresolved.
- First observed on 2026-08-21 in the exact RA1A create-from-absent rehearsal.
  Signed response `R_CD2FBA7EC9B1_20260821190854216_5e5482c8` was `FAILED`
  before any live portal publication. No task action, queue mutation, image
  read, source deletion, production route, or wafer action occurred.

### A read-only route must prove every requested observation capability before publication

- Failure signature: a recovery audit is described as read-only, but its
  selected `STATUS` or `DATA_PULL` endpoint cannot return one or more fields
  needed to decide whether any mutation has a point. Repeatedly packaging an
  incident-specific helper then turns observation into endpoint mutation and
  restarts the same failure loop.
- Cause: route safety, endpoint qualification, and question-answering
  capability were treated as interchangeable. The C1E `STATUS` handler can
  return configured task state, installed hashes, JSON states, and bounded log
  tails; `DATA_PULL` can return configured approved-root exact files. Neither
  returns exact process inventory. A qualified endpoint is therefore not
  automatically qualified for every read-only question.
- Mandatory preflight: every recovery intent must enumerate the exact requested
  capabilities and pin a machine-readable capability inventory for the exact
  route implementation. Reject before signing when any requested capability is
  absent. After repeated premise failures, do not bridge the gap with an
  incident-specific maintenance helper. Either use an already authorized exact
  admin read-only route or stop for governance review of one generic read-only
  endpoint capability improvement.
- Recovery: preserve the failed intent and capability-gap gate as bounded
  evidence, contact no endpoint, name no successor, and make no restart or data
  decision. Resume only after the capability gap is closed independently; then
  run the original exact observation once and select one evidence-supported
  remedy.
- First observed on 2026-08-21 while preflighting the post-R10 lot
  `62631-586` FRONT GUI audit. The validator returned
  `OBSERVATION_ROUTE_CAPABILITY_GAP` for `exactProcessInventory` before signing,
  publication, endpoint contact, task action, queue/ledger mutation, GUI edit,
  image read, source deletion, or wafer action.

### A sample-sized observation cap cannot prove an all-inspections invariant

- Failure signature: `Confirm-ArgosRecoveryIntent.ps1` rejects a read-only
  whole-catalog reconciliation with `OBSERVATION_ROW_BOUND_INVALID` because
  `maximumRows` exceeds 1,000, even though the current processor reports about
  1,932 stable inputs.
- Cause: the original validator confused a sample-sized row cap with bounded
  execution. That made the named ten-wafer cohort easier to validate than the
  actual requirement that every valid inspection have an explicit disposition
  and every completion appear in the GUI.
- Mandatory preflight: distinguish the regression cohort from the product
  invariant. Permit a still-bounded maximum of 10,000 rows per exact source and
  require explicit source, selector, uniqueness key, requested fields, and byte
  limits. Reject counts inferred from similarly named fields.
- Recovery: update the validator and its PASS fixture before signing. Rerun the
  original exact read-only intent against the complete catalog/hold/ledger/
  dashboard sets. Do not replace the full reconciliation with a ten-row sample.
- First observed on 2026-08-21 while preflighting
  `ARGOS_ALL_VALID_INSPECTIONS_READ_ONLY_AUDIT_INTENT_20260821.json`. The failure
  occurred before signing, endpoint contact, publication, task or process
  action, queue/ledger/GUI mutation, image read, source deletion, or wafer
  action.

### DATA_PULL cannot use an optional rolled-back artifact to prove absence

- Failure signature: a multi-file `DATA_PULL` returns signed terminal `FAILED`
  with `DATA_PULL source not found: <path>` and returns none of the other
  requested snapshot files.
- Cause: the endpoint preflights every requested source as an existing file and
  fails the complete request on the first absence. A maintenance helper created
  by a failed request is not a valid required source: queue-safe maintenance
  rollback removes or quarantines a create-on-install file when its verifier
  fails. Requesting that helper as though it must still be installed confuses
  absence evidence with file retrieval.
- Mandatory preflight: classify every requested `DATA_PULL` path as
  `REQUIRED_PRESENT`, never `PRESENT_OR_ABSENT`. Prove optional absence through
  an already qualified status/existence field, exact admin read-only evidence,
  or the signed maintenance rollback record. Do not place optional files in an
  all-or-nothing data pull.
- Recovery: preserve the signed terminal failure, publish no retry in the same
  incident, and make no restart or product-fix decision from the empty snapshot.
  A future independently authorized audit must omit the rolled-back helper and
  bind its absence separately before publication.
- First observed on 2026-08-21 for request
  `REQ_20260821T202917395Z_675B67258EC9`. Signed response
  `R_4E81B46C722B_20260821203034791_6c70a719` proved `R10.ps1` absent and
  returned only `FAILURE.json`. No installed change, task/process action,
  queue/ledger/GUI mutation, image read, source deletion, or wafer action
  occurred.

### Producer identity-state expansion can poison stale consumer predicates

- Failure signature: the authoritative confirmed/verified metadata producer
  emits three approved identity states, while installed inventory, processor,
  and dashboard consumers accept inconsistent one- or two-state subsets. The
  inventory pass terminates, the resident processor stops refreshing, valid
  FRONT acquisitions remain held, and the GUI catalog stays stale.
- Cause: the producer enum grew without one frozen cross-consumer contract.
  Equality predicates were copied into separate consumers and drifted. The
  same valid identity was therefore accepted by the producer but rejected at
  later stages.
- Mandatory preflight: enumerate the producer's exact approved state set and
  compare it mechanically with every inventory, processing, ledger, dashboard,
  and GUI-refresh predicate. Any narrower consumer must be explicitly scoped by
  domain and have negative controls proving unaffected domains unchanged.
- Recovery: align inventory, processing, and dashboard with the exact same
  three-state producer contract across every domain. Preserve each domain's
  independent route, appearance, geometry, and context gates; do not use domain
  as a substitute identity-state restriction. Execute the predicates against
  the full live dataset and require every image-confirmed row that satisfies the
  human-state baseline gates to produce the same family. The 2026-08-21 live
  dataset contained 47 non-FRONT image-confirmed rows and 12 that satisfied all
  other reference-family gates, proving that a FRONT-only correction is a
  regression.
- First observed on 2026-08-21 in the signed read-only live/source audit for lot
  `62631-586`. The target verified overlay contained seven
  `IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY` and three
  `IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY` rows while the
  processor heartbeat and catalog were more than 24 hours stale.

### Current-fingerprint-only dashboard joins silently hide valid history

- Failure signature: a completed FRONT ledger row exists exactly once for an
  identity, but the dashboard excludes it with
  `CURRENT_ACQUISITION_FINGERPRINT_HAS_NO_COMPLETED_RESULT` after a newer
  acquisition fingerprint becomes current.
- Cause: the dashboard equated current-input identity with result provenance.
  It provided no bounded historical result representation, so valid completed
  inspections disappeared instead of being labeled historical.
- Mandatory preflight: test current match, zero historical matches, exactly one
  historical match, and multiple historical matches. Exactly one FRONT
  historical match must preserve both current fingerprint and completed ledger
  job key; zero or multiple matches remain excluded with explicit reasons.
- Recovery: expose only the single unambiguous historical FRONT completion with
  `HISTORICAL_COMPLETED_SUPERSEDED_CURRENT_FINGERPRINT`; do not guess among
  duplicates or change BARE/BOW behavior.
- First observed on 2026-08-21 for three completed FRONT identities from lot
  `62631-586` scan `20260815171102`, all omitted from the live dashboard with
  one historical completed row each.

### WinForms event callbacks cannot rely on caller script scope

- Failure signature: opening Completed Lots raises `The variable
  '$script:lastActivityKey' cannot be retrieved because it has not been set`,
  even though the tray source initializes that script variable before registering
  callbacks.
- Cause: the event callback executes under a scope/runspace where the caller's
  script-scoped variable is not reliably bound.
- Mandatory preflight: mutable event state must be initialized on and retrieved
  from the captured form/control object. A callback fixture must invoke the event
  body and prove the state survives without reading a script-scoped variable.
- Recovery: move the activity key to `form.Tag.LastActivityKey`, initialize it
  before callback registration, and restart only the exact tray task after the
  installed hash is verified.
- First observed on 2026-08-21 in the operator's Completed Lots error dialog.
  This is a narrow state-binding repair, not a GUI redesign.

### Simplified Where-Object comparison operators require a separate operand token

- Failure signature: Windows PowerShell accepts the script at parse time but
  fails at runtime with `A parameter cannot be found that matches parameter
  name 'ge1'` for `Where-Object Count -ge1`.
- Cause: compact formatting joined the simplified-syntax comparison operator
  and operand. The rehearsal replaced the complete state-reader result, so the
  exact packaged selector was never executed.
- Mandatory preflight: reject `Where-Object <property> -eq1`, `-ne1`, `-gt1`,
  `-ge1`, `-lt1`, or `-le1` token adjacency mechanically. Every pre-mutation
  live-state reader must execute from exact packaged bytes under Windows
  PowerShell 5.1 against copied live-format metadata; a precomputed state object
  cannot substitute for that branch.
- Recovery: withdraw the published artifact, preserve its signed terminal
  failure, and start only from the guarded installed sources. Do not patch or
  replay the failed package.
- First observed on 2026-08-21 in `REQ_AVIR1`. The signed JBOD response failed
  before task enumeration or restart, and the endpoint rolled back all five
  installed-file swaps.

### Installed runner arguments must match the exact installed consumer parameter surface

- Failure signature: the all-wafer processor remains stale while the installed
  runner invokes `Invoke-JbodAllWaferInventory.ps1 -MetadataSnapshotRoot ...`
  and the exact installed inventory command does not declare that parameter.
- Cause: the runner was revised to propagate the configured D-root metadata
  snapshot, but the paired inventory consumer remained on a parameter surface
  that reads only `<StateRoot>\metadata\verified`.
- Mandatory preflight: under Windows PowerShell 5.1, resolve every named
  argument at each installed runner call site against `Get-Command` for the
  exact paired consumer bytes. Then execute the installed runner's exact
  `-Once -PlanOnly` path against live state before accepting a restart.
- Recovery: remove the unsupported `MetadataSnapshotRoot` argument and its
  temporary derivation from the runner. Preserve inventory's existing
  `<StateRoot>\metadata\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json`
  consumer path. `PROCESSOR_CONFIG.metadataSnapshotRoot` is the upstream MES
  snapshot input used by the Insite importer; the importer writes the active
  verified overlay into `StateRoot`, so rebinding inventory directly to the
  upstream snapshot root would select the wrong contract. Keep all other
  inventory inputs and review-only boundaries unchanged.
- First observed on 2026-08-21 by direct comparison of installed runner SHA-256
  `46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4`
  with installed inventory SHA-256
  `8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160`.

### Installed dashboard bytes do not update the dashboard unless the updater runs

- Failure signature: the exact live PlanOnly reaches dashboard reconciliation,
  but strict mode raises `The property 'resultFingerprintState' cannot be found
  on this object` while reading the unchanged dashboard.
- Cause: AVS1 installed a changed dashboard updater but never invoked it. The
  runner's `-Once -PlanOnly` path returns from the processing pass before its
  nonblocking dashboard-refresh call, so `dashboard_manifest.json` remained the
  29-row predecessor. The entrypoint then required a field and 32-row count that
  only a successful invocation of the new updater could create. The local gate
  checked source tokens rather than executing this producer/consumer sequence.
- Mandatory preflight: identify the exact producer for every newly required
  output field or count. Execute that exact producer, require its terminal
  success/status, and only then validate the exact output revision it wrote.
  Installing producer bytes, finding source tokens, or executing a different
  upstream path is not output evidence. Every newly added manifest property must
  still be accessed through an optional-property helper, and a retained
  predecessor manifest must be classified as such under strict mode.
- Recovery: do not infer dashboard refresh from runner PlanOnly or installed
  hashes. Preserve the predecessor manifest, report that the updater was not
  executed, and stop before task restart. Do not patch and replay AVS1.
- First observed on 2026-08-21 in signed terminal AVS1 response
  `R_53E919FF3990_20260821225532690_a417fac0` after the exact live PlanOnly had
  admitted the ten FRONT regression rows.

### Identity uniqueness cannot substitute for acquisition-fingerprint provenance

- Failure signature: a dashboard repair proposes to include a completed FRONT
  result solely because there is exactly one completed ledger row with the same
  identity, even though the current catalog fingerprint and ledger job-key
  fingerprint differ.
- Cause: the workflow incorrectly called a single same-identity historical row
  "unambiguous." The fingerprint covers the channel paths, byte counts,
  timestamps, and dimensions; a mismatch is positive evidence that current
  acquisition equivalence has not been proved. Same identity is not same input.
- Mandatory preflight: never re-admit a superseded result to the current
  dashboard from identity cardinality. Require recorded exact BF/DF source-byte
  hashes in the result and exact equality with hashes of the current acquisition
  sources. If either side lacks those hashes, retain the result only as
  historical evidence or reprocess the current acquisition.
- Recovery: withdraw the historical-fingerprint fallback in AVS1. The three
  ledger rows for slots 02, 07, and 10 of scan `20260815171102` remain valid
  historical completions but are not current-dashboard rows until exact source
  equivalence or a fresh current-acquisition result is proved.
- First observed on 2026-08-21 while auditing AVS1 after its signed failure. All
  three proposed fallback rows had different current catalog fingerprints and
  ledger job-key fingerprints.

### Endpoint-entrypoint task recovery cannot guess worker predecessor evidence layout

- Failure signature: after a live verifier failure, local recovery reports
  `Expected one predecessor evidence file for Run-JbodAllWaferProcessor.ps1;
  observed 0`, and the entrypoint exits before restarting stopped tasks.
- Cause: the entrypoint assumed that exact worker predecessor bytes would be
  discoverable by a hard-coded maintenance prior-root and `*.prior` hash scan.
  The exact live worker evidence layout was not directly audited through the
  entrypoint's security context before task mutation.
- Mandatory preflight: before stopping any task, prove a complete rollback
  mapping from every changed destination to one exact readable worker prior
  artifact, including path, hash, ACL/security-context readability, and atomic
  restore operation. The task-stop boundary must remain after this proof.
  Separately prove that a failure after task stop restores installed bytes and
  task availability before the child exits; the outer worker rollback alone
  does not restore scheduled-task state.
- Recovery: after this signature, do not publish another mutation. Obtain one
  signed read-only STATUS result for exact installed hashes and task states.
  Any task-availability restoration requires explicit new authority and a
  separately proven admin path; it cannot be bundled with another repair try.
- First observed on 2026-08-21 in the same AVS1 signed terminal response. The
  outer endpoint worker entered its installed-file rollback path, but task
  availability and installed rollback hashes remained unproved at the terminal
  boundary.

### Cross-PowerShell JSON date coercion can change hash inputs

- Failure signature: a locally reconstructed request, selector, or evidence
  object differs from the installed Windows PowerShell 5.1 value even though
  its source JSON text appears equivalent; ISO timestamp fields have become
  host-local `DateTime` strings.
- Cause: PowerShell 7 `ConvertFrom-Json` converts ISO timestamp strings to
  `DateTime` by default, while Windows PowerShell 5.1 preserves them as strings.
  Re-serialization can therefore change exact bytes, keys, or hash inputs.
- Mandatory preflight: when JSON strings participate in hashes, keys,
  selectors, or signed evidence, execute with the exact installed PowerShell
  host or use PowerShell 7 `ConvertFrom-Json -DateKind String`. Assert the exact
  received string before hashing or comparison. Do not treat cross-host JSON
  object equivalence as byte or hash equivalence.
- Recovery: discard the locally coerced reconstruction and return to the
  original file bytes or repeat the bounded read with string-preserving JSON
  parsing. This correction does not justify replaying or mutating an endpoint.
- First observed on 2026-08-21 while validating the post-AVC1 signed read-only
  snapshot; preserving timestamp strings restored exact selector/hash
  comparison without another live action.
- Follow-up signed read-only STATUS response
  `R_07B0A5DC725F_20260821230519159_a7ea6fee` proved the processor and monitor
  tasks were both `Ready`, not running, and `PROCESSOR_STATUS.json` was absent.
  It directly proved the processing pass had rolled back to SHA-256
  `0B063D452CA76AE5EE3EC1BDF6726853259039683C36E208718B8FE937D23753`;
  it did not expose the other four AVS1 target hashes. This is why task
  availability must be terminal evidence, not inferred from installed-file
  rollback.

### Physical candidate matching must not erase unmatched channel-local evidence

- Failure signature: an expanded native-pose synthetic gate reports the
  expected single BF/DF physical indentation and the correct conservative hold,
  but fails because a test expects zero unmatched channel-local fragments after
  that physical match.
- Cause: the test conflated physical-boundary eligibility with absence of all
  channel-local boundary response. A matched BF/DF physical candidate does not
  make a separate BF-only or DF-only response disappear. Those responses remain
  ineligible to establish wafer pose and must remain explicit evidence.
- Mandatory preflight: candidate gates must assert the exact physical-candidate
  count separately from BF-only and DF-only evidence counts. Require exact
  channel-only counts only for controls whose construction guarantees them;
  otherwise require preservation and ineligibility, not artificial emptiness.
  Never merge, delete, or relabel an unmatched channel-local response merely to
  make a single-physical-candidate control pass.
- Recovery: retain the failed executed synthetic output as withdrawn evidence,
  correct only the draft expectation, move to a fresh output namespace, rerun
  the safety/preflight gates, and require the physical state, channel
  independence, FS15 refusal, and authority boundaries to pass together.
- First observed on 2026-08-22 in
  `work/FIDUCIAL_OPENCV_V1/SYNTHETIC_GATE_V2/SYNTHETIC_GATE.json`, SHA-256
  `388A8336D5254B90FE79900673A405E64F486893C9CB46804BC89573EFEB24A8`.

### File-backed evidence timestamps must come from the host clock

- Failure signature: a newly written local evidence manifest contains a
  `createdUtc` later than the host's current UTC time even though no clock
  discontinuity was observed.
- Cause: the timestamp was manually estimated instead of captured from the
  host clock at file creation.
- Mandatory preflight: before freezing or referencing a new evidence manifest,
  parse every creation timestamp and require it to be no later than the current
  host UTC time plus a small declared clock-skew allowance. Generate timestamps
  from the host clock; never type an estimated future time.
- Recovery: while the artifact is still local draft evidence and has not been
  signed, published, executed against real inputs, or used for external
  mutation, replace the estimated value with the file's exact filesystem
  creation time, then recompute every dependent hash before promotion. A
  frozen, signed, published, or externally used artifact instead requires a
  fresh namespace.
- First observed on 2026-08-22 in the local draft
  `work/FIDUCIAL_OPENCV_V1/DEVELOPMENT_PARTITION.json`; its original estimated
  `2026-08-22T03:30:00Z` was corrected before real image access or checkpoint
  promotion to filesystem creation time `2026-08-22T01:30:19.6244427Z`.

### Gate consumers must pin and validate the producer's actual result schema

- Failure signature: an otherwise passing final-package rehearsal stops while
  writing its local gate because it reads a generic `checkCount` property from
  a prerequisite gate that actually publishes `caseCount` and `passCount`.
- Cause: the consumer pinned the prerequisite file hash and PASS state but
  guessed a summary-field name instead of checking the exact producer schema.
- Mandatory preflight: before a harness reads any prerequisite result field,
  enumerate the bounded top-level property names and pin the exact schema,
  state, hash, and required field names. Test the final gate-construction path
  in preflight or build from the actual producer schema; do not assume that
  unrelated gates share a generic count-field name.
- Recovery: confirm the failure occurred only in a fresh local partial staging
  root, record its exact path and contents, quarantine or remove only that
  verified partial root, correct the still-local harness to read the producer's real count
  field, rerun parser/harness/wrapper/pre-action gates, and rebuild from the
  unchanged signed source. Do not reuse the incomplete partial output.
- First observed on 2026-08-22 in the FIC1 local final-package build. The
  incomplete root was
  `work/FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1/final.partial` with five files
  and 80,254 bytes. It was preserved as withdrawn evidence under
  `work/FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1/withdrawn/FINAL_PARTIAL_FAILED_GATE_SCHEMA_20260822`;
  no request had been published and no JBOD target bytes had changed.
## 2026-08-22 — Signed maintenance package with `allowCreate` still requires a nonempty predecessor set

- Failure signature: `Test-SignedPortalPackage.ps1` rejected the signed, unpublished FSF1 package with `Maintenance change lacks approved predecessor hashes.`
- Cause: the create-new helper declaration used `approvedPredecessorSha256: []`. The portal verifier requires at least one exact approved predecessor for every maintenance change, including an `allowCreate: true` target, so the empty set also omitted the target-hash idempotence case.
- Preflight prevention: before signature, require every maintenance change to have at least one exact `approvedPredecessorSha256`; for a create-new/idempotent helper, include its exact `installedSha256`. The signer preflight must assert this cardinality and equality, and the exact signed package must still pass `Test-SignedPortalPackage.ps1` before final ZIP construction or publication.
- Recovery: FSF1 was signed but never zipped, published, or executed. Preserve it as `WITHDRAWN`, block replay and successor-parent authority, and use a fresh FSF2 namespace whose definition and signer enforce the nonempty target-hash predecessor rule. No endpoint, task, processor, source, image, or wafer state changed.
## 2026-08-22 — Native patterned-front source paths require a verified process-local short alias before fingerprinting

- Failure signature: the exact FSF2 PFC003/PFC010 BF/DF source path gate returned `SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH`; the longest observed source path was 178 characters and 210 with the mandatory 32-character reserve.
- Cause: FSF2 correctly moved source paths into a signed job but still planned to open the long `D:\KLARFExport\PatternedFront\...` paths directly. Configuration-driven paths alone do not satisfy the path-budget rule.
- Preflight prevention: run `Confirm-ArgosPathBudget.ps1` against every exact job source before signature. When any source is 200 or more with reserve but below the 230 hard stop, the signed job must declare a bounded alias name and one allowed source root. The entrypoint must create a process-local FileSystem PSDrive for that root, mechanically convert every source to the alias-relative path, rerun its own path/component budget on the alias path, verify the alias still resolves within the declared root, and only then read/hash bytes. Route gates must include both provenance paths and exact alias paths.
- Recovery: FSF2 was signed and built but never published or executed. Preserve it as `WITHDRAWN`, block replay and successor-parent authority, and use a fresh FSF3 namespace. Do not create a persistent junction, global drive mapping, or processor hard-coded path.
## 2026-08-22 — Raw `System.IO.File` APIs do not resolve a process-local PowerShell FileSystem PSDrive

- Failure signature: the FSF3 draft created and validated process-local PSDrive `L:`, `Test-Path` found `L:\CLEAN_PAIRED\BF.bmp`, but `[IO.File]::Open` failed with `Could not find a part of the path`.
- Cause: PowerShell provider drives are resolved by provider-aware cmdlets; they are not Win32/DOS drive mappings and raw `System.IO.File` path APIs do not resolve their names.
- Preflight prevention: when a bounded process-local FileSystem PSDrive is the path-shortening mechanism, perform the actual alias-path read with provider-aware PowerShell cmdlets. For a BMP metadata probe, use bounded `Get-Content -Encoding Byte -TotalCount 30`; use `Get-Item` and `Get-FileHash` on the same alias path. Do not silently resolve `.FullName` and pass the original long path back to raw .NET APIs.
- Recovery: FSF3 was still `DRAFT`, unsigned, unpublished, and unexecuted. Correct it in place and rerun the exact alias execution gate. No endpoint, task, processor, source, image, or wafer state changed.
## 2026-08-22 — `Get-FileHash` module scope cannot see a script-local PSDrive

- Failure signature: after the FSF3 draft successfully read the BMP header through process-local `L:`, `Get-FileHash` failed inside `Microsoft.PowerShell.Utility.psm1` with `Cannot find drive. A drive with the name 'L' does not exist.`
- Cause: `Get-FileHash` resolves its path inside module scope, where the script-scoped PSDrive is not visible, even though core provider cmdlets in the entrypoint can resolve it.
- Preflight prevention: hash alias-backed files incrementally in the entrypoint scope using bounded `Get-Content -Encoding Byte -ReadCount` blocks and `SHA256.TransformBlock`/`TransformFinalBlock`. Verify this result against `Get-FileHash` for local short-path controls. Do not convert the alias back to the original long path.
- Recovery: FSF3 remained `DRAFT`, unsigned, unpublished, and unexecuted. Correct in place and rerun the alias gate. No endpoint, task, processor, source, image, or wafer state changed.

## 2026-08-22 — A locked catalog path is not live source-existence evidence

- Failure signature: the signed FSF3 fingerprint entrypoint failed before any
  image read because one exact paired catalog path was missing through the
  verified process-local alias:
  `Lot_62616-115/62616-115_20260807120245/Slot23/BrightfieldFrontsideWafer/resizedImage/62616-115_Slot23_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`.
- Cause: the request correctly pinned the catalog-derived path, pairing, alias,
  and path budget, but no current direct endpoint observation had proved that
  every exact source leaf still existed under the installed JBOD root. Catalog
  provenance and syntactic containment do not prove live filesystem presence.
- Preflight prevention: before signing or publishing a source-fingerprint job,
  obtain current metadata-only evidence for every exact requested leaf through
  an already qualified read-only route. Pin existence, leaf type, containment,
  and reparse state without reading image bytes. If the installed route cannot
  provide exact-leaf metadata, stop with a capability gap and request one
  bounded endpoint capability improvement; do not use maintenance as an
  observation surrogate.
- Recovery: preserve the signed terminal failure and follow it with one signed
  read-only observation. Do not publish a successor fingerprint job until the
  exact source paths are resolved and re-frozen. Do not restart the healthy
  processor or the resident portal worker merely to activate a newly installed
  observation field. The FSO1 signed STATUS response proved the processor was
  still `Running` with configured root `D:/KLARFExport`, but its resident worker
  returned no `environmentInventory`; therefore exact source discovery remains
  an explicit capability gap.

## 2026-08-22 — Path-budget candidate rows do not publish a per-row `state`

- Failure signature: a signed, locally extracted DATA_PULL request passes the
  aggregate `PASS_PATH_BUDGET` check, then its package-gate writer fails under
  StrictMode with `The property 'state' cannot be found on this object` while
  projecting `pathBudget.candidates`.
- Cause: `Confirm-ArgosPathBudget.ps1` publishes the disposition on the
  top-level result. Candidate rows publish path, length, effective length, and
  longest-component measurements, but no candidate-level `state` property.
  The consumer guessed a row field after checking only the aggregate schema.
- Mandatory preflight: before signature, enumerate and pin the bounded
  top-level and candidate-row property names of every machine gate consumed by
  a package-gate writer. Exercise the final gate-construction projection in a
  non-mutating fixture using the actual gate output. Copy the aggregate state
  explicitly when a normalized per-row disposition is desired; never
  dereference an unverified candidate property.
- Recovery: preserve GUIR1's signed directory, final ZIP, and exact extracted
  directory as `WITHDRAWN_LOCAL_SIGNED_NOT_PUBLISHED` evidence. Do not publish,
  replay, patch, or use GUIR1 as a successor parent. Correct the consumer only
  in a fresh GUIR2 namespace, rerun clone-remediation, harness, recovery-intent,
  zero-recurrence, path, and final-gate-construction preflights, and sign only
  after the actual row projection passes.
- First observed on 2026-08-22 in
  `work/GUIR1/New-GUIR1ReadOnlyRequest.ps1` after creation of
  `C:\G1Z\REQ_GUIR1_0822_X1.ready.zip`, SHA-256
  `8B665354B6A5A55F772B4632236E2FB80F6170BEE92FFF4303468D1715611A67`.
  No portal request was published and no JBOD, task, processor, queue, ledger,
  source, image, or wafer state changed.

## 2026-08-22 — A mapped PSDrive's `Root` is not its UNC identity

- Failure signature: a one-shot Project Portal publisher preflight can read the
  mapped queue through `U:\`, but rejects the mapping as unpinned when it
  compares `Get-PSDrive U`.Root to the expected engineering UNC share.
- Cause: for a mapped filesystem drive, `Root` is the drive-qualified provider
  root (`U:\`). The backing UNC identity is published as `DisplayRoot`.
  Queue readability therefore did not make the incorrect `Root` comparison
  valid.
- Mandatory preflight: capture the bounded scalar fields `Name`, `Root`,
  `DisplayRoot`, and provider name in the exact Windows PowerShell 5.1
  execution context. Require `DisplayRoot` to equal the pinned UNC share and
  separately require the exact queue root to be readable. Never infer the
  backing share from `Root` and never bypass an absent `DisplayRoot`.
- Recovery: preserve the failed publisher and its preaction as
  `WITHDRAWN_PREFLIGHT_ONLY_NOT_PUBLISHED`. Create a fresh publisher namespace,
  replace only the identity predicate with the pinned `DisplayRoot` check, and
  rerun harness, clone-remediation, zero-recurrence, and the publisher's own
  non-mutating preflight. The already signed request package is unaffected
  because no request, upload, archive, publish gate, JBOD, task, process, or
  installed byte was written.
- First observed on 2026-08-22 in
  `work/GUIR2/Publish-GUIR2ReadOnlyRequest.ps1`, SHA-256
  `42A330892A14C598820F8B10157819104E87D3EDDCF6A746400E7241295B2187`.
  The request queue remained empty and `REQ_GUIR2_0822_X1` was not published.

## 2026-08-22 — DATA_PULL definition paths are nested under `parameters`

- Failure signature: a response collector passes its recurrence gate and then
  stops under StrictMode with `The property 'relativePaths' cannot be found on
  this object` before scanning or collecting a response.
- Cause: the request-definition schema publishes the requested source array as
  `parameters.relativePaths`, not as a top-level `relativePaths` property. The
  collector assumed a flattened representation. The current DATA_PULL v2
  result separately names each source as `files[].relativePath` and its ZIP
  member as `files[].entryPath`; those fields must not be conflated either.
- Mandatory preflight: enumerate and assert the exact bounded property sets of
  the signed request definition and installed DATA_PULL result schema before
  response scanning. Freeze three distinct sets: requested relative paths,
  returned `relativePath` values, and returned payload `entryPath` values.
  Mechanically compare each set at its own boundary and exercise this schema
  access in the collector's non-mutating preflight.
- Recovery: preserve the failed collector and preaction as
  `WITHDRAWN_PREFLIGHT_ONLY_NO_RESPONSE_COLLECTED`. Create one fresh collector
  namespace using `definition.parameters.relativePaths`, compare returned
  source identities through `files[].relativePath`, and verify/extract payload
  members through `files[].entryPath`. Do not republish or retry the request.
- First observed on 2026-08-22 in
  `work/GUIR2/Collect-GUIR2ReadOnlyResponse.ps1`, SHA-256
  `C4305C947325055EA530A664DEE4C6B2C895C3E815EB07E9C4780489EE42D736`.
  No local response root, route gate, terminal gate, JBOD state, queue state,
  task, process, installed byte, image, or wafer was changed.

## 2026-08-22 — General path-budget results have no aggregate maximum field

- Failure signature: a response collector verifies the matching signed
  response, exact DATA_PULL v2 fourteen-file contract, and aggregate
  `PASS_PATH_BUDGET`, then fails under StrictMode while reporting
  `pathResult.maxEffectiveLength`.
- Cause: `Confirm-ArgosPathBudget.ps1` publishes threshold fields,
  `maximumComponentLength`, and `candidates`, but no top-level
  `maxEffectiveLength`. A separate package-specific path gate happened to use
  `maximumEffectiveLength`; that consumer schema was incorrectly projected
  onto the general utility result.
- Mandatory preflight: enumerate the exact top-level property names of the
  actual general utility result and every package-specific wrapper separately.
  Derive an aggregate maximum only from verified candidate fields, or omit the
  optional display metric. Exercise the complete PASS output serialization in
  non-mutating preflight before freezing a collector.
- Recovery: preserve GUIR2 collector C2 as
  `WITHDRAWN_PREFLIGHT_ONLY_SIGNED_RESPONSE_RETAINED_UNCOLLECTED`. Do not
  republish or retry GUIR2. The matching signed `PASS_DATA_PULL` response and
  its exact hash remain on the share. Stop the task-level collector iteration;
  a C3 requires explicit operator direction and a fresh namespace.
- First observed on 2026-08-22 in
  `work/GUIR2/Collect-GUIR2ReadOnlyResponse-C2.ps1`, SHA-256
  `97E179C3E2F94BA099AA65BB74F65718F8BA22DD3999254900995C73A0C1BC53`.
  No local response root, route gate, terminal gate, retry, queue mutation,
  JBOD mutation, task/process action, installed change, image read, or wafer
  action occurred.

## 2026-08-22 — `return` requires a token boundary before a type literal

- Failure signature: a Windows PowerShell 5.1 rehearsal enters a helper and
  fails with `The term 'return[pscustomobject]@' is not recognized` before the
  helper can return its fixture descriptor.
- Cause: the draft harness concatenated the `return` keyword directly with a
  `[pscustomobject]` type literal. The parser accepted the token sequence as a
  command expression, so metadata-only parsing did not expose the runtime
  command-resolution failure.
- Mandatory preflight: require whitespace after flow-control keywords before a
  type literal, and execute every helper return path at least once in the exact
  Windows PowerShell 5.1 non-production rehearsal before freezing its gate.
  Static parser success is necessary but is not evidence that helper paths ran.
- Recovery: retain `C:\G7E` as failed local rehearsal evidence and do not reuse
  it. Correct only the still-draft endpoint test harness, select a fresh local
  root, rerun its harness-safety and zero-recurrence preflights, and then rerun
  the exact signed request rehearsal. The signed request bytes remain frozen
  and unchanged.
- First observed on 2026-08-22 in
  `work/GUIR7_PORTAL/Test-GUIR7PortalEndpoint.ps1`. The failure occurred while
  constructing the first local fixture, before the simulated endpoint worker,
  JBOD publication, task/process action, installed-JBOD change, image read,
  source mutation, or wafer action.

## 2026-08-22 — Windows PowerShell 5.1 can reject array-wrapping a generic list

- Failure signature: an exact signed maintenance request reaches its local
  endpoint rehearsal and the entrypoint exits before task/process action with
  `System.ArgumentException: Argument types do not match`; no script line is
  included in redirected stderr.
- Cause: the entrypoint placed a
  `System.Collections.Generic.List[object]` inside an array subexpression as
  `@($list)` while constructing an ordered result. Windows PowerShell 5.1 can
  fail this dynamic binder conversion even though the script parses and the
  list contains valid objects.
- Mandatory preflight: when a generic list participates in JSON/gate output,
  convert it explicitly with `.ToArray()` at the boundary. Before signature,
  execute the exact Windows PowerShell 5.1 helper path that constructs every
  result object; parser and metadata-only harness gates are insufficient.
- Recovery: mark signed request `REQ_G7_0822_A1` and its entrypoint as
  `WITHDRAWN_LOCAL_SIGNED_NOT_PUBLISHED`; do not patch, publish, replay, or use
  those frozen bytes as a successor package. Preserve `C:\G7E2` and its signed
  local failure response. A successor requires a fresh namespace, an
  independently frozen entrypoint, a direct Windows PowerShell 5.1 result-
  construction rehearsal before signature, and a fresh exact-endpoint
  rehearsal after signature.
- First observed on 2026-08-22 in exact local response
  `R_2294BAEED240_20260822194700116_358cf406`. The portal request queue remained
  empty, the JBOD was never contacted, and no JBOD task, process, installed
  file, inspection data, source image, or wafer state changed.

## 2026-08-22 — Do not name a declared PowerShell parameter `$Args`

- Failure signature: a bounded child `powershell.exe` returns exit code zero,
  but its captured stdout begins with the Windows PowerShell banner instead of
  the expected JSON; the caller then fails with `Invalid JSON primitive:
  Windows`.
- Cause: the process helper declared a named parameter `$Args`, colliding
  case-insensitively with PowerShell's automatic `$args` variable. The child
  argument list was therefore empty at runtime, launching an interactive
  redirected PowerShell host rather than the pinned `-File` invocation.
- Mandatory preflight: never declare parameters or working variables named
  `$Args`. Use a domain name such as `$ArgumentList`, assert the constructed
  `ProcessStartInfo.Arguments` is nonempty and contains the exact quoted
  `-File` scalar, and run the full success path under Windows PowerShell 5.1
  before signature. A zero exit code is not sufficient; parse and assert the
  exact expected JSON state.
- Recovery: retain `C:\G8D` as non-reusable local rehearsal evidence. Mark the
  GUIR8 draft entrypoint withdrawn; do not sign, publish, patch into a frozen
  request, or continue package iteration in the same work session. Resume only
  from the durable checkpoint with a fresh namespace after operator direction.
- First observed on 2026-08-22 in the GUIR8 full direct pre-sign rehearsal.
  The entrypoint restored all four fixture predecessor hashes and created no
  inner audit root. The engineering-share request queue remained empty, the
  JBOD was never contacted, and no JBOD task, process, installed file, image,
  source, or wafer state changed.

## 2026-08-22 — Never leave placeholder hashes in an executable pre-action flow

- Failure signature: an unexecuted local endpoint-rehearsal pre-action contains
  the literal `PLACEHOLDER_INTENT_HASH` instead of the exact hash of its frozen
  recovery intent.
- Cause: the intent and dependent pre-action were authored in one edit before
  the intent's final file hash was available. The dependent value was left for
  a later substitution rather than being mechanically populated and rejected
  before the next step.
- Mandatory preflight: before running any intent, pre-action, builder, signer,
  publisher, collector, or endpoint harness, scan its exact bounded source for
  `PLACEHOLDER`, `TODO`, `TBD`, dummy 64-character hashes, and empty required
  dependency values. A hit is a hard stop. Create and hash dependency files
  first; author dependent contracts only after those hashes exist.
- Recovery: preserve the affected GUIR9 local-rehearsal files as withdrawn,
  never execute them, and never use them as publication evidence. Do not alter
  the already frozen GUIR9 payload or signed request. The operator rejected a
  simulated laptop/JBOD environment; future GUI-only live validation must use
  the bounded environment-authentic lane in `AGENTS.md` with one request, no
  retry, exact live precondition checks, endpoint rollback, and a signed
  terminal response.
- First observed on 2026-08-22 in
  `work/GUIR9_PORTAL/GUIR9_EXACT_ENDPOINT_REHEARSAL_PREACTION.json`, SHA-256
  `3D5D43CC843400E94E149AED5C2CDC3BEA6CCC6597BEFECF035B09B2B5622E1A`.
  The affected harness was never executed, `C:\G9E` was never created, the
  request was not published, and no JBOD or laptop installed byte, task,
  process, image, source, or wafer state changed.

## 2026-08-22 — `Compress-Archive -LiteralPath` does not expand `*`

- Failure signature: a local signed-package ZIP build reports that
  `C:\...\*` does not exist, then later commands in the same shell invocation
  attempt to expand or verify a ZIP that was never created.
- Cause: `-LiteralPath` treats the asterisk literally; wildcard expansion is
  supported by `-Path`, not `-LiteralPath`. The compound invocation also did
  not set `$ErrorActionPreference = 'Stop'` before its first operation, so the
  shell continued into dependent commands after the archive failure.
- Mandatory preflight: for a directory-contents archive, use `Compress-Archive
  -Path (Join-Path $source '*')`; reserve `-LiteralPath` for a concrete file or
  directory with no wildcard. Set `$ErrorActionPreference = 'Stop'` at the
  first statement and assert the ZIP exists before extraction.
- Recovery: because no ZIP was created and the output remained an unfrozen
  draft containing only empty directories, retain the same bounded draft root
  after verifying it contains no files. Refresh the zero-recurrence contract
  against the updated memory, then rerun only the corrected packaging command.
  Do not resign or alter the request.
- First observed on 2026-08-22 while building
  `C:\G9F\REQ_G9_0822_A1.ready.zip`. The ZIP, publish path, and JBOD were
  untouched; `C:\G9F` contained no files after the failed attempt.

## 2026-08-22 — `Get-CimInstance` datetime values are not necessarily DMTF strings

- Failure signature: a live Windows PowerShell 5.1 verifier calls
  `ManagementDateTimeConverter.ToDateTime([string]$process.CreationDate)` and
  fails with `Specified argument was out of the range of valid values` and
  parameter `dmtfDate` while reading a real `Win32_Process` row.
- Cause: `Get-CimInstance` can materialize the CIM `CreationDate` property as
  a typed `System.DateTime`. Converting that value to text produces a normal
  culture-formatted timestamp, not a WMI DMTF timestamp. Passing that text to
  `ManagementDateTimeConverter.ToDateTime` is invalid. A rehearsal fixture
  that supplies a preformatted UTC string bypasses this live conversion path
  and cannot prove it.
- Mandatory preflight: preserve the runtime type of CIM datetime properties.
  If the value is `DateTime`, normalize it directly with `ToUniversalTime()`;
  use `ManagementDateTimeConverter` only for a string that first passes an
  exact DMTF-format check. Exercise typed `DateTime`, valid DMTF string, null,
  and malformed string cases under Windows PowerShell 5.1. Never claim a
  fixture-only process row proves the live CIM materialization path.
- Recovery: accept the signed terminal failure, rely on the unchanged generic
  endpoint transaction to restore all prepared destinations, and perform a
  direct read-only post-failure observation before any successor mutation.
  Do not replay `REQ_G9_0822_A1`, do not patch its frozen bytes, and do not
  publish an automatic retry. A successor must use a fresh request namespace
  and requires explicit operator authorization after rollback evidence is
  pinned.
- First observed on 2026-08-22 in signed JBOD response
  `R_B27BAAB4CDA4_20260822205836383_182e8c7d`, response ZIP SHA-256
  `0F822D4E73F04DEAF4C5DF2293920416B359DE84DFAA4193BB8A19C732820057`.
  The response state is `FAILED`, its signature is valid, and its exact stderr
  names `Apply-GUIR9DirectGuiPatch.ps1`. No second request was published.

## 2026-08-22 — Inline portal publication cleanup can be rejected before execution

- Failure signature: the local command runner rejects an entire compound
  portal-publication command before execution when that command contains an
  inline conditional `Remove-Item` cleanup branch.
- Cause: the runner's destructive-operation policy evaluates the complete
  command before PowerShell starts. An exact temporary upload cleanup that
  would only run after a copy-hash mismatch is still treated as an inline
  destructive action and blocks the otherwise create-new publication command.
- Mandatory preflight: separate the zero-recurrence preflight, create-new copy,
  hash verification, and create-new ready rename into bounded commands. Do not
  embed a deletion or cleanup branch in the publication command. If a partial
  upload is ever created, stop and classify that exact artifact before any
  separately authorized cleanup; never retry automatically.
- Recovery: confirm that the rejected command created neither the `.upload`
  nor `.ready.zip` leaf and that the live queue remains empty, refresh every
  contract that pins this memory hash, then execute the create-new publication
  steps once without inline cleanup.
- First observed on 2026-08-22 while preparing the GUIR9O1 post-failure
  read-only `DATA_PULL`. The command was rejected before execution; the
  observation request was not published and no local or JBOD file, task,
  process, queue, ledger, source, image, or wafer state changed.

## 2026-08-22 — JavaScript replacement strings interpret PowerShell `$'` as a suffix token

- Failure signature: a mechanically generated PowerShell successor draft
  duplicates a large suffix of its source inside a regex line ending in `$'`,
  producing hundreds of unexpected diff lines and an invalid script.
- Cause: JavaScript `String.replace(search, replacementString)` interprets
  `$'` in the replacement string as the unmatched suffix of the input. A
  PowerShell single-quoted end-anchored regex naturally contains that exact
  two-character sequence.
- Mandatory preflight: when generated replacement text can contain dollar
  signs, pass a callback to `String.replace` so the returned text is inserted
  literally. Strip command-runner metadata before using captured stdout as
  source text. Before any parser, harness, signature, freeze, or package step,
  require the generated successor to have only the intended bounded diff.
- Recovery: while the artifact remains `DRAFT`, remove only that generated
  draft with `apply_patch`, regenerate it from the untouched frozen source
  using a callback replacement, then prove the exact diff and Windows
  PowerShell 5.1 parse. Never correct a frozen, signed, published, or executed
  artifact in place.
- First observed on 2026-08-22 in the unexecuted draft
  `work/GUIR9C1_PORTAL/payload/Apply-GUIR9C1DirectGuiPatch.ps1`. The source
  GUIR9 entrypoint, signed requests, live queue, JBOD installed files, tasks,
  processes, images, sources, and wafer state were untouched.

## 2026-08-22 — A maintenance verifier must not reconstruct endpoint-private predecessor evidence names

- Failure signature: after the endpoint installs all declared target files, a
  maintenance verifier fails before GUI actions with `Endpoint predecessor
  evidence is missing: <destination>` even though the generic endpoint owns
  and created the transaction's predecessor records.
- Cause: the verifier independently reconstructs the endpoint's private
  `Mnnn_<destination-token>_<request-token>.prior` name and state-root layout.
  Source-level agreement between two hash/name implementations does not prove
  that the child verifier can resolve the exact live endpoint-created record.
  This duplicates an internal transaction contract across producer and
  consumer instead of passing endpoint-owned evidence explicitly.
- Mandatory preflight: a verifier that needs predecessor evidence must consume
  an exact endpoint-produced mapping or another endpoint-owned, request-bound
  contract. Do not recompute private evidence filenames or claim compatibility
  from duplicated algorithms. The exact live non-scoring path must prove that
  the verifier can resolve every prepared predecessor before publication.
- Recovery: accept the signed terminal failure and the generic endpoint's
  rollback. Perform one signed read-only observation of the four installed
  hashes and processor health. This is the second signed premise failure in
  the incident, so mutation stop-loss is active: do not publish another repair
  until workflow review creates an explicit clearance and a fresh intent.
- First observed on 2026-08-22 in signed JBOD response
  `R_4ED6AC7A9CBB_20260822213037518_7efea9df`, response ZIP SHA-256
  `6E64D74F39EA2E2E93FE6E64EFF70A9BADBBE4634D2B7E7E5F286EBC96FCC778`.
  The failure occurred before GUI task/process actions; no automatic retry is
  allowed.

## 2026-08-24 — Standalone `Get-FileHash` discovery does not prove worker-script availability

- Failure signature: the OLS1 metadata-only draft completed its bounded path
  enumeration under Windows PowerShell 5.1, then failed before writing its
  local result because `Get-FileHash` was not recognized inside the exact
  worker-script invocation. The same host could discover and run
  `Get-FileHash` in a separate standalone command, and an explicit
  `Import-Module Microsoft.PowerShell.Utility` inside the worker imported the
  module's cmdlets but did not make its `Get-FileHash` function available.
- Cause: `Get-FileHash` is a function exported by the Windows PowerShell 5.1
  `Microsoft.PowerShell.Utility` module, and its availability proved
  invocation-context dependent. A separate-shell `Get-Command` result and a
  source-level module import were therefore not caller/consumer compatibility
  evidence for the exact worker.
- Mandatory preflight: exercise the exact worker's own non-scoring path under
  Windows PowerShell 5.1 and resolve every relied-upon command from inside that
  same invocation before any write or swap. For physical short-path files,
  prefer a script-local bounded .NET SHA-256 helper over the module-exported
  `Get-FileHash` function. If a provider-only PSDrive path is involved, retain
  the existing provider-aware incremental hashing rule instead of passing the
  alias to raw .NET APIs.
- Recovery: OLS1 remained a local `DRAFT`; it was never signed, published, or
  executed on JBOD. Preserve its failed fixture roots as diagnostic evidence,
  withdraw that namespace, and use a fresh successor cloned from the unchanged
  qualified OEL1 worker. Qualify the successor's exact PS5 path before one
  bounded request. No endpoint, task, processor, source, image, wafer, queue,
  or external file state changed.

## 2026-08-24 — A parser-clean PowerShell regex can still be invalid at first evaluation

- Failure signature: the OLS2 exact-subtree provider passed Windows PowerShell
  5.1 parsing and harness safety, but its first local invocation failed while
  evaluating `(^|\)\.\.?($|\)` with a regex parsing error. No provider output
  was created.
- Cause: the PowerShell string contained a single regex backslash before a
  closing parenthesis. The PowerShell language parser validates the string as
  syntax but does not compile regex operands during `ParseFile`.
- Mandatory preflight: for every new or changed `-match`, `[regex]`, or regex
  replacement used by a provider, execute positive and negative controls under
  the exact Windows PowerShell 5.1 invocation before broader fixtures. Require
  traversal controls such as `..\\escape` to be rejected and ordinary bounded
  relative paths to compile and pass.
- Recovery: OLS2 remained an unfrozen local `DRAFT`. Preserve the failed fresh
  fixture root, correct the regex in place, refresh all pinned hashes, rerun
  clone and harness guards, then use a fresh fixture namespace. No JBOD,
  endpoint, processor, task, process, queue, source, image, or wafer state was
  contacted or changed.

## 2026-08-24 — A broad process-local source alias can still hide deeper leaves behind the path budget

- Failure signature: the signed OLS3 metadata inventory for
  `D:\KLARFExport\PatternedFront\Lot_62619-433` returned 131 directory rows
  and 40 BMP rows but remained `HOLD_INCOMPLETE` with exactly 40
  `UNSAFE_PATH_SUBTREES_SKIPPED`. There were zero access errors, zero reparse
  skips, zero truncation, and zero depth-boundary directories. Captured
  brightfield source aliases were already at effective length 198. The worker
  returned only the skip count, so the 40 rejected identities could not be
  proven from the result.
- Cause: the process-local `F:` PSDrive was anchored at the broad configured
  `D:\KLARFExport` root, then repeated the complete lot-relative path beneath
  the alias. Slightly longer children crossed the alias effective-length limit.
  The loop also rejected a child when its canonical provenance spelling was
  230 or more even when the actual provider-aware alias path could be made
  safe, and incremented a count without first recording the child's bounded
  identity and exact rejection reason.
- Mandatory preflight: anchor the process-local alias at the deepest verified
  common source ancestor required by the request, normally the exact requested
  subtree root, so the actual provider-aware I/O path begins at `F:\`. Keep
  the configured-root-relative canonical identity as provenance only; never
  pass an overlong canonical spelling to a launch, raw .NET API, hashing loop,
  or OpenCV provider. Gate the exact alias path that the process will use and
  record the canonical budget state separately. New outputs remain subject to
  the normal 230 hard stop. Before any `continue`, record a bounded skip row
  containing parent-relative path, child name, path type, extension,
  canonical and alias effective lengths, longest-component lengths, and an
  enumerated rejection reason. A count-only unsafe-path result is prohibited.
  The 80-character component cap applies to newly created outputs, not to an
  unchanged pre-existing source component. For source discovery, record a
  component above 80 as provenance and never reproduce it in a new output
  name; reject only an invalid/filesystem-impossible component or an unsafe
  total alias path.
  Require Windows PowerShell 5.1 controls proving: canonical provenance 230 or
  more plus alias below 200 is enumerated safely through the alias; alias 200
  or more holds with the exact skipped identity; a pre-existing source
  component from 81 through the filesystem maximum is enumerated with an
  advisory but not copied into a new output name; and complete inventories
  contain zero skip rows.
- Recovery: preserve OLS3 as signed terminal hold evidence. Do not hash or
  decode any source from that incomplete broad inventory. Use a fresh
  namespace and recovery intent for one generic metadata-only capability
  correction, prove the deepest-alias and exact-skip-row behavior locally, and
  only then consider one separately authorized JBOD request. The correction
  must not hard-code a lot, slot, product, source root, or authority decision.

## 2026-08-24 — Provenance-only long paths must not enter legacy .NET path parsing

- Failure signature: the first OLS4 Windows PowerShell 5.1 self-test supplied
  a deliberately long canonical provenance spelling and failed inside
  `[IO.Path]::GetPathRoot` with the legacy 260-character path exception before
  any alias or filesystem enumeration was attempted.
- Cause: the provider correctly intended the canonical spelling to be
  metadata-only, but its budget helper still passed that string to a legacy
  .NET path parser. A path can therefore violate the provenance/I/O boundary
  even when no file content is opened.
- Mandatory preflight: canonical provenance strings at and above the 230
  effective-length hard-stop boundary must be validated and split lexically,
  without `[IO.Path]`, `Resolve-Path`, provider resolution, filesystem tests,
  or child-process arguments. Only the short physical alias anchor and the
  provider-aware alias read paths may enter filesystem APIs. Run this exact
  long-provenance control under Windows PowerShell 5.1 before freezing or
  publishing the provider.
- Recovery: OLS4 remained a local draft with no JBOD contact. The provider now
  performs lexical drive/UNC provenance validation and passed the frozen local
  gate, including long-canonical/short-alias enumeration and alias cleanup
  after an injected failure. Gate SHA-256 is
  `791829F3EFE668B10FD6DB6CD6847F375556790204C8A9D811224627AD309396`.

## 2026-08-24 — A scale-search grid must include the exact complete-row extent

- Failure signature: the first OCV-02 synthetic scribe gate passed only the
  missing-scribe hold. All three visible twelve-character controls localized
  candidate regions but produced shifted image-first strings and many false
  checksum-valid alternatives. The preserved failed gate is
  `C:\O2S1\SYNTHETIC_GATE.json`.
- Cause: the new scale-search enumerated row-width fractions only through
  `0.96`. Even when the input patch was an exact twelve-cell row, it could not
  evaluate the complete `1.00` extent. A cropped grid then substituted partial
  neighboring glyphs at the boundary, and bounded checksum search amplified
  those segmentation errors into false ambiguity.
- Mandatory preflight: before a rotated/full-image synthetic gate, evaluate an
  exact twelve-cell row directly. Require its image-first string to equal the
  rendered truth, both boundary cells to pass, and the canonical SEMI M12 pair
  to match. Every scale search must include the exact `1.00` row extent as well
  as bounded margin variants. Checksum enumeration remains ineligible until
  both boundary cells establish a complete image row.
- Recovery: preserve `C:\O2S1` as failed executed evidence. Correct the
  unfrozen engine draft, run the direct-row invariant first, and use a fresh
  output namespace for the next complete synthetic gate. No JBOD image,
  installed file, processor, task, process, queue, wafer, source, or hold was
  contacted or changed.

## 2026-08-24 — Synthetic glyph geometry must match the frozen acquisition contract

- Failure signature: after the direct twelve-cell invariant passed, the fresh
  `C:\O2S2` full synthetic gate still produced `4444494944A4` for the standard
  visible row and failed all three visible cases.
- Cause: the synthetic reference generator used 64-by-112 cells while the
  frozen accepted glyphs are 96-by-215. The full-case rectified region was 200
  pixels high, so the synthetic glyph occupied a different normalized
  descriptor scale than its own short reference even though cell boundaries
  were correct. This was a fixture-geometry mismatch, not JBOD evidence.
- Mandatory preflight: inspect the exact frozen reference dimensions before
  generating OCR controls. Synthetic reference cells and rendered row cells
  must use that same native geometry, and expected-region margins must retain
  the complete row without changing glyph scale.
- Recovery: preserve `C:\O2S2` as failed executed evidence, correct only the
  synthetic fixture geometry in the unfrozen engine, rerun the direct-row
  invariant, and use a fresh output root. No production or JBOD source was
  read or changed.

## 2026-08-24 — A migration must preserve the frozen descriptor window, not a proportional approximation

- Failure signature: `C:\O2S3` still failed the three visible scribe controls
  after synthetic cells matched 96-by-215. The standard region correctly used
  a 97.5-pixel cell width but misread central glyphs in a 300-pixel-high crop.
- Cause: the OpenCV port replaced the accepted reader's exact maximum
  80-by-180 energy-centered descriptor window with proportional 0.833-by-0.783
  dimensions. A crop with harmless vertical margin therefore changed glyph
  scale relative to its frozen reference. This was an unauthorized semantic
  drift in the migration.
- Mandatory preflight: mechanically compare every migrated descriptor
  constant and population with the accepted implementation. The OpenCV port
  must use `min(cellWidth - 2, 80)` by `min(cellHeight - 2, 180)`, centered on
  squared residual energy, before 24-by-48 sampling and normalization. Test
  both an exact row and the same row inside a taller harmless-margin crop.
- Recovery: preserve `C:\O2S3`, restore the exact frozen descriptor window in
  the unfrozen engine, pass both direct descriptor invariants, and use a fresh
  synthetic output namespace. Do not tune checksum or candidate thresholds to
  compensate for descriptor drift.

## 2026-08-24 — Exception localization must join the complete twelve-cell row

- Failure signature: `C:\O2S4` passed the standard-position and missing-mark
  controls, but both rotated exception searches returned partial regions. The
  dark rotated truth was 1,152 pixels wide while the selected region was only
  548 pixels wide, so OCR saw roughly half a row and checksum search produced
  false ambiguity.
- Cause: the orientation-aware closing element was only 3.5 percent of the
  working image's minimum dimension. It joined strokes within nearby glyphs
  but not all twelve acquisition-scale cells into one region.
- Mandatory preflight: a rotated full-row control must produce at least one
  bounded candidate covering 90 percent of the known rendered row width before
  OCR. Candidate completeness is an image-localization gate; checksum may not
  repair a partial localized row. Size the oriented join element from the
  bounded working-image scale and retain maximum-region and NMS limits.
- Recovery: preserve `C:\O2S4`, increase only the unfrozen exception-search
  joining span, verify complete-row coverage before OCR, and use a fresh output
  namespace. Do not relax OCR or checksum thresholds.

## 2026-08-24 — Oriented closing alone does not prove full-row coverage

- Failure signature: `C:\O2S5` passed three of four cases, but the dark
  25-degree exception search still returned a maximum 558-pixel region for a
  1,152-pixel row even after the oriented join span increased. The explicit
  pre-OCR coverage control failed.
- Cause: response gaps within some glyph combinations kept the connected
  component split. A single contour-derived rectangle, regardless of closing
  span, was incorrectly treated as the complete row.
- Mandatory preflight: generate bounded baseline-direction expansions for
  every text-like component and preserve distinct width scales through NMS.
  OCR may select among those regions, but checksum remains ineligible until a
  complete twelve-cell boundary passes. Require a candidate covering at least
  90 percent of the known rotated control row before the full gate.
- Recovery: preserve `C:\O2S5`; add bounded multi-scale baseline expansion in
  the unfrozen locator, keep the candidate cap, retain only materially distinct
  width scales, and use a fresh output root. Do not weaken character scoring.

## 2026-08-24 — Region-scale expansion requires a commensurate bounded grid scale

- Failure signature: `C:\O2S6` passed the explicit full-row coverage control
  and three of four full cases. The remaining rotated candidate was 1,340
  pixels wide around a 1,152-pixel row, but the OCR grid omitted the matching
  0.86 row-width fraction and shifted by one cell.
- Cause: localization correctly preserved a larger complete-row region while
  OCR sampled row fractions in coarse 0.06 increments. The true bounded scale
  fell between 0.84 and 0.90.
- Mandatory preflight: enumerate row-width fractions from 0.72 through 1.00 in
  bounded 0.02 increments and preserve the existing candidate cap. Require the
  same rotated truth to pass without changing descriptor, character, boundary,
  or checksum thresholds.
- Recovery: preserve `C:\O2S6`, refine only the bounded grid-scale enumeration
  in the unfrozen engine, and use a fresh output namespace.

## 2026-08-24 — Expanding a partial component around its own center can still omit the row end

- Failure signature: `C:\O2S7` retained a complete-width 1,340-pixel region
  but still dropped the first glyph. Diagnostics showed the detected partial
  component center at `(889,369)` while the rendered full-row center was
  `(760,420)`; symmetric width expansion preserved the wrong center.
- Cause: the locator expanded a partial connected component only about that
  component's centroid. Full-row width alone did not guarantee that both row
  ends were inside the region.
- Mandatory preflight: for each bounded baseline expansion, retain left,
  centered, and right centroid hypotheses along the measured baseline. NMS
  must not merge materially shifted hypotheses merely because their width
  scale matches. OCR boundary gates choose among them.
- Recovery: preserve `C:\O2S7`, add bounded baseline-direction centroid
  offsets without weakening OCR, and use a fresh output root.

## 2026-08-24 — Multi-case real-reference scribe gates need measured timeout budgets

- Failure signature: the six-case historical BF/DF real-reference regression
  was launched with a 120-second command limit and terminated with exit 124
  before the file-backed gate could be committed. The already completed
  one-case control took about 15 seconds; the combined bounded exception
  searches did not fit the guessed aggregate limit.
- Cause: the command timeout was selected before measuring the complete
  multi-case runtime and did not reserve for all BF/DF channel, polarity, and
  orientation hypotheses.
- Mandatory preflight: measure one representative case first, multiply by the
  exact case count, and reserve at least 100 percent additional time for a
  bounded multi-case gate. Prefer smaller create-new batches when the harness
  commits output only after all cases finish.
- Recovery: retain the passing `C:\O2R1` one-case gate, confirm that the timed
  out run created no final output root, and rerun the remaining bounded cases
  in smaller create-new batches with a measured timeout. Do not interpret a
  harness timeout as an image-processing failure.

## 2026-08-24 — A timed-out PowerShell parent can leave its Python child running

- Failure signature: immediately after the six-case command returned exit 124,
  `C:\O2R2` did not exist. A smaller retry then finished computation but failed
  its create-new commit because `C:\O2R2` had appeared. Readback proved that
  the original child had completed all six cases and committed a valid PASS
  gate while the retry was running.
- Cause: terminating the bounded PowerShell invocation did not prove that its
  already-started portable Python child had terminated. Absence of the final
  output root immediately after the parent timeout was not terminal process
  evidence.
- Mandatory preflight: after any parent timeout, identify the exact child by
  executable path, start time, and command line, then wait for or terminate
  that exact process before reusing its output namespace or launching a retry.
  Recheck the create-new root immediately before a retry and treat a newly
  committed gate as candidate evidence requiring full readback.
- Recovery: do not delete or overwrite the late output. Read back its exact
  case count, pass count, source hashes, authority fields, and SHA-256; accept
  it only if complete. Use a distinct namespace for any necessary retry.

## 2026-08-24 — Windows PowerShell 5.1 can bind `String.Split` count as enum options

- Failure signature: the draft O2D1 reference-bundle `-Preflight` failed before
  any write because `$relative.Split(@('\\'), 2)` bound the integer `2` to the
  `StringSplitOptions` overload and rejected it as an invalid enum value.
- Cause: a .NET `String.Split` overload expression that is accepted or inferred
  differently by newer hosts was ambiguous under Windows PowerShell 5.1.
- Mandatory preflight: run the exact script's non-mutating mode under Windows
  PowerShell 5.1 before build. For one bounded separator, use `IndexOf` plus
  `Substring` and validate both sides rather than relying on an ambiguous
  `Split` overload.
- Recovery: the artifact was still `DRAFT` and no output existed, so correct it
  in place, rerun harness safety, and repeat the same exact `-Preflight` before
  any build.

## 2026-08-24 — Endpoint rehearsal must use the exact package payload layout

- Failure signature: O2D1 R1 staged only the short local BF/DF inputs, then the
  endpoint stopped before OpenCV because its `PayloadRoot` did not contain
  `ArgosOpenCvScribeV1.py`; the engine source lived in the separate OCV-02
  provider folder and had not been copied into a package-shaped payload.
- Cause: the harness invoked the endpoint against a source/work directory
  instead of the exact payload layout the portal request will extract.
- Mandatory preflight: enumerate and hash every endpoint-relative payload leaf
  under a fresh package-shaped root, invoke the exact endpoint `-Preflight`
  against that root, and only then run the rehearsal. Source presence elsewhere
  in the repository is not payload evidence.
- Recovery: preserve `C:\O2D1I` as the withdrawn R1 staging evidence, create
  fresh R2 input/payload/normal/failure roots, stage the engine, reference ZIP,
  and job under their exact payload names, and rerun both normal and injected-
  provenance-failure cases.

## 2026-08-24 — Clone remediation must classify process-local alias literals

- Failure signature: the first frozen O2D1 R2 clone-remediation preflight
  rejected the source `Q:` alias as undeclared and identified two generated
  full alias-leaf literals.
- Cause: the remediation manifest classified the persistent filesystem roots
  but omitted the process-local source alias; the generated harness also used
  whole alias leaves instead of composing the bounded filenames from `Q:`.
- Mandatory preflight: run clone-literal remediation before executing a cloned
  harness, classify every process-local PSDrive root, and compose leaf names so
  the manifest describes the alias anchor rather than each leaf.
- Recovery: preserve the failed frozen remediation manifest, use a fresh R2
  manifest, declare `Q:` as `UNCHANGED_ALLOWED`, and rerun both harness-safety
  and clone-remediation preflight before writing its gate.

## 2026-08-24 — Never freeze a preaction dependency hash from transcription

- Failure signature: the first frozen O2D1 live mutation intent named the R1
  test-withdrawal file but contained a transcribed SHA-256 that did not match
  the exact file.
- Cause: the dependency value was entered before running `Get-FileHash` against
  the final exact bytes.
- Mandatory preflight: compute every dependency hash from the final file, emit
  the path/hash rows, then construct the frozen contract from those rows. Never
  infer or transcribe an unseen hash, even for a small local JSON artifact.
- Recovery: withdraw the frozen R1 intent without execution, signature,
  publication, or external mutation; create a fresh R2 namespace using the
  measured hash and run the recovery-intent preflight against R2.

## 2026-08-24 — Do not force a new development request into recovery semantics

- Failure signature: the O2D1 R2 recovery-intent preflight rejected local test
  classifications, a non-B/C/D remedy, and an OCV-00 source-hash aggregate as
  recovery observation evidence.
- Cause: a normal first OCV-02 development request was incorrectly modeled as
  a successor recovery merely because it creates a bounded D-side work/output
  tree and installs an exact endpoint helper. No signed live-state premise had
  failed and no failed recovery was being replaced.
- Mandatory preflight: classify the action `MUTATE` for its writes/process, but
  create `ARGOS_RECOVERY_INTENT` only when designing a successor recovery under
  the recovery policy. New review-only development still requires the normal
  zero-recurrence, path, harness, package, queue, and route gates.
- Recovery: withdraw both unused O2D1 recovery-intent drafts, create no R3,
  and continue through the standard new-development request lane.

## 2026-08-24 — OpenCV child paths need a child-visible short source alias

- Failure signature: the unpublished signed O2D1 request passed its local
  package gates, but the exact Slot16 BF source path measured 178 characters
  raw and 210 with the mandatory 32-character reserve. The job passed that
  canonical path directly to the portable Python/OpenCV child.
- Cause: local package path planning included payload and D output leaves but
  did not run the path-budget guard against each canonical image source before
  freezing the job. A PowerShell-only PSDrive alias would not solve the child
  process path because it is provider-local.
- Mandatory preflight: path-gate every canonical source before job freeze. At
  effective length 200 or more, create a verified temporary DOS-device alias
  anchored at the deepest exact source subtree, use its short path for child
  I/O, preserve the canonical path separately in the versioned job/result
  provenance, and remove the alias in a `finally` block. Refuse a pre-existing
  or mismatched alias. Include alias create/remove in the declared process
  actions and rehearse both normal and injected-failure removal.
- Recovery: preserve and withdraw the frozen signed O2D1 ZIP before
  publication. Use fresh request and D work/output namespaces for O2D2; never
  patch or publish O2D1.

## 2026-08-24 — `subst.exe <drive>:` is not a mapping query

- Failure signature: O2D2 successfully created and later removed the temporary
  `X:` alias, but its local rehearsal stopped before OpenCV because
  `subst.exe X:` returned `Invalid parameter - X:` and the endpoint treated
  that as an alias-target mismatch.
- Cause: `subst.exe` lists mappings only when invoked without arguments; the
  single-drive form is not a supported query.
- Mandatory preflight: after creating the exact alias, invoke `subst.exe` with
  zero arguments, parse exactly one case-insensitive line for the requested
  drive, and require its right-hand target to equal the frozen anchor. Rehearse
  alias removal on both normal and injected-failure paths.
- Recovery: preserve the O2D2 local roots, confirm `X:` and the diagnostic `Z:`
  are absent, withdraw the executed O2D2 test/endpoint namespace, and use a
  fresh O2D3 namespace with zero-argument mapping verification.

## 2026-08-24 — PowerShell keywords require token separation from variables

- Failure signature: O2D3 created and verified the short alias, completed the
  OpenCV child, wrote `RESULT.json`, and removed the alias, then failed because
  `return$r` was interpreted as a command named `return$r` at runtime.
- Cause: source compaction removed mandatory whitespace between the `return`
  keyword and its variable. The AST parser and static harness did not classify
  this token sequence as a parse error.
- Mandatory preflight: reject keyword-variable adjacency such as `return$...`
  and `throw$...` with an explicit bounded lexical check in addition to the
  parser/harness gate; keep whitespace around control keywords in generated
  PowerShell.
- Recovery: preserve the O2D3 result as withdrawn local evidence, confirm the
  alias is absent, and use a fresh O2D4 endpoint/test/request namespace with
  separated `return $value` and `throw $value` tokens.

## 2026-08-25 — Empty external-evidence sets cannot rely on `Measure-Object.Sum`

- Failure signature: the first O2A1 direct-admin read-only rehearsal reached
  the `ZERO` collection case and stopped under Windows PowerShell 5.1 with
  `The property 'Sum' cannot be found on this object`. The failed expression
  cast `(($copyCandidates.ToArray() | Measure-Object -Property bytes -Sum).Sum)`
  while the generic list contained zero rows.
- Cause: an empty generic-list pipeline did not provide the assumed aggregate
  object/property boundary under StrictMode. The harness had a ZERO case, but
  the aggregate itself was evaluated before the test could assert the case.
- Mandatory preflight: for a bounded numeric total that must support zero,
  initialize an explicitly typed scalar to zero and add each materialized row
  inside a `foreach` loop. Exercise ZERO, ONE, and MANY through the exact
  packaged Windows PowerShell 5.1 entrypoint; never dereference an aggregate
  property whose command may receive no pipeline invocation.
- Recovery: preserve `C:\O2A1T` and the exact O2A1 source as withdrawn local
  rehearsal evidence. No live `C:\O2A1` root or share return was created.
  Use fresh O2A2 script, package, test, output, and return namespaces; do not
  patch, publish, or execute O2A1 again.

## 2026-08-25 — StrictMode does not guarantee collection member enumeration

- Failure signature: the O2A2 package completed and returned a passing ZERO
  observation, but its outer test harness then failed on
  `$observation.sourceResults.rows` with `The property 'rows' cannot be found
  on this object` under Windows PowerShell 5.1 StrictMode.
- Cause: the harness relied on implicit member enumeration across an array of
  deserialized source-result objects. That convenience is not a stable
  Windows PowerShell 5.1 collection contract under StrictMode.
- Mandatory preflight: materialize the outer collection, iterate each source
  result explicitly, materialize its `rows` collection, and add each row
  through a nested loop before filtering or counting. Exercise the exact
  deserialized ZERO, ONE, and MANY result schemas.
- Recovery: preserve `C:\O2A2T` and the failed `Test-O2A2.ps1` as withdrawn
  harness evidence. The exact O2A2 audit package passed and remains unchanged;
  use a fresh `Test-O2A2R2.ps1`, `C:\O2A2T2`, and create-new gate. No live
  `C:\O2A2` root, share return, JBOD contact, or target mutation occurred.

## 2026-08-25 — A PowerShell `if` statement is not a parenthesized argument expression

- Failure signature: the O2A2 R2 outer harness completed the passing `ZERO`
  audit case, then stopped while constructing the `ONE` fixture with
  `The term 'if' is not recognized as the name of a cmdlet`. The expression
  passed `(if (...) { ... } else { ... })` directly as a `Join-Path` argument.
- Cause: Windows PowerShell 5.1 treated `if` inside ordinary parentheses as a
  command invocation. Control-flow output may be captured with a subexpression
  or, more clearly, assigned by a preceding statement; ordinary parentheses
  do not turn a statement into an argument expression.
- Mandatory preflight: assign each conditional argument to a scalar with an
  explicit `if`/`else` statement before invoking the consumer. Rehearse every
  branch through the exact Windows PowerShell 5.1 harness, including ZERO,
  ONE, and MANY fixtures; parsing and token inspection alone do not prove the
  dormant branch can execute.
- Recovery: preserve `C:\O2A2T2` and `Test-O2A2R2.ps1` as withdrawn harness
  evidence. The unchanged O2A2 audit package passed the ZERO case again; use
  fresh `Test-O2A2R3.ps1`, `C:\O2A2T3`, and a create-new R3 gate. No live
  `C:\O2A2` root, share return, JBOD contact, or target mutation occurred.

## 2026-08-25 — Regex backslashes must remain doubled in PowerShell single-quoted patterns

- Failure signature: the first local CDM1 draft rehearsal reached relative-path
  validation and stopped with `Not enough )'s` while parsing
  `(^|\)\.\.(\|$)` as a regular expression.
- Cause: the intended literal-backslash regex lost one backslash in each
  alternation arm while the draft script was constructed. The PowerShell AST
  remained valid because the defect was in runtime regex syntax.
- Mandatory preflight: for every safety-significant regex, run the exact
  expression through Windows PowerShell 5.1 in the package rehearsal and
  exercise both an accepted path and the rejected `..` segment. In a
  PowerShell single-quoted regex string, preserve `\\` where the regex engine
  must match one literal backslash.
- Recovery: the unpublished, unsigned DRAFT package made no JBOD contact and
  deleted no retired source file. Correct the draft in place, refresh every
  dependent hash, and use fresh local rehearsal and create-new gate paths
  before freeze; never reuse the failed `work\M1D` rehearsal root.

## 2026-08-25 — A JBOD-local collector cannot assume direct engineering-share reachability

- Failure signature: frozen JEO1 passed its exact live preflight on JBOD
  `A1025645101`, completed the bounded read-only observation with state
  `PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION`, wrote
  `D:\A2\x\JEO1R_LOCAL.zip`, and then failed closed at line 430 when
  `Test-Path` against the `\\shm-cifs\...\InspectionRevs` parent raised
  `The network path was not found`. The observation performed zero target
  mutations; only the direct share return failed.
- Cause: the portable package treated the engineering share, which is
  reachable from the engineering laptop and gateway, as if the JBOD host had
  the same direct network route. Path-length proof and share existence from a
  different hop did not prove JBOD-to-share reachability.
- Mandatory preflight: for every direct-admin endpoint package, identify the
  exact host that performs each return hop and prove reachability from that
  host before collection. If the endpoint has no direct share route, retain a
  create-new local result on qualified `D:` and use an already-qualified relay,
  pull channel, or explicit operator reverse-transfer path. A failed optional
  return copy must not invalidate or obscure a successfully committed local
  observation; catch and report return failure separately. Rehearse the exact
  unreachable-share case through Windows PowerShell 5.1.
- Recovery: do not rerun JEO1. Preserve frozen JEO1 as executed terminal
  failure evidence and retrieve only exact `D:\A2\x\JEO1R_LOCAL.zip` through
  the already-open reverse RDP path. Verify its hash and contents before using
  any observation claim. Build the durable signed read-only JBOD evidence
  channel with a host-authentic return route; JEO1 is non-reusable and cannot
  parent a patched execution package.

## 2026-08-25 — A nullable scheduled-task timestamp must not erase task presence

- Failure signature: JEO1 returned four scheduled-task rows with
  `present=false` and `You cannot call a method on a null-valued expression`,
  even though its independent process inventory proved the JBOD endpoint worker
  and response sender were running. The task collector called
  `$info.NextRunTime.ToUniversalTime()` while `NextRunTime` was null, and its
  broad catch replaced the entire already-found task with a false absent row.
- Cause: one optional task-info timestamp was treated as mandatory inside the
  same failure boundary as task discovery, definition export, principal,
  actions, and current state. A presentation-field null therefore destroyed
  the authoritative presence evidence.
- Mandatory preflight: capture task existence and definition identity before
  optional task-info fields. Null-check `LastRunTime` and `NextRunTime`
  independently and preserve a present row with a field-scoped diagnostic when
  either timestamp is absent. Rehearse null, zero/default, and populated task
  timestamps through Windows PowerShell 5.1; a field error must never flip a
  discovered task to absent.
- Recovery: treat all JEO1 scheduled-task rows as unusable and make no task or
  processor-health claim from them. Retain the independently captured process
  rows and installed config hashes. Any successor observation must use a fresh
  namespace and null-safe task fields before task state can clear a route or
  processor hold; frozen executed JEO1 is non-reusable.
### OpenCV scribe exception search cannot substitute texture OCR for qualified localization

- Signature: a signed real-wafer OpenCV scribe run reports a checksum-valid
  image-first string under `SCRIBE_REFERENCE_COVERAGE_HOLD`, while its job has
  zero pose-bound expected regions, the selected region is a low-confidence
  whole-image exception candidate, no hypothesis/candidate is accepted, and a
  large set of checksum-valid alternatives comes from unrelated wafer texture.
- Cause: the engine ranked OCR grid score before localization confidence,
  applied no qualified localization threshold, mixed standard and exception
  regions in one winner list, and evaluated reference coverage before
  localization-confidence and ambiguity disposition. The correct accepted
  glyph library was present; the failure was localization and decision
  precedence, not missing reference bytes.
- Preflight: require at least one qualified pose-bound region or an explicitly
  qualified exception-localization result before OCR can be eligible. Freeze
  standard and exception result classes separately. Reject an unqualified
  exception region before checksum adjudication, and prove that localization,
  segmentation, confidence, and multiple-valid-candidate holds outrank the
  general reference-coverage hold. Run the accepted V4 physical holdout and
  duplicate-view regression before any new real-wafer package.
- Recovery: retain the signed response as diagnostic evidence, do not freeze
  the slot or run the next slot, and perform a direct read-only observation of
  the installed current-acquisition proposal/crop metadata before changing the
  OpenCV engine. A corrected engine requires a fresh namespace and must not
  reuse the failed package or its output roots.
- First observed on 2026-08-25 in signed O2D5 response
  `R_ADD3BF802E2F_20260825193812855_dbc9bb56`: selected exception region
  `EXCEPTION_120_0010_X1.25_O+0.00`, localization score
  `0.544673502445221`, reported string `699F999999F6`, and 124
  checksum-valid candidates. No task/process restart, provider activation,
  source mutation/deletion, wafer action, hold clearance, XML, training, or
  production action occurred.

### Signed-response verification gates cannot grant downstream workflow authority

- Signature: a response collector correctly verifies a signature, request ID,
  file hashes, and protected invariants, then writes downstream booleans such
  as `slotFrozen=true` or `nextSlotAuthorized=true` before migration-parity
  adjudication has occurred.
- Cause: cryptographic/transport success was conflated with semantic family
  acceptance. A valid signed result proves what executed and what it returned;
  it does not prove that the returned algorithm preserved the frozen accepted
  semantics.
- Preflight: response collectors must stop at transport, signature, exact
  payload, and bounded-result facts. Slot freeze, family parity, successor
  authorization, hold clearance, and provider eligibility belong only in a
  separate semantic adjudication gate that pins the accepted baseline.
- Recovery: preserve the verified response and its immutable collector output
  as terminal evidence, explicitly withdraw the overbroad downstream claims,
  mark the collector non-reusable, and create a separate adjudication artifact.
- First observed on 2026-08-25 in the O2D5 response-collection gate. Its
  signature and payload verification remain valid; its Slot16-freeze and
  Slot17-authorization claims are withdrawn.

## 2026-08-25 — Nested-RDP clipboard synchronization can transiently lock the local clipboard

- Failure signature: a direct-control observation stopped locally at
  `Set-Clipboard : Requested Clipboard operation did not succeed` before the
  command was sent to the remote Argos console.
- Cause: RustDesk plus two nested RDP clipboard channels can hold the Windows
  clipboard while synchronizing a prior remote result. A single
  `Set-Clipboard` call is not a reliable delivery or sentinel preflight.
- Mandatory preflight: every direct-control clipboard write must use a bounded
  retry loop, verify an exact readback after the write, and stop before remote
  input if the clipboard cannot be acquired. Keep command/result sentinels
  unique and never treat a stale clipboard value as a new endpoint response.
- Recovery: retry only the local clipboard acquisition. Because the failing
  call preceded all remote keystrokes, it is not a remote execution attempt and
  does not authorize bypassing the endpoint identity gate or reusing a stale
  result.

## 2026-08-25 — Direct-control runners need an explicit local preflight before freeze

- Failure signature: the harness-safety gate rejected the frozen R1
  direct-control runner with `MISSING_NON_MUTATING_MODE` and
  `PARAMETER_VARIABLE_REASSIGNED`; no remote preflight or mutation had run.
- Cause: read-only behavior was represented only by action names instead of a
  named `-Preflight` mode, and the typed `$Command` parameter was reassigned
  when loading `-CommandPath`. PowerShell variable names are case-insensitive,
  so a typed parameter must not double as mutable working storage.
- Mandatory preflight: run `Confirm-ArgosPowerShellHarnessSafety.ps1` against
  the exact direct-control runner before freezing or pinning it in a pre-action
  contract. Require an early local-only `-Preflight` return that validates
  action-specific dependencies without focusing RustDesk or sending remote
  input. Copy typed parameters into separately named effective-value variables
  and never reassign the parameters.
- Recovery: withdraw the failed frozen R1 contract, preserve it as evidence,
  add the explicit local preflight, rename mutable command storage, rerun the
  parser and harness gates, and issue a fresh R2 intent and pre-action contract.
  Do not edit or execute the failed frozen R1 contract.

## 2026-08-25 — A multiline clipboard payload is not a terminal response sentinel

- Failure signature: the R2 remote preflight executed successfully, but the
  local collector immediately passed the still-synchronizing payload text
  beginning with `[CmdletBinding()]` into `ConvertFrom-Json`, which failed with
  `Invalid JSON primitive: CmdletBinding`. The exact terminal preflight JSON
  arrived moments later and proved zero target mutations.
- Cause: the response predicate accepted any clipboard value whose trimmed
  form differed from the untrimmed multiline payload sentinel. Newline
  normalization across RustDesk and nested RDP made the same payload compare
  unequal to itself.
- Mandatory preflight: a clipboard response collector must match an exact
  terminal schema and action/revision identity. Inequality with a sent payload,
  nonce, or stale clipboard value is not positive response identification.
  Exercise payload newline normalization and delayed clipboard propagation
  before freezing the collector.
- Recovery: collect and pin the already-arriving exact terminal once without
  retrying the remote preflight. Withdraw the frozen R2 collector, change the
  predicate to require `argos_legacy_converter_disable_terminal_v1`, rerun all
  local gates, and issue a fresh R3 contract before any apply action.

## 2026-08-25 — Alt-based focus handoff can change the nested JBOD input language

- Failure signature: while a long Base64 PowerShell command was being typed
  through RustDesk, Argos RDP, and JBOD RDP, the JBOD input indicator changed
  from English to German. The remaining command was corrupted, no terminal
  clipboard marker returned, and later direct-control actions timed out.
- Cause: the control runner tapped Alt to satisfy Windows foreground-focus
  restrictions while Shift remained held in the nested remote input state.
  JBOD received `Left Alt+Shift`, which is a keyboard-layout switch. Base64 is
  not layout-independent when keys such as Y and Z are subsequently remapped.
- Mandatory preflight: never emit Alt, Windows-key, or another shortcut to gain
  foreground focus. Attach the current and foreground input threads, call
  `SetForegroundWindow`, detach, and require the exact window handle to be
  foreground. Then send key-up events for left/right Shift, Ctrl, Alt, and
  Windows keys before every input stage. Require the visible JBOD input
  indicator to be English before a typed command.
- Recovery: stop the corrupted shell once, restore English input explicitly,
  discard the unterminated command attempt, and do not retry its namespace.
  Patch and validate the direct-control runner before sending more remote input.

## 2026-08-25 — Nested RDP can keep typing after the local runner times out

- Failure signature: a local direct-control process reached its outer timeout
  while the JBOD console was still visibly receiving the earlier long command;
  terminating the local runner did not immediately empty the RustDesk and
  nested-RDP input queues, so the operator had to stop the remote console.
- Cause: `SendKeys` queued 400-character bursts with only 20 milliseconds
  between them. The local API accepted input much faster than RustDesk plus two
  RDP layers could deliver it. The outer process timeout covered only an
  assumed result window and did not budget the actual remote typing/drain time.
- Mandatory preflight: pace long Base64 input in 16-character chunks with at
  least 200 milliseconds between chunks and wait five seconds after the final
  chunk before Enter. Calculate the caller timeout as the typing estimate plus
  the declared result timeout plus 30 seconds. At the 8,192-character ceiling,
  reserve roughly two minutes for typing alone. Never send a second stream or
  kill the runner while the first stream is visibly draining.
- Recovery: stop the affected console once, leave processor/task state
  unchanged, mark the incomplete command non-reusable, validate the paced
  runner locally, and begin any later observation under a fresh command
  namespace only after English layout and exact JBOD identity are reverified.

## 2026-08-25 — SendKeys Ctrl+V can degrade to a literal `v` through nested RDP

- Failure signature: the direct-control runner placed the complete command on
  the verified shared clipboard, called `SendKeys.SendWait('^v')`, and the JBOD
  PowerShell console received only the single character `v`. The expected
  nonce-bound result never arrived and the console remained open.
- Cause: through RustDesk, gateway RDP, Argos RDP, and JBOD RDP, the synthesized
  Ctrl modifier was dropped while the V key was delivered. A SendKeys chord is
  not an atomic clipboard-paste operation across this topology.
- Mandatory preflight: clipboard-based direct control must emit explicit
  low-level left-Ctrl-down, V-down, V-up, and left-Ctrl-up events with bounded
  delays. Prove the exact mechanism first with a short `hostname|clip;exit`
  paste and require `A1025645101`. Do not send a substantive command until that
  probe passes. Every pasted wrapper must exit its own console on PASS or FAIL.
- Recovery: terminate the waiting local collector, close only the console
  opened by that failed attempt, patch and validate the direct-control skill,
  then run the exact short paste probe. Never fall back to long typed Base64;
  long typed commands are prohibited in this nested topology.

## 2026-08-25 — Exiting an EncodedCommand child does not close its parent console

- Failure signature: each clipboard-based `Invoke` returned its nonce-bound
  result, but a new blank interactive PowerShell console remained open. A
  bounded process inventory showed the hidden qualified monitor/tray processes
  unchanged and multiple recent plain `powershell.exe` parents, each with a
  console host and no substantive command line.
- Cause: the fresh interactive PowerShell launched `powershell.exe
  -EncodedCommand ...`. The wrapper's `exit` terminated only that child process;
  control returned to the fresh parent prompt, which had no outer exit command.
- Mandatory preflight: the pasted command must append `;exit` after the complete
  EncodedCommand token. Rehearse PASS and remote FAIL and require both to return
  a nonce-bound result and leave no additional recent plain interactive parent.
- Recovery: enumerate exact recent plain PowerShell parents and distinguish
  them from pinned hidden processor, monitor, and tray command lines. With an
  explicit bounded cleanup authorization, close only the stale parents created
  by direct control. Never kill PowerShell by name or touch the pinned healthy
  processor/tray processes.

## 2026-08-25 — A long nested-RDP clipboard paste can open an interactive confirmation

- Failure signature: a bounded cleanup payload was placed on the shared
  clipboard and pasted into the JBOD console, but an interactive confirmation
  window opened instead of executing the command. No nonce-bound terminal
  marker returned; the operator directly reported that the paste did not work.
- Cause: the terminal/remote clipboard path applied an interactive large-paste
  safety boundary. A successful short paste probe does not prove that a much
  longer EncodedCommand will bypass that boundary.
- Mandatory preflight: record the exact final pasted character count and test
  the actual transport-length class non-mutatingly before a mutation. Keep
  direct clipboard commands within the already proven short-paste class. A
  large file-backed workflow requires a qualified file/portal transfer route;
  it must not be tunneled as a long clipboard command.
- Recovery: send Escape once to reject the confirmation, mark the attempted
  command non-reusable, and make one short direct observation of the exact
  target identities. Do not press Enter, accept the dialog, or retry the same
  mutation namespace. Any successor requires fresh observation, intent,
  pre-action contract, and a transport proven at its exact final length.

## 2026-08-25 — PowerShell `$Matches` can overwrite a case-insensitive process variable

- Failure signature: a locally validated direct-control action failed while
  binding its RustDesk `-Process` parameter, reporting that a CSV PID string
  could not convert to `System.Diagnostics.Process`. No remote focus or input
  occurred.
- Cause: the runner stored its RustDesk collection in `$matches`. A later
  `-match`/`-notmatch` validation populated PowerShell's automatic `$Matches`
  variable; variable names are case-insensitive, so the process collection was
  replaced by regex captures.
- Mandatory preflight: never use `$matches` as application storage. Prefer
  `[regex]::IsMatch()` when the automatic captures are not required, and keep
  exact process collections under a semantically unique variable name. Exercise
  every new action through local preflight plus its first focus-binding call.
- Recovery: because the failure occurred before remote focus or input, correct
  the DRAFT runner, rerun parser/harness/skill validation, and repeat only the
  unchanged read-only observation. Do not classify it as a JBOD execution.

## 2026-08-25 — Bare `python` can resolve outside the qualified Argos environment

- Failure signature: a local OpenCV parity gate stopped during module import
  with `ModuleNotFoundError: No module named 'cv2'`; no gate output or image
  processing occurred.
- Cause: the shell resolved bare `python` to `C:\Python314\python.exe`. The
  qualified Argos development interpreter is the separately recorded
  `C:\ArgosPy313\Scripts\python.exe`; neither the system Python nor a Codex
  workspace dependency loader is an interchangeable OpenCV authority.
- Mandatory preflight: before every local Python/OpenCV gate, resolve the exact
  interpreter path from `work/ARGOS_LOCAL_DEVELOPMENT_TOOLCHAIN_CHECKPOINT_20260819.md`,
  invoke that absolute path, and run a bounded `import cv2,numpy` version probe.
  Never rely on PATH or a bare `python` command.
- Recovery: retain the no-output failed invocation as transport/toolchain
  evidence only, verify the qualified interpreter and module versions, then
  rerun the unchanged local gate using its fresh create-new output path.

## 2026-08-25 — One-letter PowerShell helper names can collide with built-in aliases

- Failure signature: an exact read-only metadata observer called helper `H`
  with a file path, but Windows PowerShell resolved `H` as the built-in history
  alias and tried to convert the path to `Get-History -Id`.
- Cause: command-name precedence and case-insensitive alias resolution make
  terse one-letter helper names unsafe even when a same-looking function was
  declared in compact source.
- Mandatory preflight: prohibit one-letter function/helper names in every
  Windows/JBOD script. Resolve each custom command name with `Get-Command -All`
  under Windows PowerShell 5.1 and use a unique verb-noun name such as
  `Get-ExactSha`.
- Recovery: withdraw the executed observer namespace, record its nonce and
  terminal failure, and create a fresh observer artifact with the unique
  helper name. The failed read-only action returned no asset rows, read no
  image bytes, and made no mutation.

## 2026-08-25 — Nested RustDesk clipboard input can fail while typed control and clipboard return remain healthy

- Failure signature: the exact short `hostname|clip;exit` clipboard probe
  timed out, but the immediately subsequent typed `WindowInventory` hostname
  gate returned exact host `A1025645101` and a complete bounded window list.
  No substantive command ran during the failed paste attempt.
- Cause: the RustDesk/RDP inbound clipboard-paste direction was unavailable or
  intercepted even though the visible nested route, typed key delivery, and
  remote-to-local clipboard return direction were healthy. A full-screen
  RustDesk window alone does not prove both clipboard directions.
- Mandatory preflight: after a clipboard-probe timeout, do not retry the paste
  or send an EncodedCommand. Run one typed hostname-gated window inventory. A
  typed fallback may be used only when that exact inventory passes, the command
  is parser-valid and non-mutating, its source is at most 512 characters, and
  the transport returns a nonce-bound result. It must reject common mutation
  tokens and must not carry files, packages, or binary content.
- Recovery: use the skill's `InvokeTypedReadOnly` lane for the single bounded
  read-only projection only after the complete constructed transport—not merely
  the caller source—has passed the typed-length class. Otherwise stop at the
  exact typed inventory and return to a qualified file or portal transport for
  payload delivery. Do not type long Base64, accept a paste confirmation, or
  resize RustDesk.

## 2026-08-25 — Bounding caller source does not bound a constructed typed transport

- Failure signature: a 469-character read-only caller passed its source limit,
  but the constructed nonce/hostname/result wrapper expanded beyond 1,000
  characters. The nested RustDesk/RDP/RDP input queue delivered the tail before
  the head, changed character case, and left PowerShell at continuation prompt
  `>>`. Console capture proved no caller result and no target mutation.
- Cause: the gate bounded only caller source and permitted a much longer final
  typed transport. Nested interactive typing is not an ordered file-transfer
  channel; a locally parser-valid wrapper can still arrive reordered.
- Mandatory preflight: path, character, and transport gates must measure the
  exact final string actually sent. Arbitrary typed wrappers are prohibited in
  this topology regardless of caller-source length. Typed commands remain
  limited to the short fixed commands already implemented and proven by the
  direct-control skill, such as `hostname|clip` and bounded inventory actions.
- Recovery: withdraw the typed-wrapper feature and failed command namespace,
  preserve the exact console text as failure evidence, and use a qualified file
  or portal transport for every payload or compound command. Do not repair the
  partial continuation prompt by blindly sending Enter or retrying the caller.

## 2026-08-25 — A typed PowerShell parameter can silently coerce a same-named local result

- Failure signature: the bounded OpenCV child completed, but the caller failed
  in strict mode at `$run.exitCode` because `$run` was a string rather than the
  intended `PSCustomObject`. The disposable rehearsal root was removed and no
  gate was created.
- Cause: function parameter `[string]$Result` and local variable `$result` are
  the same case-insensitive PowerShell variable. Assigning the invocation object
  to the typed parameter coerced it to text before return.
- Mandatory preflight: prohibit local variables that case-insensitively equal a
  parameter name, especially generic names such as `Result`, `Path`, `Input`,
  or `Output`. Run an AST inventory of parameter/local assignments and execute
  the exact normal result-return path under Windows PowerShell 5.1 before freeze.
- Recovery: withdraw the executed rehearsal namespace, preserve the failure and
  cleanup proof, and create a fresh product namespace with semantically distinct
  names such as `$ResultPath` and `$invocation`. Do not patch executed product
  bytes in place.

## 2026-08-25 — A preserved hold need not be the top-level result state

- Failure signature: the corrected OpenCV endpoint completed its rehearsal, but
  the harness failed because it required top-level `resultState` to equal
  `SCRIBE_REFERENCE_COVERAGE_HOLD`. The output contract separately returned the
  complete `holds` array, where the coverage hold is authoritative.
- Cause: result-state precedence selects a more specific recognition or
  localization disposition while independent safety holds remain present in
  `holds[]`. Equality between one hold code and the top-level state is not the
  hold-preservation contract.
- Mandatory preflight: assert required holds by exact code and cardinality in
  the returned hold set. Validate top-level state only against its explicitly
  enumerated result-state contract; never infer that an independent hold must
  replace a more specific state.
- Recovery: withdraw the executed rehearsal namespace and create a fresh test
  namespace. Preserve the endpoint semantics and replace only the invalid
  harness assertion with an exact `holds[]` membership/cardinality check.

## 2026-08-25 — `allowCreate` does not waive maintenance predecessor declaration

- Failure signature: the local signed-package verifier rejected a maintenance
  request with `Maintenance change lacks approved predecessor hashes` after the
  request directory was signed but before final ZIP creation or publication.
- Cause: generic maintenance validation requires every change to declare at
  least one approved predecessor hash even when `allowCreate` is true. The
  declaration is also the idempotent/existing-target safety boundary.
- Mandatory preflight: mechanically validate each `changes[]` row before the
  first signature. Require a nonempty normalized predecessor set. For a fresh
  create-only helper destination, declare the exact intended installed hash as
  the sole idempotent predecessor and keep `allowCreate: true`.
- Recovery: retain the signed-invalid directory as withdrawn evidence, create a
  fresh high-entropy request/product namespace, and run the generic signed-
  package verifier before final ZIP construction. Never patch signed bytes.

## 2026-08-25 — A builder cannot pin the hash of a gate that hashes that builder

- Failure signature: a draft clone-remediation gate recorded the exact builder
  hash, while the builder also pinned the clone-gate file hash. Updating the
  builder with that gate hash necessarily made the recorded builder hash stale.
- Cause: the two artifacts formed an unsatisfiable cryptographic dependency
  cycle. No choice of gate-ordering can make both exact hashes current.
- Mandatory preflight: construct the complete clone-remediation manifest before
  generation, but do not make a generated script pin the hash of an evidence
  file whose contents include that script's hash. Detect bidirectional hash
  dependencies as a hard stop before signature or execution.
- Recovery: while both artifacts remain draft and unsigned, preserve the
  original pre-generation manifest, make the builder dynamically require the
  gate state, manifest hash, exact generated path, and its own recorded hash,
  then regenerate the gate once after the builder is final. The builder may pin
  the immutable manifest hash; it must not pin the self-referential gate hash.

## 2026-08-25 — Refactoring a pinned gate requires a full downstream symbol audit

- Failure signature: a signed request passed the generic package verifier and
  exact ZIP extraction, then strict mode rejected an unset former gate-hash
  variable while constructing the final evidence object.
- Cause: the builder's preflight dependency was correctly changed from a pinned
  clone-gate hash to dynamic exact-builder validation, but one downstream
  evidence-field expression still referenced the removed variable.
- Mandatory preflight: after removing or renaming a dependency symbol, perform
  an exact whole-file symbol search and execute the complete build through final
  gate serialization on an unsigned rehearsal namespace. Preflight success is
  insufficient when it returns before final evidence construction.
- Recovery: preserve the signed and partial-final artifacts as withdrawn and
  non-reusable, create a fresh request/product namespace, replace the evidence
  field with the actual current clone-gate hash computed after validating the
  gate contents, and rerun every exact gate before the first new signature.

## 2026-08-25 — Path-budget maxima must be derived from candidate rows

- Failure signature: the exact pre-sign final-gate construction rehearsal failed
  in strict mode because `maximumEffectiveLength` was read as a top-level
  property of the path-budget result.
- Cause: `Confirm-ArgosPathBudget.ps1` returns thresholds and `candidates[]` at
  the top level; each candidate owns its exact `effectiveLength`. It does not
  emit a top-level observed maximum.
- Mandatory preflight: inspect the exact utility schema and derive the observed
  maximum mechanically from `candidates[].effectiveLength`. Do not confuse the
  top-level warning/hard-stop thresholds with an observed maximum, and exercise
  final evidence serialization before signing.
- Recovery: while the product remains draft and unsigned, calculate the maximum
  from the nonempty candidate collection, bind that scalar into the final-gate
  constructor, regenerate any source-hash gate affected by the correction, and
  rerun the exact preflight.

## 2026-08-26 — Foreground attachment must include the exact RustDesk target thread

- Failure signature: the exact full-screen RustDesk window existed once at the
  pinned title and `1920x1200` bounds, but the direct-control runner stopped
  before input with `Exact RustDesk desktop did not become foreground`.
- Cause: the focus helper attached the calling thread only to the current
  foreground window thread. Windows accepted the target only after the caller
  was also attached to the exact RustDesk target UI thread and used
  `BringWindowToTop`, `SetActiveWindow`, `SetFocus`, and `SetForegroundWindow`.
- Mandatory preflight: resolve exactly one RustDesk process by pinned title,
  require the verified full-screen bounds, obtain both foreground and target
  UI thread IDs, attach the caller to both when distinct, and verify the exact
  target handle is foreground before emitting any key, click, or clipboard
  command. A process-name or title match alone is insufficient.
- Recovery: record that the failed attempt sent zero remote input, update the
  draft control helper to attach and detach both threads inside `try/finally`,
  preserve the no-resize/no-minimize rule, run wrapper/harness validation, and
  forward-test the focus-only path before one exact hostname-gated action.

## 2026-08-26 — RustDesk foreground does not prove synthetic keys entered its capture path

- Failure signature: the exact RustDesk frame was foreground, active, focused,
  childless, and at the verified full-screen bounds, but the hostname clipboard
  sentinel never changed. RustDesk's current connection log recorded the
  sentinel clipboard update and no corresponding Escape, Ctrl+Escape, text, or
  Enter key events.
- Cause: `SetForegroundWindow` and GUI-thread focus prove only Win32 focus. The
  RustDesk client converts events from its own local keyboard-capture path into
  remote key messages; Windows-synthetic `SendKeys`/`keybd_event` events were
  not captured in this session.
- Mandatory preflight: after a focus-only proof, correlate the exact attempt
  time with the bounded RustDesk connection log. Require the expected key-event
  rows before treating GUI input as delivered. If the clipboard changes but no
  attempt keys appear, stop before retry and inventory an already-established
  non-GUI management tunnel instead.
- Recovery: preserve the unchanged sentinel and no-command proof, do not add
  longer sleeps or repeat keyboard input, and qualify the existing fixed
  RustDesk WinRM port-forward as a separate read-only capability. Never guess,
  extract, or persist credentials to make the tunnel usable.

## 2026-08-26 — A listening RustDesk port-forward does not prove an upstream route

- Failure signature: the existing RustDesk `--port-forward` process owned the
  expected local listening port, but had no persistent upstream connection.
  WS-Man Identify returned HTTP error `12152`, and a header-only HTTP probe
  received an empty reply.
- Cause: a long-lived local listener can survive the interactive RustDesk
  connection that authenticated or routed it. Local `LISTEN` state proves only
  that the client process accepted the socket; it does not prove gateway or
  target reachability.
- Mandatory preflight: pin the exact RustDesk executable hash, peer, local and
  target ports, process command line, and creation time. Require both the exact
  new listener and a valid protocol-level response before granting the tunnel
  any read-only remote-command capability.
- Recovery: preserve the stale listener, refuse to recycle or overwrite its
  port, create at most one fresh listener on a new exact port, and track its
  exact PID/command line. If protocol validation fails, stop only the process
  created by that attempt and leave every predecessor listener untouched.

### A direct-control skill is incomplete when it omits the separate listener state

- Failure signature: a prior session had established a RustDesk management
  listener, but the next session treated the nested desktop-input helper as
  the complete transport and began debugging GUI injection without first
  inventorying that listener. The operator correctly reported that the prior
  listener window was no longer visible.
- Cause: the durable skill documented only the interactive RustDesk/RDP input
  path and explicitly created no listener. It did not require a task-start
  inventory of the separate background port-forward or candidate console
  listener, so session-scoped transport state was lost from the workflow.
- Mandatory preflight: before remote input or tunnel recovery, run the bounded
  control-transport inventory. Record matching RustDesk forward PIDs, creation
  times, listener ownership, candidate PowerShell/Python listeners, and—when
  the exact read-only authority permits it—a protocol-level WS-Man Identify.
- Recovery: classify the desktop chain and management listener separately.
  Never call a listener absent from window appearance alone, and never call it
  healthy from local `LISTEN` alone. Restore a failed listener only through a
  governed one-attempt action; do not compensate with repeated GUI input.

## 2026-08-26 — Tunnel success must include protocol validation inside rollback

- Failure signature: a frozen tunnel launcher passed its non-mutating
  preflight and could prove one new process/listener, but its success path did
  not execute the protocol-level WS-Man Identify check promised by the
  pre-action contract.
- Cause: listener/process cardinality was implemented as the terminal success
  boundary while protocol health remained a later caller responsibility. That
  made the declaration broader than the atomic implementation and could leave
  a useless process after a nominal pass.
- Mandatory preflight: mechanically trace every declared terminal predicate to
  code inside the same `try/catch` rollback boundary. For a tunnel, require
  exact process, exact listener owner, and valid protocol response before PASS.
- Recovery: stop before Apply, withdraw the frozen launcher, preserve its
  no-mutation proof, and create a fresh launcher namespace. The successor must
  run WS-Man Identify before PASS and stop only its newly created PID if that
  validation fails.

## 2026-08-26 — A multiline clipboard payload is not a safe result sentinel

- Failure signature: the Argos hostname gate passed and the pinned multiline
  observation source was placed on the shared clipboard, but the runner's
  `value != originalPayload` predicate returned that source text as though it
  were result JSON; `ConvertFrom-Json` then failed at `CmdletBinding`.
- Cause: RustDesk/RDP clipboard propagation may round-trip or normalize a
  multiline source representation before the remote command replaces it. Byte
  or string inequality against the original source is not a result-ready
  predicate.
- Mandatory preflight: for an in-memory clipboard payload, accept a response
  only when it begins with the expected serialized container and contains the
  exact result schema/state. A payload-transfer acknowledgement and a result
  readiness predicate are separate gates; neither may be inferred from local
  clipboard assignment.
- Recovery: do not retry the frozen action. Preserve the original payload and
  parser failure, create a fresh action namespace, require exact schema-shaped
  result readiness, and make the remote observer return bounded structured
  failure rows instead of leaving source text on the clipboard.

## 2026-08-26 — Generic Argos visibility does not prove protected portal readability

- Failure signature: the ordinary Argos current-layer inventory verified
  `DESKTOP-266P787` and returned legacy task/window rows, but the bounded portal
  observation terminated with operator-visible `Access denied` before it could
  return config, worker-hash, or queue evidence.
- Cause: the visible `lwm` RDP token can observe ordinary desktop state while
  one or more protected `C:\ProgramData\ArgosProjectPortalRO` sources remain
  inaccessible. A successful hostname or generic task inventory is not an
  administrative-read proof.
- Mandatory preflight: a portal observer must isolate every task, config, bin,
  connection, and queue read inside its own bounded failure boundary and return
  the exact denied source as structured evidence. Route health cannot pass when
  any required source is denied, missing, truncated, or unparsable.
- Recovery: remain in the non-mutating lane, return partial readable evidence
  plus exact access errors, and require an already-authorized administrative
  read route for any protected source. Never respond to `Access denied` by
  changing ACLs, creating a helper task, guessing credentials, or silently
  elevating the desktop process.

## 2026-08-26 — Windows PowerShell 5.1 generic lists require explicit ToArray

- Failure signature: a parser-clean, harness-clean read-only payload completed
  every bounded source section, then Windows PowerShell 5.1 threw `Argument
  types do not match` at `@($genericList)` during final result construction.
- Cause: array-subexpression enumeration of a closed generic `List[object]` is
  not reliable in the exact Windows PowerShell 5.1 host even though ordinary
  pipeline collections behave correctly.
- Mandatory preflight: execute final result construction in Windows PowerShell
  5.1 and convert generic evidence lists with their explicit `.ToArray()`
  method before count, filtering, or JSON serialization. Parser and static
  harness success do not prove this runtime boundary.
- Recovery: while the payload remains draft and unexecuted on the target,
  replace the generic-list array subexpression with `@($list.ToArray())`,
  update every exact dependent hash, and repeat the full no-clipboard local
  execution rehearsal before freeze.

## 2026-08-26 — A visible error console is not proof of a reusable command prompt

- Failure signature: after an earlier Argos observer displayed an error, a
  fresh read-only successor tried to reuse that visible PowerShell window. Its
  exact `hostname | clip` identity gate timed out after 30 seconds, so the
  successor payload was never transferred or invoked.
- Cause: a console can remain visible while it is in selection mode, running a
  predecessor, closed behind another surface, or otherwise not accepting
  commands at its prompt. Visibility and prior command success do not prove
  current prompt readiness.
- Mandatory preflight: every reuse-existing-console action must first obtain
  the exact expected hostname through a short bounded command and a
  schema-shaped clipboard response. Treat timeout, unchanged clipboard, or a
  mismatched hostname as a terminal local focus/prompt failure before payload
  transfer.
- Recovery: do not repeat input into the same presumed prompt and do not type
  the payload after the identity timeout. Preserve `payloadTransferred=false`,
  remain non-mutating, and require an operator-confirmed usable prompt at the
  exact required privilege level or a separately qualified non-GUI route.

## 2026-08-26 — Do not regress a proven short clipboard-paste gate to synthetic text typing

- Failure signature: the one-attempt Argos administrative observer timed out
  at its first hostname gate even though the preceding current-layer observer
  had delivered that same short gate through clipboard paste. The withdrawn
  successor instead emitted the command characters with `SendKeys`.
- Cause: the successor changed the already demonstrated transport primitive
  while cloning the observer. A short command is not safe merely because its
  character count is bounded; RustDesk can accept clipboard paste while
  dropping or misrouting individually synthesized text keys.
- Mandatory preflight: mechanically assert that the exact hostname command is
  placed on the clipboard and delivered only by the bounded paste primitive.
  Keep the observation source on the clipboard and type only the fixed
  11-character `iex(gcb -r)` trigger. Require create-new structured evidence
  for every local or remote failure stage before authorizing the attempt.
- Recovery: withdraw the executed runner without retry, preserve its
  `payloadTransferred=false` evidence, and use a fresh namespace whose local
  Windows PowerShell 5.1 transport test proves the clipboard-paste hostname
  path, short trigger, parser validity, and structured stage-failure output.

## 2026-08-26 — The persistent InspectionRevs U mapping is infrastructure, not cleanup

- Failure signature: each portal publication rediscovers the engineering
  share's over-budget UNC path because an earlier publisher removed the known
  good short `U:` mapping in its normal or failure cleanup.
- Cause: the exact persistent mapping was incorrectly treated as temporary
  process state even though later Argos work repeatedly requires the same
  verified `InspectionRevs` root and the raw UNC leaf exceeds the safe path
  budget.
- Mandatory preflight: require `Get-PSDrive U` `DisplayRoot` and the Windows
  logical-disk `ProviderName` to equal the frozen `InspectionRevs` UNC root.
  If absent, create the mapping once with `New-PSDrive -Persist`, verify it
  through both views, and path-gate the exact final and upload leaves. If it
  maps anywhere else, stop for explicit authority; never silently replace it.
- Recovery: leave the verified persistent `U:` mapping in place across
  publication, collection, rehearsal, success, and failure. Publishers and
  their `finally` or cleanup blocks may remove only their own exact create-new
  temporary file, never the `U:` drive. Removing or repurposing `U:` requires
  a separate explicitly authorized infrastructure action.

## 2026-08-26 — Portal endpoint and response sender health do not prove the request receiver

- Failure signature: the exact O2D10 request was accepted by the gateway and
  queued at Argos `to_jbod\pending`, while the Argos sender remained in
  `SYN_SENT` to JBOD port `48716`. On JBOD, the endpoint and response-sender
  scheduled tasks were both running, but
  `ArgosProjectPortal.JBOD.RequestReceiver.RO` was `Ready`, its last result was
  `1`, its receiver process was absent, and no process listened on `48716`.
- Cause: route preflight treated the endpoint and response-return components as
  sufficient portal health and did not independently require the inbound
  request-receiver task, process, and listening socket. The three portal roles
  have separate liveness boundaries.
- Mandatory preflight: before publishing a portal request, pin and verify the
  exact endpoint, request-receiver, and response-sender task identities,
  principals, installed dependency hashes, process cardinalities, and required
  listening sockets. A running endpoint or response sender must never stand in
  for a missing request receiver.
- Recovery: after direct read-only observation pins the failed receiver and the
  unchanged dependencies, start only the exact existing pinned request-receiver
  task once. Require its task, process, and `48716` listener to become healthy,
  prove the healthy wafer processor and the other two portal roles unchanged,
  and allow the already queued request to continue without republishing or
  retrying it. If the one start does not pass, stop and observe; never restart
  other tasks or issue a second start.

## 2026-08-26 — CIM process creation timestamps must retain full source precision

- Failure signature: a frozen receiver-recovery precondition compared the
  healthy processor creation time recorded by earlier JSON as
  `2026-08-25T15:38:27.716Z` with the live CIM value
  `2026-08-25T15:38:27.7160450Z` and stopped before its first task action.
- Cause: the observation record shortened the CIM timestamp to milliseconds.
  Process identity pins require the full source precision; millisecond JSON
  display is not an exact substitute for the originating CIM value.
- Mandatory preflight: normalize `Win32_Process.CreationDate` to UTC with the
  round-trip `o` format and freeze every retained fractional digit before
  comparing process identity. Assert the full normalized string or parsed
  instant derived from that exact string, not a manually shortened timestamp.
- Recovery: preserve the no-mutation terminal evidence, withdraw only the
  failed frozen recovery revision, create a fresh namespace with the full CIM
  timestamp, rerun clone, wrapper, harness, intent, and zero-recurrence gates,
  then make at most the still-authorized single task-start attempt.

## 2026-08-26 — Process cardinality must match the selector, not the task tree

- Failure signature: the receiver recovery filtered command lines for literal
  endpoint or sender config names, correctly observed two matching resident
  processes, but failed because its contract expected three rows copied from a
  broader earlier inventory. The task-host wrapper carries its config in
  base64 and does not match that literal selector.
- Cause: expected cardinalities were inherited from a different process
  predicate instead of being derived from the exact predicate in the action.
- Mandatory preflight: freeze selector and cardinality together. For the exact
  literal-config selector, require two unchanged resident endpoint/sender
  processes before and after, and one receiver executable owning port `48716`.
- Recovery: preserve the verified zero-start evidence, create a fresh payload
  namespace changing only those two proven cardinalities, and rerun the exact
  static gates before the still-unused single start attempt.

## 2026-08-26 — Advanced-script parameter defaults cannot depend on PSScriptRoot under Windows PowerShell 5.1 -File

- Failure signature: the signed O2D10 maintenance entry point passed its local
  rehearsal whenever `-PayloadRoot` was supplied explicitly, but the installed
  endpoint launched the same frozen bytes with Windows PowerShell 5.1 `-File`
  and no arguments. `Join-Path $PayloadRoot ...` then failed immediately with
  `Cannot bind argument to parameter 'Path' because it is an empty string.`
- Cause: for an advanced script containing `[CmdletBinding()]`, a parameter
  default such as `[string]$PayloadRoot = $PSScriptRoot` is evaluated before
  `$PSScriptRoot` is populated when the script is the direct `-File` target.
  The script body later sees a populated `$PSScriptRoot`, but the already-bound
  parameter remains empty. The rehearsal concealed this host boundary by
  always supplying a nonempty `-PayloadRoot` override.
- Mandatory preflight: every changed or relied-upon entry point that the
  installed consumer launches without arguments must be exercised as the
  direct target of the consumer's exact Windows PowerShell 5.1 `-File`
  invocation with the exact omitted-argument shape. Script-root-derived
  defaults must be assigned after the `param` block, for example by accepting
  an empty parameter and setting it from `$PSScriptRoot` in the script body.
  An explicit-override rehearsal is a separate case and cannot substitute for
  the no-argument installed invocation.
- Recovery: retain the signed O2D10 failure as terminal evidence and never
  patch or retry its frozen namespace. A fresh successor must change only the
  draft entry-point root initialization first, add both exact no-argument
  `-File` and explicit-override Windows PowerShell 5.1 controls, preserve all
  review-only and processor invariants, and pass the full publication gates
  before any separately authorized successor request.

## 2026-08-26 — Cast byte arrays at overloaded .NET `ComputeHash` calls

- Failure signature: a draft Windows PowerShell 5.1 response collector reached
  an in-memory SHA-256 check and reported `Multiple ambiguous overloads found
  for ComputeHash and the argument count: 1`.
- Cause: the advanced function parameter was declared `[byte[]]`, but the
  PowerShell method binder still saw an ambiguous argument at the overloaded
  .NET call boundary. A zero-length ZIP entry can also collapse to `$null`
  when returned through the PowerShell pipeline.
- Mandatory preflight: call `ComputeHash([byte[]]$Bytes)` explicitly for
  in-memory response entries, normalize `$null` from a zero-length entry to
  `[byte[]]::new(0)`, and exercise the collector's exact `-Preflight` before it
  creates its collection root.
- Recovery: because the collector was an unexecuted `DRAFT` and created no
  output, add the explicit cast, rerun harness safety and exact preflight, then
  retain the same collection namespace.

## 2026-08-26 — Recovery capability evidence must be the route inventory

- Failure signature: a draft `OBSERVE` recovery intent pointed
  `route.capabilityEvidence` at a worker-inheritance gate. The recovery-intent
  preflight stopped with `The property 'routes' cannot be found on this
  object` before request construction or publication.
- Cause: the pinned file proved inheritance but did not implement the required
  `argos_endpoint_read_only_capability_inventory_v1` schema with one `routes`
  row for the declared route type.
- Mandatory preflight: for `STATUS`, `DATA_PULL`, or
  `DIRECT_ADMIN_READ_ONLY`, pin the exact endpoint read-only capability
  inventory as `route.capabilityEvidence`; pin worker inheritance and current
  route health separately. Require exactly one row matching `route.type` and
  request only capabilities enumerated by that row.
- Recovery: while the intent is still `DRAFT` and no request bytes or external
  mutation exist, replace only the incorrect capability-evidence pin and align
  `requestedCapabilities` to the inventory, then rerun the exact recovery
  preflight.

## 2026-08-26 — PowerShell keyword and expression token boundaries are mandatory

- Failure signature: a draft response collector passed AST/harness safety but
  its exact non-mutating preflight stopped at `return$Path.Replace(...)` with
  `The term 'return$Path.Replace' is not recognized` before creating output.
- Cause: the `return` keyword and following expression were concatenated into
  one command token. The general harness parser accepted the source because it
  was syntactically valid PowerShell, but it was not the intended runtime
  expression.
- Mandatory preflight: require whitespace after `return` and `throw`, and
  inspect compact generated functions for `return$`, `throw"`, or equivalent
  keyword/expression adjacency before running them. The exact script
  `-Preflight` remains mandatory because AST parsing alone cannot prove the
  intended command tokenization.
- Recovery: when the collector remains `DRAFT` and preflight created no output,
  correct only the token boundary, refresh its exact preaction dependency pin,
  rerun harness and clone-remediation gates, and rerun the same non-mutating
  preflight before collection.

## 2026-08-26 — Validate installed identity folders by exact full identity suffix

- Failure signature: a draft Slot17 response collector correctly read the
  signed proposal but rejected its oriented-input paths because it expected a
  directory segment named only `Slot17`. The installed directory is the exact
  physical identity `62619-433_20260824005735_Slot17`.
- Cause: the path assertion shortened an authoritative compound identity into
  a display-slot label that is not an actual filesystem component.
- Mandatory preflight: derive the exact expected proposal directory from the
  frozen physical identity and assert the complete identity plus channel leaf.
  Never replace a compound acquisition identity with its trailing slot label
  when validating installed paths.
- Recovery: while the collector remains `DRAFT` and has created no output,
  correct only the exact suffix assertion, refresh the preaction dependency
  pin, and rerun the non-mutating collector preflight.

## 2026-08-26 — Do not name helper functions after built-in PowerShell aliases

- Failure signature: a draft collector defined a one-letter `H` hash helper,
  but the exact preflight resolved the built-in `h`/`Get-History` alias first
  and attempted to bind a file path to `Get-History -Id`.
- Cause: PowerShell command precedence gives aliases priority over functions;
  case does not disambiguate them.
- Mandatory preflight: use descriptive, project-specific helper names and run
  `Get-Command` for every compact helper token before execution. Prohibit
  one-letter helper names in Windows/JBOD harnesses.
- Recovery: while the collector is still `DRAFT` and created no output, rename
  only the colliding helper, refresh the preaction dependency pin, rerun harness
  safety, and rerun the exact non-mutating preflight.

## 2026-08-26 — Clone remediation must represent a verified zero-root pair

- Failure signature: clone-remediation preflight rejected a bounded cloned
  Python engine/harness pair with `Clone-remediation pair has no root rules`
  even though the utility's own literal-root scanner found zero drive and UNC
  roots in both source and generated files.
- Cause: the manifest schema and checker had dispositions for replaced,
  unchanged, and added roots, but no explicit representation for the valid
  zero-root case. An empty rule set was rejected before the scanner result
  could become evidence.
- Mandatory preflight: declare one `NO_LITERAL_ROOTS` rule with empty source
  and generated roots. The checker must accept it only when its exact scanner
  finds zero literal roots in both files; any discovered root fails the gate.
- Recovery: while the cloned files remain local `DRAFT` bytes and no image or
  external target was read or changed, add the explicit zero-root disposition,
  rerun clone-remediation preflight, and write a create-new gate before running
  either cloned harness.

## 2026-08-26 — Automatic scribe localization must rank OCR-scale bands

- Failure signature: the first V1R4 automatic-localization positive gate found
  twelve diagnostic regions and promoted four, while every promoted region was
  too narrow for a twelve-cell grid. The reader therefore returned
  `NOT_EVALUATED`; the unchanged recognition corpus still passed 15/15 and all
  four duplicate-agreement groups passed.
- Cause: diagnostic regions were ranked only by mean morphology response.
  Short high-contrast strokes outranked the two broad scribe-band candidates,
  and the promoted rectangle was not expanded to the reader's frozen
  twelve-cell working envelope.
- Mandatory preflight: an automatic-localization positive control must include
  multiple short high-response distractors and a lower-response OCR-scale band.
  Promotion must require and prioritize configured minimum band width, expand
  only into a bounded configured OCR envelope, and prove the reader evaluates
  at least one promoted region. The locked 15/15 recognition and 4/4 duplicate
  gates remain mandatory.
- Recovery: retain V1R4 and its failed gate as `WITHDRAWN` local evidence. Use
  fresh V1R5 bytes to change only development-only candidate eligibility,
  ranking, and bounded OCR-envelope expansion; do not alter R3 recognition
  thresholds, direct-input behavior, identity eligibility, holds, or authority.

## 2026-08-26 — Alias-path rehearsals must stage metadata from canonical paths

- Failure signature: the first local O2D14 rehearsal stopped while building
  its file-backed job because `Get-Item X:\BF.png` ran before the endpoint had
  created the temporary `X:` alias.
- Cause: the harness correctly wrote `X:` as the provider-facing source path,
  but incorrectly reused that not-yet-materialized path to calculate the
  staged source byte count.
- Mandatory preflight: when a rehearsal tests endpoint-owned alias creation,
  construct hashes and byte counts from the exact canonical rehearsal files;
  reserve the alias path only for the provider-facing job. Assert the alias is
  absent before entrypoint execution and absent again afterward.
- Recovery: because the draft harness failed before invoking the endpoint and
  its `finally` block removed the bounded rehearsal root, correct only the two
  metadata dereferences, refresh the harness/clone/preaction hashes, and rerun
  the same rehearsal. No product revision or external retry is required.

## 2026-08-26 — Scribe entrypoint rehearsal must prove the reader evaluated

- Failure signature: an O2D14 local entrypoint gate reported `PASS` for alias,
  failure-before-write, hold, and processor invariants while its normal result
  was `SCRIBE_LOCALIZATION_HOLD`, `imageFirstString` was empty, and checksum
  evaluation never occurred.
- Cause: the gate asserted safety mechanics and hold preservation but omitted
  an explicit positive OCR-evaluation assertion; its inherited sample was not
  the V1R5 automatic-localization positive control.
- Mandatory preflight: the entrypoint rehearsal must use a hash-pinned positive
  control that exercises the exact development auto-localization mode and must
  require a promoted region, nonempty image-first string, and checksum state
  other than `NOT_EVALUATED`, in addition to all safety invariants.
- Recovery: withdraw the mechanically insufficient V1 local gate, retain the
  unbuilt/unpublished O2D14 product namespace, strengthen only the test harness,
  and write a create-new R2 gate. The final builder must pin only the R2 gate.

## 2026-08-26 — Signed maintenance declarations must name the exact final rehearsal gate

- Failure signature: the signed but unpublished O2D14 maintenance definition
  declared `PASS_O2D14_ENTRYPOINT_TEST_GATE_R2`, while the final package gate
  relied on the later exact-endpoint R3 rehearsal. The R3 gate was the correct
  execution evidence, but the signed declaration still named its predecessor.
- Cause: the package builder was updated to pin the create-new R3 gate without
  mechanically requiring the maintenance definition's declared gate state and
  evidence hash to equal that same final rehearsal artifact.
- Mandatory preflight: before signing, require one exact rehearsal identity in
  the maintenance definition, builder inputs, extracted request manifest, and
  final package gate. Assert the gate state and SHA-256 in all four locations;
  a pass from an older endpoint revision is not interchangeable evidence.
- Recovery: do not publish or reuse the signed O2D14 request. Record it as
  `WITHDRAWN`, retain its hashes as local evidence, and build the same bounded
  Slot19 raw-source read in a fresh O2D15 namespace only after the exact final
  rehearsal declaration is corrected and mechanically cross-checked.

## 2026-08-26 — Artifact withdrawal is not recovery premise-failure evidence

- Failure signature: a draft O2D15 recovery intent counted the withdrawn
  O2D14 package declaration mismatch as a third local premise failure and used
  the unsupported failure-evidence state `WITHDRAWN`.
- Cause: artifact lifecycle evidence and recovery premise failures were merged
  into one array even though the recovery guard accepts only signed failures or
  qualified withdrawn local rehearsal failures in that count.
- Mandatory preflight: keep withdrawn package evidence in a separate metadata
  field with `countsAsPremiseFailure=false`; require the declared signed and
  local premise counts to equal only guard-supported failure classifications.
- Recovery: the intent was still `DRAFT` and the guard performed no mutation.
  Remove the package withdrawal from `failureEvidence`, restore the exact local
  premise count, preserve it separately, and rerun the same preflight.

## 2026-08-26 — Maintenance `installedSha256` must equal the exact payload source hash

- Failure signature: the matching signed O2D15 response failed before the
  entrypoint with `Maintenance source hash mismatch:
  payload/Invoke-O2D15ScribeEndpoint.ps1`. The extracted signed manifest
  declared `changes[0].installedSha256` as O2D14's endpoint hash
  `29EAE036...`, while the exact O2D15 payload hash was `748C9DCB...`.
- Cause: the fresh namespace changed the endpoint bytes, but the mechanically
  cloned maintenance definition retained its predecessor `installedSha256`.
  The builder pinned both the definition and endpoint independently without
  asserting that the definition's one installed hash equaled `$endpointSha`.
- Mandatory preflight: before signing, require exactly one change record and
  mechanically assert its normalized source path, destination, predecessor
  set, and `installedSha256 == endpointSha`. Repeat the same equality against
  the extracted signed manifest and record both values in the final gate. An
  endpoint rehearsal cannot substitute for this maintenance-verifier contract.
- Recovery: collect the compact signed terminal failure, retain O2D15 as
  executed terminal evidence only, and never retry it. No entrypoint, image
  read, processor/provider action, source/wafer mutation, or hold clearance
  occurred. This is the second signed premise failure in the Slot19 incident,
  so mutation stop-loss is active until a file-backed workflow review and a
  fresh recovery intent explicitly clear it for one new namespace.

## 2026-08-26 — Live-only endpoint self-pins must be exercised before signing

- Failure signature: the matching signed O2D16 response failed before alias
  creation or any source read with `O2D16 live job changed.` The packaged job
  SHA-256 was `146C2E2A...`, but the endpoint hard-coded the predecessor job
  SHA-256 `D14E47EF...`. The local entrypoint rehearsal passed because its
  `-Rehearsal` branch deliberately skipped both live job and installed-runtime
  hash assertions.
- Cause: the final package gate compared the payload and signed maintenance
  declaration but did not mechanically compare every endpoint self-pin with
  the exact packaged dependency. The only execution test used a branch that
  bypassed the failing live-only assertions.
- Mandatory preflight: inventory every hash literal and live-only assertion in
  the exact packaged endpoint. Require each payload self-pin to equal the exact
  packaged file hash and each installed-state self-pin to equal qualified
  installed evidence. Exercise the live assertion branch against bounded
  fixtures before signing; a rehearsal branch that skips an assertion cannot
  prove it. Record the endpoint constant, computed hash, and branch coverage in
  a machine-readable gate.
- Recovery: retain O2D16 as executed terminal evidence and never retry it.
  Collect the exact signed response, pin a direct post-failure observation, and
  activate the third-premise-failure mutation stop-loss. No successor may be
  built or published until a file-backed workflow review and fresh recovery
  intent explicitly clear one new namespace with the live self-pin gate.

## 2026-08-26 — Exact response collection must accept portal correlation suffixes

- Failure signature: the legacy bulk response receiver rejected the exact
  signed response leaf
  `R_43B046749202_20260826234809840_3bbc13fa.ready.zip` as an unexpected
  filename even though its request ID, response signature, source role, and ZIP
  hash matched the pending request.
- Cause: the receiver's filename regular expression predates the portal's
  current `_xxxxxxxx` correlation suffix. Filename parsing failed before the
  response-package signature verifier could evaluate the selected archive.
- Mandatory preflight: enumerate the exact selected response leaf and test its
  current naming shape before invoking a collector. Select by pinned request
  identity and exact ZIP SHA-256, extract only that archive to a fresh bounded
  root, and let the signed manifest establish response identity. Do not use a
  bulk legacy filename parser as the identity authority.
- Recovery: do not retry the request or the incompatible bulk import. Preserve
  the rejected collector invocation as local diagnostic evidence, run an
  exact-ZIP signature-first collection under a fresh invocation/preaction, and
  remove only the explicit temporary C: staging root after the collected copy
  and its hash are verified.

## 2026-08-26 — Caller timeout must cover the endpoint rehearsal ceiling

- Failure signature: the O2D19 local endpoint rehearsal remained active after
  the invoking command envelope expired at about 124 seconds. Its pinned
  portable Python child was still consuming CPU, the test root still existed,
  and no gate had yet been written. The unchanged endpoint itself correctly
  retained its independent 600-second child timeout and later completed with a
  PASS gate and bounded-root cleanup.
- Cause: the caller timeout was 120 seconds even though the exact endpoint
  contract permits up to 600 seconds plus harness setup, injected-failure
  coverage, and cleanup. Expiry detached the still-valid Windows PowerShell
  process instead of proving an endpoint failure.
- Mandatory preflight: for an exact endpoint rehearsal, set the caller envelope
  above the endpoint child ceiling with explicit setup/cleanup reserve (at
  least 720 seconds for a 600-second child), or retain the yielded command cell
  and observe it in bounded intervals. If a caller expires first, inventory
  only the exact parent/child identities, bounded test root, CPU progress, and
  gate state; do not launch a duplicate, kill an active bounded child, or call
  the run failed while its own timeout remains in force.
- Recovery: O2D19 was still DRAFT and had performed no external mutation,
  signing, publication, or current Slot21 image read. The exact active run was
  observed through completion, its parent and child exited, its test root was
  removed, and `O2D19_ENTRYPOINT_TEST_GATE_R2.json` recorded PASS. No retry was
  performed and no new product namespace was required.

## 2026-08-26 — Ordered clone replacements must preserve parent evidence

- Failure signature: the draft O2D19 builder paired the O2D18 parent response
  hash with an impossible O2D19 terminal-response path and expected the O2D19
  Slot21 terminal state before O2D19 had been built. No build, signature, or
  publication had occurred when bounded source inspection found the mismatch.
- Cause: the generator first changed the O2D17 parent reference to O2D18, then
  a later broad O2D18-to-O2D19 token replacement transformed that already
  corrected parent reference a second time. Literal-root classification could
  not detect the semantically wrong evidence generation.
- Mandatory preflight: apply broad product-token replacement before explicit
  parent-evidence replacement, then assert the parent path, hash, terminal
  state, slot, and generation as one tuple. The parent generation must be
  exactly one less than the successor and its terminal artifact must already
  exist. A matching hash alone is insufficient when path or state was
  mechanically advanced.
- Recovery: correct the still-DRAFT generator ordering and builder tuple in
  place, rerun exact wrapper, harness, clone, and dependency gates, and bind
  the O2D18 Slot20 signed terminal response as O2D19's sole development parent.

## 2026-08-27 — Context searches on ordered slot inventories can expose the next slot

- Failure signature: a text-only query intended to reveal only frozen OLS6
  Slot24 source metadata used `rg -C 18` against the multi-slot JSON inventory.
  The after-context crossed the Slot24 record boundary and emitted the adjacent
  Slot25 path, byte count, timestamp, and SHA-256 before Slot24 was terminal.
- Cause: line-oriented context around a match is not a record boundary. The
  query bounded file scope but did not bound the selected JSON object identity.
- Mandatory preflight: reveal sequential slot metadata only by parsing the
  frozen JSON and selecting the exact requested `slot` plus the exact BF/DF
  channel set. Require exactly two selected records and serialize only those
  records. Do not use `rg -C`, `Select-String -Context`, line ranges, or tail
  output against a multi-slot inventory for an unseen-slot reveal.
- Recovery: no image bytes, pixels, OCR output, candidate result, or tuning
  evidence was read, and no filesystem or external state was mutated. Preserve
  the frozen engine and no-tuning rule, disclose that Slot25 source metadata is
  prematurely exposed, and never again describe Slot25 as wholly unseen. Slot24
  may continue under its unchanged frozen contract. Treat Slot25 outcome and
  image content as still blind; before counting Slot25 as the fourth sequential
  blind-validation member, require a file-backed workflow review that explicitly
  addresses the metadata-only early exposure.

## 2026-08-27 — Wrapper-manifest compatibility must pass before publisher freeze

- Failure signature: the first O2D22 one-shot publisher was committed and
  pushed in commit `1e33325` before its direct Windows PowerShell 5.1 wrapper
  gate was constructed. Static inspection then proved that the frozen script
  did not declare `InvocationManifest`, so the mandatory file-backed invocation
  contract could not be supplied to `Confirm-ArgosPowerShellWrapper.ps1`.
- Cause: harness safety, clone-literal safety, and the publication pre-action
  were treated as sufficient publisher freeze gates. The separate wrapper
  safety contract was deferred until immediately before execution, after the
  publisher and checkpoint had already crossed the repository publication
  boundary.
- Mandatory preflight: before committing, freezing, signing, or publishing any
  new or changed publisher/collector/operator entrypoint, require its bounded
  UTF-8 invocation manifest, require the script to declare and validate the
  exact `InvocationManifest`, create the canonical fixed-argument `.cmd`
  wrapper when applicable, and run `Confirm-ArgosPowerShellWrapper.ps1` against
  all three exact files. Only then may the checkpoint pin the entrypoint.
- Recovery: the first publisher was never executed and no portal, JBOD, image,
  provider, task, processor, source, wafer, or hold state changed. Preserve it
  as non-reusable evidence, supersede its provisional publication-ready
  checkpoint, create a fresh `Publish-O2D22R2` namespace from the qualified
  O2D21 source rather than from the rejected publisher, and repeat clone,
  harness, wrapper, pre-action, continuity, commit/push, and exact preflight
  gates before the sole authorized publication.

## 2026-08-27 — Checkpoint filenames are part of the pre-launch path budget

- Failure signature: the uncommitted O2D22 R2 publisher path preflight rejected
  the provisional checkpoint
  `OCV02_O2D22_COMPLETE_ROUTE_PASS_SLOT24_BLIND_PUBLICATION_READY_R2_CHECKPOINT_20260827.md`.
  Its filename component was 88 characters and its laptop path had effective
  length 209 with the required 32-character suffix reserve.
- Cause: the request/route paths and short `U:` alias had been gated, but the
  newly created continuity-checkpoint filename was not included before its
  first write. Descriptive checkpoint naming crossed the mandatory 80-character
  component limit even though no portal path was long.
- Mandatory preflight: construct every proposed checkpoint, invocation,
  publisher, gate, local evidence, share, processed, response, and extraction
  path before creating any of them. Run `Confirm-ArgosPathBudget.ps1` with the
  real suffix reserve, reject any component longer than 80, and prefer a short
  stable checkpoint name whose detailed scope lives inside the file.
- Recovery: no entrypoint launched and no external state changed. The R2 files
  remained uncommitted DRAFT bytes, so replace the provisional checkpoint with
  a short path, update every exact path/hash pin, retain the failed path-gate
  output only in task commentary, and rerun clone, harness, wrapper, path,
  pre-action, continuity, and clean-tip gates before publication.

## 2026-08-27 — The task-rollover hook is an event consumer, not a no-argument status command

- Failure signature: manually invoking
  `py -3 .codex\hooks\argos_task_rollover.py` returned
  `ARGOS_AUTOMATIC_ROLLOVER_GUARD_ERROR: Expecting value: line 1 column 1
  (char 0)` instead of a task-size measurement.
- Cause: the normal hook path calls `json.load(sys.stdin)` and requires the
  Codex hook event object. The no-argument command omitted that event entirely;
  the script has no standalone status mode. Its argument-only mode is reserved
  for recording an already completed handoff with `--complete-handoff`.
- Mandatory preflight: inspect the hook interface before a manual invocation.
  For an ordinary measurement, supply one valid bounded JSON hook event with
  the exact current `session_id`, project `cwd`, event name, and any known
  transcript path. Prefer reading the state already written by the automatic
  SessionStart/Stop hooks when only status is needed. Never invoke the hook
  without either a hook event on standard input or the complete handoff
  argument set.
- Recovery: the empty-input invocation changed no repository, portal, JBOD,
  image, processor, source, wafer, hold, or provider state. Read the exact
  current rollover state first; if a new measurement is necessary, send one
  correctly formed event and use its machine-readable result before starting
  another atomic operation.

## 2026-08-27 — Verify rollover-state creation immediately after a task handoff

- Failure signature: the predecessor task recorded a completed handoff to
  task `01a04125-ad32-7b93-8f45-2e634cd38120` at commit `b4cd1e5`, but the new
  task had no matching file under `.git/codex/argos-task-rollover` after five
  repository commits and 5,961 cumulative changed lines.
- Cause: the expected SessionStart state write was absent. A later ordinary
  hook event would therefore initialize its baseline from the current `HEAD`
  and incorrectly exclude all work already completed in the new task.
- Mandatory preflight: immediately after every completed handoff, require the
  new task's exact rollover-state file to exist and require its
  `baselineCommit` to equal the predecessor handoff's exact `commit` and
  `remoteTip` before making the first repository change. A missing or different
  baseline is a hard stop; never let a delayed hook silently rebase the count.
- Recovery: use only the predecessor's machine-recorded completed handoff to
  reconstruct the missing metadata-only state for the exact new task ID and
  baseline, then send one valid bounded SessionStart event and verify its
  measurement against `git diff` from that baseline. Do not infer the baseline
  from chat history or initialize it from the later current `HEAD`.

## 2026-08-27 — Windows PowerShell may not mount the `Cert:` provider in an exact script invocation

- Failure signature: the O2D23 signed-request builder passed its dependency,
  clone, path, and zero-recurrence checks, then its non-mutating Windows
  PowerShell 5.1 preflight failed at `Get-Item Cert:\CurrentUser\My\...` with
  `Cannot find drive. A drive with the name 'Cert' does not exist.` No signed,
  partial, final, ZIP, or package-gate path existed afterward.
- Cause: the exact clean Windows PowerShell script invocation did not mount the
  certificate provider drive. A certificate available to the current user is
  not evidence that the provider drive will exist in every invocation context.
- Mandatory preflight: resolve the pinned signer through the provider-independent
  .NET `X509Store` API in the exact builder invocation. Open `CurrentUser/My`
  read-only, normalize thumbprints, require exactly one match, require its
  private key, and close the store in `finally` before any signed-output write.
  Do not use a separate `Cert:` discovery command as caller/consumer evidence.
- Recovery: because the failure was preflight-only and the complete create-new
  output set remained absent, correct the DRAFT builder in place, refresh the
  failure-memory dependency and build pre-action hash, create a fresh clone-gate
  namespace that binds the corrected builder, and rerun every exact preflight.
  Do not reuse or overwrite the earlier clone gate and do not create a request
  until the .NET certificate lookup passes in the paired PS5.1 consumer.

## 2026-08-27 — A passing visible-route hostname gate does not prove a longer clipboard result round trip

- Failure signature: after the operator exposed the existing full-screen JBOD
  layer, the fresh short hostname gate returned exact `A1025645101`, but the
  separately frozen 1,934-character metadata-only inventory command returned
  no nonce-bound clipboard result before its 50-second boundary.
- Cause: unresolved. The short gate proves the exact visible host and current
  prompt accepted one short paste; it does not prove that a longer encoded
  command parsed, ran, serialized within its result bound, or replaced the
  shared clipboard. A timeout is not inventory evidence and cannot be used to
  infer remote execution or completion.
- Mandatory preflight: preserve separate short-gate and command-result
  boundaries, freeze the exact command source/hash/length, require the direct
  runner's exact nonce, command hash, `PASS` state, and non-truncated bounded
  result, and treat absence of any one as terminal. Never call the exact lot
  absent, empty, complete, or inventoried from the timeout.
- Recovery: do not rerun the same command namespace, repeat Enter, click
  blindly, or accept a paste-confirmation dialog. Keep the visible sessions
  open. Require the operator to report the exact current JBOD console state.
  Only when a remote parse/runtime error is visibly present may the existing
  bounded `CaptureConsoleText` action collect that already-visible text; any
  successor command requires a fresh separately governed namespace.

## 2026-08-27 — A long encoded paste can remain in the console input buffer after the runner sends Enter

- Failure signature: the operator's post-timeout screenshot showed the exact
  long Base64 `powershell.exe -EncodedCommand ...;exit` text fully visible in
  the JBOD PowerShell input buffer with the insertion cursor at its end. There
  was no parse/runtime error, paste-confirmation dialog, returned prompt, or
  nonce-bound result.
- Cause: the substantive Invoke wrapper exceeded the transport's previously
  proven short-paste class. The unchanged runner sent Enter only 500 ms after
  Ctrl+V; the observed pending input proves that the command was not submitted
  at that boundary. It does not prove whether Enter arrived too early, was
  dropped, or was consumed while the nested terminal was still applying the
  paste.
- Mandatory preflight: calculate and record the complete pasted wrapper length,
  not merely the embedded source length. Before a fresh substantive namespace,
  run one non-mutating nonce-bound Invoke rehearsal whose final pasted length
  is equal to or greater than the successor and whose source returns only a
  fixed scalar. Continue only on its exact nonce, command hash, PASS state, and
  non-truncated scalar result. The successor must remain at or below that exact
  qualified length.
- Recovery: never press Enter into the stranded input, clear it with blind
  keystrokes, capture it as an error, or reuse the failed namespace. Leave the
  stranded console untouched. A fresh console and fresh namespace may be used
  only after the exact-length rehearsal and every observation/pre-action gate
  pass. If the exact-length rehearsal fails, stop with a direct-transport
  capability gap rather than installing an observation helper or using a
  maintenance request.

## 2026-08-27 — A failed equal-length fixed-scalar rehearsal disqualifies the substantive clipboard class

- Failure signature: after the long inventory namespace was withdrawn, a fresh
  1,583-character source that returned only `PASS_O3T1` produced the exact same
  5,711-character pasted length planned for its substantive successor. It also
  returned no nonce, command hash, PASS state, or scalar result before 30
  seconds.
- Cause: the 5,711-character nested RustDesk/RDP clipboard class is not
  qualified by the current direct runner's 500 ms paste-to-Enter boundary. A
  fixed-scalar failure rules out filesystem enumeration time, JSON size, image
  access, and lot topology as the cause of that attempt.
- Mandatory preflight: a substantive successor must never run when its equal-
  or-greater-length fixed-scalar rehearsal lacks an exact terminal result.
  Record the rehearsal source hash, source length, constructed pasted length,
  timeout, and absent nonce/hash/state/result as a machine blocker.
- Recovery: withdraw the rehearsal namespace, keep the blocked substantive
  successor unexecuted, and stop with a direct-transport capability gap. Do not
  explore progressively shorter clipboard commands, press Enter on stranded
  input, install a helper, or publish maintenance as observation. Continuing
  requires operator authority for one separately designed endpoint capability
  improvement or another already installed qualified metadata route.

## 2026-08-27 — Embedded portable Python does not add a script's directory to `sys.path`

- Failure signature: the frozen O3D2 V2 R2 entrypoint failed its first
  non-mutating `--runtime-preflight` with `ModuleNotFoundError` while importing
  its sibling core module by bare module name. No image was decoded and neither
  planned output root existed afterward.
- Cause: the portable Python 3.13 runtime is governed by `python313._pth`.
  Its `.` entry resolves to the embedded executable directory, not the invoked
  script's directory, so a sibling source file is not importable by name merely
  because the entrypoint and core are adjacent.
- Mandatory preflight: every wrapper that imports a project sibling under the
  embedded runtime must load the exact sibling path with
  `importlib.util.spec_from_file_location`, register the resulting module in
  `sys.modules`, and execute the spec. Run the wrapper's own runtime preflight
  before any image decode or output-root creation; adjacency is not import
  evidence.
- Recovery: withdraw the frozen failed wrapper/job namespace, preserve its
  terminal preflight failure as non-reusable evidence, create a fresh wrapper
  and job namespace with exact-path loading, re-freeze every hash and gate, and
  rerun the full pre-action and non-mutating preflights before execution.

## 2026-08-27 — Capture an original function before monkey-patching its module binding

- Failure signature: the frozen O3D2 V2 R3 synthetic gate created its fresh
  root, then failed before drawing or writing either case because its wrapper's
  replacement `synthetic_parameters` called `core.synthetic_parameters` after
  that binding already pointed to the replacement. Python terminated with
  `RecursionError`; the synthetic root was empty and no real POST2 run began.
- Cause: the wrapper did not capture the original callable before assigning the
  replacement to the module. Looking the function up through the module from
  inside the replacement resolves the replacement itself.
- Mandatory preflight: when a frozen wrapper replaces a loaded module binding,
  first store the original callable in a distinct immutable wrapper-level name;
  the replacement may call only that captured name. Exercise the exact
  replacement path in a fresh synthetic namespace before any real image decode.
- Recovery: withdraw the wrapper, job, and empty output namespace, create a
  fresh entrypoint/job/output namespace that captures the original callable,
  re-run all hashes, isolation, path, zero-recurrence, runtime, job, and
  synthetic gates, and do not reuse the failed empty root.

## 2026-08-27 — Bind endpoint result-schema assertions to the producer constant, not a guessed suffix

- Failure signature: the first draft O3D3 endpoint rehearsal completed the
  exact R6 OpenCV run and wrote a one-row result, but the endpoint rejected
  `argos_native_frontside_wafer_pose_opencv_v2` because its guard guessed
  `argos_native_frontside_wafer_pose_opencv_v2_result`. The endpoint failed
  closed and moved the work/output trees to the exact `.failed` quarantines;
  no JBOD request was built, signed, published, or executed.
- Cause: the endpoint guard inferred a result-schema suffix instead of reading
  the producer's exact `RESULT_SCHEMA` constant or a frozen producer output.
  The summary schema happens to carry a `_summary` suffix, but that naming
  convention does not imply a `_result` suffix for the per-input schema.
- Mandatory preflight: before freezing any endpoint that validates an installed
  or packaged producer's output schema, mechanically compare every asserted
  schema token with the exact producer constant and one frozen producer output.
  Include that comparison in the Windows PowerShell 5.1 rehearsal gate; do not
  derive one schema name from another.
- Recovery: preserve the failed local rehearsal roots as diagnostic-only
  evidence, correct the still-DRAFT endpoint assertion, freeze fresh endpoint
  and harness hashes, and use a fresh short rehearsal namespace. Re-run clone,
  harness, wrapper, path, zero-recurrence, success, and injected-failure gates
  before signing. Never reuse `C:\A35` as the rehearsal root.

## 2026-08-27 — Strip shell-result metadata before mechanically cloning source through an orchestration tool

- Failure signature: the first generated O3D3R2 draft files began with three
  non-source lines (`Exit code`, `Wall time`, and `Output`) captured from the
  shell tool result. Windows PowerShell parsing rejected the endpoint before
  any rehearsal execution; the JSON job and Python fixture generator were also
  visibly prefixed. No new test root, signed package, or external mutation was
  created.
- Cause: the orchestration layer returned a structured command-result envelope
  as text. The mechanical clone treated the entire envelope as file contents
  instead of isolating the command's stdout payload.
- Mandatory preflight: after every tool-mediated mechanical source clone,
  inspect the first source lines and parse the exact generated file before
  hashing or execution. Reject generated PowerShell unless its first logical
  source line is the expected `#Requires`/attribute/comment, JSON unless it
  begins with `{` or `[`, and Python unless it begins with the expected shebang
  or source text. The clone-remediation gate does not replace this check.
- Recovery: because the generated files remained DRAFT and were never parsed
  successfully or executed, remove only the three disclosed envelope lines in
  place, then rerun exact parser/JSON/Python compilation, hashes, clone,
  harness, wrapper, path, and zero-recurrence gates before rehearsal.

## 2026-08-27 — Compare fixture schema literals mechanically after namespace changes

- Failure signature: the O3D3R2 rehearsal generated only its local synthetic
  source fixture, then the endpoint's non-mutating live-contract branch rejected
  `argos_o3d3r2_live_contract_fixture_v1` because the exact endpoint still
  required `argos_o3d3_live_contract_fixture_v1`. No source hash, detector run,
  signed package, JBOD request, or provider action occurred.
- Cause: a namespace transformation changed the fixture JSON schema but did not
  change the matching lowercase schema token embedded in the endpoint. Parser,
  clone-root, and hash gates cannot detect two individually valid but unequal
  contract literals.
- Mandatory preflight: extract and compare the endpoint's exact accepted fixture
  schema with the fixture JSON's `schema` before executing the harness. Apply
  the same literal equality check to every required output schema/state token;
  namespace search-and-replace is not contract evidence.
- Recovery: preserve `C:\A36` as the R2 diagnostic-only partial test root,
  withdraw the R2 endpoint/test namespace, and create a fresh R3 namespace whose
  preflight mechanically proves fixture-schema equality before fixture creation.
  Re-freeze and rerun every parser, clone, harness, wrapper, path, and zero-
  recurrence gate before execution.

## 2026-08-27 — Do not array-subexpress a generic List when constructing a Windows PowerShell 5.1 gate

- Failure signature: the O3D3R3 rehearsal completed the exact synthetic R6
  detector run and validated its result, then Windows PowerShell 5.1 threw
  `Argument types do not match` before writing `RUN_GATE.json`. The work and
  output were quarantined under `C:\A37\*.failed`; no signed package or JBOD
  request existed.
- Cause: the endpoint placed a `Collections.Generic.List[object]` into the gate
  with `@($resultRows)`. Windows PowerShell 5.1's binder can throw this opaque
  argument-type error while enumerating a generic list in an array
  subexpression, even though `.Count` and individual items are valid.
- Mandatory preflight: convert generic lists explicitly with `.ToArray()` before
  assigning them to JSON/gate properties under Windows PowerShell 5.1. The exact
  success rehearsal must reach gate serialization and read the written gate;
  detector output alone is not endpoint-output evidence.
- Recovery: preserve the R3 diagnostic roots, withdraw its endpoint/test
  namespace, and create a fresh R4 namespace using `.ToArray()` for the bounded
  result rows. Re-freeze exact hashes and rerun the complete parser, clone,
  harness, wrapper, path, zero-recurrence, success, and injected-failure gates.
  Never reuse `C:\A37`.

## 2026-08-27 — Do not use Join-Path to preflight an absent target drive

- Failure signature: the first DRAFT O3J1 provider test preflight failed before
  creating its fixture root because Windows PowerShell 5.1 `Join-Path` rejected
  the planned `D:` result root on the engineering laptop, where that JBOD drive
  is intentionally absent. No JSON source was read and no local or external
  mutation occurred.
- Cause: `Join-Path` resolves its drive provider and therefore requires the
  named drive to exist even when code is only constructing and validating an
  absolute path for a different host.
- Mandatory preflight: planning-only code for an installed or remote absolute
  root must construct candidate leaves with `System.IO.Path.Combine` followed
  by `GetFullPath`, then enforce containment and path-budget checks. Existence,
  reparse-lineage, and byte reads remain confined to the explicit collection or
  apply branch.
- Recovery: correct the unpublished DRAFT provider in place, re-pin its exact
  hash, and rerun parser, harness-safety, non-mutating provider/test preflights,
  and the fresh ZERO/ONE/MANY gate before freezing any package bytes.

## 2026-08-27 — Match the installed host's malformed-JSON failure class in negative controls

- Failure signature: the frozen O3J1 R1 local provider gate completed ZERO,
  ONE, MANY_13, and seven negative cases, then its harness rejected the expected
  malformed-JSON rejection because Windows PowerShell 5.1 reported `Invalid
  object passed in` rather than one of the harness's narrower expected phrases.
  The provider failed closed correctly; no JBOD contact or image read occurred.
- Cause: the negative control asserted selected message wording instead of the
  complete known Windows PowerShell 5.1 malformed-JSON error class.
- Mandatory preflight: malformed-JSON negative controls must accept the bounded
  installed-host phrase set while still requiring an exception and must record
  the exact observed message. Positive schema/state checks remain exact.
- Recovery: preserve the R1 partial fixture and withdrawal evidence, clone the
  harness into a fresh R2 namespace under literal-remediation control, add the
  installed-host phrase, and rerun guard, preflight, and every case in a fresh
  fixture root before writing a PASS gate.

## 2026-08-27 — Declare the exact root token emitted by the clone-literal scanner

- Failure signature: the DRAFT O3J1 R2 clone-remediation preflight rejected the
  declared `C:\outside` test root because the scanner's exact token for the
  rooted negative-control literal was `C:\outside.json`. The preflight wrote no
  gate and executed neither source nor generated harness.
- Cause: the remediation manifest shortened the mechanically reported literal
  token instead of declaring it exactly.
- Mandatory preflight: obtain every root token from the remediation tool's
  bounded preflight result and declare the exact case-insensitive token,
  including a leaf-like first component when that is what the scanner emits.
- Recovery: correct the unexecuted DRAFT manifest in place and require a clean
  preflight and durable gate before the cloned harness runs.

## 2026-08-27 — State the general mutation flag in recovery observations

- Failure signature: O3J1 recovery-intent preflight rejected its frozen
  supporting observation as mutated even though the observation explicitly
  reported `sourceMutationPerformed: false`.
- Cause: the recovery validator fails closed when the general
  `mutationsPerformed` field is absent; a narrower source-mutation flag does not
  establish that no other mutation occurred.
- Mandatory preflight: every recovery observation must explicitly set
  `mutationsPerformed: false` in addition to any narrower source, task, process,
  queue, or ledger flags, and must pass the exact recovery-intent validator
  before build or signature.
- Recovery: preserve the failed frozen observation and intent, create fresh R2
  evidence namespaces with the explicit general flag, re-pin the R2 observation
  hash, and rerun the preflight before package construction.

## 2026-08-27 — Read the exact frozen result schema before pinning a review renderer

- Failure signature: the DRAFT O3K1 OpenCV review renderer parsed successfully
  and then stopped in its non-mutating preflight with `Frozen result schema
  changed` before any image read, source hash, output creation, JBOD contact, or
  external mutation.
- Cause: the renderer guessed the frozen result schema token as
  `argos_native_frontside_wafer_pose_opencv_v2_result`; the exact signed Slot16
  and Slot17 results publish `argos_native_frontside_wafer_pose_opencv_v2`.
- Mandatory preflight: before coding a consumer for frozen JSON, enumerate and
  pin the actual top-level schema and required property set from every exact
  input file. Exercise the consumer's complete non-mutating preflight against
  those exact files before source hashing, pixel decode, output creation,
  package build, or signature.
- Recovery: because the renderer and job remained DRAFT and no target bytes or
  output root were created, correct only the schema constant in place, rerun
  parser and exact-input preflight, and proceed only on its explicit PASS.

## 2026-08-27 — Periodic-texture attenuation is not an exterior-boundary proof

- Failure signature: O3L1 passed BF/DF periodic-die synthetic controls, but its
  first bounded real-crop run localized only three of six views, confirmed zero
  of three BF/DF pairs, and placed one primary center at x=951 in a 1000-pixel
  crop. The run was review-only and changed no source, provider, processor,
  task, process, hold, XML, training, or production state.
- Cause: the boundary score blurred tangential texture and rewarded a texture
  drop, but absolute gradient and intensity-step terms could still promote an
  internal die street. The score did not require the pixels below a proposed
  boundary to match the column-local exterior appearance measured at the
  bottom of the tangent/radial crop.
- Mandatory preflight: a notch crop localizer must measure a bounded exterior
  reference from the known outward end of every crop, normalize column-local
  intensity and texture distance against that exterior, and score a sustained
  wafer-above/exterior-below transition. Synthetic controls must include strong
  internal die streets, channel-specific contrast, no-notch exterior, and two
  physical indentations. The first real-development run is not presentable
  unless its exact BF/DF cardinalities and edge-adjacent primaries are assessed
  before any gallery is built.
- Recovery: preserve O3L1 as withdrawn diagnostic evidence, make no threshold
  relaxation, and use a fresh namespace for an exterior-referenced successor.
  Do not patch or present the O3L1 output root.

## 2026-08-27 — Exterior similarity must be an edge-eligibility gate, not a weight

- Failure signature: O3L2 passed its non-mutating preflight but its frozen
  synthetic suite stopped on `EXTERIOR_NO_NOTCH_NEGATIVE` because a periodic
  die-only crop still produced an indentation candidate. No synthetic gate,
  real-crop output root, source read, or external mutation was created.
- Cause: O3L2 measured column-local exterior appearance, but used likeness of
  the pixels below a candidate only as a soft multiplier. A strong internal
  transition could retain nonzero score and remain in the dynamic-programming
  search even though the below-region did not actually match the exterior.
- Mandatory preflight: candidate boundary rows must be ineligible unless a
  sustained below-region falls inside a pinned normalized distance from the
  exact column-local exterior model. Keep the no-notch negative, strong die
  streets, BF/DF contrast variants, and two-indentation ambiguity control; do
  not compensate by lowering notch depth or ambiguity thresholds.
- Recovery: withdraw O3L2 and create a fresh namespace with the hard exterior
  eligibility mask. Do not run O3L2 on real pixels or reuse its source as the
  runtime parent.

## 2026-08-27 — OpenCV medianBlur float support depends on kernel size

- Failure signature: O3L3 passed non-mutating preflight, then stopped before
  synthetic assertions because OpenCV 5.0 rejected `medianBlur` on a float32
  one-row boundary with kernel size 9. The optimized path asserted an 8-bit
  source. No gate, real-pixel read, or output root was created.
- Cause: the implementation assumed float32 support at kernel 9 because small
  median kernels accept float data. OpenCV's larger optimized median path has
  a narrower source-depth contract.
- Mandatory preflight: exercise the exact dtype, channel count, shape, and
  kernel size of every OpenCV smoothing operation in the synthetic gate.
  Prefer a float-safe Gaussian filter for subpixel boundary arrays; if a fixed-
  point conversion is used, pin its range and round-trip error.
- Recovery: withdraw O3L3, preserve the unchanged hard-exterior and notch
  thresholds, and use a fresh namespace with float-safe smoothing before any
  real crop is read.

## 2026-08-27 — Per-column exterior transitions do not enforce wafer topology

- Failure signature: O3L4 exercised its float-safe smoothing path but the BF
  periodic-die single-notch synthetic control did not return one primary
  notch. The test stopped before its gate and before any real-crop read.
- Cause: hard exterior eligibility was applied per column, then missing rows
  were interpolated. That approach still permits fragmented edge evidence and
  ignores the stronger physical invariant that the wafer is one region
  connected to the crop's inward/top side while die streets are interior holes.
- Mandatory preflight: segment exterior-dissimilar pixels, retain only the
  largest top-connected wafer component, close and fill bounded interior holes,
  and extract the outward contour from that component. Synthetic controls must
  keep stronger die streets than the physical edge, a no-notch negative, BF/DF
  contrast variants, and a two-indentation ambiguity case.
- Recovery: withdraw O3L4 and use a fresh topology-based namespace. Do not
  lower notch depth, exterior separation, or ambiguity thresholds.

## 2026-08-27 — A notch mouth midpoint is not necessarily its physical axis

- Failure signature: O3L5's topology segmentation found the BF synthetic
  indentation, but the red-center test missed the known axis by 26.5 pixels.
  The center was defined as the midpoint of threshold-dependent left/right
  mouth returns. No real crop was read and no output root was created.
- Cause: asymmetric or differently recovered shoulders can move the mouth
  midpoint even when the deepest topology-derived indentation point remains on
  the physical notch axis. Width bounds and axis location are different
  measurements.
- Mandatory preflight: render the deepest indentation point/axis as the red
  notch center, retain left/right mouth returns as separate yellow width
  evidence, and record their midpoint only as diagnostic geometry. Synthetic
  BF/DF cases must gate the red axis against the known deepest point.
- Recovery: preserve O3L5 as withdrawn, change no segmentation or thresholds,
  and use a fresh namespace for the corrected center semantics.

## 2026-08-27 — Topology indentation noise must exclude the positive tail

- Failure signature: O3L6 passed its non-mutating preflight, its BF/DF
  deepest-axis positive checks, and its contour-hugging/no-full-height-ray
  overlay assertions, but the no-notch BF control still produced one
  14.91-pixel-deep candidate. The frozen suite stopped before its gate, before
  any real image read, and before any output root was created.
- Cause: notch noise was estimated from absolute residuals across the complete
  contour. A repeated or broad physical indentation can inflate that estimate,
  while an isolated positive die-pattern tail can still exceed the old
  7-pixel floor. The exact controls bounded the false positive at 14.91 pixels
  and both single-notch positives at 63.19 pixels or deeper.
- Mandatory preflight: estimate contour noise from the non-positive/lower half
  of the residual population so physical indentation tails cannot veto one
  another. Pin an evidence-backed 20-pixel topology-indentation floor between
  the exact negative and positive bounds. Require the BF/DF single-notch
  controls, no-notch negative, two-indentation ambiguity hold, red
  mouth-to-mouth contour coverage, and absence of any full-height red column
  to pass in one frozen suite.
- Recovery: withdraw O3L6 and use a fresh namespace. Change only the robust
  noise population and the evidenced topology-depth floor; preserve topology
  segmentation, all other thresholds, deepest-axis semantics, and the
  contour-hugging overlay. Do not read real crops until the complete successor
  synthetic gate passes.

## 2026-08-27 — Two qualified topology indentations always require a hold

- Failure signature: O3L7 passed both single-notch axis controls, the no-notch
  negative, and its contour-hugging/no-full-height-ray assertions. Its final
  synthetic frame then returned two independently qualified 60-pixel-plus
  physical indentations but labeled the frame primary because the second score
  was 0.643 of the first, below the predecessor 0.72 ratio. No gate, real image
  read, or output root was created.
- Cause: the score-ratio ambiguity rule treated weaker recovered support or
  width as evidence that a second physical indentation could be discarded.
  Once topology, depth, and width gates qualify two distinct indentations,
  their relative rendering score is not a physical uniqueness proof.
- Mandatory preflight: classify every frame with more than one independently
  qualified topology indentation as ambiguous. Keep scores and their ratio as
  diagnostics only. The complete frozen suite must prove one BF notch, one DF
  notch, zero notches, and a two-indentation hold, plus the contour-hugging and
  no-full-height-ray raster assertions.
- Recovery: withdraw O3L7 and use a fresh namespace. Preserve segmentation,
  evidence-bounded depth/noise gates, axis semantics, and overlay bytes; change
  only multi-candidate decision semantics before any real crop read.
## 2026-08-27 — A full-perimeter topology synthetic must preserve real pixel scale

- Failure signature: the first O3M1 full-perimeter topology synthetic gate
  returned zero eligible candidates for every positive case while its periodic
  no-notch negative passed.  No real source image was read and no external
  action occurred.
- Cause: the synthetic used a 420-pixel wafer radius with a 2.4-degree notch,
  making the mouth only about 18 pixels wide.  The unchanged real-image
  17-pixel die-street closing kernel, contour smoothing, and 20-pixel depth
  floor were therefore applied at a radically different spatial scale than
  the approximately 5,160-pixel real wafer radius.  A bounded diagnostic found
  a 22.37-pixel raw residual but only a 16.01-pixel processed peak after the
  fixed topology filtering; relaxing the fixed gates would have hidden the
  fixture defect.
- Mandatory preflight: every angular notch/topology synthetic must preserve the
  real ratio among wafer radius, notch mouth width, morphology kernels,
  smoothing widths, and depth floor.  Assert the constructed mouth-pixel width
  and its ratio to every fixed kernel before launch.  Scale the synthetic canvas
  and radius when needed; never weaken a real detector threshold merely to make
  an underscaled fixture pass.
- Recovery: preserve `work/O3M1/T1` and the executed O3M1 R1 engine as
  `WITHDRAWN`.  Use a fresh engine/output namespace with a spatially scaled
  synthetic, keep the real topology thresholds unchanged, and rerun every
  positive, no-notch, ambiguity, and chipout control before any real-image or
  JBOD execution.
- R2 follow-up: scaling the mouth to 35.19 pixels while retaining a 38-pixel
  synthetic depth was still not commensurate with the accepted real S17
  topology, whose measured peaks are 72.17 and 76.52 pixels.  The unchanged
  topology path measured only an 18.96-pixel raw residual and a 17.80-pixel
  filtered peak, correctly below the frozen 20-pixel floor.  A bounded
  in-memory sweep proved that 64-, 76-, and 90-pixel constructed depths pass
  without a threshold change, while 50 pixels does not.  Future preflight must
  bind both mouth scale and positive depth to the accepted real development
  regime and assert the filtered positive clears the frozen floor; preserve
  `work/O3M2/T2` and the executed R2 engine as `WITHDRAWN`.
- R3 follow-up: the accepted 76-pixel depth made the 2.4-degree upper-right
  control pass, but four 2.2-degree BF controls still disappeared while their
  DF partners survived.  The smaller BF mouth was only about twice the
  17-pixel closing kernel, so the fixture remained direction/edge-family
  sensitive.  A bounded five-angle in-memory preflight at a 2,200-pixel BF
  radius produced an 84.47-pixel 2.2-degree mouth and returned exactly one
  eligible BF/DF candidate at every tested angle, including 37, 82, 217, 242,
  and 315 degrees.  Require the minimum positive mouth to be at least four
  times the largest topology kernel, not merely wider than it; preserve
  `work/O3M3/T3` and the executed R3 engine as `WITHDRAWN`.

## 2026-08-27 — A composed image-provider job must validate its complete downstream configuration

- Failure signature: O3M4 R4 passed its scale-realistic full-perimeter
  synthetic gate and non-mutating real-job preflight, but the first frozen
  POST2 execution marked all 72 tiles in all six BF/DF inputs incomplete with
  the exact exception `'clahe'`.  It wrote review-only local evidence only;
  no JBOD request, provider activation, processor action, source mutation, or
  hold clearance occurred.
- Cause: the successor job carried only the configuration keys referenced
  directly by its orchestration module.  The delegated unchanged O3L8
  topology provider also required `clahe`, exterior sampling, connected-region,
  support, noise, and candidate-width keys.  The preflight validated selected
  values but did not assert the complete downstream key set, while the
  synthetic path supplied an internal complete dictionary and therefore could
  not expose the real-job omission.
- Mandatory preflight: every composed provider must define one complete exact
  downstream configuration schema, require every delegated-provider key in
  job validation, reject unknown or missing keys, and run at least one
  no-pixel-decode configuration-construction check through the same real-job
  path.  Synthetic fixtures must consume the same validated configuration
  object as real jobs or mechanically compare their key sets before launch.
- Recovery: preserve `work/O3M4/T4`, `work/O3M4/P4`, the R4 engine, and its job
  as `WITHDRAWN`.  Use a fresh namespace, restore the unchanged frozen O3L8
  configuration values, add complete key-set validation, rerun the full
  synthetic suite, and then rerun the exact POST2 inputs without threshold or
  algorithm changes before any Slot16/JBOD action.

## 2026-08-27 — Frontside BF and DF edge appearance regimes must not be forced through one segmentation method

- Failure signature: O3M5 R5 corrected the complete configuration contract,
  passed the full scale-realistic synthetic suite, and decoded the exact three
  frozen POST2 BF/DF pairs.  BF topology qualified 71 of 72 tiles on every
  wafer and recovered each known approximately 90-degree notch.  The identical
  solid-region topology method failed 12, 63, and 68 DF tiles respectively;
  the failures were `No top-connected wafer component qualified` or `Wafer
  contour covers fewer than two columns`.  The run wrote local review-only
  evidence only and made no external or source mutation.
- Cause: DF wafer interiors in this frozen appearance regime are not a solid
  exterior-dissimilar region.  Treating sparse/dark DF interior response like
  BF prevents the top-connected filled-component invariant from existing,
  even though the qualified R6 outer-edge radial method independently recovers
  the DF physical notch in every exact POST2 pair.  This is an appearance-
  regime mismatch, not evidence to lower topology thresholds.
- Mandatory preflight: declare channel methods explicitly.  Use the proven
  top-connected topology contour for BF and the proven full-360 outer-edge
  radial contour for DF, then pair only candidates supported by both channels.
  Keep frontside and backside providers independent.  Gate upper-right and
  arbitrary-angle positives, a no-notch negative, two-notch ambiguity, and a
  one-channel chipout under the split method.  On the exact POST2 evidence,
  require one BF-topology/DF-radial eligible pair per wafer at the frozen notch
  without tuning.
- Recovery: preserve `work/O3M5/T5`, `work/O3M5/P5`, the R5 engine, and its job
  as `WITHDRAWN`.  Use a fresh namespace for the explicit BF-topology/DF-radial
  provider.  Reuse frozen R6 radial parameters and O3L8 BF topology values;
  change no threshold, use no Argos rotation/orientation input, and do not
  consume backside pixels.
- O3P6 recurrence: the O3P6 corroborator correctly isolated candidate-local
  topology exceptions but nevertheless invoked the BF top-connected topology
  method on DF and required that DF topology result for eligibility.  Its blind
  POST2 output therefore held Slot03 and Slot17 despite correct BF topology and
  qualified DF radial measurements, and admitted an unrelated DF-only response
  as a second Slot01 topology-correlated candidate.  The output was frozen
  before scorer labels were read, failed 0 of 3 as an implemented detector,
  and is withdrawn.  Future gates must mechanically assert that DF pixels never
  enter the BF topology function, that eligibility consumes only BF topology
  plus DF outer-edge radial evidence, and that one-channel responses remain
  negative controls.  A prose declaration of channel-specific methods is not
  sufficient; the exact invoked functions and per-channel result fields must be
  checked in the synthetic and real-output gates.

## 2026-08-27 — PowerShell keyword boundaries require whitespace even when the AST parses

- Failure signature: the first O3M8 Windows PowerShell 5.1 endpoint preflight
  stopped with `The term 'return$r' is not recognized`.  The harness parser
  gate had passed because PowerShell parsed the adjacent text as a command
  token.  The failure occurred before alias creation, source metadata or image
  reads, output creation, signature, publication, or external action.
- Cause: a mechanically compacted function ended with `return$r` instead of
  `return $r`.  AST parse success alone does not prove keyword/token boundary
  semantics for compact PowerShell source.
- Mandatory preflight: scan every changed PowerShell harness for adjacent
  control-flow keywords and variables (`return$`, `throw$`, `break$`,
  `continue$`, `exit$`) in addition to the AST parser and harness-safety gate.
  Execute the exact non-mutating Windows PowerShell 5.1 preflight before any
  rehearsal output, signature, or publication.
- Recovery: because O3M8 remained an unsigned, unpublished, unexecuted local
  `DRAFT` and no target bytes changed, correct the token boundary in place,
  update exact hashes, and rerun the preaction, harness, and endpoint preflight.

## 2026-08-27 — A create-new output leaf still requires an existing parent

- Failure signature: the frozen O3M8 endpoint rehearsal passed its exact
  non-mutating Windows PowerShell 5.1 preflight, created and later removed only
  its owned `F:` alias, then the OpenCV child stopped with `WinError 3` while
  creating `C:\A3M8R\o.partial`.  The parent `C:\A3M8R` did not exist.  No
  image was decoded, no output leaf was created, and no request was signed or
  published.
- Cause: path-budget and collision gates proved the planned leaf was safe and
  absent but did not prove that its immediate parent existed.  The provider
  intentionally uses non-recursive create-new output creation.
- Mandatory preflight: for every provider output, partial, export, and failure
  leaf, prove the exact immediate parent exists before launch, or choose a
  create-new leaf directly under an already verified existing parent.  Never
  rely on an image provider to create missing ancestors implicitly.
- Recovery: preserve O3M8 as withdrawn frozen rehearsal evidence.  Use a fresh
  namespace whose rehearsal output/export leaves are directly under verified
  `C:\`; retain the unchanged live roots whose parents are already pinned.

## 2026-08-27 — Guard switches must be discovered from the exact installed command

- Failure signature: the first O3M9 build pre-action invocation supplied
  `-AsJson` to `Confirm-ArgosZeroRecurrencePreaction.ps1`, which does not
  declare that switch.  PowerShell rejected the parameter before the guard
  inspected the contract; the later build preflight in the same local shell
  command still ran, but no build, signature, publication, source read, or
  external mutation occurred.
- Cause: the invocation copied an output-format switch supported by adjacent
  guards without resolving the exact parameter set of the zero-recurrence
  guard first.
- Mandatory preflight: before invoking any guard, resolve its exact installed
  command and parameter names with `Get-Command`; never infer optional switches
  from a sibling utility.  Run guards as separate processes or fail the
  compound caller immediately so a rejected mandatory guard cannot be hidden
  by a later successful command.
- Recovery: O3M9 build/sign remains an unsigned, unpublished local draft.
  Correct only the guard invocation, refresh the failure-memory pin in the
  pre-action contract, and rerun the zero-recurrence guard successfully before
  signing.

## 2026-08-27 — A signed maintenance request requires at least one declared change row

- Failure signature: the O3M9 builder created and signed request
  `REQ_20260827T230600111Z_62629419O3M9`, then the exact package verifier
  stopped with `Maintenance package has no declared changes.`  No ZIP was
  finalized, and nothing was published or executed.
- Cause: the portal `MAINTENANCE_PATCH` manifest verifier requires one or more
  `changes` rows even when the bounded entrypoint is intended to execute only
  packaged payload bytes.  An empty changes array is not a valid signed
  maintenance package in this installed protocol revision.
- Mandatory preflight: before signing, assert the selected portal package
  class's exact manifest cardinalities against the installed verifier.  For a
  payload-only review action that still requires `MAINTENANCE_PATCH`, use only
  a separately pinned, already-installed non-processor review helper as an
  idempotent same-hash protocol anchor with `allowCreate=false`; never name a
  protected processor file or represent an actual algorithm install as inert.
- Recovery: withdraw the signed O3M9 request ID and preserve its exact manifest
  and signature hashes as terminal local evidence.  Build any successor under
  a fresh request/package namespace, rerun all gates, and publish it at most
  once with no retry.

## 2026-08-27 — Native Python `-c` verification cannot depend on inner JSON quotes surviving PowerShell

- Failure signature: the O3P1 offline local-runtime apply installed the pinned
  NumPy and OpenCV wheels into `C:\A3P1R`, then its post-install verification
  failed with Python `SyntaxError`.  The received expression had unquoted JSON
  dictionary keys and an invalid `separators=(,,:)` tuple.  No PASS gate was
  written, no network or source mutation occurred, and JBOD was not contacted.
- Cause: the Windows PowerShell 5.1 to native-process argument boundary removed
  the inner double quotes from a Python `-c` expression that constructed JSON.
  PowerShell AST parsing, harness safety, and wrapper-manifest compatibility do
  not prove preservation of nested language quoting inside a native argument.
- Mandatory preflight: do not pass structured Python source containing quoted
  JSON keys or delimiters through an external `-c` boundary.  Put nontrivial
  verification code in an exact, hash-pinned file-backed Python script and pass
  only bounded scalar paths after its filename.  Exercise that exact apply-only
  verification code in a non-mutating rehearsal against an already isolated
  runtime before a create-new install is authorized.
- Recovery: preserve `C:\A3P1R` as failed, non-reusable evidence and never
  retry or repair it.  Pin a direct read-only inventory proving the installed
  versions and absent final/partial gate, then use a fresh runtime namespace
  with a file-backed verifier, refreshed hashes, recovery intent, wrapper,
  harness, path, and zero-recurrence gates.

## 2026-08-27 — Candidate-level contour insufficiency must not abort a multi-wafer batch

- Failure signature: the frozen O3P5 local POST2 run decoded its first exact
  full-resolution frontside inputs, then an R6-proposed crop supplied fewer
  than two observed wafer-contour columns to the unchanged topology provider.
  The provider correctly raised `ValueError: Wafer contour covers fewer than
  two columns`, but the new corroborator did not bound that expected
  candidate-level insufficiency.  The exception escaped the seed/channel loop
  and terminated the entire three-wafer batch.  No output or partial output,
  launch gate, source change, JBOD contact, or provider activation occurred;
  the launcher's `finally` path removed the temporary `R:` alias.
- Cause: the synthetic suite tested explicit missing-contour feature records
  but did not exercise the real delegated topology provider's exception path.
  The batch engine therefore treated an ordinary rejected seed as an
  infrastructure failure.  A preliminary post-failure probe also hashed the
  six source rasters before the exact `OBSERVE` intent had passed; that probe
  was not promoted as recovery evidence, and the observation was rerun under a
  passed intent using metadata only and no image-byte read.
- Mandatory preflight: every multi-seed/multi-channel image provider must
  mechanically classify documented candidate-local insufficiency exceptions
  inside the innermost candidate boundary and emit an explicit non-eligible
  reason record.  Contract, hash, decode, runtime, or output-commit failures
  remain batch-fatal.  The frozen synthetic suite must inject the exact
  delegated-provider exception and prove that later candidates and later
  wafers still complete, with zero/one/many decision semantics unchanged.
  After any failed frozen rehearsal, create and pass the exact recovery intent
  before even a read-only source hash or image-byte probe; the observation lane
  may inspect only the fields its passed route contract permits.
- Recovery: preserve O3P5 and its executed engine, job, launcher, and preaction
  as withdrawn, non-replayable evidence.  Use a fresh namespace for the
  candidate-boundary repair and its new output root, pin the post-failure
  metadata-only observation, rerun synthetic exception-continuation coverage,
  and perform at most one fresh POST2 run.  Do not change any contour,
  prominence, support, angle-agreement, or radial/topology threshold.

## 2026-08-28 — A post-engine launcher gate must consume the exact engine terminal schema

- Failure signature: the frozen O3P7 POST2 launcher passed its exact Windows
  PowerShell 5.1, harness, wrapper, path, continuity, session, synthetic, and
  zero-recurrence gates; created and verified only its temporary `R:` alias;
  hash-verified and decoded the six locked POST2 frontside rasters; and wrote a
  complete three-row numeric result with one BF-topology/DF-radial candidate
  per wafer and zero DF-topology calls.  After the engine succeeded, the
  launcher failed while constructing its terminal gate because strict mode
  could not find `candidateLocalTopologyInsufficiencyCount` on the engine's
  one-line terminal object.  That property existed only on each result row.
  The `finally` path removed `R:`; no launch gate or partial remained, no
  source was changed, and no network, task, process, provider, or JBOD action
  occurred.
- Cause: the launcher and engine were frozen against different terminal-result
  schemas.  The engine returned `state`, output identity/hash, input count,
  member states, and `dfTopologyInvocationCount`; the launcher additionally
  dereferenced an aggregate candidate-insufficiency property that the engine
  never emitted.  Syntax, wrapper, synthetic detector behavior, and a
  non-mutating launcher preflight did not exercise this post-engine gate-
  construction contract.
- Mandatory preflight: freeze the exact engine terminal JSON field set and run
  the launcher's post-engine gate construction against a bounded file-backed
  terminal-object fixture before any source-image execution.  Every consumed
  property must either exist in that frozen terminal schema or be derived from
  the hash-verified output document under an explicit zero/one/many collection
  test.  Strict-mode property access that is absent from the fixture is a hard
  stop before image decode.  The generated launch gate must also assert the
  output hash, member count/states, and zero DF-topology invocations.
- Recovery: preserve O3P7, its numeric output, engine, job, launcher,
  invocation, and preaction as failed frozen evidence; never rerun or repair
  that executed namespace.  Pin a direct post-failure observation proving the
  output hash/state, absent gate/partial, removed alias, and unchanged source
  contract.  Use a fresh O3P8 namespace with unchanged detector, job values,
  and thresholds; add the terminal-schema fixture gate, then perform at most
  one fresh POST2 run.

## 2026-08-28 — PowerShell keywords require token separation from type literals

- Failure signature: the first exact O3Q1 signed-package rehearsal extracted
  and signature-verified the frozen request and created only bounded local
  predecessor fixtures under `C:\A3Q1R`, then stopped with `The term
  'return[ordered]@' is not recognized` while entering the invocation-object
  helper.  No endpoint preflight or execution occurred, no image bytes were
  read, `S:` was never created, and neither `C:\A3Q1F` nor `C:\A3Q1P` was
  created.
- Cause: the generated Windows PowerShell 5.1 harness omitted required token
  separation between the `return` keyword and the `[ordered]` type literal.
  The AST parser accepted the text, but runtime command resolution treated the
  joined token as a command name.
- Mandatory preflight: reject keyword/type, keyword/quoted-string, and
  keyword/expression adjacency in generated PowerShell (`return[`, `throw'`,
  `throw"`, `throw(`, and equivalent forms).  Exercise
  every helper at least once through the exact Windows PowerShell 5.1
  preflight branch; parsing and static harness inspection do not prove that a
  helper's body tokenizes as intended at runtime.
- Recovery: preserve `Test-O3Q1FinalPackage.ps1` and `C:\A3Q1R` as withdrawn
  harness evidence.  Do not reuse their namespace.  Use a fresh R2 harness,
  `C:\A3Q1R2`, injected-failure root `C:\A3Q1F2`, success root
  `C:\A3Q1P2`, and a create-new R2 gate.  The signed O3Q1 ZIP is unchanged
  and remains eligible for exact-package rehearsal because the failure was in
  the external local harness before endpoint invocation.

- Follow-on application: O3Q1 package rehearsal R3 proved its success path,
  timeout quarantine, and alias cleanup, but its captured injected-failure
  message exposed `throw'O3Q1 ...'` inside the already signed endpoint.  That
  signed request was withdrawn before publication.  A successor must use a
  fresh request/output namespace and prove the intended timeout exception text
  as well as quarantine and cleanup; the signed O3Q1 ZIP is not reusable.

## 2026-08-28 — Rehearsal alias and frozen job paths must name the same drive

- Failure signature: O3Q1 exact-package rehearsal R2 signature-verified the
  signed ZIP, passed the extracted endpoint preflight, and proved the injected
  timeout was quarantined under `C:\A3Q1F2.failed`.  Its subsequent success
  case created and verified `S:`, but the frozen local rehearsal job contract
  still named `Q:`.  The unchanged engine therefore failed resolving the BF
  leaf before hashing or decoding; the endpoint quarantined the attempt under
  `C:\A3Q1P2.failed` and removed `S:`.
- Cause: the outer harness independently selected the process-local alias
  drive without mechanically comparing it to the drive prefix of every frozen
  source path in the job contract.  Endpoint preflight proved seed/config and
  terminal schemas but did not assert that relationship.
- Mandatory preflight: parse every frozen input source path, require one exact
  common drive prefix, and require it to equal `sourceAliasDrive` before alias
  creation or output write.  Package rehearsals must use that exact drive and
  exercise both injected-failure and success paths.  Alias existence alone is
  insufficient.
- Recovery: preserve the R2 harness, `C:\A3Q1R2`,
  `C:\A3Q1F2.failed`, and `C:\A3Q1P2.failed` as withdrawn local evidence.
  Use a fresh R3 harness with `Q:` and fresh `C:\A3Q1R3`,
  `C:\A3Q1F3`, and `C:\A3Q1P3` namespaces.  The signed live O3Q1 request is
  unchanged: its frozen job sources and invocation both name `F:`.

## 2026-08-28 — Direct-control transport inventory must pass the current harness policy before use

- Failure signature: after the authentic signed O3Q2 terminal response proved
  a live NumPy-version premise failure, the incident-bound recovery intent,
  observation source, direct runner, wrapper, path, continuity, session, and
  zero-recurrence gates passed.  The mandatory harness-safety preflight then
  rejected the unchanged skill dependency
  `Get-ArgosControlTransportState.ps1` with
  `MISSING_NON_MUTATING_MODE` and
  `CONDITIONAL_COLLECTION_ASSIGNMENT_CAN_SCALARIZE` at its `$state`
  assignment.  The inventory script was not executed and no RustDesk/RDP or
  JBOD input was sent.
- Cause: the transport inventory predates the current mandatory harness
  contract.  It declares only `ValidateWinRm`, not a distinct `Preflight` or
  `Rehearsal` mode, and assigns the output of a conditional containing an
  array branch directly to `$state`.  A skill instruction requiring the
  script does not exempt that relied-upon runner from the project harness
  gate.
- Mandatory preflight: before every direct-control transport inventory, pin
  the exact inventory-script hash and run
  `Confirm-ArgosPowerShellHarnessSafety.ps1 -Preflight` before executing the
  script or sending GUI input.  Require a declared strictly non-mutating mode
  and place any array boundary around the complete conditional assignment.
  A parser pass or an established historical use is not sufficient.
- Recovery: preserve the rejected hash
  `853776763BF5449E582CE5E1E163E7D44EED511ED43CD34A90A23ACD3C00720B`
  as non-executable evidence for this incident.  Do not bypass the transport
  preflight with `Invoke-ArgosJbodDirect.ps1 -Action Probe`.  A future direct
  observation requires a separately authorized, fresh, harness-qualified
  transport-inventory revision (and refreshed intent, path, wrapper,
  zero-recurrence, continuity, and session gates) or one bounded installed
  portal observation capability that can return the required runtime version.

## 2026-08-28 — A passing transport-inventory repair does not qualify the long Invoke clipboard class

- Failure signature: the operator authorized the bounded repair of the existing
  `Get-ArgosControlTransportState.ps1`.  Its fresh hash passed the harness,
  wrapper, Windows PowerShell 5.1 preflight, path, recovery, continuity,
  session, and zero-recurrence gates.  The resulting inventory reported no
  matching WinRM forward and no errors.  The separately authorized O3Q2
  1,826-character read-only runtime-version source was then sent once through
  the unchanged GUI direct runner, which still uses a 500-millisecond
  paste-to-Enter delay.  No nonce, command hash, terminal state, or runtime
  version returned before the 45-second boundary.  The command was not retried.
- Cause: the O3Q2 safety and preaction evidence qualified the repaired local
  inventory dependency but did not mechanically require the already documented
  deterministic complete-pasted-length calculation and equal-or-greater-length
  fixed-scalar rehearsal for the substantive `Invoke` clipboard class.  A
  passing local runner preflight does not prove that the nested clipboard paste
  was submitted or returned.  The timeout is a recurrence of the known long
  encoded-paste failure class, not runtime-version evidence.
- Mandatory preflight: every future substantive direct `Invoke` must pin the
  exact command-source length, complete constructed pasted-wrapper length,
  runner hash, and paste-to-Enter delay.  Its zero-recurrence contract must pin
  one fresh equal-or-greater-length fixed-scalar rehearsal terminal gate with
  exact nonce, command hash, PASS state, and non-truncated result.  A Boolean
  assertion or generic runner preflight is insufficient.  The substantive
  action is a hard stop when that dependency is absent.
- Recovery: preserve the failed O3Q2 observation attempt as withdrawn terminal
  transport evidence.  Do not rerun it, press Enter, clear the remote console,
  click blindly, or infer target execution.  Require the operator to report the
  current JBOD console state.  `CaptureConsoleText` is eligible only when the
  operator reports a visibly present parse/runtime error.  Any fresh rehearsal
  and successor require new namespaces, exact-length gating, refreshed recovery
  and zero-recurrence evidence, and must leave the stranded console untouched.

## 2026-08-28 — Function-local MyInvocation does not identify the script file

- Failure signature: the first local `O3TR1` exact-length rehearsal preflight
  passed parser, harness, wrapper, and path gates, then stopped under strict
  mode with `The property 'Path' cannot be found on this object.` No GUI focus,
  clipboard change, remote input, target execution, or terminal-gate write
  occurred.
- Cause: `Get-RehearsalPlan` evaluated `$MyInvocation.MyCommand.Path` inside a
  function. In that scope `MyCommand` identifies the function rather than the
  script file and does not expose the expected script `Path` property.
- Mandatory preflight: a Windows PowerShell entry point that needs its own path
  inside helper functions must capture the scalar `$PSCommandPath` once at
  script scope, reject an empty value, and pass or close over that captured
  scalar. Its exact `-Preflight` must exercise the helper before any external
  action; parser and static harness success are insufficient.
- Recovery: O3TR1 remains a local `DRAFT`. Correct the wrapper in place to use
  the script-scope path, refresh its manifest hash, and rerun parser, harness,
  wrapper, path, and exact Windows PowerShell 5.1 preflight gates. Preserve the
  original stranded JBOD console and send no remote input until all refreshed
  gates pass.

## 2026-08-28 — Get-Command does not resolve a script through LiteralPath

- Failure signature: after the O3TR1 script-scope path correction, the exact
  local preflight again stopped before GUI focus or remote input. Windows
  PowerShell 5.1 surfaced a null-method error; a non-mutating same-path local
  diagnostic identified line 193, where `Get-Command -LiteralPath` could not
  retrieve the direct runner and reported that `ArgumentList` is valid only
  for one cmdlet or script. No terminal gate was written.
- Cause: `Get-Command` has a `Name`-based command-discovery contract, not a
  filesystem `LiteralPath` contract. The invalid named argument did not return
  the one `ExternalScriptInfo` object whose parameter map the caller expected.
- Mandatory preflight: for an exact installed script consumer, call
  `Get-Command -Name <absolute-script-path> -CommandType ExternalScript
  -ErrorAction Stop`, materialize the complete result as an array, require
  exactly one row, and only then inspect its declared parameters. Do not infer
  filesystem-style parameter names for command discovery.
- Recovery: O3TR1 remains a local `DRAFT`; replace only the command-discovery
  call, refresh the wrapper hash in its invocation manifest, and rerun every
  parser, harness, wrapper, path, and exact Windows PowerShell 5.1 preflight.
  Preserve the original stranded console and send no remote input first.

## 2026-08-28 — A direct Windows PowerShell worker must not rely on Get-FileHash auto-loading

- Failure signature: frozen O3TR1 passed its direct Windows PowerShell 5.1
  script preflight, parser, harness, wrapper, path, recovery, continuity,
  transport-inventory, and zero-recurrence gates. The exact `.cmd` launcher
  then entered the local `-Gate` plan and stopped before invoking the direct
  runner with `Get-FileHash is not recognized`. The planned terminal gate was
  absent. No RustDesk focus, clipboard change, fresh remote console, JBOD
  input, target execution, or target mutation occurred; the original stranded
  console remained untouched.
- Cause: the rehearsal wrapper's `Get-Sha256File` helper depended on the
  module-exported `Get-FileHash` command. This contradicted the existing
  project rule that exact Windows PowerShell workers must use a script-local
  bounded .NET SHA-256 helper. A direct script preflight and a static `.cmd`
  wrapper check did not reproduce the exact `.cmd`-launched module environment.
- Mandatory preflight: every fresh direct-control launcher must use a
  script-local bounded .NET SHA-256 implementation for file hashes. Its exact
  `.cmd` must automatically invoke the target's non-mutating `-Preflight` first
  and continue to the one-attempt gate only after PASS. The wrapper gate must
  pin that exact flow; a direct script preflight in a different host boundary
  is not sufficient.
- Recovery: O3TR1 and its frozen manifest, source, wrapper, preaction, and
  absent planned terminal gate are withdrawn and non-reusable. Do not rerun or
  patch them. Use a fresh O3TR2 namespace with the existing unchanged direct
  runner, a .NET hash helper, refreshed recovery/length/path/wrapper/harness/
  continuity/transport/zero-recurrence gates, and at most one fresh-console
  rehearsal. Preserve the original stranded console throughout.

## 2026-08-28 — Complete long paste does not prove the direct runner's Enter took effect

- Failure signature: frozen O3TR2 used the unchanged qualified direct runner,
  a script-local .NET SHA-256 helper, an exact `.cmd` preflight-to-gate flow,
  and a 6,935-character complete pasted command versus the failed O3Q2
  command's 6,347 characters. The runner opened one fresh JBOD PowerShell
  console and attempted the one authorized remote input, but no exact scalar,
  nonce, or command hash returned before its 60-second boundary. The signed
  local terminal gate records `FAIL_O3TR2_EQUAL_LENGTH_REHEARSAL`, target
  execution unconfirmed, and no target mutation. The operator's immediate
  visual observation then showed the fresh foreground console with the long
  command and `;exit` suffix completely visible and the cursor still at its
  end, with no returned prompt or visible parse/runtime error. The original
  background console remained visible and untouched.
- Cause: the long clipboard paste completed, but the runner's subsequent Enter
  action did not take effect in the intended fresh console before timeout. The
  available evidence does not distinguish a focus loss, ignored keystroke, or
  timing defect, so no narrower cause may be assumed. Equal-or-greater pasted
  length alone qualifies paste completion but not command submission.
- Mandatory preflight: a future direct-control capability revision for long
  commands must separately and deterministically prove both complete paste and
  command submission in a fresh disposable console. The gate must identify the
  exact focused window/console, prove that the cursor leaves the pasted input
  through a returned nonce-bearing scalar, and fail without retry when Enter is
  not observed to take effect. A longer delay, a second Enter, or a blind
  keystroke is not an acceptable inference-based repair.
- Recovery: withdraw O3TR2 and retain its terminal gate as non-reusable
  transport evidence. Do not press Enter, clear either console, capture console
  text, replay O3TR2, or send another fresh command. Preserve both visible
  consoles untouched. The notch workflow has a direct-transport capability gap
  until one separately authorized endpoint/runner capability improvement can
  prove command submission without retry, or the operator explicitly directs a
  bounded manual recovery after reviewing this exact state.

## 2026-08-28 — A qualified short trigger does not prove a heavier payload returned

- Failure signature: O3TC1 had qualified one disposable fresh-console
  `hostname|clip` plus file-backed clipboard payload and 11-character
  `iex(gcb -r)` trigger using native `VK_RETURN`. Frozen O3RO1 reused that
  exact entrypoint and passed all recovery, harness, wrapper, path, continuity,
  session, transport-inventory, and zero-recurrence gates. Its fresh console
  returned exact hostname `A1025645101`, and the runner submitted the payload
  trigger once, but no exact O3RO1 schema/nonce/state/scalar returned within
  90 seconds. Two bounded local clipboard checks after timeout found the exact
  4,069-character payload source unchanged, with no pass or failure result.
- Cause: the terminal failure was caused by absence of a synchronized result
  before the frozen timeout while the local clipboard remained the payload.
  This evidence does not prove whether the short trigger failed to execute,
  whether exact `D:\AFCV1\rt\python.exe` started and remained blocked during
  import, or whether it exited before `clip.exe` received the result. O3TC1's
  fixed-scalar qualification proved the transport primitive only; it did not
  qualify the runtime cost or completion behavior of the later payload.
- Mandatory preflight: before another runtime-version attempt, use a fresh
  read-only namespace to observe only exact process identity, executable path,
  command line, creation time, and running count for the O3RO1 Python command.
  Do not touch the O3RO1 console, send a second Enter, replay its payload, or
  infer execution from `payloadTriggerSubmitted`. Any future version query
  must be split into bounded stages whose timeout covers independently observed
  runtime behavior and whose exact payload always returns a compact failure
  result for a completed PowerShell path.
- Recovery: O3RO1 is withdrawn after one execution and cannot be retried or
  used as a publication parent. Preserve every existing console untouched.
  Perform at most one separately gated fresh-console process-state observation
  with no image read, process management, installed change, or target mutation.
  If no exact O3RO1 process is running, stop and classify command execution as
  unproved; if one is running, continue only with non-mutating observation and
  do not terminate or restart it.

## 2026-08-28 — A result producer must implement every property its strict-mode runner reads

- Failure signature: frozen O3RO2 passed payload parser/harness/Windows
  PowerShell 5.1 preflight, runner wrapper/preflight, path, recovery, clone,
  collection, transport-inventory, continuity/session, and zero-recurrence
  gates. The final caller/consumer audit before execution found that the
  payload returned `processManagementPerformed`, while the unchanged qualified
  O3TC1 runner reads `taskOrProcessManagementPerformed`. No remote input,
  target execution, terminal gate, observation gate, or target mutation
  occurred.
- Cause: the new result producer and frozen consumer used different property
  names for the same safety assertion. Under the runner's strict mode, reading
  the absent property would throw after a result arrived and misclassify the
  otherwise bounded observation as a transport failure. Parser and independent
  producer/consumer preflights did not exercise their joined result schema.
- Mandatory preflight: before freezing any payload consumed by an unchanged
  direct-control runner, mechanically enumerate every remote-result property
  the exact runner reads and require the payload's success and failure objects
  to implement that complete set with exact names and compatible types. The
  joined fixture must exercise the exact consumer expressions under Windows
  PowerShell 5.1 strict mode; separate source hashes and separate preflights are
  insufficient.
- Recovery: withdraw O3RO2 unexecuted and retain it only as non-reusable
  evidence. Use a fresh namespace whose payload differs only by implementing
  the exact required `taskOrProcessManagementPerformed` property in both
  success and failure results, then refresh every dependent hash and gate. Do
  not patch, rerun, or use O3RO2 as a parent.

## 2026-08-28 — A progress marker does not bound an in-process CIM query

- Failure signature: frozen O3RO3 passed the joined producer/consumer result
  contract, exact Windows PowerShell 5.1 payload preflight, transport, wrapper,
  harness, path, recovery, continuity/session, and zero-recurrence gates. Its
  one authorized fresh-console execution returned the exact hostname and then
  synchronized the exact progress schema, nonce, and computer name before the
  process query. The same progress marker remained in the clipboard after the
  60-second terminal boundary and again at least 36 seconds later. No terminal
  success or compact failure result returned.
- Cause: the payload called `Get-CimInstance Win32_Process` directly in its
  execution thread. The outer transport timeout bounded only the local wait;
  it could not interrupt or convert a non-returning remote CIM operation into
  the payload's compact failure schema. The progress marker proves the short
  trigger and payload started, so this is not an Enter, paste, or transport
  failure.
- Mandatory preflight: a direct observation operation must be selected from a
  fixed typed request schema and implemented by one hash-pinned executor. Each
  operation must declare and mechanically enforce its own timeout, maximum row
  count, maximum field lengths, and success/failure result shape. Validate the
  request producer, executor dispatch, every success/failure result fixture,
  and the exact transport consumer as one joined contract before freeze. An
  outer wait timeout or a pre-query progress marker is not operation timeout
  evidence. Do not introduce another one-off payload for the same observation.
- Recovery: withdraw O3RO3 after its single execution and do not retry, press
  Enter, close its console, terminate its query, or manage any related process.
  Preserve the progress and terminal gates as non-reusable evidence. Inventory
  the existing project observers first; then build only the smallest reusable
  schema-driven read-only executor needed to close the capability gap. If a
  timeout-safe process observation cannot be proven locally under the exact
  Windows PowerShell 5.1/.NET contract, retain process state as unknown and
  stop before another live process or runtime query.

## 2026-08-28 — OrderedDictionary keys are not PSObject property metadata

- Failure signature: the draft schema-driven observer passed parser and
  harness safety, then its first Windows PowerShell 5.1 preflight reported all
  declared result fields missing and reported only `Count`, `Keys`, `Values`,
  `IsReadOnly`, and other collection metadata as extra fields.
- Cause: success and failure fixtures were ordered dictionaries. Enumerating
  `$value.PSObject.Properties.Name` inspected the dictionary object's CLR
  metadata rather than its schema keys, even though PowerShell's adapter still
  permits convenient `$value.schema` access.
- Mandatory preflight: exact-property-set validation must branch on
  `System.Collections.IDictionary` and enumerate its `.Keys`; use
  `PSObject.Properties.Name` only for non-dictionary objects. Exercise both a
  deserialized JSON object and the executor's native ordered result object in
  the joined producer/consumer preflight.
- Recovery: because the executor and request were still local `DRAFT` bytes
  and no clipboard, remote input, or target query occurred, correct the helper
  in place, rerun harness safety, and repeat every result fixture. Do not
  loosen the exact field set or convert the transport consumer to permissive
  optional access.

## 2026-08-28 — SwitchParameter arithmetic and bare JSON Booleans are not PowerShell contracts

- Failure signature: two draft preflights stopped locally before their target
  actions. One attempted `[int]$Preflight` on a `SwitchParameter`; another
  used bare `true`/`false` tokens inside a PowerShell ordered result and tried
  to invoke commands named `true` or `false`.
- Cause: JSON and PowerShell syntax were mixed into the orchestration layer,
  and switch selection was treated as numeric conversion rather than explicit
  control flow. Parser success does not detect either runtime mistake.
- Mandatory preflight: count selected switches with explicit `if ($Switch) {
  $modeCount++ }` statements. PowerShell Boolean values are always `$true` and
  `$false`; native `true`/`false` belongs only in JSON. The exact non-mutating
  preflight must construct every returned object before any execution or
  output write.
- Recovery: correct only the local `DRAFT` bytes, rerun harness and wrapper
  safety, and rerun the exact Windows PowerShell 5.1 preflight. No fresh
  product namespace is required when no artifact was frozen, signed,
  published, executed externally, or written to its final gate path.

## 2026-08-28 — Recovery evidence state and evidence classification are separate schemas

- Failure signature: the frozen O3SO1 recovery intent referenced an exact gate
  whose own state was `WITHDRAWN`, and copied that value into the intent's
  `failureEvidence[].state`. `Confirm-ArgosRecoveryIntent.ps1` rejected it with
  `FAILURE_EVIDENCE_CLASS_INVALID` and `LOCAL_FAILURE_COUNT_UNPROVED` before a
  payload build or remote input.
- Cause: the referenced artifact state was confused with the recovery-intent
  evidence classification. The gate must itself contain state `WITHDRAWN`,
  while its record inside `failureEvidence` must declare the validator's class
  `WITHDRAWN_LOCAL_REHEARSAL_FAILURE` so it contributes to the mechanically
  proved local-failure count.
- Mandatory preflight: before setting a recovery intent to `FROZEN`, enumerate
  the exact accepted evidence classes from the pinned validator and test every
  referenced gate's own state separately. Keep the intent `DRAFT` until this
  exact preflight passes; source-file existence and hash equality do not prove
  evidence-class compatibility.
- Recovery: withdraw O3SO1 because its intent was already marked `FROZEN`.
  Create a fresh O3SO2 namespace, classify every withdrawn local gate as
  `WITHDRAWN_LOCAL_REHEARSAL_FAILURE`, increment the proved local-failure count,
  and rerun recovery preflight before creating a request or payload. Preserve
  the independently qualified generic observer schemas/executor; do not use
  any O3SO1 artifact as an execution or publication parent.

## 2026-08-28 — A nested executor preflight does not satisfy the generated entrypoint contract

- Failure signature: O3SO2's payload builder passed its own harness/wrapper
  checks, joined schema rehearsal, exact request validation, path budget, and
  zero-recurrence gate, then created the frozen combined payload. Guarding that
  exact generated `.ps1` reported `MISSING_NON_MUTATING_MODE`: the embedded
  executor declared `-Preflight`, but the generated file's top level declared
  no parameters or preflight return guard. No remote input occurred.
- Cause: builder preflight validated the nested executor and the combined
  syntax, but did not apply the mandatory harness guard to the exact generated
  entrypoint shape before writing frozen output. Static harness discovery does
  not treat a parameter block nested inside an invoked scriptblock as the
  outer entrypoint's non-mutating mode.
- Mandatory preflight: a generated direct-observation payload must itself
  declare a top-level `-Preflight` switch, keep the executor in one scriptblock,
  route top-level preflight to the nested executor's preflight and return, and
  use the unchanged no-argument path only for the qualified short trigger's
  live execution. Before freezing, construct those exact bytes in memory and
  require the same top-level parameter and return-guard shape that the harness
  will inspect; after build, guard the exact file again.
- Recovery: withdraw O3SO2 and preserve its payload/build gate as non-reusable
  evidence. Keep the request/result schemas and executor V1, which passed their
  independent gates. Create a fresh composer V2 and O3SO3 namespace; never use
  the O3SO2 payload or composer V1 as a template or execution parent.

## 2026-08-28 — Escaped drive-path tails can look like synthetic UNC roots to clone remediation

- Failure signature: O3SO3's exact generated payload passed parser, harness,
  top-level preflight, and rehearsal. Clone-literal preflight correctly found
  the added real root `D:\AFCV1`, but also classified the JSON-escaped tail
  `\\rt\python.exe` inside `D:\\AFCV1\\rt\\python.exe` as a second
  UNC-looking root. The R1 manifest declared only the real drive root and was
  conservatively rejected before remote input.
- Cause: clone-remediation drive detection normalizes repeated backslashes,
  while its UNC detector separately inspects the original escaped source text.
  A JSON-escaped Windows drive path can therefore yield both its real drive
  root and a synthetic UNC-looking suffix token.
- Mandatory preflight: when a generated PowerShell payload embeds JSON paths,
  run clone remediation in preflight and mechanically inventory every reported
  root. Declare the real drive root and any exact synthetic escaped-tail token
  separately; do not treat the synthetic token as a real route, share, or
  authorization boundary. Keep the generated bytes unchanged.
- Recovery: preserve the failed R1 invocation. This is a conservative guard
  false positive with no target execution, so retain O3SO3 and create a fresh
  R2 remediation manifest that classifies both `D:\AFCV1` and the exact
  synthetic `\\rt\python.exe` token as `ADDED`; rerun preflight and the
  create-new evidence gate before any transport execution.

## 2026-08-28 — CIM operation timeout is not a hard wall-clock boundary

- Failure signature: the schema-driven O3SO3 process observer passed exact
  request/result schema, Windows PowerShell 5.1 ZERO/ONE/MANY/ERROR/TIMEOUT,
  wrapper, harness, clone-remediation, path, recovery, continuity/session, and
  zero-recurrence gates. Its one authorized JBOD execution returned the exact
  progress schema, nonce, request hash, operation, and computer name, but no
  terminal result within the 60-second transport boundary. The 8-second
  `Get-CimInstance -OperationTimeoutSec` request budget did not return control
  to the executor's stopwatch/catch boundary.
- Cause: `OperationTimeoutSec` configures the CIM operation but is not an
  externally enforced hard wall-clock cancellation boundary for a locally
  blocked `Get-CimInstance Win32_Process` call. A stopwatch checked before and
  after a synchronous cmdlet cannot interrupt the cmdlet while it is blocked.
  Local fixture TIMEOUT success therefore did not prove the exact live Windows
  provider call would return within that budget.
- Mandatory preflight: a live observer must not claim hard timeout behavior
  from `OperationTimeoutSec`, a stopwatch, or synthetic fixtures alone. Before
  reuse, the exact provider call must pass an environment-authentic terminal
  timing gate, or the provider must run behind a separately authorized,
  ownership-pinned, externally enforceable isolation boundary whose timeout
  cleanup is itself within authority. Emit stage-specific progress before
  every potentially blocking provider/property call so terminal absence can
  be localized without a retry.
- Recovery: withdraw O3SO3 after its single execution and never retry or use
  its generated payload, composer, or executor as a live execution parent.
  Do not touch its fresh console or any process it may own. Preserve the exact
  progress marker and failed terminal gate as read-only evidence. Retain O3RO1
  process state and command execution as unknown and stop before another live
  process query, runtime-version attempt, or numeric successor unless a
  separately authorized timeout-isolated endpoint capability is available.

## 2026-08-28 — A target runtime premise cannot inherit a different interpreter's module version

- Failure signature: O3Q2 pinned exact JBOD paths and hashes for
  `D:\AFCV1\rt\python.exe` and `D:\AFCV1\INSTALLATION.json`, but its runtime
  gate retained state `PASS_O3P2_LOCAL_RUNTIME_INSTALLED` and NumPy `2.5.1`
  from the laptop-only `C:\A3P2R` CPython 3.14 rehearsal. The original FOI1
  portable runtime and installer had already frozen JBOD CPython `3.13.2`,
  OpenCV `5.0.0`, and NumPy `2.5.2`. O3Q2 therefore returned a signed premise
  failure before image read even though the exact JBOD executable and
  installation-manifest hashes matched.
- Cause: target runtime identity and local rehearsal compatibility were
  conflated. Exact path/hash checks correctly proved which JBOD runtime was
  present, but the expected NumPy value was copied from a different Python
  ABI/runtime root instead of being derived from the target runtime's own
  qualified installation evidence.
- Mandatory preflight: every runtime-binding contract must mechanically join
  runtime role, Python path/hash/version, installation-manifest path/hash,
  bundle or wheel identity, OpenCV version, and NumPy version. Reject any
  target gate whose state token names a different runtime, whose module
  versions come only from another interpreter/ABI, or whose expected versions
  contradict the target's original signed install gate or a newer exact signed
  observation with the same executable and installation hashes. A local
  rehearsal proves algorithm compatibility only; it never supplies the live
  target's version premise.
- Recovery: preserve O3Q2 as withdrawn/no-retry and preserve its signed failure
  as evidence. Use the original FOI1 portable/install gates plus O3EI1's exact
  signed version observation to correct the false contract premise to NumPy
  `2.5.2` without changing runtime bytes. Any later numeric execution must be a
  fresh independent namespace using the unchanged detector/config and locked
  sources; neither O3Q2 nor O3EI1 is an execution parent.

## 2026-08-28 — A PowerShell `foreach` statement cannot feed a pipeline without an expression boundary

- Failure signature: two bounded local evidence-inventory commands ended in
  parser error `An empty pipe element is not allowed` at `} | ConvertTo-Json`.
- Cause: a statement-form `foreach (...) { ... }` was placed directly before a
  pipeline. Windows PowerShell and PowerShell 7 require that output to be
  materialized or enclosed as an expression before it can feed the next
  command.
- Mandatory preflight: never emit `} |` after a statement-form loop. Use
  `$rows = @(foreach (...) { ... })` and pipe `$rows`, or wrap the complete loop
  in `@( ... )` before the pipeline. Apply this shape mechanically to bounded
  JSON evidence inventories.
- Recovery: the failed commands were read-only and wrote no artifact. Preserve
  no output from them; rerun only the corrected materialized-array form.

## 2026-08-28 — PowerShell variable names collide case-insensitively with automatic variables

- Failure signature: the first O3Q3 local endpoint rehearsal started its owned
  Python child and then failed at `$pid = [int]$child.Id` with `Cannot
  overwrite variable PID because it is read-only or constant`. No terminal
  result or output root was produced by the PowerShell endpoint.
- Cause: PowerShell variable names are case-insensitive. The local name `$pid`
  therefore addressed the built-in read-only `$PID` automatic variable rather
  than a new writable variable. Static parsing and the non-executing preflight
  path did not exercise this assignment after child creation.
- Mandatory preflight: no new or changed PowerShell harness may assign to a
  name that case-insensitively matches a built-in read-only automatic
  variable. At minimum, mechanically reject assignments to `PID`, `HOME`,
  `Host`, `MyInvocation`, `PSCommandPath`, and `PSScriptRoot`; also avoid local
  names that shadow other automatic variables such as `Error`, `Args`,
  `Input`, or `Matches`. Deliberate assignments to governing preference
  variables such as `$ErrorActionPreference = 'Stop'` remain allowed. Exercise
  the exact owned-child start/result-construction path with a bounded benign
  fixture before any image-processing rehearsal.
- Recovery: do not query, stop, or otherwise touch the child that may have
  started; retain its state as unknown. Withdraw the executed O3Q3 rehearsal
  namespace and do not reuse its endpoint or invocation as an execution
  parent. Create a fresh rehearsal namespace and output root, rename the local
  field to an unambiguous name such as `$ownedChildProcessId`, rerun all exact
  static, collection, recovery, wrapper, path, and zero-recurrence gates, and
  only then run one fresh local rehearsal. This local failure did not publish
  or consume the one authorized live Slot16 successor.

## 2026-08-28 — A response locator must bound the post-publication cohort, not the historical root

- Failure signature: the first O3Q4 response locator selected the first 21
  top-level ready ZIPs from the shared response root and then stopped with
  `response root exceeded the bounded 20-ZIP discovery limit`. The root
  legitimately contained more than 20 historical responses; the locator did
  not reach manifest correlation and made no remote change.
- Cause: the row cap was applied to the complete historical response root
  instead of to the exact cohort created at or after the O3Q4 publication
  timestamp. The cap therefore measured retention history rather than the
  bounded response candidates for the published request.
- Mandatory preflight: a post-publication response locator must freeze the
  exact publish-gate timestamp and lazily enumerate only top-level ready ZIPs
  whose last-write time is at or after that timestamp, with a small documented
  clock-skew allowance. Apply the row cap after this time predicate, then read
  only bounded manifests and require zero or one exact request-ID match.
- Recovery: withdraw the executed read-only locator as non-parent and do not
  retry it. Preserve the single published request unchanged. Use a fresh
  locator namespace keyed to the signed request ID and exact publish-gate
  timestamp; do not republish, scan processes, or mutate the response share.

## 2026-08-28 — A runtime-gate producer state must match every pinned consumer predicate

- Failure signature: O3Q4 supplied correct file-backed JBOD runtime evidence
  with state `PASS_O3RV1_FILE_BACKED_JBOD_RUNTIME_PREMISE` and correct Python
  `3.13.2`, OpenCV `5.0.0`, and NumPy `2.5.2`, but unchanged O3P8 stopped in
  `load_job` with `ValueError: O3P8 runtime gate is not PASS.` before image
  read. O3P8 line 120 accepted only the hard-coded predecessor state
  `PASS_O3P2_LOCAL_RUNTIME_INSTALLED`.
- Cause: the new runtime-gate producer schema was validated by the O3Q4
  endpoint wrapper but not mechanically compared with the independent O3P8
  consumer predicate. Version and file hashes were compatible; the state-token
  vocabulary was not. Local O3Q4 rehearsal used a predecessor-compatible
  runtime-gate fixture and therefore did not exercise the exact live gate state.
- Mandatory preflight: freeze the exact runtime-gate state set and mechanically
  inspect every packaged consumer of that file before signing. The exact live
  gate bytes—not a semantically equivalent rehearsal fixture—must pass each
  consumer's non-image `load_job` path under the packaged runtime. Reject a
  producer state that any consumer hard-codes out, and reject a rehearsal whose
  runtime-gate state differs from the live payload state.
- Recovery: O3Q4 is signed-terminal failed, withdrawn, and no-retry. Do not
  relabel the correct O3RV1 evidence as the old laptop-runtime state, change
  thresholds/algorithms, or run another runtime observation. O3Q2 plus O3Q4 are
  two signed premise/contract failures in the same incident, so mutation
  stop-loss is active. A future non-algorithmic runtime-gate compatibility
  improvement and fresh numeric namespace require workflow review and a new
  intent that explicitly clears stop-loss; they are not authorized here.

## 2026-08-28 — A source-alias gate must match the drive actually written into the engine job

- Failure signature: static review after O3Q4 withdrawal found that its live
  invocation declared and its endpoint created source alias `Q:`, while the
  job contract still supplied BF/DF paths rooted at `F:`. Its route gate then
  verified the stale `F:` leaves and asserted that the endpoint created the
  verified alias. O3Q4 stopped at the runtime-gate consumer before image read,
  so this is a latent package-contract mismatch rather than an observed image
  execution failure.
- Cause: the alias lifecycle, route path inventory, and engine-job input-path
  materialization were independently declared. The endpoint created one drive
  but copied already rooted predecessor paths into the job, and the route gate
  never mechanically compared those roots.
- Mandatory preflight: store source identities as exact source-root-relative
  paths. Construct every engine input path from the one invocation-pinned alias
  only after that alias is created. Mechanically require the invocation alias,
  constructed job-path drive, route-gate alias rows, and cleanup target to be
  identical; reject any rooted input path in the job contract and any second
  drive token. Include the exact constructed BF/DF leaves in the non-mutating
  endpoint preflight and final route gate.
- Recovery: keep O3Q4 withdrawn and non-parent. Do not patch or replay its
  endpoint, job, or route gate. A fresh successor must use a fresh job schema
  with relative BF/DF leaves, a fresh endpoint that materializes the pinned
  alias paths, and a source-binding gate before package construction.

## 2026-08-28 — A package path gate must expand the final payload leaf set through the deepest archival root

- Failure signature: the signed local O3Q6 package passed its conservative
  64-path planning gate, but the exact post-signing cross-product found six
  request leaves with effective lengths from 200 through 207. The missed
  roots were `requests_from_gateway\pending` and
  `endpoint_jbod\processed\completed`; the missed leaves included the nested
  O3Q5 adapter, O3P8 engine, and detector-equivalence gate. No package was
  published or launched.
- Cause: the pre-signing plan modeled representative predecessor payload
  names and the endpoint pending root instead of freezing the final package's
  complete internal leaf set and expanding every leaf across every request
  receive, send, pending, processed, completed, and archive root. A later
  exact gate therefore discovered a route layout that the planning gate had
  not represented.
- Mandatory preflight: before signing, freeze the exact proposed request ID
  (or its maximum length), final payload-relative leaf set, and every expanded
  request root. Mechanically cross-product every leaf through all roots,
  including `requests_from_gateway\pending` and
  `endpoint_jbod\processed\completed`, then append ZIP, response, maintenance,
  compact-failure, output, and source-alias leaves. Run
  `Confirm-ArgosPathBudget.ps1` on that complete set and require every
  effective length below 200 before the first signature.
- Recovery: retain the signed O3Q6 ZIP only as withdrawn terminal local
  evidence; it is non-publishable and not a package parent. Do not rename,
  patch, or re-sign it. Use a fresh package namespace assembled from the
  independently qualified exact endpoint and locked detector inputs, with an
  independently constructed shorter request identifier that the unchanged
  qualified portal consumers accept, and pass the full exact route
  cross-product before signing once.

## 2026-08-28 — PowerShell permits a missing return-expression space to survive static parsing

- Failure signature: the first O3B8 exact-package rehearsal stopped locally
  with `The term 'return[ordered]@' is not recognized`. The harness was valid
  PowerShell syntax to the parser, but it attempted to invoke the combined
  token as a command when the helper function executed. No JBOD action or
  signed-package change occurred.
- Cause: a mechanically compacted helper omitted the required whitespace in
  `return [ordered]@{...}`. Parser-only safety cannot prove that every legal
  token sequence has the intended runtime meaning.
- Mandatory preflight: search new or transformed PowerShell harnesses for
  `return[` and reject it before execution. Exercise every helper function in
  the exact local rehearsal, not only the script parser and top-level
  preflight branch.

## 2026-08-29 — Manually reproduced regression manifests can corrupt pinned hashes and paths

- Failure signature: the signed R19 backside-notch actual-wafer regression
  stopped before image decode on its first case with `DF source changed`.
  Exact comparison to the frozen R18 case manifest proved the R19 DF SHA-256
  was truncated from 64 to 55 characters; two later source paths had also been
  silently changed while reproducing the JSON. The detector never started and
  no test output was created.
- Cause: a frozen regression case manifest was manually retyped instead of
  mechanically cloned and compared. JSON parsing, PowerShell parsing, package
  signature validation, and source-file existence do not prove that copied
  hash/path fields equal the predecessor.
- Mandatory preflight: mechanically compare every successor case to its frozen
  predecessor. Require exact equality for identity, BF/DF paths, BF/DF hashes,
  and expected state; permit only explicitly declared output-root changes.
  Independently require every SHA-256 field to match `^[A-F0-9]{64}$` before
  signing. Any difference must be emitted as a bounded machine-readable row
  and is a hard stop.
- Recovery: R19 is signed-terminal failed, withdrawn, no-retry, and non-parent.
  Pin one read-only post-failure rollback observation, then use a fresh
  namespace whose case manifest is mechanically derived from exact R18 bytes.
- Recovery: correct only the unfrozen local harness token, rerun harness
  safety and the exact success/injected-failure rehearsal, and preserve the
  abandoned create-new fixture under a clearly failed local-evidence name.

## 2026-08-31 — DATA_PULL response layouts must come from the installed producer contract

- Failure signature: the successful signed GUIHV1 read-only response declared
  `DATA_PULL_PAYLOAD.zip` at the response-package root, while the local
  collection assumption and prepublication path row used
  `payload/DATA_PULL.zip`. Signature verification passed and no target action
  failed; the mismatch stopped only the first local nested-payload lookup.
- Cause: the response payload leaf was reconstructed from a generic layout
  assumption instead of copied from the qualified installed DATA_PULL
  producer contract and frozen in the request-specific return-path gate.
- Mandatory preflight: pin the exact installed producer's emitted response
  leaf name and placement. Expand that literal leaf through response partial,
  ready, sent, share, laptop archive, and extraction roots; after receipt,
  require the signed manifest to declare the same literal leaf before lookup.
- Recovery: keep the already verified response and request unchanged. Read the
  manifest-declared `DATA_PULL_PAYLOAD.zip`, verify its declared hash, and
  continue in the existing create-new short extraction root. Do not republish
  or retry the request.
