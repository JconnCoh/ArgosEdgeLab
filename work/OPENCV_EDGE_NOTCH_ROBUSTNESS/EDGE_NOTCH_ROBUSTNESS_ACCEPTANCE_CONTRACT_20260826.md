# OpenCV edge/notch robustness acceptance contract — 2026-08-26

Disposition: `LOCKED_INPUT`  
Authority: review-only development and validation requirements. This contract
does not grant provider activation, production routing, XML, training, defect,
Normal, source mutation, wafer action, or hold-clearance authority.

## Purpose and required order

Complete OCV-02 scribe development on Slots19-21, freeze the scribe engine,
and execute Slots22-25 as an independent no-tuning validation partition before
beginning OCV-03 perimeter/notch work. A failed validation target is frozen as
failure evidence and may enter only a fresh later development revision with a
new independent validation partition.

OCV-03 treats edge and notch detection as a separately frozen image-processing
family. Existing accepted results on ordinary wafers are parity controls.
Known legacy failures are development and permanent regression challenges,
not accepted truth and not independent validation.

## Mandatory robustness cohorts

- Exact operator-named hotspot lot:
  `Lot_62629-419_NotchBad_Hotspot`. Argos missed the physical notch on at least
  one wafer because a hotspot darkened the notch and produced an incorrect
  rotation. The failed legacy rotation is not truth.
- Every discoverable known chipout wafer in the bounded Argos/KLARF evidence
  catalog. A physical chipout remains a notch competitor and must never be
  selected as the manufactured notch merely because it is deepest.
- Ordinary wafers with currently accepted notch/edge results, used only for
  unchanged-semantic parity.
- A separately frozen independent paired BF/DF validation partition that is
  not inspected or tuned before the model is frozen.

The exact physical identities, source paths, source hashes, acquisition
fingerprints, and development/validation assignments must be frozen before
pixel outcomes are inspected. Later scans of the same physical wafer do not
count as independent wafers.

## Acceptance rules

1. Zero incorrect rotations in the frozen robustness and independent
   validation cohorts.
2. Zero chipout-as-notch selections.
3. Correct hotspot-obscured notch position and angle when evidence is
   sufficient; otherwise emit `FRONTSIDE_NOTCH_ALIGNMENT_HOLD` rather than
   guessing.
4. Fit and adjudicate BF and DF independently with native 1:1 pixels. Never
   condition one channel on the other and never average their transforms.
5. Never select by fixed image angle, acquisition zero angle, fixed position,
   or deepest indentation.
6. A channel-local inward boundary caused only by appearance/illumination,
   without independent physical-boundary displacement, is ineligible to
   establish pose.
7. A BF/DF-supported physical indentation remains an eligible competitor.
   Resolve multiple plausible physical candidates with manufactured-notch
   morphology, native refinement, and reciprocal notch-relative scribe
   support; otherwise hold.
8. Preserve incomplete coverage, channel disagreement, multiple plausible
   physical candidates, and notch-versus-damage ambiguity as explicit holds.
9. Preserve frontside handedness (`flipImageHorizontal=false`) and never infer
   die-grid phase from notch angle alone.
10. Do not use screenshots, thumbnails, resampled rasters, old baked previews,
    or failed legacy rotations as pose truth.

## Deferred human validation

The operator may be unavailable while development proceeds. Any fact that
cannot be established mechanically from exact file-backed evidence remains an
operator-visible hold. Development may continue around those holds, but no
human-only judgment is guessed, silently defaulted, or promoted to validation
truth.

## Preserved invariants

The live provider remains disabled. The protected processor is not restarted
or modified. Work, cache, runtime-intensive processing, and outputs remain on
JBOD `D:`. All current scribe, reference-coverage, alignment, appearance,
training, XML, production, deletion, and source/wafer holds remain in force.

