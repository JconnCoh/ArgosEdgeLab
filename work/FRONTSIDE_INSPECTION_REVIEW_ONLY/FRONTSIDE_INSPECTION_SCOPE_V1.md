# Frontside inspection review-only scope V1

Status: active, isolated engineering workstream. This scope does not enable
frontside inspection on the JBOD, training, KLA/XML generation, bin export,
recipe writing, or production routing.

## Purpose

Develop frontside review-only detection for the same broad surface and
physical-edge evidence needed on the backside while respecting frontside
pattern and dielectric appearance. Scratch presence has first priority for
sensitivity, but this is not scratch-only authority and must never suppress,
omit, or postpone other supported defect evidence.

Initial proposed defect classes are:

- `Scratch`;
- `Residue` (including known-process residue when independently supported);
- `Contamination`;
- `Particle`;
- `Stain`;
- `EdgeChipout`;
- `EdgeMicroDamage`;
- `BevelDamage`;
- class-specific confirmation holds when evidence or validated authority is
  insufficient.

The frontside inspection domain runs through the physical wafer boundary. It
must inspect the surface, narrow edge zone, physical edge, notch neighborhood,
and visible bevel evidence. A detector or review page restricted to the
interior surface is incomplete and must be held rather than reported as a
frontside pass.

`HotSpot` is reserved in the class contract but remains
`DISABLED_NO_EXAMPLES`. It must not create detections, training truth, bins,
or XML rows until representative photo examples and a separate validation
gate exist.

Recurring patterned or dielectric structure is reference context, not a
defect class. It must not be relabeled merely to make a comparison pass.

Known material origin does not create a separate residue defect class. Ink,
when its origin happens to be known, is still classified and detected as
`Residue`; origin may be retained only as provenance metadata. It must not
receive a separate detector exception, scratch threshold, production class,
or XML bin.

## Identity and cohort contract

Frontside material state is independent of the Bare/BowComp backside regime.
Backside calibration, thresholds, truth, geometry, or golden images must not
be reused as frontside authority.

Every acquisition is joined in this order:

1. operator-confirmed frontside scribe;
2. exact read-only MES lineage keyed by scribe;
3. the last exact Insite `MoveIn` preceding the Argos scan plus the next
   surrounding event, preserving the scan timestamp basis;
4. a later/current visual-state snapshot as provenance only, never as proof
   of the material state at scan time;
5. native BF/DF source provenance;
6. independently qualified frontside center, radius, notch, and handedness;
7. exact acquisition-profile evidence.

The exact visual-state key is inherited unchanged from
`FRONTSIDE_GOLDEN_REFERENCE_CANDIDATE_CONTRACT.md`. Missing fields never form
an `UNKNOWN` or nearest-neighbor cohort.

Process-block, step, recipe, and folder names do not establish whether the
frontside is patterned. A label containing `PATTERN` may describe a process
block whose earlier steps are still visually unpatterned, while a later step
inside that same block may be patterned. Pattern state must be supported by
the actual BF/DF appearance and the scan-time Insite history. If those two
sources disagree or the surrounding history is incomplete, emit an explicit
frontside appearance-state hold; never borrow the later/current MES state.

A wafer that has entered the pattern-forming tool sequence is not eligible
for an unqualified unpatterned declaration merely because the expected end
step is not recorded. An interruption, breakage event, rework, or engineering
scan may capture an intermediate material state. Use
`POTENTIALLY_PATTERNED_PROCESS_INTERRUPTION_HOLD` until the actual BF/DF
appearance and complete surrounding history support a stable cohort. Such a
wafer must not contribute to either an unpatterned or patterned composite.

## Composite method contract

Patterned/dielectric wafers require target-excluded references. A target wafer
must never contribute any acquisition to its own reference. Repeated scans of
one physical wafer do not count as independent physical peers.

A comparison may advance only when:

- visual-state and acquisition-profile keys are complete and exact;
- center/radius/notch and `flipImageHorizontal=false` are explicit;
- frontside pattern/grid phase and orientation are independently validated;
- at least three distinct physical peer wafers remain after target exclusion;
- BF and DF references are constructed and retained separately;
- the raw target and composite-residual evidence are both preserved;
- a recurring feature cannot be cleared solely because it appears in every
  member of the current lot.

The last condition is enforced by comparing a newly proposed lot reference to
a separately approved, versioned cross-lot golden before promotion. Promotion
is human-gated and append-only. A feature common to the lot becomes a
cross-lot comparison hold, not silent Normal truth.

Source images remain unchanged. Detector scoring must use the original
native lossless pixels. Reduced images, thumbnails, and overview composites
are display-only and cannot establish detector truth. A target may remain in
its native coordinate system while peer samples are mapped into that system;
the transform, interpolation rule, crop origin, and scale must be recorded.

The current 15-acquisition intake lacks a complete acquisition-profile key,
so no current cohort is an approved golden cohort. The six-physical-wafer
CONTACT cohort may support a bounded display/registration diagnostic; the two
two-wafer cohorts and the singleton remain explicit physical-peer-count holds.

## Geometry boundary

Frontside notch selection follows the governing physical-competitor rules.
No deepest-indentation or fixed-angle shortcut is allowed. Ambiguous physical
competitors emit `FRONTSIDE_NOTCH_ALIGNMENT_HOLD`.

Surface inspection may use qualified pose for masking and registration, but
frontside die-grid phase/orientation requires its own validation. No XML
coordinate export is allowed from notch pose alone.

Frontside edge chip, microdamage, and bevel decisions require a separate
frontside geometry qualification. Bare-backside V5.11 geometry authority is
not transferable. Until that qualification passes, detected edge/bevel
evidence remains in class-specific confirmation holds; it is not omitted,
erased, or treated as Normal.

The visible frontside tool hardware is behind the wafer and must not create a
frontside holder-exclusion mask. Do not use a blanket inward surface inset or
broad angular/radial exclusion. Suppress only independently qualified
non-wafer pixels and the bounded scribe identity region. Compact raw-supported
surface evidence remains eligible up to and touching the physical perimeter.

## Operator review contract

The production-shaped review layout must clone the already accepted JBOD
backside layout instead of introducing a new card or feedback system:

- one `Composite Accepted BF` full-wafer tab;
- one `Composite Accepted DF` full-wafer tab;
- raw accepted OR target-excluded shadow accepted, by class;
- confirmation holds excluded from the accepted display but retained in the
  machine record;
- exact supported accepted pixels over the unchanged full-wafer base;
- no bounding boxes, inferred lines, filled region heatmaps, or broad halos;
- no scratch-only event queue as the primary review;
- the physical edge and visible bevel remain in frame;
- the same lot/date selection, image export, and sharing behavior as the
  approved backside viewer.

Local crops may exist only as secondary diagnostics after the full-wafer page
has exposed the complete all-class result. They do not replace full-wafer
coverage or the accepted BF/DF interface.

## Frozen safety state

- `reviewOnly = true`
- `trainingEligible = false`
- `xmlEligible = false`
- `xmlGeometryEligible = false`
- `productionEligible = false`
- `jbodFrontsideProcessingEnabled = false`
- `hotSpotEnabled = false`
