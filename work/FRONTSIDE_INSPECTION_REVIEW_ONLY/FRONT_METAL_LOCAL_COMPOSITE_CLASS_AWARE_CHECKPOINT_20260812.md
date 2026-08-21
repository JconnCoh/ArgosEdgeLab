# Front-metal local-composite class-aware checkpoint — 2026-08-12

## State

`PASS_REVIEW_ONLY_LOCAL_COMPOSITE_COVERAGE_WITH_FAIL_CLOSED_CLASS_HOLDS`

This checkpoint corrects the prior broad composite-difference display. The
composite is used only after target exclusion and local target-to-reference
registration. Original native BF/DF pixels define retained physical
footprints and defect size. The target is not warped or resampled.

## Frozen operator evidence

- Feedback: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260811T172156Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`
- SHA-256: `D642D9F64F0F45BDF8CB3518DCD49E6A42AA05B1AF5E62942973D99467DEB320`
- Positive strokes: 70
- Explicit false scribe controls: 4

## Registration result

- Ten non-scribe feedback fields passed bounded local reference registration.
- `T21_R04C00` deliberately remains a reference-coverage hold because only
  one of three target-excluded peers qualified; the peer gate was not weakened.
- The four false scribe controls in T21 are wholly inside the locked scribe
  exclusion (4/4 exact full coverage), while its three contamination strokes
  are outside that exclusion (0/3 touched).

## Exact feedback audit

Qualified registered fields contain 67 positive strokes:

| Class | Total | Direct accepted | Accepted or class hold | Missed |
|---|---:|---:|---:|---:|
| Scratch | 53 | 48 | 53 | 0 |
| ResidueStreak | 8 | 0 | 8 | 0 |
| Contamination | 2 | 2 | 2 | 0 |
| Residue | 4 | 3 | 4 | 0 |

The remaining three T21 contamination strokes stay in the explicit local
reference-coverage hold. Therefore all 70 positive strokes have bounded
detector support or an explicit coverage/confidence hold, and all four false
scribe controls are excluded.

The accepted footprint occupies 181,554 of 48,000,000 scored pixels
(0.3782375%) across the ten registered 2400 x 2000 native fields. This is not
the earlier 3.1% class-neutral texture field.

## Weak-scratch promotion decision

Five scratches were initially hold-only. A bounded sweep on only the affected
T27 and T29 native fields showed that one T27 scratch could be promoted by a
conservative strong-seed adjustment. The three exposed weak T29 paths did not
support a safe global threshold reduction. They remain explicit Scratch
confirmation holds. This prevents grid flooding and does not create Normal
truth.

No grid pitch, direction, recurrence, component size, or repeated-location
rule is used to suppress candidates. A real defect may cross or coincide with
the product pattern. Unsupported gaps remain empty.

## Locked safety contract

- Target-excluded composite required.
- Local reference registration required; reference pixels may move, target
  pixels may not.
- Original native BF/DF required for physical footprint and size.
- Scribe, holder, and physical-boundary exclusions apply before candidates.
- Frontside chipout branch is unchanged.
- Common-mode evidence cannot be promoted without an approved golden sentinel.
- No review GUI is published from this checkpoint.
- Review-only; training-, XML-, and production-ineligible.

## Evidence files

- Combined audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/MWC_V8_CLASS_AWARE_FEEDBACK_AUDIT_20260812/COMBINED_STROKE_AUDIT.json`
  - SHA-256: `E9567AD7C06F096DF94B5D6C51DBA26F26F699AFA0EF9C02F40979CC488CA566`
- T21 exclusion audit: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/MWC_V7_T21_SCRIBE_EXCLUSION_FEEDBACK_AUDIT_20260812.json`
  - SHA-256: `23F89624B3432889C2844C4FF5002DE187E95AD0003BFE25BD90F55F0C96250F`
- Promotion sweep: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/MWC_V8_PROMOTION_SWEEP_V3_20260812/PROMOTION_SWEEP_SUMMARY.csv`
- Detector source: `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FrontMetalCompositeSeededRawFootprintV1.cs`
  - SHA-256: `2EC097D559CFFDC1413AD0962FB33806BEF4CFDEB29A60A51393259C05938C72`

