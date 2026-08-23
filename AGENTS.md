# AGENTS.md — ArgosEdgeLab Governing Instructions

These instructions apply to the entire workspace.

## Mandatory Windows/JBOD failure-prevention memory

Before building or launching any Windows batch, mapped-drive analysis,
portable installer, JBOD hotfix, relay/portal step, or long-running inspection,
read and apply `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.  That file is the
project's durable operational memory for previously observed path, drive,
PowerShell, disk-space, file-lock, task-discovery, package-layout, and
installed-predecessor failures.  Do not rediscover a documented failure by
trial and error.  Record any genuinely new failure signature, its cause, its
preflight, and its recovery in that file before continuing the affected work.

The failure memory is not a passive checklist. Before publishing or launching
any new or changed Windows/JBOD package, launcher, portal request, long-running
inspection, or before promoting a new continuity checkpoint, apply
`work/ARGOS_ZERO_RECURRENCE_PREACTION_POLICY.md`, create a file-backed
pre-action contract from
`work/templates/ARGOS_ZERO_RECURRENCE_PREACTION.template.json`, and run
`utilities/Confirm-ArgosZeroRecurrencePreaction.ps1 -Preflight` against both the current
history audit and that exact contract. A mechanically cloned predecessor,
guessed root/hash/state/switch/task principal, declaration broader than the
implemented action, unresolved legacy mismatch, or missing exact dependency
hash is a hard stop. An already executed legacy artifact with a disclosed
declaration mismatch may be retained as terminal evidence only when its exact
signed response proves the bounded action; it is non-reusable and cannot be a
template or publication parent. A checkpoint written before this audit is
provisional and must be superseded, never silently treated as authoritative.

## Mandatory recovery classification, observation lane, and stop-loss

Before designing a successor for a failed Windows/JBOD/portal/processor
recovery, read and apply `work/ARGOS_RECOVERY_OBSERVATION_AND_STOP_LOSS.md`,
create a file-backed intent from
`work/templates/ARGOS_RECOVERY_INTENT.template.json`, and run
`utilities/Confirm-ArgosRecoveryIntent.ps1 -Preflight` against that exact
intent. Classify the next step as `OBSERVE` or `MUTATE` before writing package
code.

`OBSERVE` is a distinct non-mutating lane. It must use an already installed and
qualified `STATUS`, `DATA_PULL`, or exact authorized admin/read-only route. It
must not use `MAINTENANCE_PATCH`, install a helper, change an installed file,
start/restart/stop a task or process, change a queue or ledger, read image
bytes, delete a source, or abort a wafer. An unchanged endpoint implementation
and route gate may be inherited only when the exact worker, installed config
evidence, and qualified gate hashes are pinned. If those existing capabilities
cannot supply the required evidence, stop with a capability gap and request
authority for one endpoint capability improvement; do not disguise observation
as maintenance.

After one signed terminal failure disproves a live-state premise, no later
mutation is allowed until a direct post-failure observation is pinned. After
two signed premise failures in the same incident, mutation stop-loss is active:
do not create another successor package until the workflow is reviewed and a
new intent explicitly clears the stop-loss. For GUI recovery, do not change GUI
code until the authoritative ledger/dashboard contains the expected rows and
the unchanged UI still fails to display them.

For a reported all-inspections or all-completed-lots visibility failure, a
named lot is a regression cohort rather than the success boundary. Reconcile
the complete bounded current catalog, explicit holds, ledger, and dashboard
identity sets; do not redefine success as the named sample appearing.

When an authoritative producer emits an enumerated identity, eligibility, or
state set that multiple installed consumers use, freeze that exact producer
set and mechanically compare every consumer predicate before publication. A
consumer may narrow the set only with an explicit domain-scoped invariant and
a negative regression control for all unaffected domains. A new producer state
must never be accepted by only some of inventory, processing, ledger, dashboard,
or GUI refresh code.

For every changed or relied-upon runner, resolve each named argument against
`Get-Command` for the exact paired installed consumer under Windows PowerShell
5.1. Source hashes alone do not prove caller/consumer compatibility. A live
restart gate must execute the runner's exact non-scoring `-Once -PlanOnly` path;
do not replace that path or its state reader with a precomputed result object.

A completed result whose acquisition fingerprint has been superseded is not a
current-acquisition result. Identity uniqueness alone is never provenance and
must not re-admit that result to the current dashboard. Reuse is allowed only
when the result records exact source-byte hashes and those hashes match the
current acquisition's exact source bytes; otherwise retain the result only as
explicitly historical evidence or reprocess the current acquisition. Mutable
state used by WinForms event callbacks must be anchored to a captured
form/control object or another explicitly shared object. Do not rely on
script-scope variables being visible inside callback runspaces.

An installed output producer must actually run successfully before an
entrypoint validates fields or counts that only that producer can create.
Installing new producer bytes, checking for source-code tokens, or running a
different upstream `-PlanOnly` path is not output evidence. Read the producer's
own terminal status first, then validate the exact output revision it wrote.
If the producer is intentionally nonblocking, retained predecessor output must
be treated as predecessor output rather than as a failed instance of the new
schema.

Artifacts have explicit lifecycle states. `DRAFT` bytes may be corrected in
place before freeze, signature, execution, publication, or external mutation.
`FROZEN` bytes are immutable. A failed `FROZEN`, `SIGNED`, `PUBLISHED`, or
executed artifact is withdrawn and requires a fresh namespace. A malformed
guard invocation, conservative-guard false positive, or draft-manifest omission
that changed no target bytes does not by itself require a new product revision;
correct the draft or invocation, record the cause when genuinely new, and rerun
the exact gate.

Path length must be rejected during planning, not discovered during launch.
Before creating a new output root, extracting a package, or launching any
Windows PowerShell 5.1/.NET workflow, apply
`work/ARGOS_PATH_LENGTH_SAFETY.md` and run
`utilities/Confirm-ArgosPathBudget.ps1` against every planned source and the
longest possible output path with suffix reserve. An effective length of 200
or more requires a verified short alias/staging root before the first write;
230 or more is a hard stop. New path components longer than 80 characters are
also a hard stop. Never wait for a runtime path error before shortening.

## Mandatory Project Portal round-trip and queue-safety gate

Moving a signed request into the engineering share's `requests\processed`
directory proves only that the gateway share importer accepted it. It does not
prove gateway-to-Argos delivery, Argos-to-JBOD delivery, endpoint execution, or
response return. Never describe a request as executed, failed, or complete
without a matching signed terminal response or direct exact-endpoint evidence.

Before signing or publishing any Project Portal `STATUS`, `DATA_PULL`,
`INSITE_DIAGNOSTIC`, or `MAINTENANCE_PATCH` request, enumerate the complete
round trip for every declared or maximum-possible result leaf. Include the
exact installed endpoint incoming/work roots, response partial/ready root,
response-sender watch/sent roots, every relay receive/archive root, gateway
share staging/archive roots, and the planned laptop extraction root. Preserve
the actual request/response token lengths, nested `parameters.relativePaths`,
`files[].path`, maintenance output layout, temporary suffixes, and required
suffix reserve. Run `utilities/Confirm-ArgosPathBudget.ps1` on every final
constructed leaf. If any installed root or maximum result layout is unknown,
the request is a hard stop. A ZIP, short source path, or small byte limit is not
evidence that its expanded or returned paths are safe.

Every signed portal request must have a machine-readable pre-publication path
gate beside its final ZIP. The gate must identify the exact request manifest
hash, installed route/config revision, all roots evaluated, longest relative
leaf, maximum path and component lengths at every hop, suffix reserve, and a
PASS disposition. `DATA_PULL` may preserve deep source-relative paths only when
all return hops pass. Otherwise use a separately rehearsed short endpoint root
or short deterministic returned names plus a signed source-to-return mapping;
never silently truncate, rename, omit, or flatten provenance.

Project Portal endpoint implementations must be queue-safe. Response path
preflight and response construction belong inside the per-request failure
boundary. If the normal response cannot be constructed, the endpoint must
commit a compact signed failure response from a reserved path-gated short root,
preserve the exact failed attempt in recoverable quarantine, and advance the
signed request to a terminal failed ledger state. A pre-existing deterministic
work root or response partial must be handled as an exact resumable match,
quarantined failed attempt, or explicit hold; it must never escape the loop as
a process-fatal collision. Scheduled-task restart counts are not a recovery
mechanism, and one malformed or overlong request must not remain at the queue
head or prevent later requests from receiving terminal responses.

The exact packaged portal code must pass a Windows PowerShell 5.1/.NET
round-trip rehearsal before publication. Exercise the longest real declared
leaf, effective path boundaries below 200, at 200, at 229, and at 230 or more,
an injected response-construction failure, a pre-existing work/partial
collision, process termination between handler completion and response commit,
restart, idempotent receipt, and a second queued control request. The gate must
prove rejection before write for unsafe paths, a signed compact failure for a
runtime response error, no orphaned queue-head poison, and successful processing
of the control request. Store the machine-readable PASS artifact beside the
package.

For a bounded GUI-only patch whose signed manifest names fixed JBOD installed
destinations and whose task/process behavior cannot be represented faithfully
on the engineering laptop, do not create a fake laptop installation or claim
that mocked tasks/processes prove live behavior. A single operator-authorized
live transaction may serve as the environment-authentic round trip only when
all of the following are true before publication: the payload was derived from
signed exact-JBOD pulls; every payload, manifest, signature, predecessor, live
task definition, live task principal, and endpoint-worker hash is pinned; the
unchanged generic endpoint has an existing qualified queue-safety and rollback
gate; the exact entrypoint has passed Windows PowerShell 5.1 success and
injected-failure construction tests without changing the frozen payload; and
the entrypoint validates the real JBOD premises before its first task/process
action. Limit the live transaction to one request with no automatic retry. The
endpoint and entrypoint must roll back every installed byte on failure, return
a signed terminal response, restart only the explicitly authorized GUI tray,
and prove that the healthy processor PID and creation time did not change.
This exception never applies to processor, inspection, XML, training,
production-routing, deletion, source-image, fiducial, or wafer actions.

Do not publish a later request to the same endpoint while an earlier accepted
request lacks a signed terminal response, unless a bounded direct endpoint
audit proves the earlier request's exact queue/ledger state and proves the
endpoint and every return hop healthy. If the portal endpoint itself may be
unhealthy, recovery must use a separately rehearsed manual/admin path outside
that portal queue. Such recovery must verify and quarantine only exact artifacts
and must not restart detector, scribe, Insite, monitor, or inspection tasks.

PowerShell wrapper structure must also be rejected during planning, not debugged
through repeated operator launches. Before running a new or changed `.cmd` or
Windows PowerShell entry point, apply
`work/ARGOS_POWERSHELL_WRAPPER_SAFETY.md` and run
`utilities/Confirm-ArgosPowerShellWrapper.ps1` against the exact `.ps1`,
wrapper, and file-backed invocation manifest. Require one quoted scalar `.ps1`
after `-File`, Windows PowerShell 5.1 with `-NoProfile -ExecutionPolicy
Bypass`, a non-mutating `-Preflight` or `-Rehearsal` switch, and no `%*`,
`-Command`, `start`, or `Start-Process` wrapper hop. Complex arguments belong
in bounded UTF-8 JSON, not command-line Boolean, array, or expression text.
This rule also applies to direct `powershell.exe -File` utility calls: comma-
joined text is one scalar, not an array-valued parameter. Use one scalar per
process invocation or a file-backed JSON array, and assert the received count
and exact normalized values before acting.

PowerShell package/test harness defects must also be rejected before build or
signature. Apply `work/ARGOS_POWERSHELL_HARNESS_SAFETY.md` and run
`utilities/Confirm-ArgosPowerShellHarnessSafety.ps1` against the exact bytes of
every new or changed builder, signer, route test, endpoint rehearsal, response
collector, publisher, and operator launcher. A `-Preflight` action is strictly
non-mutating, including local evidence files and directories; durable output
requires a distinct `-Gate`, `-Build`, `-Test`, or `-Apply` action.

For any cloned or mechanically transformed harness, first guard every source
template, then create a complete file-backed literal-root remediation manifest
and run `utilities/Confirm-ArgosCloneLiteralRemediation.ps1` against every
source/generated pair. Every test, fake-drive, extraction, partial, quarantine,
response, production, and UNC root must be classified as an explicit
replacement or an allowed unchanged root; an undeclared literal or unchanged
predecessor root is a hard stop before execution or signature. Then guard every
generated script again. After those gates pass, freeze
entry-point/payload/predecessor/invariant hashes and the exact post-swap
rollback-injection design before the first signature. External
`powershell.exe` stdout is text: use an in-process script for typed objects or
explicit bounded JSON rehydration before property access. Machine gates must
emit bounded JSON or scalar rows, never width-dependent `Format-*` evidence.
PowerShell 7 `ConvertFrom-Json` can coerce ISO timestamp strings to `DateTime`
and later serialize them with host-local formatting, unlike Windows PowerShell
5.1. When JSON strings participate in hashes, keys, selectors, or signed
evidence, use the exact installed PowerShell host or PowerShell 7
`ConvertFrom-Json -DateKind String`; never hash or compare reserialized JSON
after an unverified cross-host conversion.
Do not recursively enumerate the whole project/work tree; use `rg` or one
bounded exact root with row and error caps. A harness-safety failure is a hard
stop before execution. A `FROZEN`, signed, executed, published, or externally
mutating artifact requires a fresh output root after the cause and prevention
are recorded. A `DRAFT` that has not crossed any of those boundaries may be
corrected in place under the lifecycle rule above.

When a gateway or JBOD host already exposes a working constrained Argos-only
maintenance endpoint that authorizes the required bounded action, use that
endpoint directly. Do not make the operator run another local package merely
because an earlier workflow depended on operator execution. When operator-local
execution is genuinely required, provide one rehearsed launcher that writes a
persistent create-new log, runs exact non-mutating preflight, automatically
continues into the pinned apply only after PASS, and leaves the result visible.
Do not send a preflight-only window that disappears or create a sequence of
manual launchers for the operator to relay one result at a time.

Raster provenance and rendered-layer semantics must be rejected before a
reviewer is presented, not inferred from filenames, dimensions, or DOM labels.
Apply `work/ARGOS_RASTER_PROVENANCE_SAFETY.md` and run
`utilities/Confirm-ArgosRasterProvenance.ps1` against the exact current
manifest. Every clean BF/DF or full-wafer base must hash-match its locked clean
source. Current detector heatmaps and imported operator feedback must remain
separate layers with exact source/mask/revision lineage. A composited heatmap
must change zero pixels outside its documented current mask. Inspect the exact
review ID in the real browser with feedback hidden and all full-wafer/native
heatmap toggles exercised before release. Any stale baked annotation,
predecessor preview, unexplained changed pixel, or missing full-wafer defect
heatmap is a hard stop requiring a fresh output root; never patch the
presented root or erase saved feedback.

## Mandatory reviewer launch, field-completeness, and coverage-semantics gate

A reviewer is not launched correctly merely because `index.html` opens. The
exact release URL must contain `?manifest=` followed by the percent-encoded
path of the current locked manifest. Include the exact feedback parameter when
feedback is part of the review contract. The launcher preflight must construct
and record this URL, and the real-browser gate must prove that the loaded URL,
manifest revision, page title, and displayed review ID all match. A bare index
URL, an implicit default manifest, or a predecessor manifest is a hard stop.

Before presentation, freeze the expected native-field identifier set. Require
both the awaiting-review and all-fields queues to contain that complete exact
set, with no missing, extra, duplicate, or sample-only field. Every expected
field must have its clean BF/DF assets and every declared current mask/layer in
the raster manifest. Exercise representative fields in the real browser, but
do not mistake representative visual sampling for queue-cardinality proof. A
reviewer that exposes only one test field when the manifest declares more is
withdrawn, even if that one field renders correctly.

Coverage truth and detector visualization must remain separate. Uncovered or
unassigned inspection pixels, outside-domain pixels, target-excluded fallback,
removed detector response, and accepted candidate response require distinct
machine counts, layers, labels, and colors. `zero uncovered pixels` proves only
coverage closure; it does not mean a yellow removed-response or fallback layer
is empty. Every page and summary must state the color semantics directly and
must never call a detector-removal block a blank region or an outside-domain
pixel an inspected Normal pixel.

## Mandatory unresolved-prerequisite ordering gate

Before changing `activePhase`, `nextAction`, or declaring a later transfer or
production-source test ready, enumerate unresolved `PENDING_GATE`, explicit
hold, and required-alignment records in `work/ARGOS_CONTINUITY_STATE.json` and
the current checkpoint. A later detector or reviewer approval does not
supersede an earlier required registration, fiducial-designation, map, pose,
coverage, or sensitivity gate. Record the prerequisite sequence explicitly in
the new checkpoint.

For patterned-wafer inspection, production-wafer defect scoring cannot begin
until the applicable product/process fiducial is operator-designated from
native paired BF/DF evidence and a fresh alignment-transfer test passes. Any
map, pose, missing-model, or ambiguous-model row remains an operator-visible
hold. `Production wafer` describes the source material and never bypasses this
gate or implies production routing authority.

## Mandatory reusable fiducial-model workflow

Before designating, calibrating, validating, transferring, or presenting any
patterned-wafer fiducial model, read and apply
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.md` and its machine-readable companion
`work/ARGOS_FIDUCIAL_MODEL_WORKFLOW.json`. Start each new model or appearance-
regime revision from
`work/templates/ARGOS_FIDUCIAL_MODEL_RUN.template.json` and bind the exact
workflow hash. The mandatory sequence is operator topology designation when
needed, automatic native-pixel channel-local calibration using sustained
geometric lines, frozen internal verification, and independent paired BF/DF
validation without tuning. No operator judgment raster may be presented before
that validation passes.

