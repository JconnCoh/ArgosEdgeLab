# ArgosEdgeLab — Current State

Status: **All 16 available Bare backside native surface reviews completed;
frozen Bare edge contracts still pass; corrected six-wafer BowComp
surface-transfer diagnostic completed with tangential nitride-boundary
filtering and BowComp geometry held; production use not approved**

## 2026-07-28 Bare completion and BowComp transfer

The native, lossless-BMP Bare surface study completed all 16 available
backside wafers. All 16 runs passed their surface execution/integrity gates
with zero holder leaks, zero accepted holder-overlap pixels, and zero
class-specific confirmations. The separate frozen edge contracts were rerun
after the surface work:

- combined component contract: 26/26;
- V5.9 resolution contract: 27/27;
- V5.11 resolution contract: 29/29.

This confirms that the surface changes did not alter the frozen
Slot01/Slot03/Slot17 chipout, microdamage, or MAN053 DF-only authority.

The BowComp study remains a separate domain. Both supplied archives were
staged as six independent lot/slot identities. All six completed a
native-pixel blue-robust surface-transfer diagnostic using `RG_AVERAGE`
detector evidence. The run produced zero holder leaks and no broad blue-film
heatmap overcall. Representative native-pixel audit crops show useful
scratch recovery, including faint scratches that would be lost by a simple
threshold increase.

A first full six-wafer diagnostic exposed three long false scratch traces
that followed the inner blue nitride transition on the second lot. That
diagnostic was not accepted. The current BowComp-only correction rejects a
long, unsupported component when its major axis is essentially tangential
to the wafer, while retaining scratches that cross or depart from the blue
band. The three exposed controls fell to zero scratch pixels, all ten marked
positive tiles retained their exact counts, and the corrected six-wafer pass
completed 6/6 with zero holder leaks. Bare compatibility remains 13/13 and
the frozen edge combined contract remains 26/26.

The unchanged Bare geometry qualifier did not transfer to BowComp. All
BowComp edge/notch/bevel engines therefore remain explicit geometry holds;
no Bare tolerances were loosened and no BowComp edge authority was claimed.

Detailed record:

- `BOWCOMP_SIX_WAFER_TRANSFER_STATUS_20260728.md`
- `BOWCOMP_V66_NATIVE_COMPONENT_CONFIDENCE_CHECKPOINT_20260730.md`

The latest V6.6 correction consumed the saved operator annotations without
requiring the same cards to be reviewed again. Exact freehand-path auditing
now shows direct native-pixel anomaly evidence in 12/12 saved miss markings,
Scratch reject/confirmation evidence in 11/12, and no Scratch reject or
confirmation in all 6 saved false nitride-texture markings. The one remaining
noticed-only stroke is fail-closed coverage evidence, not Normal truth or
inferred Scratch geometry.

A fresh six-wafer V49 run completed 6/6 identities and 180 native scoring
tiles with zero accepted holder overlap. Eight frozen targeted tiles matched
the complete run byte-for-byte across all 56 compared raw/mask artifacts.
The output still contains class-specific Scratch confirmation holds and is
therefore a review-only confidence checkpoint, not autonomous production
authority.

The focused BowComp annotation GUI now has a clean V5 highlighter page. V4 is
superseded because it reused composite images with legacy magenta guide boxes
baked into all three views. V5 rebuilds all 22 panels from the latest V49
native BF, display-only local contrast, and accepted/confirmation evidence
without drawing any guide box. It uses translucent, adjustable-width
MISS/FALSE/ISSUE brush corridors, defaults each card to `All three`, preserves
the existing coordinate fields, and tags new strokes as
`tool: HIGHLIGHTER`. Closed highlighter strokes are never polygon-filled by
the saved-annotation audit. The historical V3 page and completed V3 feedback
remain unchanged. See
`BOWCOMP_REVIEW_GUI_CLEAN_HIGHLIGHTER_V5_20260730.md`.

## V5.11 Slot18 independent gate

V5.11 keeps the V5.9 detector unchanged and adds a separate confidence hold
layer. An automatic microdamage reject must have at least two direct accepted
one-hop neighbors in the existing 8-192 px interval and a maximum bright run
of no more than 9 px. Failure becomes an explicit
`INSPECTION_HOLD_CORROBORATION_QUALITY_INSUFFICIENT`, not Normal truth.

The frozen labeled regression retained all 8/8 accepted microdamage
references and automatically rejected none of the 9/9 labeled non-damage
references. That was post-exposure development evidence, so Slot18 was frozen
separately before extraction and scoring.

Slot18 per-wafer circle/notch geometry passed. The frozen base scan produced
zero large-damage rejects and three microdamage rejects. The pre-frozen V5.11
layer converted all three to quality holds, leaving zero automatic rejects.
One separate large-DF candidate remains a BF-corroboration hold, and 29/64
coverage sectors remain holds rather than Normal results.

