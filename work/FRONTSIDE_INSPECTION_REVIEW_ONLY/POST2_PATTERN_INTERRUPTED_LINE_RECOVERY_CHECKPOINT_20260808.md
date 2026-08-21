# POST2 patterned-frontside interrupted-line recovery checkpoint

Date: 2026-08-08  
State: review-only; operator confirmation required

## Frozen operator feedback

- Response: `C:\Users\joshua.conn\Downloads\FRONTSIDE_POST2_FULL_WAFER_FEEDBACK_RESPONSE.json`
- SHA-256: `3A5364FC852B8E0B21900D9F722CF197EBB44B3B6D0F7B10051B4A083F88A1D9`
- Saved open-path guidance: 38 strokes on Slot02, Slot03, Slot18, and Slot25.
- The strokes are overview/native-coordinate guidance. They are not pixel truth, training truth, XML truth, or production authority.
- Because the first marker did not preserve the selected BF/DF view and defaulted every miss to Scratch, these 38 paths remain class-neutral missed-surface-defect guidance. Slot25 includes operator-identified pen residue and must not be promoted to Scratch merely because it is linear.

## Existing detector evidence audit

- Native evidence audit: `work\FP2_PATTERN_FEEDBACK_EVIDENCE_AUDIT_V1_20260808T185500Z\FEEDBACK_EVIDENCE_AUDIT_RESULT.json`
- The existing accepted masks had registered local support near 36 of 38 saved paths.
- The main failure mode was fragmentation: long visible defects appeared as isolated specks instead of a connected, reviewable path.
- The two exact local no-support exceptions remain unresolved local underkill. They were not manufactured into detections.

## Bounded continuity recovery

- Frozen-mask run: `work\FP2MS1_20260808T2210Z\RECOVERY_INDEX.json`
- Inputs are the target-excluded, strict native masks already scored at 14411 by 10995 and scale 1.
- No composite was recomputed and operator feedback was not detector input. Feedback selected the bounded evaluation tiles only.
- Recovery joins only already observed native evidence fragments. It does not fill unsupported gaps or infer a complete line.
- Fixed gates: at least 6 fragments, at least 4 occupied 48-pixel bins, at least 150-pixel span, no gap over 96 pixels, and no normal RMS over 9 pixels.
- Parallel controls and the repeated-direction population gate suppressed recurring pattern-line families.
- Result across 51 marked-intersecting tiles: 431 confirmation candidates, 24,788 observed native pixels, and 670 repeating-pattern line candidates suppressed.
- Recovered evidence disposition is `CONFIRM_SCRATCH_PATTERN_INTERRUPTED_LINE`; it has no automatic-reject authority.

## Feedback coverage after recovery

- Audit: `work\FP2MS1_FEEDBACK_AUDIT_20260808T222000Z\RECOVERY_FEEDBACK_AUDIT_RESULT.json`
- Exact centerline support: 8 of 38 paths.
- Fixed brush-radius support: 12 of 38 paths.
- Fixed registration-margin support: 14 of 38 paths.
- This is a bounded diagnostic improvement, not a sensitivity claim. Unsupported saved paths remain underkill guidance.

## Current operator review

- Gallery: `work\FP2_PATTERN_INTERRUPTED_LINE_FULL_WAFER_REVIEW_V1_20260808T223500Z\POST2_PATTERN_INTERRUPTED_LINE_FULL_WAFER_REVIEW.html`
- Manifest: `work\FP2_PATTERN_INTERRUPTED_LINE_FULL_WAFER_REVIEW_V1_20260808T223500Z\INTERRUPTED_LINE_FULL_WAFER_REVIEW_MANIFEST.json`
- Four marked wafers are shown with six views each: Candidate BF, Raw BF, Accepted BF, Candidate DF, Raw DF, and Accepted DF.
- Magenta image pixels are the new confirmation layer. Existing accepted overlays are unchanged.
- Previous operator paths can be shown as yellow dashed guidance.
- New feedback records the exact view used for every stroke and permits a separate human class for missed Scratch, Residue, Contamination, Particle, EtchStain, or SurfaceDefect.
- No image bytes, base64, or data URLs are embedded in the HTML or task history.

## Required next gate

1. Operator checks Candidate BF and Candidate DF together.
2. Operator marks false magenta continuity evidence as overkill.
3. Operator marks remaining visible misses and assigns the best human class; Slot25 pen is Residue.
4. Only after this review may the same fixed recovery be exercised on the unmarked family tiles as a false-positive regression.
5. No JBOD deployment, training, XML, or production change is authorized by this checkpoint.