Reuse a qualified geometric topology across colors or compositions when the
physical structure is unchanged, but bind polarity, response width, edge-
family association, and thresholds to a declared appearance regime. A failed
different-regime transfer requires a new automatic appearance calibration and
fresh validation, not a geometry redraw or target-specific relaxation. Never
reintroduce per-candidate line intercept/slope fits, far opposite-polarity edge
switches, exact-seed-only polarity, transformed-length sample counts, endpoint-
trim-only corner handling, screenshot repeating-grid location recovery,
validation-target tuning, or gallery-only lot-availability conclusions.

Independent fiducial validation is site-bound. Before validation outcomes are
inspected, freeze the intended fiducial prediction and deterministic
eligibility radius from the qualified notch pose, exact map/operator-
designation relationship, crop transform, and calibration localization error.
Require exactly one refined candidate inside that radius. A complete geometric
instance elsewhere in a wide crop is an ineligible repeated instance or
lookalike and can never substitute for the operator-designated site. Zero or
multiple candidates inside the radius remain a hold. Whole-crop `exactly one
complete geometry` is diagnostic only and is never a validation pass.

Short-line support gates must make their declared gap allowance real. Use an
explicit accepted-sample count and maximum contiguous unsupported run; do not
combine a nonzero allowed gap with a fractional-support threshold that makes
the gap impossible on three- or seven-sample lines. Residual and response-width
statistics must name their exact population. An allowed unsupported sample may
not be silently reintroduced through a found-sample percentile veto. Threshold
values and these population semantics are frozen from development/calibration
evidence before independent validation.