The operator reviewed the two combined post-freeze locations:

- `H01`: `NOT_DAMAGE` - contamination, possibly dielectric;
- `H02`: `NOT_DAMAGE` - polished reflective bevel.

Review page:

- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_11_SLOT18_BLIND_PRETRUTH_FULL_CIRCUMFERENCE_20260727T004214Z/POSTFREEZE_HUMAN_REVIEW_V1/SLOT18_HOLD_REVIEW.html`

Primary V5.11 records:

- `work/V2DC_edge_residual_spike/implementation/v5_11_confidence_layer/V5_11_CONFIDENCE_LAYER_FREEZE.md`
- `work/V2DC_edge_residual_spike/implementation/v5_11_confidence_layer/V5_11_REGRESSION_AUDIT_20260727.md`
- `work/V2DC_edge_residual_spike/implementation/v5_11_confidence_layer/IMPLEMENTATION_RESULT_V5_11.md`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_11_SLOT18_BLIND_SELECTION_20260727T003450Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_11_SLOT18_BLIND_GEOMETRY_20260727T003809Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_11_SLOT18_BLIND_PRETRUTH_FULL_CIRCUMFERENCE_20260727T004214Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_11_RESOLUTION_CONTRACT_20260727T005312Z`

The V5.11 resolution contract passed 29/29. V5.11 is now the stable
Bare-backside review-only confidence checkpoint and has independently avoided
the exposed V5.10 automatic false-reject pattern. Autonomous sensitivity is
not established because Slot18 contained no human-confirmed damage in the
reviewed locations, and 29 low-coverage sectors remain explicit holds rather
than Normal results.

## V5.10 independent transfer result

The V5.9 rules were transferred unchanged to independently selected Slot22,
Slot14, and Slot23 Bare backside wafers. Selection and per-wafer circle/notch
geometry were frozen before defect scoring. All three geometry gates passed,
and the candidate manifests record `knownTruthConsumed=false`.

The run produced no automatic large-damage rejects and two automatic
`EdgeMicroDamage` rejects, both on Slot14:

- `Slot14_MICRO_0006`
- `Slot14_MICRO_0007`

The user classified both as `NOT_DAMAGE`. They are independent blind false
positives and must be suppressed. V5.10 therefore does not validate the V5.9
one-hop local-corroboration rule for independent automatic transfer.

The V5.9 same-wafer checkpoint remains preserved. Any correction developed
from the V5.10 findings is truth-informed and requires a separately frozen
blind gate before a new transfer claim. The review remains training-,
XML-geometry-, and production-ineligible.

Primary V5.10 records:

- `work/V2DC_edge_residual_spike/implementation/v5_10_blind_transfer_geometry/V5_10_BLIND_TRANSFER_AUDIT_PENDING_REVIEW.md`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_10_BLIND_TRANSFER_GEOMETRY_SLOTS142223_20260726T233816Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_10_BLIND_TRANSFER_PRETRUTH_FULL_CIRCUMFERENCE_20260726T234408Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_10_BLIND_TRANSFER_PRETRUTH_FULL_CIRCUMFERENCE_20260726T234408Z/BLIND_REJECT_HUMAN_REVIEW_V1/V5_10_BLIND_REJECT_REVIEW.html`

## Current V5.9 checkpoint

The Slot01/Slot03/Slot17 full-circumference V5.9 regression is complete. It
keeps all V5.8 pixel, geometry, large-damage, coverage, and safety rules and
adds one fixed one-hop micro-corroboration decision:

- a separate accepted micro interval must be 8–192 px away;
- nearest-neighbor chain grouping is prohibited;
- an isolated otherwise-valid micro signal becomes
  `INSPECTION_HOLD_ISOLATED_MICRO_SIGNAL`, not Reject and not Normal.

The V5.8 unmatched human review supplied three DAMAGE decisions and seven
RESIDUE/NORMAL decisions. V5.9 retained exactly those three damage detections
as unmatched automatic rejects and converted all seven false rejects to
explicit inspection holds.

The frozen regression recovered 5/5 known large-edge positives and 6/6 known
micro positives while suppressing 13/13 known edge negatives and 3/3 known
micro negatives. MAN053 remains DF-only with no borrowed BF contour. The
immutable combined component contract passed 26/26, and the V5.9 resolution
contract passed 27/27.

This is a truth-informed same-wafer regression, not independent blind
validation. Automatic authority for an isolated tiny damage signal is not
established. V5.9 remains review-only, training-ineligible,
XML-geometry-ineligible, and production-ineligible.

Primary records:

- `work/V2DC_edge_residual_spike/implementation/v5_autonomous_locator_gate/IMPLEMENTATION_RESULT_V5_9.md`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_9_POSTAUDIT_LOCAL_MICRO_CORROBORATION_FULL_CIRCUMFERENCE_20260726T231437Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V5_9_RESOLUTION_CONTRACT_20260726T232147Z`
- `work/V2DC_edge_residual_spike/outputs/review_only/V2DC_COMBINED_COMPONENT_CONTRACT_V1_20260726T231757Z`

