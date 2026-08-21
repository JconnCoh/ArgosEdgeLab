# Argos reusable fiducial-model workflow

Date: 2026-08-18

Revision: `ARGOS_FIDUCIAL_MODEL_WORKFLOW_V1`

Disposition: `APPROVED_BASELINE`

Authority: operator-directed best practice distilled from the qualified test-
wafer workflow and the corrected PFC004 workflow. It governs review-only
fiducial-model creation, automatic calibration, and validation. It does not by
itself grant alignment, inspection, XML, production, or reject authority.

## Purpose

Turn a new product or process layer into a verified fiducial model quickly and
repeatably without rediscovering already-rejected methods. The mandatory
sequence is:

1. operator designation when topology is not already bound;
2. automatic native-pixel calibration using the proven geometric-line method;
3. frozen, no-tuning validation on independent wafers;
4. operator presentation only after the validation gate passes.

The workflow separates reusable geometry from appearance response. A topology
and its straight-line graph may be reused across wafers and across color or
composition changes when physical geometry is unchanged. Channel-local edge
polarity, gradient response, response width, and association behavior belong
to a declared appearance regime and must be automatically calibrated and then
validated. A new film stack is not permission to redraw the geometry, and a
shared geometry is not proof that the old response model transfers.

## Stage 0: inventory, provenance, and partition

- Bind exact product, revision, process block, step, operation, lot, physical
  wafer identity, channel, source path, source hash, and actual dimensions.
- Preserve each wafer's real dimensions. Never assume one fixed size for a lot.
- Use native lossless BF and DF pixels at 1:1 scale. A rotated or enlarged view
  is display-only and retains an exact affine map to the native source.
- Qualify the physical notch independently per wafer using the governing
  frontside notch-competitor rules. Map/bin evidence nominates a region only
  unless exact topology binding is already qualified.
- Partition evidence before tuning: designation/development, calibration,
  independent validation, and later production-transfer sets. A validation
  target cannot become calibration evidence after its result is inspected.
- Inventory the full lot and related process acquisitions before concluding
  that independent wafers are unavailable. A prepared gallery is not the raw
  source inventory.

## Stage 1: operator topology designation when needed

Skip repeated designation only when an exact locked topology identifier and
line inventory already apply. Otherwise:

1. Find the notch, map the bounded fiducial neighborhood, and create a straight,
   full-resolution paired BF/DF crop.
2. Let the operator mark the intended nonrepeating fiducial topology. Use exact
   saved-pixel differences or native coordinates; do not register a screenshot
   by repeating-die correlation.
3. Ask for line presence and identity semantics, not pixel-perfect geometry.
   Record every sustained horizontal/vertical boundary the operator says must
   exist.
4. Separate pose-bearing straight lines from identity-only arrows, curves,
   circles, stems, lollipops, text, or other disambiguating features.
5. Enumerate all inner and outer corners. Create a hash-bound corner-exclusion
   model. Rounded corners and arrow vertices have zero pose weight.

The designation output is a stable geometric topology model: model center,
ordered line IDs, nominal endpoints, outward normals, corner vertices, and
identity-only components. Operator strokes establish semantic presence; their
drawn endpoints and thickness are never automatic pixel truth.

## Stage 2: automatic channel-local calibration

Calibration is automatic once topology is bound.

### Edge association

- Search from geometric outside toward the intended interior and require an
  unused outside guard beyond every accepted crossing.
- Associate only within a bounded distance of the topology seed. A wider
  profile may expose alternatives but may not silently change edge family.
- Freeze signed gradient polarity independently for every BF/DF line using the
  strongest stable response in a bounded neighborhood of the seed. Do not use
  one brittle exact-seed sample and do not assume BF and DF share polarity.
- Reject a farther opposite-polarity transition, an outer profile-limit hit,
  a doubled/thick response, or a broken/bouncing response.
- Reject a sample before reading pixels when its full gradient and bilinear-
  interpolation footprint touches a locked inner or outer corner mask.

### Geometry calibration

- Determine nominal sample count and along-line coordinates from the nominal
  model length, never from transformed floating-point endpoint length.
- Fit channel-local line intercept and slope geometry on development evidence,
  iterating to a fixed point. Freeze that geometry before pose solving.
- Candidate pose solving has exactly three unknowns: `GLOBAL_X`, `GLOBAL_Y`,
  and `GLOBAL_THETA`.
- Per-candidate line intercept, slope, endpoint, polarity, or line-family refit
  is prohibited. Such local freedom makes global pose non-identifiable.
- BF is calibrated and solved from BF only. DF is calibrated and solved from DF
  only. BF/DF agreement is a diagnostic gate; transforms are never averaged.

### Required calibration evidence