## Mandatory OpenCV image-processing migration boundary

The approved migration objective is to move all image decoding and pixel
processing into configuration-selected OpenCV providers. This includes scribe
deciphering/OCR, wafer perimeter and notch pose, fiducial localization,
reference composites, inspected-wafer registration, Bare, backside, BowComp,
frontside patterned and unpatterned defect processing, detector masks,
heatmaps, crops, overlays, and review-raster generation. PowerShell is limited
to orchestration, configuration/manifest validation, exact file operations and
hashing, provider invocation, timeout/exit handling, queues, ledgers,
dashboards, GUI data flow, and signed transport. It must not decode image
bytes, loop over pixels, crop/resize/filter/composite images, perform OCR, fit
image geometry, register wafers, score defects, or generate image-derived
masks and heatmaps.

Apply `work/ARGOS_OPENCV_ALL_IMAGE_PROCESSING_MIGRATION.md` and its
machine-readable companion before beginning or integrating migration work.
Freeze each currently accepted family implementation as regression evidence;
do not use migration to redesign working semantics. Migrate and activate one
family at a time through installed configuration, preserve the unchanged
disabled path, and fail closed on missing runtime, schema, model, appearance
regime, registration, composite revision, or provenance. OpenCV engines must
not hard-code a lot, product, source/output root, FS15 exception, review-only
or production switch, or authority decision. All resource-intensive runtime,
cache, and output work belongs on JBOD `D:`. Geometry, OCR, and registration
return measurements, confidence, and explicit holds; they never grant
production authority.

## Mandatory continuation memory

Before changing, building, diagnosing, or presenting any Argos artifact, read
these files in order:

1. `AGENTS.md`;
2. `work/ARGOS_CONTINUITY_STATE.json`;
3. `work/ACTIVE_ARGOS_EDGE_LAB_STATE.md`;
4. `work/PROJECT_MEMORY_INDEX.md`;
5. the current phase checkpoint named by the continuity state.

Do not reconstruct the active revision, approved reviewer, detector contract,
or next action from chat history. The filesystem record is authoritative. At
each major milestone, update the active-state file, append one row to
`work/ARGOS_REVISION_LEDGER.md`, and update the machine-readable continuity
state before reporting completion. Every revision must be labeled as one of
`LOCKED_INPUT`, `APPROVED_BASELINE`, `DIAGNOSTIC_ONLY`, `WITHDRAWN`,
`PENDING_GATE`, or `RELEASED_REVIEW_ONLY`. A withdrawn or diagnostic artifact
must never silently become the parent of a presented or deployed revision.

Run `utilities/Confirm-ArgosProjectContinuity.ps1` after resuming work and
before presenting a reviewer or publishing a JBOD package. A failed continuity
check is a hard stop; repair the filesystem record before continuing.

## Canonical defect-feedback reviewer

The operator-approved defect-feedback/highlighter application is the original
BowComp reviewer in `work/BOWCOMP_REVIEW_ONLY/reviewer_v1`: `index.html`,
`app.js`, and `styles.css`. Its layout and interaction contract are reusable
across inspection families. Future Bare, BowComp, frontside dielectric,
front-metal, resist, and other defect-feedback pages must be built by adapting
that application, not by independently generating or imitating a new HTML,
CSS, or JavaScript interface.

The canonical source hashes and required controls are locked in
`work/REVIEW_UI_CANONICAL/BOWCOMP_HIGHLIGHTER_V1_LOCK.json`. A derived reviewer
may adapt the data-manifest schema, review labels, inspection-family text,
asset mappings, and response filenames. It must preserve the canonical DOM,
CSS, full-wafer and native-tile review tabs, zoom/pan controls, the four
highlighter actions, defect/false-reason palettes, native-coordinate capture,
queue workflow, and staged-feedback semantics. `styles.css` must remain
byte-for-byte identical unless the operator explicitly approves a new
canonical UI revision.

Every derived reviewer build must verify the canonical source hashes before
copying, record both source and output hashes, and assert the required control
IDs and action tokens. A separately generated page that merely contains
similar labels is a regression and must not be presented for operator review.
Do not change detector evidence, masks, thresholds, classes, or inspection
authority while repairing or adapting this UI.

## Mandatory JBOD hotfix release gate

Never publish or ask the operator to run a JBOD hotfix based only on source
parsing, payload hashes, or inspection of the manifest. Before copying the
final ZIP to `InspectionRevs`, run the exact packaged installer preflight
under Windows PowerShell 5.1 against a fresh rehearsal install tree containing
byte-for-byte copies of every approved installed predecessor. Exercise every
declared `allowedInstalledSha256` value, not merely the newest one. The gate
must verify final-ZIP extraction, manifest and payload hashes, explicit
normalized predecessor matching, path/quoting behavior, nested extraction,
refusal before mutation for an unapproved hash, and idempotent acceptance of
the target hash. Store a machine-readable PASS artifact beside the package.
Do not publish the ZIP when any rehearsal case is absent, skipped, or failed.

JBOD installers must expose a non-mutating preflight/rehearsal mode with an
overrideable install root so their exact validation path can be executed
without scheduled tasks or production-state changes. A separate reimplementation
of the comparison is not sufficient evidence that the packaged installer will
accept the intended predecessor.

## Task-history payload safety

The former Codex task `019f95b4-36be-72c0-b0bc-34ae4c3dbf97` is
quarantined because embedded image/base64 payloads expanded its JSONL history
to approximately 20.6 GiB. Never open, read, fork, restore, summarize, or
otherwise load that task into an active session. Recovery must use the saved
filesystem artifacts and lightweight text checkpoints only.

Argos evidence and review work must remain file-backed. The enforceable
session-safety contract is `work/ARGOS_CODEX_SESSION_SAFETY.md`. Run
`utilities/Confirm-ArgosCodexSessionSafety.ps1` after resuming an Argos task,
at each major checkpoint, and before presenting a reviewer or starting a
long-running inspection. The metadata-only checker must never read session
contents and must exclude all quarantined task IDs.

The task-size gates are mandatory: checkpoint and continue at 128 MiB; run a
deterministic session-health probe at 256 MiB; run a second probe and make a
soft rotation recommendation at 384 MiB; and hard-stop payload-producing work
at 512 MiB. A probe passes only when filesystem continuity, authority, and
observed interaction health remain intact. An abnormal single-turn growth
alarm is an immediate stop regardless of total size. A rotation handoff
contains filesystem paths, hashes, authority, and next action only; never fork
an image-heavy task or attach its JSONL.

Argos evidence and review work must remain file-backed:

- Never embed image, video, or audio bytes, base64 strings, or `data:` URLs in
  conversation messages, tool output, JSON, JSONL, Markdown, or HTML.
- Do not read binary image files into conversation context, base64-encode
  them, or bulk-load image bytes. Do not use image-returning inspection or
  screenshot tools in Argos tasks. Even when visual inspection is requested,
  create a bounded local file-backed gallery and give the operator its path;
  never return the image bytes through the task.
- Generate crops, overlays, and contact sheets as ordinary local files.
  Review galleries must reference those files by relative or absolute local
  path; they must not contain embedded image payloads.
- Report image evidence by local path, dimensions, hashes, coordinates, and a
  concise text summary. The operator reviews the file-backed gallery outside
  the conversation.
- Do not dump large manifests, CSVs, JSONL journals, logs, or component tables
  into conversation context. Query only the required fields or rows and
  summarize counts, states, and hashes.
- Keep normal tool output below 8,000 tokens. Save larger evidence to a local
  text file and report only its path, size, hash, and selected fields.
- Save an append-only filesystem checkpoint at each major review milestone.
  Start a fresh Codex task when a health probe fails, the 384 MiB soft rotation
  is accepted, the 512 MiB hard stop is reached, or abnormal growth is detected;
  continue from that checkpoint rather than reconstructing prior chat.

The former Codex task `019fcd2e-cf41-7f11-93de-592c43d4131b` is also
quarantined. Its JSONL reached exactly 18,490,749,343 bytes after 306 oversized
binary/image records were serialized. Never open, read, fork, restore,
summarize, or otherwise load it. Use only
`ARGOS_JBOD_TEXT_RECOVERY_20260814/RECOVERED_HANDOFF.md` and its bounded
text-only companion artifacts.

These protections are operational safety rules only. They do not change
detector truth, image provenance, review authority, or eligibility.

## Frontside notch competitors

Frontside notch alignment must not select the deepest indentation or the
candidate nearest a fixed image angle. Appearance-only occlusions and
physical edge damage may compete with the manufactured notch. A channel-local
inward boundary response without matching independent physical-boundary
displacement is an appearance-only boundary competitor and is ineligible to
establish wafer pose. A BF/DF-supported physical indentation remains a
physical competitor; it must not be erased or relabeled merely to obtain an
angle. The notch engine must not encode or infer a cause or material identity
for an appearance-only competitor. When more than one physical indentation
remains plausible, refine the candidates at native resolution and require
manufactured-notch morphology and reciprocal notch-relative scribe support.
Otherwise emit `FRONTSIDE_NOTCH_ALIGNMENT_HOLD`. Never use a fixed notch angle
as the deciding rule.