## Resolved by the handoff

- The browser-chat continuation is present as `Argos AI Feedback.txt` inside `ARGOS_CODEX_HANDOFF_ARTIFACTS.zip` and has been read completely.
- V2CT render-only tooling and lock notes are present.
- V2CX postprocessor tooling, the six-row truth-lock feedback pack, and analysis report are present.
- V2DB and V2DC source packages are present inside the handoff.
- Map/XML infrastructure notes are present.
- The three authoritative same-lot geometry seed CSVs are present.
- `Slot1Slot3Slot17.zip` supplies the six sufficient full-size backside BF/DF working images.
- `BareBackside.zip` supplies 26 additional full-resolution backside BF/DF working images for Slot02, Slot13–Slot16, and Slot18–Slot25.
- Approved copied inputs have been staged under `scratch\V2DC_edge_residual_spike_staging`.

## Locked state

- V2CT surface behavior is locked and immutable.
- All planned implementation is edge-only.
- Surface rows cannot create `EdgeChipout`, `ChipoutSmall`, `BevelDamage`, or `PhysicalDamage`.
- No training.
- No production XML geometry.
- No full-lot run.
- No packaging.
- V2DC work must remain isolated under `work\V2DC_edge_residual_spike`.
- Review-only harness approval does not authorize production integration.

## Current authority

1. V2CX six-row human truth lock for edge decisions.
2. V2CW feedback-applied pack for provenance.
3. V2CV complete feedback pack and audit output for the full review set and cropped samples.
4. V2CT continuation/notes/tool package/sample as the canonical locked logical/package baseline.
5. Three-part full-evidence snapshot for historical V2CM–V2CR provenance only.

V2CT exists as a locked logical/package baseline; full extracted output folder not found in workspace. This is no longer a blocker.

## Staged inputs