Every line and channel records direct support, maximum unsupported gap, P90 and
maximum residual, response width, signed polarity, selected offsets, outside-
guard rejections, corner-masked samples, frozen intercept/slope, and accepted
native sample coordinates. The joint pose records rank, condition, rigid RMS,
P90 and maximum residual, X/Y/theta, and BF/DF disagreement.

Thresholds are appearance-regime parameters, not geometry edits. A threshold
may change only from bounded development evidence, with the exact old/new value
and motivating native response recorded. No validation result may motivate the
change.

## Stage 3: mandatory internal verification before transfer

The frozen development model must pass all applicable checks:

- all required lines in both channels;
- minimum direct support and maximum unsupported gap;
- residual, width, full-rank, and conditioning gates;
- zero accepted signed-polarity violations;
- alternating-sample or equivalent disjoint-sample cross-validation;
- common-nominal-pose X/Y/theta perturbation returns measured against the
  channel-local fixed points;
- line-order invariance and bounded line/sample leave-outs;
- nominal-sample-cardinality invariance under pose transforms;
- ignored-corner pixel mutation invariance;
- high-correlation repeating-pattern lookalikes rejected by incomplete rigid
  topology rather than by correlation rank or expected image angle.

The verifier must record the exact perturbation origin and return references.
Starting each channel from its return reference is a different experiment and
cannot replace the common nominal-pose test.

Line or sample leave-out stability is a geometry-space test. The verifier must
compare the full frozen line model under the complete and leave-out poses and
gate the maximum native-pixel displacement over its sampled points or
endpoints against a predeclared pixel bound tied to the fixed sampling
contract. Raw X, Y, or theta differences remain diagnostic fields; a scalar
theta difference alone is not a valid leave-out failure because the same
angle can have materially different pixel effects at different model sizes.

## Stage 4: independent frozen validation

- Apply the frozen topology, appearance response, polarities, line geometry,
  and thresholds to independent paired BF/DF wafers with no tuning.
- Locate each wafer from its own qualified notch pose. Do not transport a fixed
  image coordinate or an unproven map-bin offset across wafers.
- Require the complete nonrepeating topology and every mandatory line. A
  repeating die with high template correlation remains a reject/hold when its
  rigid line evidence is incomplete.
- Keep same-stage validation separate from later process acquisitions. A
  different color/composition may be a transfer diagnostic; failure means a
  new appearance-regime calibration using the same geometry, not arbitrary
  relaxation of the old model.
- Do not tune on a failed validation wafer. If the appearance regime is truly
  new, declare a new development/calibration revision and reserve fresh
  independent validation wafers before inspecting their outcomes.

At least one independent complete paired BF/DF positive is required before an
operator judgment raster. Use the full available lot when practical to expose
wafer-to-wafer variation; preserve physical identities and do not treat later
scans of the same wafer as independent wafers.

## Stage 5: presentation and downstream use

Only after frozen validation passes may a fresh file-backed operator raster be
built. It must separate direct native edge evidence, excluded corners, prior
pose, and fitted rigid pose into unambiguous layers. Colors never substitute for
line IDs, polarity, or inner/outer semantics. The raster is for judgment, not
for calibration.

Operator acceptance of the validated fiducial model permits the next fresh
alignment-transfer test. It does not grant defect, Normal, training, XML,
production, routing, or automatic-reject authority.

## Prohibited shortcuts retained from test-wafer and PFC004 failures

- no screenshot/repeating-grid correlation to recover an operator location;
- no assumption that bin 1, 32, 34, or 36 universally identifies a fiducial;
- no deepest-notch or fixed-angle notch selection;
- no endpoint trim as a substitute for full corner-footprint exclusion;
- no per-candidate line intercept or slope refit;
- no unguarded profile-limit crossing;
- no far/opposite-polarity edge-family switch;
- no exact-seed-only polarity decision;
- no transformed-length-dependent sample count;
- no dropping a difficult line or loosening residual/support gates to pass a
  repeating-die lookalike;
- no BF/DF pose averaging;
- no validation-target tuning;
- no conclusion that a lot is unavailable from gallery contents alone;
- no operator raster before internal and independent frozen validation.

## Standard run states

- `PENDING_OPERATOR_TOPOLOGY_DESIGNATION`
- `PENDING_AUTOMATIC_APPEARANCE_CALIBRATION`
- `HOLD_INTERNAL_FIDUCIAL_MODEL_VERIFICATION_FAILED`
- `PENDING_INDEPENDENT_FROZEN_VALIDATION`
- `HOLD_FROZEN_MODEL_DID_NOT_TRANSFER`
- `PASS_FIDUCIAL_MODEL_VALIDATED_REVIEW_ONLY`
- `HOLD_PATTERNED_WAFER_ALIGNMENT_TRANSFER_REQUIRED`

Every run uses the machine-readable companion contract and starts from
`work/templates/ARGOS_FIDUCIAL_MODEL_RUN.template.json`. Any deviation is a
new review-only workflow revision, not an implicit exception.