## Active BowComp six-wafer transfer study

The user explicitly approved review-only testing of all six physically
distinct BowComp backside wafers. Repeated physical slot numbers in the two
archives are separate wafers from different lots. Preserve these identities:

- `62624_803_SLOT16`, `62624_803_SLOT18`, `62624_803_SLOT20`;
- `62624_869_SLOT16`, `62624_869_SLOT18`, `62624_869_SLOT20`.

BowComp remains isolated from Bare calibration, truth, geometry statistics,
and output authority. `RG_AVERAGE` detector evidence is approved for the
BowComp surface-transfer diagnostic so variable blue nitride-film response
does not drive detections. Raw BF/DF must remain available and unchanged.
The broad blue field, the two recurring blue-band features, and the rounded
edge feature identified by the user are normal nuisance evidence and must
not be rejected merely because their blue appearance changes.

Scratch detection has first priority. Do not raise the global BowComp
scratch threshold merely to remove weak subclass labels: native-pixel audit
crops show that several genuine faint scratches have low BF contrast and no
DF support. Keep defect-presence confidence separate from subclass
confidence. `REVIEW_ONLY_REJECT_CLASS_LOW_CONFIDENCE` means accepted defect
pixels with an uncertain residue/contamination/particle/scratch subtype; it
must not be summarized as an unqualified automatic-classification pass.

The current BowComp-only scratch correction must distinguish long false
nitride transitions from real scratches by local geometry. A long
blue-nuisance component with no independent DF support and a major axis that
is essentially tangential to the wafer is ineligible; a scratch that departs
from or crosses the blue band remains eligible. Do not turn this into a
global blue mask or a broad radial sector exclusion. The final targeted gate
retained all ten marked positive tiles and cleared the three exposed
second-lot tangential boundary controls. Preserve the detailed thresholds
and evidence in `BOWCOMP_SIX_WAFER_TRANSFER_STATUS_20260728.md`.

The latest bounded scratch-mask coverage correction is V5.7, recorded in
`work/BOWCOMP_REVIEW_ONLY/BOWCOMP_V57_AXIS_RECOVERY_CHECKPOINT_20260729.md`.
It may recover additional observed native pixels only along the measured axis
of an already accepted enhanced-Hough scratch seed. It must keep unsupported
gaps empty, preserve the frozen global threshold, apply holder exclusion
before recovery, and retain the blue-transition/tangential-nuisance rules
above. It is not permission to infer a complete line, group by proximity, or
promote a display halo to detector truth.

The unchanged Bare geometry qualifier did not transfer to the six BowComp
wafers. Preserve
`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED` for BowComp edge, notch,
microdamage, and bevel decisions. Do not loosen Bare geometry tolerances to
manufacture a BowComp pass. A future BowComp edge step requires its own
per-wafer geometry method and targeted approval.

The current six-wafer record is
`BOWCOMP_SIX_WAFER_TRANSFER_STATUS_20260728.md`. All BowComp outputs remain
review-only, training-ineligible, XML-geometry-ineligible,
production-ineligible, non-full-lot, and unpackaged.

The operator provisionally accepts the current V67 BowComp surface findings.
The V67 reviewer may collect missed-defect, false-detection,
recategorization, and display/alignment highlighter guidance directly on the
full-wafer overview, but this feedback must remain staged and review-only.
Full-wafer strokes must preserve both overview and native source coordinates.
Do not change BowComp edge-zone false suppression or eligibility until a
BowComp wafer with known physical edge damage is available for a
sensitivity-preserving regression gate.

The newer review-only surface defect-presence checkpoint is
`BOWCOMP_V65_DEFECT_PRESENCE_CONFIDENCE_CHECKPOINT_20260729.md`. A fresh
native-pixel reinspection completed all six identities with zero holder
overlap. The supplied pink-mark evidence has detector support in 20/22 exact
registered boxes and 22/22 boxes under the fixed 150-source-pixel
screenshot-registration audit margin. The two exact exceptions are the
previously identified unreliable registrations, not validated detector
escapes. New class-neutral line-presence recovery is fail-closed and emits
class-specific Scratch or Scratch/Residue confirmation holds; it must not be
reported as autonomous scratch authority. The governing BowComp edge, notch,
microdamage, and bevel state remains
`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED`.

The current post-V5.7 reinspection record is
`work/BOWCOMP_REVIEW_ONLY/BOWCOMP_V58_SIX_WAFER_REINSPECTION_RESULT_20260729.md`.
The full six-wafer rerun preserved every V5.7 scratch mask except the intended
`62624_869_SLOT20/T01_R00C00` correction. Two no-DF, nearly radial
enhanced-Hough components on the user-declared normal rounded blue feature now
produce `CONFIRM_SCRATCH_BLUE_FEATURE_BOUNDARY` and contribute zero accepted
scratch pixels. This is a local component gate, not a broad blue mask.
Confirmation components must never be painted into an accepted defect mask or
seed scratch-axis recovery. The 51-case targeted gate retained 50 masks
byte-for-byte, changed only that exposed false case, and had zero holder
overlap. All six native-pixel reruns completed at 1:1 scale with zero holder
leaks. The three `62624_803` images are 14409 by 10994; the three
`62624_869` images are 14411 by 10995. Preserve the actual per-source
dimensions recorded in each run manifest rather than assuming one fixed
BowComp image size.

The latest saved-annotation-corrected checkpoint is
`BOWCOMP_V66_NATIVE_COMPONENT_CONFIDENCE_CHECKPOINT_20260730.md`. Its exact
freehand-path audit retains native-pixel anomaly evidence for 12/12 saved
`MISS` drawings, accepted Scratch or class-specific Scratch confirmation
evidence for 11/12, and zero accepted/confirmation Scratch evidence for all
6/6 saved `FALSE` drawings. The remaining miss path is a directly noticed
coverage signal beside independently confirmed fragments; it is not Normal,
but lowering the component gate further would re-admit known nitride texture.
Do not turn it into inferred line geometry or pixel-exact truth.

The corresponding V49 six-wafer native run completed 6/6 identities and 180
native scoring tiles with zero accepted holder overlap. All 56 BF/DF and mask
artifacts compared between the frozen targeted tiles and the complete run
matched byte-for-byte. The run has 20,067 class-specific Scratch or
Scratch/Residue confirmations, so it is a fail-closed review-only confidence
checkpoint rather than autonomous production authority. BowComp edge,
notch, microdamage, and bevel remain
`INSPECTION_HOLD_BOWCOMP_GEOMETRY_NOT_QUALIFIED`.

## Active Bare surface-inspection study

The user has explicitly opened a new isolated, review-only Bare-backside
surface-inspection phase. Preserve V2CT unchanged as the locked
surface-review/rendering baseline; do not edit or rerun the V2CT package.

The new work belongs under `work/BARE_SURFACE_INSPECTION_REVIEW` and initially
targets scratches, concentric chuck marks, the outer etch-stain ring, EBR
residue, broad suspected resist residue, contamination specks, and deliberate
ink-pen swirls. Deliberate pen ink is classified as residue with known
`InkResidue` provenance; it is not a separate production class and must remain
out of scratch truth. Scratch detection has first priority. Chuck marks and the
etch-stain ring must be detected and measured as distinct process-pattern
classes rather than mislabeled as scratches.

The first cyan chuck-circle search was rejected by human review because its
patterns were off center. Retire that output as a failed diagnostic; do not
tune, reuse, or treat its circles as truth. Do not infer, fit, complete,
paint, or group chuck evidence by a center, radius, circumference, circle, or
arc. Chuck-imprint evidence may be reconsidered only as ordinary locally
abnormal surface pixels and directly pixel-connected components. The
temporary Slot21 center crop is a speed/tuning aid only; it is not full-wafer
coverage and cannot support full-wafer negative truth.

Human review confirms that
`SURFACE_IMPRINT_DEFECT_PIXELS_20260727T191745Z/Slot21/events/Slot21_IMPRINT_DEFECT_PIXEL_01`
is a real long diagonal `Scratch` signal. Preserve it as a review-only
scratch-transfer reference, not as training truth or pixel-exact production
geometry. A scratch remains eligible when it crosses a faint imprint region;
an imprint context must not suppress observed BF/DF scratch pixels. Native
tile fragments may be consolidated only where their observed detector pixels
overlap or touch by one pixel in a shared tile region. Do not join fragments
by proximity, bounding-box overlap, shared direction, or an inferred line.

The accepted response was transferred across Slot21 in bounded overlapping
4000-source-pixel tiles evaluated at the same 3000-working-pixel scale:
`SURFACE_SLOT21_TILED_SCRATCH_PIXEL_TRANSFER_20260727T195151Z`. The confirmed
center scratch was recovered. The detector produced five candidate views and
eleven hold views before exact duplicate-view suppression; the finalized
gallery shows five candidate views and eight unique holds. Overlapping cards
may be separate views of one physical scratch and are not automatically
declared separate events. Yellow overview pixels are review-only scratch
candidates; blue pixels are holds, never automatic rejects. The failed
native-response experiment
`SURFACE_SLOT21_NATIVE_SCRATCH_TRANSFER_20260727T193907Z` emitted zero events
and is diagnostic only; it is not scratch authority.