- `scratch\V2DC_edge_residual_spike_staging\source_archives\Slot1Slot3Slot17.zip`
- `scratch\V2DC_edge_residual_spike_staging\geometry\` — three byte-identical CSV copies
- `scratch\V2DC_edge_residual_spike_staging\extracted_samples\` — 30 backside-only files:
  - 6 full-size working BMPs;
  - 6 acquisition JSON files;
  - 18 metadata/thumbnail PNGs.

Original files remain untouched. `flipImageHorizontal=true` must be preserved.

## Remaining boundary

No input artifact is blocking isolated targeted V2DC preparation.

The approved contact-sheet run is:

`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_CONTACT_SHEETS_20260724_233524Z`

It contains six individual contact sheets, one overview, a review-only manifest, and a safety summary. MAN016 reaches the full 160 px reviewed bite and uses one contiguous human-confirmed curved left wall without a loop, separate wedge, or adjacent rounded contact feature. MAN040 shows five separate shallow islands plus one tiny review-guided outline across the confirmed chewed edge. Slot17 emitted zero radial chipout contours and two thin DF-only support outlines. No detector pipeline, GUI, XML, training, full lot, archive, or package was produced.

The latest revision incorporates thin pink human review guidance and an explicit edge-zone rule: accepted chipout residuals require a complete dark corridor through the expected edge into outside-wafer space. Search depth grows only to the bounded reviewed area. The tiny MAN040 outline and MAN016 non-radial closure remain labeled review aids, not autonomous detections. Interior dark surface particles, contamination, and residue separated from the outside by intact wafer are excluded.

Two additional approved targeted validations are complete:

- `work\V2DC_edge_residual_spike\outputs\review_only\V2DC_BARE_NEGATIVE_CONTROLS_20260724_233451Z` — nine representative V2CV false controls, all rejected.
- `work\V2DC_edge_residual_spike\outputs\review_only\V2DC_DF_BEVEL_CONTROLS_20260724_234115Z` — MAN053 detected as two DF-only bevel disruptions; eight false DF controls rejected.

The user accepted the current MAN053 result as the conservative DF-bevel review reference. The two detected damage cores are correct; tiny pink-marked endpoint/shoulder misses are a known minor under-contour and must not be chased by globally widening the bevel detector. Revisit those endpoints only after additional confirmed DF bevel-damage positives are available.

Notch and holder rejection uses overlap with the narrow same-lot `EXPECTED_NOTCH_PRIOR_MATCH` and `HOLDER_FIXED_PRIOR_MATCH` intervals. It does not use broad radial sector masks.

The additional Bare archive was inventoried without extracting its full-resolution BMPs. A thumbnail-only, no-detection screening set is at `work\V2DC_edge_residual_spike\outputs\review_only\BARE_ADDITIONAL_SLOT_THUMBNAIL_SCREEN_20260724_235721Z`. Full-resolution evidence is present, but the current authoritative geometry CSVs and V2CX truth cover only Slot01, Slot03, and Slot17. The additional slots must not be treated as automatic positives or negatives without targeted geometry and human review.

A later bounded full-resolution visual spot check copied only Slot13, Slot20, and Slot25 backside BF/DF images into scratch and created eight paired native-resolution edge sectors per slot at `work\V2DC_edge_residual_spike\outputs\review_only\BARE_FULLRES_EDGE_VISUAL_REVIEW_SLOTS132025_20260725_000354Z`. No detector ran. No obvious Slot01/03-like chipout is visible in the sampled sectors, but the result is not continuous 360° coverage and does not establish negative truth.

Targeted review-only V2DC harness work was subsequently approved and is active
under `work\V2DC_edge_residual_spike`. Production integration, machine-workflow
execution, GUI-server launch, production XML, full-lot execution, and packaging
remain unapproved.

The held-out DF post-freeze review is complete at
`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_HELDOUT_DF_POSTFREEZE_GATE_20260725_031736Z`.
All six reviewed candidate groups D01-D06 were resolved by the operator as
`NORMAL_EDGE` validation negatives. D01 and D06 required independently fitted
inner/outer bevel-boundary follow-ups. For final D06, the orange outer boundary
was accepted while the cyan inner boundary was noted to sit too far inside the
dark wafer edge. This is a retained geometry limitation, not training truth or
production geometry.

The remaining human-review gate is the three-case held-out Brightfield
notch/chipout ambiguity set H01-H03 at
`work\V2DC_edge_residual_spike\outputs\review_only\V2DC_ROUND2_HELDOUT_BF_GATE_20260725_025716Z\HELDOUT_NOTCH_REVIEW_GALLERY_WITH_RESPONSES.html`.
Its candidates and geometry were frozen before human review. It remains
review-only, training-ineligible, and XML-ineligible.

That gate is now complete: H01-H03 were all human-reviewed as
`NORMAL_NOTCH`. None is chipout or notch-damage truth. Those decisions also
resolve the eight corresponding Darkfield notch-held groups as confirmed
normal-notch-associated review negatives without rewriting the frozen
manifests.

The resulting review baseline is summarized in
`work\V2DC_edge_residual_spike\V2DC_BARE_REVIEW_BASELINE_V1.md`. The next
recommended gate is one additional three-slot blind raw BF/DF smoke test on
previously unreviewed Bare slots selected by a frozen hash. It is not a
full-lot run and requires no production XML, training, packaging, or BowComp
work.

The next-gate selection is frozen before image review in
`work\V2DC_edge_residual_spike\V2DC_BARE_BLIND_SMOKE_V2_SELECTION_FREEZE.md`.
The selected slots are Slot21, Slot24, and Slot15. Their full-size BF/DF
backside working images and metadata are present in `BareBackside.zip`; the
selected inputs have not yet been extracted or scored for this gate.

Current work is Bare-backside-only. Future BowComp/nitride work must be inventoried and calibrated as a separate higher-variation domain; Bare thresholds must not be transferred automatically.

## Documentation

- `PROJECT_INVENTORY.md` — approval summary.
- `INVENTORY_ARGOS_EDGE_LAB.md` — detailed evidence inventory.
- `MISSING_ARTIFACTS.md` — recovery checklist.
- `AGENTS.md` — governing workspace rules.
- `TODO_V2DC_EDGE_RESIDUAL_SPIKE.md` — original bounded V2DC scope and
  restrictions.
- `DO_NOT_USE_OR_TRAIN.md` — training/truth exclusions.
- `ARGOS_MAP_CONVERSION_AND_XML_INFRASTRUCTURE.md` — descriptive map/XML notes.
- `ARGOS_GUI_DASHBOARD_ROADMAP.md` — consolidated future review GUI,
  reporting, alignment, downstream analytics, and PowerPoint-export roadmap.

Original source packages and production workflows remain unmodified. New
executable work is confined to the approved isolated review harness; its
outputs remain review-only and ineligible for training and production XML.

The first isolated V2DC implementation increment is now complete under
`work/V2DC_edge_residual_spike/implementation/v1`. It adds only
boundary-confidence estimation and safety refusals. The final targeted run at
`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V1_BOUNDARY_REGRESSION_20260725_184529Z`
passed 7/7 confidence regressions and 5/5 frozen evidence checks. C02 keeps an
`OUTER_BOUNDARY_UNCERTAIN` hold; the other six groups remain review usable.
At completion of that V1 increment, the residual-island decision layer still
required separate approval. That approval was later granted and is recorded
in the V2 completion paragraph below. Production integration, training, XML,
full-lot execution, GUI deployment, packaging, and BowComp remain disabled.

The second isolated residual-island increment is now complete at
`work/V2DC_edge_residual_spike/implementation/v2`. The authoritative V2.5
targeted run passed 15/15 expected decisions and 10/10 frozen file checks:
five BF chipout positives detected, nine selected V2CX negatives suppressed,
and MAN053 preserved as DF-only. A focused seven-view operator gallery is
provided in that run. Production integration, training, XML, full-lot
execution, GUI deployment, packaging, surface changes, and BowComp remain
disabled.

The user's written V2.5 review showed that technically valid child islands
still under-represented complete physical damage. The normalized review is in
`work/V2DC_edge_residual_spike/V2DC_FOCUSED_REVIEW_NORMALIZED_20260725.md`.
An isolated V3 parent-span candidate now groups the two Slot01 evidence views
into one physical chipout event and MAN040/MAN041/MAN042 into one Slot03
chewed-edge event. Its targeted run at
`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V3_PARENT_SPAN_REVIEW_20260725_204013Z`
passed 15/15 technical regressions and 10/10 frozen checks. Human review of
the two parent events and the still-pending MAN042 local contour is required.
No production integration, training, XML, full lot, GUI deployment, package,
surface change, or BowComp action is authorized.

The isolated V4.1 DF inner-boundary micro-pocket increment is complete under
`work/V2DC_edge_residual_spike/implementation/v4`. Its authoritative targeted
run is:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_1_DF_MICRO_POCKET_REGRESSION_20260725_225620Z`

