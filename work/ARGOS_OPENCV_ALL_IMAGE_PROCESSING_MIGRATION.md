# Argos OpenCV all-image-processing migration program

Revision: `OPENCV_ALL_IMAGE_PROCESSING_MIGRATION_V1_20260822`

Disposition: `PENDING_GATE`
Authority: review-only migration definition; no live processor replacement,
image read, XML, training, production, deletion, or wafer action is authorized
by this document.

## Objective

All image decoding and pixel processing must move out of PowerShell and into
configuration-selected OpenCV providers. This includes scribe deciphering,
wafer perimeter and notch pose, fiducial localization, reference composites,
inspected-wafer registration, Bare, all backside regimes, BowComp, frontside
unpatterned and patterned inspection, defect masks, heatmaps, crops, and review
raster generation.

PowerShell remains responsible for orchestration: watchers and scheduling,
configuration and manifest validation, exact file discovery/copy/rename/hash,
provider invocation and timeout handling, queue/ledger/dashboard/GUI data flow,
and signed Project Portal transport. It must not decode images, loop over
pixels, crop/resize/filter/composite rasters, perform OCR, fit image geometry,
register wafers, score defects, or generate image-derived masks and heatmaps.

## Starting point

The old direct-native notch V3 is diagnostic history, not reusable source. It
passed a synthetic chipout control but failed the sealed FS15 regression at
15/15 holds and violated independent-channel semantics by conditioning DF on
BF and allowing pose averaging. It was never integrated into the installed
processor and remains `WITHDRAWN`.

The newer OpenCV prototype is the structural starting point, not a qualified
live implementation. Its five synthetic cases pass, BF and DF are independent,
and its portable runtime is installed and self-tested at `D:\AFCV1\rt`. No
real OpenCV development pixels have been scored; the installed inspection
processor has not been integrated with it. The current blocker is exact source
path authority for the paired PFC003/PFC010 development inputs.

## Updated remaining work

1. **OCV-00 — exact inventory and source authority.** Inventory every installed
   PowerShell, C#, and helper operation that reads image bytes or produces
   image-derived measurements, rasters, masks, crops, transforms, or
   composites. Resolve and hash the exact PFC003/PFC010 BF/DF inputs. Freeze
   current family outputs and semantics as regression baselines.
2. **OCV-01 — provider platform.** Define versioned job/result, transform,
   composite, mask, and review-raster schemas. Select runtime and provider from
   configuration. Put runtime-intensive work, caches, and outputs on JBOD `D:`.
   Preserve the unchanged disabled path and fail closed on missing runtime.
3. **OCV-02 — scribe deciphering.** Replace weak scribe image processing with
   OpenCV pose-bound ROI localization, BF/DF channel-local enhancement,
   rectification, glyph segmentation, OCR candidates, canonical/checksum
   scoring, calibrated confidence, and explicit operator holds. Do not guess
   ambiguous characters. Preserve reciprocal notch-relative scribe evidence as
   a pose/alignment gate.
4. **OCV-03 — perimeter, notch, and global pose.** Independently fit full-native
   BF and DF perimeters; preserve physical chipouts and other indentations as
   competitors; reject appearance-only competitors from pose authority;
   require manufactured-notch morphology and reciprocal scribe support; fail
   closed on ambiguity, incomplete coverage, or channel disagreement. FS15 is
   exposed failure evidence and cannot be a tuning set.
5. **OCV-04 — reusable fiducials.** Bind operator-designated topology and site,
   automatically calibrate native channel-local sustained geometry, freeze
   product-specific appearance regimes, require exactly one eligible refined
   site-bound candidate, then independently validate paired BF/DF without
   tuning.
6. **OCV-05 — composite and registration.** Build the reference composite only
   from qualified reference transforms with exact source/model provenance.
   Register every inspected patterned wafer to that exact composite revision
   before comparison.
7. **OCV-06 — Bare/unpatterned.** Migrate the accepted Bare front and backside
   pixel processing, preserving edge, notch, bevel, microdamage, scratch,
   particle, residue, and coverage semantics. BowComp truth must remain
   isolated.
8. **OCV-07 — backside regimes.** Migrate backside normalization, visual-regime
   evidence, geometry, scratches, particles, residue, edge, and coverage.
   Visual evidence may support routing but cannot replace metadata authority;
   missing or ambiguous regimes hold.
9. **OCV-08 — BowComp.** Preserve `RG_AVERAGE`, raw BF/DF availability, blue
   nuisance semantics, tangential-transition rejection, faint-scratch
   sensitivity, V5.7 supported-axis recovery, and separation of defect
   presence from subclass confidence. BowComp geometry stays held until
   independently qualified.
10. **OCV-09 — all frontside families.** Migrate frontside dielectric,
    front-metal, resist, scratch, and other pixel processing. Unpatterned
    families qualify independently; patterned comparison cannot occur before
    exact composite registration.
11. **OCV-10 — review assets.** Generate detector masks, heatmaps, crops,
    overlays, and review rasters in OpenCV with clean-source, mask, transform,
    revision, coordinate, and feedback provenance kept separate.
12. **OCV-11 — shadow comparison and activation.** Compare each OpenCV family
    against the frozen working implementation on bounded review-only cohorts.
    Activate one qualified provider at a time through configuration. Prove
    unchanged disabled behavior, fail-closed states, rollback, resource limits,
    and D-drive performance before proceeding to the next family.

## Integration rules

- No hard-coded lot, product, source root, output root, FS15 exception, or
  production-authority switch may exist in an OpenCV engine.
- The processor selects providers and authority from installed configuration;
  switching on a qualified provider must not require a source-code edit.
- Existing successful family behavior is frozen and compared mechanically;
  migration does not authorize redesign of working semantics.
- Geometry and registration produce evidence, never production authority.
- Missing, ambiguous, unqualified, or provenance-mismatched inputs produce
  explicit holds.
- No big-bang live replacement is allowed. Migration is family-by-family and
  review-only until separately qualified and authorized.

The machine-readable companion is
`work/ARGOS_OPENCV_ALL_IMAGE_PROCESSING_MIGRATION.json`.