The same fixed response was transferred without tuning to the other already
bounded Bare surface-review slots. Slot03 produced 0 candidates/5 holds,
Slot15 0/8, and Slot24 0/12. These rows have no supplied human scratch truth;
their holds are not Normal or reject truth. The four-wafer result is recorded
in
`work/BARE_SURFACE_INSPECTION_REVIEW/BOUNDED_TILED_SCRATCH_PIXEL_TRANSFER_RESULT_20260727.md`.
Do not reinterpret the lack of candidates as full-wafer negative truth.

Current surface work starts from local BF/DF pixel components. Link components
only when bounded shared pixel or cross-channel evidence supports one physical
event; never use nearest-neighbor chaining. Human review must use a reasonable
local field of view comparable to the historical surface cards. Save the
full-wafer detection overview separately after local events are formed.
Every local review overlay must show all selected surface-evidence components
inside that field of view, not only the component that selected the card.
Component growth may cross a weak interval only through an observed bounded
pixel-support corridor. Spatial proximity alone is not continuity evidence.

The approved surface-event design is layered. First create a high-recall,
class-neutral local anomaly mask; then form evidence-supported parent/child
relationships; only then assign Scratch, Residue, ResidueStreak,
Contamination, Stain, or Unknown. Uncolored local pixels mean not detected,
not Normal. The focused Slot21 F01/F02 pen lines are known-provenance
`InkResidue` diagnostic controls, not training truth and not Scratch truth.
Slot24 F03 is one accepted parent residue-streak complex with multiple child
streaks, branches, deposits, and specks. See
`work/BARE_SURFACE_INSPECTION_REVIEW/SURFACE_LAYERED_EVENT_CONTRACT_20260727.md`.

The earlier F01 structured-crosshatch hold has been resolved by explicit
human review: `BLUE_CROSSHATCH - DEFECT`. Promote only the previously isolated
blue evidence to `DEFECT_REVIEW_ONLY / UNCLASSIFIED_SURFACE_DEFECT`. It must
not seed new relationship paths, expand into nearby texture, become Scratch
or Residue truth without separate evidence, or become training/XML/production
truth. Enhancement visibility alone is not a general rule proving that other
structured patterns are defects. The human-declared broad faint F01/F02 wisps
remain fail-worthy surface evidence even where the current autonomous pixel
mask misses them. Do not convert those misses to Normal, invent their pixel
area, or promote a low-threshold scan-texture response merely to fill them.

For supported little surface specks, keep defect disposition separate from
class and do not require routine human classification. Preserve each
disconnected speck as a separate component when the pixels support that.
Classify a standalone speck as `Contamination`. Classify it as `Residue` only
when it is part of an observed pixel-connected residue group or lies inside a
bounded residue context and has a sufficiently similar BF/DF channel
signature to the known residue. Proximity alone must never create a residue
classification or a nearest-neighbor relationship chain.

The dark BF specks visible inside the human-reviewed Slot21 EtchStain card
windows are a bounded residue context. Preserve them as separate `Residue`
components and separate masks; do not absorb them into the EtchStain band,
discard them when the stain width changes, or show only the solid stain line.

The user confirmed that every previously displayed Slot21 `Other` /
unclassified orange component is real surface-defect evidence. In the current
bounded Slot21 review they are `Residue` review-only rejects; there is no
remaining unclassified layer. This confirmation does not make the components
training, XML, or production truth.

Compact raw-visible dark BF spots remain surface-defect eligible through the
narrow physical wafer-edge zone, including spots touching the fitted
perimeter. Do not use a generic inward surface inset to erase them. Continue
to reject the long smooth wafer/outside transition itself. Suppress only the
locally connected physical holder body and its immediate outline. An
image-derived local holder exclusion is allowed when same-slot geometry
priors are unavailable, but it must be constrained to the connected holder
body and a small local dilation; never expand it into a broad angular,
radial, holder, or notch sector mask.

The same local holder/notch exclusion contract must be applied before
candidate formation in every surface engine, including Scratch and
ChuckImprint. It is not sufficient to draw the exclusion in the combined
review overlay after another engine has already created a holder candidate.
Likewise, every surface engine must keep compact raw-supported defect pixels
eligible through the physical edge zone. A context-only recovery pass cannot
substitute for native first-pass eligibility, and a blanket inward inset may
not erase compact edge residue, contamination, particles, or scratches.

Surface visual-audit overlays must be strong enough to remain visible over
dark defect pixels. The local visual-audit page must also provide one global
control that hides or restores all overlays, revealing the same enhanced BF
base beneath them. This visibility control is display-only and must not
change masks, classes, relationships, areas, or eligibility.

Argos image pixel pitch is 14.5 micrometres. One source pixel is 210.25 square
micrometres or 0.00021025 square millimetres. Surface evidence reports must
state the measured or estimated area and the inspected-area fraction. Any
reduced-resolution estimate must be scaled by its actual X and Y reduction
factors and clearly marked as an estimate.

Curve enhancement may be used for display and visibility, including to expose
subtle chuck circles, but must not overwrite source images or silently change
detector truth. Rejected surface regions use transparent heatmap overlays.
Integrated full-wafer review must use the original unmodified BF/DF image as
the base and keep accepted rejects, unclassified noticed pixels, and coverage
holds on separate toggleable heatmap layers. Local event cards must provide
working BF and DF raw/adjusted toggles and label every adjusted view as either
detector input or display-only.

All Bare inspection engines must score the full available lossless Argos
working-image pixels at their original dimensions. For the current lot this
means the `14411 x 10995` BF/DF BMP inputs at the stated `14.5 um` pixel
pitch. A crop or tile may be read directly from those pixels for bounded
processing, but it must not be resampled before scoring. JPEG, thumbnails,
bilinear/bicubic reductions, and other resampled images are display or
diagnostic artifacts only. A detector run must record the source path, source
hash, source dimensions, scored dimensions, crop origin, and scale. It must
assert `scaleX=1` and `scaleY=1` for scored pixels. If it cannot, its engine
state is `HOLD_NONCOMPLIANT_INPUT_RESOLUTION`, never `ENABLED`, Reject, or
Normal. A reduced full-wafer overview remains allowed only when explicitly
marked `DISPLAY_ONLY`.

Every detected event must receive an automatic proposed class and confidence
state. A sufficiently supported event may receive its specific automatic
class. Insufficient evidence or insufficient validated decision authority
must produce a fail-closed, class-specific confirmation request such as
`CONFIRM_SCRATCH`, `CONFIRM_RESIDUE`, `CONFIRM_CONTAMINATION`,
`CONFIRM_PARTICLE`, `CONFIRM_ETCH_STAIN`, `CONFIRM_EDGE_CHIPOUT`,
`CONFIRM_EDGE_MICRODAMAGE`, or `CONFIRM_BEVEL_DAMAGE`. When two classes remain
plausible, name both in the hold. Do not emit a generic `UNCLASSIFIED`,
`UNSURE`, or routine open-ended human-classification task when a bounded
candidate class is available. A confirmation hold is not Normal truth and is
not training truth. Because training remains prohibited, describe the cause
as insufficient evidence, coverage, confidence, or validated decision
authority—not as an invitation to train automatically.

The combined Bare reviewer uses a fail-closed required-engine contract. Every
expected engine must appear with `configured=true` and a state of `ENABLED`,
`HOLD`, or `FAILED`. A missing or failed engine creates
`INSPECTION_HOLD_REQUIRED_ENGINE_FAILED`; a configured engine without a clear
same-wafer result remains `HOLD`. It must never become a silent pass. Review
layer/channel toggles are visibility-only and must not enable, disable, skip,
retune, or change the state of any detector.

Surface outputs remain training-, XML-, and production-ineligible until
separately approved. No full-lot run, package, GUI deployment, BowComp mixing,
or edge-class change is authorized by this phase.

## Current phase

The project is in **Bare-backside V2DC V5.11 stable review-only confidence
checkpoint after the independent Slot18 transfer and 29/29 resolution
contract pass**.

V5.11 is a frozen post-exposure confidence layer developed from the V5.10
Slot14 false-positive pair. It preserves V5.9 pixel scoring, geometry,
coverage, priors, corridor logic, and large-damage logic. An otherwise
automatic microdamage reject must have at least two direct accepted one-hop
neighbors within the unchanged 8-192 px interval and
`MaximumBrightRunPx <= 9`. Failure becomes
`INSPECTION_HOLD_CORROBORATION_QUALITY_INSUFFICIENT`, never Normal truth.
No nearest-neighbor chain grouping or child-island merging is introduced.

The separately frozen rank-7 Slot18 gate was selected before full-resolution
extraction or scoring. Per-wafer geometry passed with 0.900322 circle inlier
fraction, 0.582311 px residual MAD, a 5-degree maximum unsupported span, and
one shape-qualified notch at 89.666090 degrees. The frozen base scan produced
zero large-damage rejects and three microdamage rejects. V5.11 converted all
three to corroboration-quality holds, leaving zero automatic rejects. One
separate large-DF candidate remains a BF-corroboration hold, and 29/64
coverage sectors remain explicit holds. The operator classified H01 as
`NOT_DAMAGE` contamination/possible dielectric and H02 as `NOT_DAMAGE`
polished reflective bevel. The V5.11 resolution contract passed 29/29.
V5.11 has therefore demonstrated independent suppression of the V5.10-type
false-reject pattern and is the current stable Bare review-only confidence
checkpoint. It has not established autonomous sensitivity because Slot18
contained no human-confirmed damage in the reviewed locations; the 29
low-coverage sectors remain holds and are not Normal truth.