It reproduces the six human-accepted Slot03 micro-pocket examples and rejects
the three human-marked false examples (9/9 expected decisions). A frozen
alignment stress test passed 225/225 combinations over radial and tangential
errors from -2 through +2 pixels. The upstream V3 gate continues to suppress
all nine frozen V2CX negatives, and the MAN053 DF-only reference is unchanged.

These six accepted features interrupt the DF inner boundary but do not form a
complete dark corridor through the bevel to persistent outside-wafer space.
They therefore must not be promoted automatically to `EdgeChipout`,
`ChipoutSmall`, production/XML geometry, or training truth.

The user subsequently approved `EdgeMicroDamage` as their autonomous reject
class. V4.2 implements that taxonomy without a routine human-classification
step: accepted micro pockets without a complete corridor automatically become
`EdgeMicroDamage`/`REJECT`; complete corridors defer to the separate
`EdgeChipout` stage; rejected pockets produce `NoEdgeMicroDamage`.

The authoritative targeted V4.2 run is:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_2_EDGE_MICRO_DAMAGE_REGRESSION_20260725_232132Z`

It produced six automatic rejects, three automatic non-rejects, zero holds,
and 9/9 taxonomy regressions. A second run produced a byte-identical
classification manifest. Production integration remains unapproved; all
outputs retain `TrainingEligible=0`, `XMLGeometryEligible=0`, and
`ProductionEligible=0`.

The next validation boundary is documented in
`work/V2DC_edge_residual_spike/V2DC_EDGE_MICRO_DAMAGE_HELDOUT_VALIDATION_PLAN.md`.
Phase A would test the frozen automatic rule on bounded, previously unseen
Slot03 locations and expose complete selected strips so false positives and
missed visible damage can both be measured.

Phase A has now executed at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_EDGE_MICRO_DAMAGE_PHASE_A_HELDOUT_20260725_235935Z`

V4.3 adds the previously missing autonomous first-stage locator. It recovered
all six known accepted references and none of the three known false
references. Across eight hash-selected held-out strips it emitted 35
first-stage signals and zero automatic `EdgeMicroDamage` rejects. Six windows
had usable DF coverage and automatic no-reject results. H01 and H07 are
explicit low-DF-coverage inspection holds and must not be counted as Normal.
The window and candidate manifests reproduced byte-for-byte. The remaining
gate is one-time complete-strip review for visible misses; Phase B and
production integration remain unapproved.

Phase B later exposed a specificity failure: `Slot01_B01-03` contained three
automatic yellow `EdgeMicroDamage` rejects that the user identified as no
damage. `Slot17_B17-02` remained unresolved/possibly bevel-only. Phase B is
therefore retained as exposed regression evidence rather than fresh transfer
evidence.

V4.5 is implemented in the isolated review tree at
`work/V2DC_edge_residual_spike/implementation/v4_5`. It aligns radial sampling
locally before first-stage extraction and adds a candidate-level physical
boundary-morphology gate. The authoritative frozen and exposed regressions
retained 6/6 positives, suppressed 3/3 negatives, removed all three B01-03
false rejects, and reproduced byte-identical manifests.

A genuinely new Phase C selection was frozen before pixel inspection at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_PHASE_C_NEW_BLIND_SELECTION_20260726_030822Z`

The completed review is at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_PHASE_C_NEW_BLIND_TRANSFER_GATE_20260726_031138Z`

Human assessment is **pass with four preserved inspection holds**:

- all four usable strips had no visible miss;
- all four hold displays had no visible damage observed;
- none of the holds were converted to Normal or negative truth;
- there were zero automatic rejects and zero human-rejected rejects.

Two holds are caused only by coherent 10 px offsets beyond the current 8 px
alignment bound. Two others lack sufficient DF transition support and must
remain holds. Any experiment to conditionally support the stable 10 px cases
requires separate approval and another new blind gate.

Training, XML, production integration, full-lot execution, packaging, GUI
deployment, surface changes, and BowComp remain disabled.

## Isolated Bare surface scratch / EtchStain study

An explicitly separate review-only Bare surface study now exists under:

`work/BARE_SURFACE_INSPECTION_REVIEW`

It does not modify, rerun, or reinterpret V2CT. Scratch processing remains
full-resolution and conservative. `Slot21_IMPRINT_DEFECT_PIXEL_01` is the
human-confirmed review-only Scratch transfer reference, but it is not
training, XML, production, or pixel-exact geometry truth. The Slot21 pen
fields are `InkResidue` diagnostic controls, not Scratch truth.

The user clarified that the near-edge etch stain is a wafer-concentric
surface band that may be discontinuous. The broad V1.1 mask was then rejected
as too weak and radially overfilled. The current dark-core V1.2 result is:

`work/BARE_SURFACE_INSPECTION_REVIEW/outputs/review_only/SURFACE_ETCH_STAIN_DARK_CORE_V1_2_20260727T170426Z`

V1.2 uses original BF grayscale pixels and reduces accepted EtchStain to the
thin locally darkest angularly coherent core. The broader weak haze remains a
separate audit-only support mask and is not rejected area. Slot21 accepted
area fell from about 366.64 mm2 in the over-broad V1.1 display to 27.89 mm2.
The BF adjusted card view now uses a bounded mid-gray local-contrast display
instead of saturating the normal wafer surface white. The result is
review-only and training-, XML-, production-, package-, and BowComp-ineligible.

The current combined integrated Slot21 surface-feedback run is:

`work/BARE_SURFACE_INSPECTION_REVIEW/outputs/review_only/SURFACE_INTEGRATED_SLOT21_REVIEW_20260727T204606Z`

Its full-wafer tab uses the original BF/DF BMP as the base with separate
toggleable accepted-reject, scratch-candidate, unclassified, and coverage-hold
heatmaps. The user confirmed
that the previous orange `Other` layer contains real defects, so its
components are now `Residue` review-only rejects and the unclassified layer
is empty. Known Slot21 ink is corrected to `Residue`, and the bounded black BF
specks in the EtchStain windows are independent magenta `Residue` masks rather
than part of the red stain core. Compact raw-visible dark BF spots at the
physical wafer perimeter are again surface-defect eligible; only the locally
connected holder bodies and their immediate outlines are excluded. No broad
holder/notch sector mask is used. Its local event cards provide BF and DF
raw/adjusted toggles, transparent evidence toggles, explicit feedback
semantics, copy fallback, and JSON response export. Adjusted card views are
display-only in this run.

A local standalone Windows review app loads the newest compatible integrated
run and writes feedback to `Desktop\ARGOS_REVIEW_FEEDBACK`. It is a
review-only local utility, not a production GUI deployment.

The combined run also attaches the fixed Slot21 tiled scratch transfer:
five review-only candidate views and eight unique inspection holds after exact
duplicate tile views are suppressed. It records eight required engines in
`ENGINE_STATE_MANIFEST.json`. All eight are explicitly configured. Scratch,
contamination/particle, residue, and dark-core EtchStain are `ENABLED`.
Chuck-imprint classification, EdgeChipout, EdgeMicroDamage, and DF-only
BevelDamage remain visible fail-closed `HOLD` rows because this stitched
surface review has no clear autonomous imprint decision or matched Slot21
edge/bevel result attached. The overall state is
`INSPECTION_HOLD_REQUIRED_ENGINE_OUTPUT_NOT_CLEAR`. A missing/failed engine
cannot become a silent pass, and all GUI toggles are display-only.

## Slot21 pixel-only imprint study

The rejected off-center cyan chuck-circle diagnostic remains retired. The
current bounded follow-up does not find or draw circles. It tests the Slot21
wafer center as a temporary 4000 x 4000 source crop and emits only locally
abnormal raw-BF pixels plus components formed by direct sampled-pixel
adjacency.

The current deterministic candidate is:

`work/BARE_SURFACE_INSPECTION_REVIEW/outputs/review_only/SURFACE_IMPRINT_DEFECT_PIXELS_20260727T191745Z`