V5.10 transferred the unchanged V5.9 rules to Slot22, Slot14, and Slot23
after selection and geometry were frozen without pixel review. All three
wafer-specific circle/notch geometry gates passed. The candidate manifests
were frozen with `knownTruthConsumed=false`. The run produced zero automatic
large-damage rejects and two automatic `EdgeMicroDamage` rejects, both on
Slot14 (`Slot14_MICRO_0006` and `Slot14_MICRO_0007`). The user classified
both as `NOT_DAMAGE`; they are frozen blind false positives and must be
suppressed. V5.10 therefore does not validate V5.9 for independent automatic
transfer. Do not tune from these exposed findings and then reuse this run as
blind evidence. A correction may use them diagnostically, but a new transfer
claim requires a separately frozen blind gate. The Slot23 large-DF candidate
remains an explicit BF-corroboration hold, not Normal truth.

V5.9 preserves the V5.8 pixel scoring, large-damage logic, geometry, coverage,
and safety thresholds. It adds a fixed one-hop local micro-corroboration rule:
an otherwise valid micro signal requires a separate accepted interval 8–192
px away. Nearest-neighbor chain grouping remains prohibited. An isolated
signal becomes `INSPECTION_HOLD_ISOLATED_MICRO_SIGNAL`, not Reject and not
Normal.

The truth-informed Slot01/Slot03/Slot17 regression recovered 5/5 known
large-edge positives and 6/6 known micro positives while suppressing 13/13
known edge negatives and 3/3 known micro negatives. All seven V5.8
human-confirmed false rejects are now inspection holds. The only three
remaining unmatched automatic rejects are exactly the three detections the
operator classified as DAMAGE: `Slot17_LARGE_069`,
`Slot03_MICRO_0010`, and `Slot03_MICRO_0016`. MAN053 remains DF-only with no
borrowed BF contour. The immutable component contract passed 26/26 and the
V5.9 resolution contract passed 27/27.

V5.9 is a same-wafer truth-informed regression, not independent blind
validation. It does not establish automatic authority for isolated tiny
damage. Production integration and broader/full-lot V2DC execution remain
unapproved. Training, XML, packaging, GUI deployment, surface changes, and
BowComp remain disabled.

V4.5.2 preserves the bounded V4.5.1 alignment rules and adds a general
6-gray-level absolute DF contrast-drop floor for automatic microdamage
rejection. Signals below the floor become explicit inspection holds. The
frozen 6/6 accepted and 0/3 false references remain unchanged, and exposed
Phase B, C, and D regressions passed. The unconfirmed V4.5.1 `D01-04` reject
is now held rather than rejected. A genuinely new Phase E selection was
frozen before pixel inspection. Its eight windows produced zero automatic
rejects, five low-DF-coverage holds, and three usable no-reject results. Human
review found no visible miss in all three usable strips and no visible damage
in the five hold displays; those five rows remain inspection holds rather
than Normal truth. A deterministic repeat reproduced 67/67 compared core
artifacts byte-for-byte across Phases A-E. V4.5.2 is therefore the current
stable review-only `EdgeMicroDamage` component. The combined V1 boundary, V3
parent-span, MAN053 DF-only, and V4.5.2 authority contract passed 26/26 checks.
The user confirmed the V3.2 event continuity as good but its radial contour
depth as under-covered. V3 remains frozen historical authority and must not
be rewritten. V3.2 supplies the accepted angular spans: one continuous
270.30 px main chewed run and one separate 54.06 px right-hand run. V3.3
preserves those spans and recovers 17 BF inward tips by 1–4 px only where a
strong raw BF transition and complete outside-wafer dark corridor support the
change. BF remains the sole contour-geometry source. The extremely tiny
feature farther left remains unaccepted and uncertain. The user accepted
V3.3 depth as correct; V3.3 is now the Slot03 review-only contour authority.
It remains training-, XML-, and production-ineligible. Production integration
and broader/full-lot V2DC execution remain unapproved.

V3.4 is a separate review-only DF-native decision study, not contour
authority. A fixed 40 px connected-arc gate triggered the 88.096 px Slot03
MAN040 DF event while suppressing all eight frozen false controls; the closest
surviving false-control component was 30.098 px at a notch edge. This supports
future DF-primary `damage exists / reject` decisions, but its DF band remains
approximate display evidence and is not BF or XML geometry. MAN053 remains
under its separate DF-only bevel taxonomy. The tiny far-left feature remains
below this autonomous size path.

V3.5 transferred that unchanged 40 px rule to the overlapping Slot01 MAN010
and MAN016 windows. Both triggered as one connected DF component at 452.455 px
and 454.117 px respectively. They are two views of
`Slot01_EDGE_DAMAGE_EVENT_01`, not independent physical positives. The frozen
eight-control V3.4 authority remains suppressed, MAN053 remains out of this
chewed-edge taxonomy, and the post-transfer component contract passes 26/26.
The consolidated Bare regression is review-only and does not authorize
training, XML, production integration, full-lot execution, or packaging.

## Frontside scribe validation

The current FS15 automatic whole-string reader correction is V4, recorded in
`work/SCRIBE_REVIEW_ONLY/FS15_SCRIBE_READER_V4_CORRECTIVE_CHECKPOINT_20260804.md`.
The previous positive absolute check-glyph score floor was not invariant across
physical-wafer acquisition styles and discarded bounded correct `H2` and `B0`
candidates. V4 uses a bounded relative check-symbol gate (`0.40` maximum score
delta, `-0.05` minimum score, at most all eight legal symbols) and then permits
only the unique canonical M12 check pair generated from each bounded image-read
ten-character body. A remainder-zero noncanonical alias is ineligible. Preserve
the independently highest-scoring image-first string and require confirmation
when checksum reranking changes it. The physical-wafer-held-out FS15 regression
now has correct top proposals for 15/15 acquisitions with zero unresolved and
4/4 duplicate-view agreement. This is truth-informed current-corpus evidence;
generic alphabet coverage remains incomplete for `IJKLOQVWXYZ`, so independent
future-transfer and production authority remain held.

Frontside material state is independent of the Bare/BowComp backside
distinction. Scribe crops may require BF, DF, pattern-suppressed, or other
explicitly labeled display/detector variants. Start from the expected
notch-relative location, but use a bounded exception search when the scribe is
not present there.

Use
`work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md` as the
deterministic 12-character whole-string validation contract. Its source is
`SEMI M12-0998E SPECIFICATION FOR SERIAL ALPHANUMERIC MARKING (1).pdf`.

The locked SEMI M12 character value is always `ASCII(character) - 32`, with
the rolling remainder `(8 * remainder + value) mod 59`. Never substitute
digit ordinals `0-9` or alphabet ordinals `10-35`. Every checksum
implementation and gallery must pass the fixed 19-vector regression directly;
testing a different implementation is not parity evidence.

The current FS15 correction is governed by
`work/SCRIBE_REVIEW_ONLY/FS15_SCRIBE_LOCKED_CORRECTIVE_CHECKPOINT_20260804.md`.
The earlier FS15 V1 automatic reader and V1-V3 galleries are retired failed
diagnostics. Their checksum claims, checksum alternatives, and automatic
identities are ineligible. The 11 operator-confirmed canonical identities are
under
`work/SCRIBE_REVIEW_ONLY/outputs/review_only/FS15_SCRIBE_OPERATOR_CONFIRMED_V1_20260804T180000Z`;
all 11 pass the governing checksum and remain review-only.

Do not impose the older positional body profile (four digits followed by one
of `N/P/R/T`) on a new product. Unless a product-specific profile is
independently qualified, SEMI M12 body positions 1-10 remain uppercase
alphanumeric. Positions 11-12 retain only their standard check-character
shape (`A-H`, then `0-7`). Missing glyph-reference coverage creates
`SCRIBE_REFERENCE_COVERAGE_HOLD`, never a forced nearest known character.
Preserve the independently highest-scoring image character at every position
and its alternatives/scores. Apply the SEMI M12 checksum to eligible
12-character strings. A failing image-first string may be compared only with
bounded near-scoring image-supported combinations. Never invent a candidate,
silently replace the image-first read, or treat checksum validity alone as
sufficient when localization, segmentation, image confidence, or metadata
agreement is inadequate.

Reranked strings, multiple checksum-valid alternatives, checksum failure,
nonstandard formats, localization/segmentation failure, and MES conflicts
must remain explicit confirmation holds. Human-confirmed scribe labels may be
recorded as eligible references with provenance, but training remains
separately controlled and is currently unauthorized. The fixed 19-vector
SEMI M12 regression must pass 19/19 after any implementation change.

Use
`work/SCRIBE_REVIEW_ONLY/FRONTSIDE_NOTCH_AND_SCRIBE_IDENTITY_METHOD.md`
for frontside notch-first localization and compact scribe identity cards.
The historical `Build-NotchRelativeScribeCrops.ps1` hardcodes one 148-degree
rotation and one 2300-by-1100 crop; preserve its outputs as diagnostic history
only. Do not use it as future localization or identity-card geometry.

Qualify frontside center, radius, and notch per wafer before applying the
standard scribe-location prior. The notch must be shape-qualified from local
BF/DF boundary evidence. The visible tool hardware is behind the wafer in
frontside images and does not occlude the frontside surface; do not create a
frontside holder-exclusion mask from it. A fixed image position or the
acquisition metadata's zero prealign angle is not notch truth. Multiple
candidates, incomplete coverage, or notch-versus-damage ambiguity must produce
`FRONTSIDE_NOTCH_ALIGNMENT_HOLD`.