It contains 48,719 working evidence pixels and 24 bounded review cards. The
sampled cards include strong scratches/specks and faint visible curved or
linear imprint fragments without extrapolating their missing pixels. The
detector mask, component CSV, and BF/DF adjusted review views reproduced
byte-for-byte across the repeat. The crop is tuning evidence only, not
full-wafer coverage or negative truth. See
`work/BARE_SURFACE_INSPECTION_REVIEW/SURFACE_IMPRINT_PIXEL_STUDY_20260727.md`.

The user subsequently confirmed
`Slot21_IMPRINT_DEFECT_PIXEL_01` as a real long diagonal `Scratch`. It is now
the review-only transfer reference for a Slot21-only tiled scratch audit at
the proven 4000-source/3000-working-pixel response scale. It is not training
truth or production/XML geometry. The
audit may stitch only detector fragments with observed pixel overlap in
shared tile regions; it may not infer or draw a line through missing pixels.

The confirmed response was then transferred in 20 bounded overlapping
Slot21 tiles at its proven 4000-source/3000-working-pixel scale. The current
review authority is:

`work/BARE_SURFACE_INSPECTION_REVIEW/outputs/review_only/SURFACE_SLOT21_TILED_SCRATCH_PIXEL_TRANSFER_20260727T195151Z`

It recovered the confirmed long center scratch and exposed one additional
shorter line candidate. The finalized gallery contains five candidate views
and eight unique holds; overlapping views are not claimed as separate
physical events. The full-wafer overview is separate from local BF/DF cards.
The accepted center mask repeated byte-for-byte. See
`work/BARE_SURFACE_INSPECTION_REVIEW/SLOT21_TILED_SCRATCH_PIXEL_TRANSFER_RESULT_20260727.md`.

The earlier native-response experiment
`SURFACE_SLOT21_NATIVE_SCRATCH_TRANSFER_20260727T193907Z` missed the confirmed
scratch and is a failed diagnostic, not authority.

The fixed response was then transferred without tuning to the other bounded
Bare review slots. Slot03 produced zero candidates and five holds, Slot15 zero
and eight, and Slot24 zero and twelve. These are conservative review-only
holds, not negative or reject truth. No missing gallery artifacts were found
across any of the four outputs. See
`work/BARE_SURFACE_INSPECTION_REVIEW/BOUNDED_TILED_SCRATCH_PIXEL_TRANSFER_RESULT_20260727.md`.

## Slot03 MAN042 BF-primary / DF-corroborated candidate

The user confirmed that the isolated V3 MAN042 child contour broadly
under-covered the damaged edge. That local review page was BF-only and also
omitted the broader `Slot03_CHEWED_EDGE_EVENT_01` parent coverage.

The operator confirmed that V3.1 still fragmented the visibly continuous
chewed edge. V3.1 is therefore retained as review provenance and is not the
current candidate.

The current isolated V3.2 candidate is at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V3_2_SLOT03_DF_EVENT_CONTINUITY_REVIEW_20260726T162717Z`

It uses local DF ridge depression/broadening to anchor the bounded physical
event while BF remains the only contour-geometry source. Short positive BF
gaps are kept continuous, the exact local notch/holder vetoes remain active,
and unsupported smooth drift is excluded. It yields one 270.30 px continuous
main run and one 54.06 px right-hand run. The separate extremely tiny
far-left feature remains unaccepted and uncertain.

The user accepted the V3.2 event continuity but found its radial depth
under-covered. The current depth-only V3.3 candidate is:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V3_3_SLOT03_BOUNDED_INWARD_DEPTH_REVIEW_20260726T164606Z`

It preserves both accepted V3.2 angular spans and moves 17 BF samples inward
by 1–4 px. Each expansion has a strong raw tangent-averaged BF transition and
a complete dark corridor to outside-wafer space. The configured maximum is
5 px. The uncertain far-left feature remains excluded.

The user accepted V3.3 depth as correct. V3.3 is now the Slot03 review-only
contour authority. The frozen historical V3 output remains unchanged.
Training, XML, production integration, full-lot execution, packaging, GUI
deployment, surface changes, and BowComp remain disabled.

## V3.4 DF-native damage-existence study

A separate review-only study tested the operator's proposal that an obvious
DF damage component can drive a reject decision without requiring exact DF
contour geometry:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_V3_4_DF_NATIVE_SIZE_GATE_STUDY_20260726T165210Z`

With a fixed 40 px minimum connected arc, the Slot03 MAN040 positive triggered
at 88.096 px. All eight frozen DF false controls remained suppressed. The
closest false-control remainder was 30.098 px at the edge of the Slot03 notch;
the next was 22.079 px at the Slot17 notch. MAN053 remains out of this chewed-
edge taxonomy and under its separate DF-only bevel logic.

This is promising evidence for a future DF-primary `damage exists / reject`
path. The DF evidence band is approximate display-only visualization and is
not BF contour geometry, XML geometry, or training truth. The extremely tiny
far-left feature is expected to remain below the size gate and needs a
separate future sensitivity/false-fail study.

## Combined edge-component contract

The isolated read-only combined authority validator passed 26/26 checks at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_COMBINED_COMPONENT_CONTRACT_V1_20260726T160321Z`

It validates the frozen V1 DF boundary-confidence manifest, V3 parent-span
manifest, MAN053 DF-only bevel manifest, and V4.5.2 recovery/Phase E
artifacts together. It does not run or merge detector code.

The contract preserves three non-approved states:

- MAN042 remains `PENDING_HUMAN_REVIEW`;
- C02 / `Slot24_DF_GROUP_11` remains `OUTER_BOUNDARY_UNCERTAIN`;
- the five Phase E low-DF-coverage rows remain inspection holds.

All selected V2CX negatives remain suppressed, MAN053 retains two DF-only
support runs without borrowed BF geometry, and every checked row remains
review-only and training/XML/production-ineligible.

## V4.5.2 conservative signal-floor gate

The V4.5.1 Phase D review confirmed that `D01-01`, `D01-02`, and `D17-01`
were dark/low-coverage sectors. The Slot01 BF and DF source files are
uncompressed 24-bit BI_RGB BMP working images, and the review strips are
lossless PNG. They remain Argos `resizedImage.bmp` inputs rather than
sensor-raw images.

The only Phase D automatic reject, `D01-04`, was not human-confirmed. Its
absolute local DF contrast drop was approximately 5.434 gray levels, compared
with 6.610 for the weakest previously confirmed tiny positive. V4.5.2 adds a
general 6-gray automatic-reject floor. Sub-floor candidates remain explicit
inspection holds.

V4.5.2 retained 6/6 frozen accepted references and 0/3 frozen false
references. The exposed Phase B, C, and D regressions passed. `D01-04` now
becomes an inspection hold with its evidence retained, not an automatic
reject.

A new Phase E selection was frozen before image inspection at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_2_PHASE_E_NEW_BLIND_SELECTION_20260726_135018Z`

Its review-only transfer output is:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_2_PHASE_E_NEW_BLIND_TRANSFER_GATE_20260726_135239Z`

It contains zero automatic rejects, five low-DF-coverage holds, and three
usable automatic no-reject windows. Human review found no visible miss in all
three usable strips and no visible damage in all five hold displays. The five
dark-sector rows remain holds without forced human classification; they were
not converted to Normal or negative truth.

The assessment is preserved in
`PHASE_E_HUMAN_ASSESSMENT_20260726.md` inside the transfer-output directory.
A complete deterministic repeat of the Phase A-E core detector artifacts
matched 67/67 files byte-for-byte. V4.5.2 is frozen as the current stable
review-only `EdgeMicroDamage` component.

A future dual-pass Bare acquisition is appropriate only if the second scan
changes the wafer-to-illumination relationship through validated rotation or
alternate lighting/exposure. Each pass must be independently aligned in wafer
coordinates, and sector selection must use predetermined signal quality
rather than detected defect presence.

Training, XML, production integration, full-lot execution, packaging, GUI
deployment, surface changes, and BowComp remain disabled.

## V4.5.1 stable extended-alignment gate

The isolated V4.5.1 experiment keeps the normal local-alignment bound at
8 pixels and permits 9- or 10-pixel alignment only with transition support at
least 0.98 and offset MAD no greater than 0.5 pixels. It also prevents a stable
extension from silently erasing preliminary evidence: one or more preliminary
signals followed by zero aligned candidates remains an explicit
`INSPECTION_HOLD_ALIGNMENT_ERASED_PRELIMINARY_SIGNAL`.

Phase A retained 6/6 frozen accepted references and 0/3 frozen false
references. The exposed Phase B and Phase C regressions passed, including
preservation of their necessary low-coverage and evidence-erasure holds.
Repeated Phase A/B/C runs reproduced all 27 compared artifacts byte-for-byte.

A genuinely new Phase D selection was frozen without pixel inspection at:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_1_PHASE_D_NEW_BLIND_SELECTION_20260726_053914Z`

Its review-only transfer output is:

`work/V2DC_edge_residual_spike/outputs/review_only/V2DC_IMPLEMENTATION_V4_5_1_PHASE_D_NEW_BLIND_TRANSFER_GATE_20260726_054205Z`

The eight blind windows contain one automatic rejection, three
low-DF-coverage holds, one alignment-evidence-erasure hold, and three usable
automatic no-reject results. Phase D is pending human visual review. A
no-damage observation in a hold display does not convert that hold to Normal
or negative truth.

Training, XML, production integration, full-lot execution, packaging, GUI
deployment, surface changes, and BowComp remain disabled.