Frontside acquisition records `flipImageHorizontal=false`, while the matching
backside acquisition records `flipImageHorizontal=true`. Preserve this
handedness explicitly in every future frontside/backside transform; notch
angle alone cannot resolve a mirror. Center/radius/notch normalization is
wafer-pose evidence only. Die-grid phase and orientation require a separate
frontside grid-validation step before any XML coordinate export.

The scribe must appear as the first `WAFER_IDENTITY` card in a selected
wafer/slot gallery, but it is never a defect, yield item, KLA bin, or XML bin.
Its crop must be derived from the observed character row and kept tight,
level, and readable. A human edit must update one canonical identity record
only after explicit Save/Confirm, record an audit trail, rerun checksum/MES
conflict checks, and propagate through references without overwriting or
silently renaming prior artifacts.

## Governing sources

Use these sources together:

1. `Argos AI Feedback.txt` inside `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip` for the governing technical brief.
2. `README_CODEX_HANDOFF.md` inside that archive for the attached artifact roles.
3. `ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md` for descriptive map/XML infrastructure notes.
4. This file for workspace guardrails.
5. `work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md` and the
   local SEMI M12 PDF for deterministic scribe verification.

The continuation has been read. The map/XML document describes production infrastructure but is not proof that the current deployed scripts, tasks, mappings, or destinations match the document.

## Locked technical scope

- Treat the V2CT surface baseline as locked and immutable.
- All planned work is edge-only.
- Never change, tune, rerun, replace, or reinterpret the surface baseline as part of edge work.
- V2CX truth-lock feedback is the current local edge-truth authority.
- Preserve review-only and XML-ineligible flags from the V2CV/V2CW/V2CX evidence.
- Surface rows must never create `EdgeChipout`, `ChipoutSmall`, `BevelDamage`, or `PhysicalDamage`.
- Grouped/tile rows are display-only unless an explicit human label says otherwise.
- Edge work must remain isolated from surface work.
- Bare `EtchStain` is a surface-only wafer-concentric band. It may be
  discontinuous and may contain connected deeper inward lobes, but a generic
  dark near-edge patch or illumination gradient is not sufficient. Do not
  force a complete annulus, bridge across clean surface, or turn the stain
  into edge/chipout/bevel geometry.

## Bare surface scratch / etch-stain review component

- The bounded Slot03/15/21/24 scratch and near-edge etch-stain study is
  recorded in
  `work/BARE_SURFACE_INSPECTION_REVIEW/SURFACE_SCRATCH_STAIN_V1_RESULT_20260727.md`.
- Detector input must remain original BF/DF grayscale. Global RGB-channel
  stretching, rainbow/blue enhancement, heatmaps, and neutral review curves
  are display-only and must never feed detector pixels.
- `EtchStain` is a surface-only class formed safely inward from the physical
  edge with a same-angle inward reference. It must never create edge,
  chipout, bevel, or physical-damage geometry.
- The rejectable EtchStain area is the thin, locally darkest,
  angularly coherent concentric core. The broader approximately
  one-gray-level haze may remain audit-only support, but it is not rejected
  area and must not be painted as a filled radial wedge.
- EtchStain BF adjusted review images must use a bounded mid-gray local
  contrast display that preserves black outside-wafer space. Do not use a
  black-to-white percentile stretch that renders the normal wafer surface
  as saturated white.
- Scratch formation must run at original 14.5 µm source-pixel resolution.
  Reduced wafer images are overview/localization artifacts only.
- The user-confirmed Slot21 pen-ink fields are Scratch-negative diagnostic
  controls and must not become Scratch truth.
- A strong line beside unrelated residue remains
  `SCRATCH_INSPECTION_HOLD_RESIDUE_CONTEXT`; proximity alone must not merge or
  relabel the events.
- `Slot21_IMPRINT_DEFECT_PIXEL_01` is a human-confirmed review-only Scratch
  transfer reference, but there is still no production-authoritative
  autonomous Scratch positive. Other `ScratchCandidate` rows are not training
  truth, XML geometry, or production rejects.

## Truth and training restrictions

- Do not train from automatic grouped/tile labels.
- Do not train from V2CF/V2CG/V2CH/V2CI/V2CJ/V2CK automatic grouped labels.
- Do not train from V2CP edge-validation rows.
- Do not train from V2CQ `EdgeRescueSeed` rows.
- Do not train from `EdgeAuditCandidate`, `EdgeRescueSeed`, review-only, or audit-only rows.
- Treat pink user markup as approximate review guidance only; never convert it directly into pixel-exact training truth or production geometry.
- BowComp focused annotation review uses a translucent pixel highlighter by
  default. Preserve `FREEHAND`, `brushPx`, and `points` compatibility and tag
  new strokes with `tool: HIGHLIGHTER`. Only the painted brush corridor is
  intended; never infer or fill the interior of a closed highlighter stroke.
  Keep `All three` as the default card view. Highlighter output remains
  approximate review-only guidance and is never training truth, XML geometry,
  or production authority.
- Keep the local-alignment default bound at 8 pixels. A 9- or 10-pixel
  extension is review-only and eligible only when transition support is at
  least 0.98 and offset MAD is no greater than 0.5 pixels.
- When a 9- or 10-pixel extension changes one or more prealignment preliminary
  signals into zero aligned candidates, retain
  `INSPECTION_HOLD_ALIGNMENT_ERASED_PRELIMINARY_SIGNAL`; do not silently
  classify the row as Normal.
- An otherwise eligible automatic `EdgeMicroDamage` signal with an absolute
  DF contrast drop below 6 gray levels must remain an explicit
  `EdgeMicroDamageInspectionHold`. Do not convert weak sub-visible evidence
  to either Reject or Normal.
- For the current focused correction, written human comments take precedence
  over ambiguous GOOD/BAD/UNSURE button values. Use
  `work/V2DC_edge_residual_spike/V2DC_FOCUSED_REVIEW_NORMALIZED_20260725.md`.
- Keep local contour correctness separate from complete physical-event
  coverage in review and reporting.
- Multiple child residual islands may belong to one bounded physical damage
  event, but parent grouping must never bridge intact wafer, residue,
  holder/contact, notch evidence, or loss of the outside-connected corridor.
- Deep chipout search may expand only within a bounded human-reviewed window. It must require a complete dark corridor through the expected edge into outside-wafer space; do not remove the surface/edge eligibility gate.
- Review-guided micro outlines and curved-closure control points are display requirements only. Do not report them as autonomous detections, training truth, or XML-eligible geometry.
- Preserve `Slot01_B01-03` as a frozen Phase B false-positive exposure case:
  the user reported no damage and rejected all three automatic yellow
  candidates. Preserve `Slot17_B17-02` as unresolved/possibly bevel-only, not
  Normal truth. Neither row is training- or XML-eligible.
- Do not tune a correction and then reuse Phase B as fresh held-out transfer
  evidence. A correction may use the exposed failure diagnostically, but any
  new transfer claim requires a separately selected blind gate.
- Phase B diagnostics show a 5–6 px stable local boundary offset at the three
  `B01-03` false candidates versus 1–2 px at the six frozen positives.
  Second-stage recentering alone does not remove the false candidates. Any
  V4.5 correction must align before first-stage residual extraction and rerun
  candidate formation; a large offset alone must not be classified as damage
  or Normal truth.
- Notch and holder rejection may use only local overlap with the supplied same-lot `EXPECTED_NOTCH_PRIOR_MATCH` and `HOLDER_FIXED_PRIOR_MATCH` intervals. Do not expand these into broad sector masks.
- MAN053 bevel logic is DF-only. Its bright-ridge/outer-band disruptions must never borrow BF contour geometry.
- The human-selected `0.55` inner-transition fraction is accepted for the
  targeted Bare DF review display. Approximately one pixel of local cyan
  placement variation is acceptable for review and must not trigger global
  retuning.
- Orange is an approximate outer-bevel review guardrail, not pixel-exact truth.
  When the low-signal outer transition is unsupported or visibly displaced
  (for example C02 / D09 / `Slot24_BEVEL_DF_027`), emit an explicit
  `OUTER_BOUNDARY_UNCERTAIN`/coverage hold. Do not use that orange boundary as
  a production detection limit, training truth, or XML geometry.
- Accepted chipout, edge, and bevel-damage regions must use a low-alpha yellow
  fill and a thin semi-transparent yellow boundary in review imagery so the
  underlying BF/DF evidence remains visible. This is a display-only rule and
  must not change masks, classifications, geometry, truth, or eligibility.
- V2CX human decisions are the edge review authority, but their preserved `TrainingEligible=0` and `XMLGeometryEligible=0` flags still apply.
- See `DO_NOT_USE_OR_TRAIN.md` for the consolidated exclusion list.

## Prohibited actions

- Do not train or retrain anything.
- Do not generate or write production XML geometry.
- Do not run a full lot.
- Do not package or release anything.
- Do not execute existing project Python, PowerShell, batch, HTML, installer, converter, or machine workflow during inventory.
- Do not modify existing source packages or extracted source trees during inventory.
- Do not overwrite, delete, rename, or move original archives.
- Do not extract an archive over an existing folder.
- Do not treat V2CR, V2CU, V2CV, V2CW, or V2CY as the missing V2CT baseline.
- Do not treat source-code references to geometry CSV filenames as the geometry data itself.
- Do not create XML geometry from audit candidates.
- Do not use broad radial holder/notch sector masks.
- Do not use nearest-neighbor chain grouping.
- Do not use old baked preview images as active heatmap or contour views.
- A chipout contour must be edge-connected and transition to persistently outside-wafer pixels. Interior dark particles, contamination, and residue remain surface-zone evidence and are ineligible.
- `EdgeMicroDamage` is the approved automatic reject class for a validated
  short DF inner-boundary micro pocket that passes the bounded V4.1 rule but
  does not have a complete dark corridor through the bevel to persistent
  outside-wafer space. Routine human classification is not part of this
  decision. A complete corridor routes to the separate `EdgeChipout` stage;
  absence of a micro pocket produces no `EdgeMicroDamage` reject. Until
  separately approved for production integration, these automatic decisions
  remain review-only, training-ineligible, XML-geometry-ineligible, and
  production-ineligible.
- Low DF contrast or incomplete local profile support is an inspection
  coverage hold, not `NoEdgeMicroDamage` and not Normal truth. Display-only
  curve enhancement may help review the area, but it must not alter detector
  pixels or silently convert a low-signal hold into a no-reject result.

## Artifact authority

Use this order unless the user supplies a newer, checksummed artifact:

1. Canonical V2CT logical/package baseline:
   - `Argos_DefectReview_V2CT_RenderOnly_CleanHeatmapContour_tool_package.zip`;
   - `Argos_V2CT_render_only_notes.txt` inside `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip`;
   - `Argos_V2CT_sample_V2CO_G1440_fixed.jpg` inside the handoff;
   - `Argos AI Feedback.txt` governing brief inside the handoff.
2. `V2CX_GUI_BUTTON_feedback_pack_20260724_110500.zip` for edge truth-lock decisions.
3. `V2CW_GUI_BUTTON_feedback_pack_20260724_104526.zip` for feedback-applied provenance.
4. `V2CV_GUI_BUTTON_feedback_pack_20260724_101435.zip` for the complete V2CV feedback set.
5. `V2CV_DF_EDGE_BEVEL_OUTWARD_AUDIT_20260724_093331.zip` for full V2CV audit output.
6. The three-part full-evidence snapshot for historical V2CM–V2CR provenance only.

`V2CV_GUI_BUTTON_feedback_pack_20260724_095411.zip` is a visible subset and is not the complete V2CV authority.

No extracted V2CT run folder exists in the workspace. Record this as: “V2CT exists as a locked logical/package baseline; full extracted output folder not found in workspace.” Do not block staging on the missing extracted output, and do not substitute V2CR/V2CU/V2CW/V2CY for V2CT.

The three geometry CSVs in the workspace are the authoritative same-lot AutoGeometryBootstrap seeds for the targeted V2DC harness. Their bootstrap/prior labels and circle confidence near 0.621 are accepted facts, not blockers. Do not edit them; copy them only into scratch.

`Slot1Slot3Slot17.zip` supplies sufficient Slot01/03/17 backside BF/DF working images. They are `resizedImage.bmp` inputs, not sensor RAW. Preserve `flipImageHorizontal=true`.

`BareBackside.zip` supplies complete full-resolution BF/DF frontside/backside folders for Slot02, Slot13–Slot16, and Slot18–Slot25. Only backside imagery is in scope. The current geometry CSVs and V2CX truth locations do not cover these additional slots; do not run an unlabeled or full-lot V2DC scan on them.

The V2DB and V2DC packages inside `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip` are supplied source candidates only; they have not been executed or approved for implementation.

## Required pre-implementation gate

Do not create or edit the V2DC detector/package code until the user explicitly approves implementation. The isolated contact-sheet harness is the only approved executable source. The artifact/staging prerequisites are satisfied:

- browser-chat continuation supplied and read;
- canonical V2CT logical/package baseline confirmed;
- three authoritative geometry CSV seeds supplied;
- V2DB/V2DC source candidates supplied;
- full-size working Slot01/03/17 backside BF/DF samples supplied and declared sufficient;
- isolated work/scratch directories approved.

## Safe inventory operations

Allowed read-only operations include:

- listing files and ZIP central directories;
- reading manifests, CSVs, JSON, text, and source for inventory;
- computing hashes;
- comparing files without modifying them;
- updating only the inventory/governance Markdown files requested by the user.

Approved staging operations:

- copy original inputs into the isolated scratch tree without changing the originals;
- extract only copied Slot01/03/17 sample archives into a new empty scratch directory;
- copy only thumbnail/JSON inventory members from `BareBackside.zip` into a new empty scratch directory; do not extract full-resolution additional-slot BMPs without a targeted review plan;
- under a documented targeted human-review plan, copy only explicitly selected additional-slot backside BF/DF BMPs into a new scratch directory and create no-detection visual crops; do not interpret sampled sectors as full-wafer negative truth;
- compute hashes and inspect metadata;
- keep source code, detector pipelines, GUIs, production outputs, and original run folders untouched.

Approved targeted evaluation operations:

- create and run the isolated contact-sheet harness under `work\V2DC_edge_residual_spike`;
- read only the staged Slot01/03/17 Bare backside inputs;
- write new timestamped review-only PNG, CSV, and JSON outputs;
- refuse overwrite and keep every row training- and XML-ineligible.

The harness must not import or execute the existing detector pipeline.

## Bare and BowComp separation

- The current V2DC contact-sheet work is `BARE_BACKSIDE_ONLY`.
- Do not mix BowComp images into Bare calibration, local-offset statistics, tolerance selection, or review outputs.
- BowComp is a future separate domain with nitride and substantially higher surface/edge variation.
- BowComp will require its own inventory, truth review, geometry validation, tolerance study, and targeted approval.
- Do not assume Bare thresholds or residual morphology transfer to BowComp.

If extraction is later approved, extract only into a new empty staging directory and verify the target path first.

## Approved isolated V2DC working rule

The explicitly approved isolated V2DC work must:

- be created in a new `work/V2DC_edge_residual_spike` tree;
- consume the V2CT surface artifact read-only;
- add edge-only residual-spike logic;
- use targeted, review-only smoke tests rather than a full lot;
- keep production XML output disabled;
- keep training disabled;
- keep packaging disabled until separately authorized.

## Wafer alignment and notch safety

- Do not assume the wafer notch is at a fixed image angle or position.
- Estimate wafer translation and rotation per wafer; Argos loading/prealignment
  can shift or rotate a wafer.
- Keep tool-frame fixed-holder/contact geometry separate from wafer-frame notch
  geometry.
- Never use a fixed notch-angle mask as an automatic rejection rule.
- A chipout can resemble or corrupt the notch. When notch and chipout evidence
  conflict, emit an explicit ambiguity/review state rather than forcing either
  classification.
- Notch validation must use local shape, width/depth, edge continuity, and
  per-wafer alignment evidence. It must not rely only on proximity to the
  expected notch position.

Before any build or package is considered, generate targeted sample contact sheets showing:

- cyan expected edge;
- orange observed edge;
- gray tolerance/nonreject band;
- yellow accepted residual chipout islands.

## Active front-metal physical-footprint contract

Front-metal detector physical-footprint development must resume from
`work/ACTIVE_ARGOS_EDGE_LAB_STATE.md` and retain the exact locked detector
feedback at
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`.
The feedback SHA-256 is
`D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`.
Do not substitute a newer gallery, cached detector replay, chat description,
or screenshot for this saved native-coordinate response.

The current operator-facing review state is D5, recorded in
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/FRONT_METAL_D5_RECOVERY_RECONCILIATION_AND_SESSION_SAFETY_CHECKPOINT_20260814.md`.
The released review-only reviewer ID is
`FM_D5_CANONICAL_V4_20260813T184500Z`. The current D5 operator response is
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T002521Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
SHA-256
`7E3E586F2CA7611935434932A93F74E5393C35ADD66553FE581A1F64A756D967`.
It is staged classification guidance only and must never be automatically
applied to detector masks or promoted to training, XML, production, or size
truth. D4 review ID `FM_D4_CANONICAL_V3_20260813T223500Z` remains a separate
diagnostic input and must not be substituted for D5.

The next canonical review must preserve the locked interface and add separate
accepted and held heatmap layers to the full-wafer view. Preserve the
operator's written class guidance and emit class-specific holds when evidence
is insufficient. Do not interpret this as authority to train.

Raw native BF and DF are the only authority for physical defect width, area,
and affected-die geometry. Seam-corrected target-excluded DF residual and
strict-zero-peer DF support are display-only localization aids. They may
identify bounded corridors to inspect but must never be painted, thresholded,
or relabeled as final physical defect geometry. Sparse proposal pixels that
merely touch an operator-marked path do not constitute footprint agreement.
The saved feedback includes paired raw-visible physical-damage paths where a
shorter/broader branch and a longer/narrow branch must both be recovered;
localization support on only a few points is under-coverage.

`FRONT_METAL_NATIVE_PEER_V1_6_20260811T220500Z` is withdrawn from operator
review and is diagnostic only. Its default reviewer painted the review-union
alpha over the enhanced panels, and its cached-peer replay measured
localization contact rather than raw-footprint recovery. A successor must
keep enhanced panels clean by default, show result masks as separately
toggleable layers, and audit each saved path for longitudinal coverage,
transverse expansion, unsupported gaps, and false-control overlap before it
is shown to the operator.

Use the canonical BowComp reviewer in `work/BOWCOMP_REVIEW_ONLY/reviewer_v1`
exactly as governed above. Do not create a replacement interface. Front-metal
work remains truth-informed review-only, training-ineligible, XML-ineligible,
and production-ineligible.
