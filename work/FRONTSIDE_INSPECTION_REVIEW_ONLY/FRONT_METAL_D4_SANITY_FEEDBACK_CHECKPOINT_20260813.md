# Front-metal D4 sanity-feedback checkpoint — 2026-08-13

## Frozen operator response

- Review: `FM_D4_CANONICAL_V3_20260813T223500Z`
- Response directory: `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T222605Z`
- Coordinate JSON SHA-256: `FD714DA87C377AD0AEFA5A646174BA54EF57B15B87205CF224F084B8A79D4476`
- Response TXT SHA-256: `B115971F4D6D84EE6CE15184496F38C1CBD0264713C57D7182EA213F987327A0`
- Save-complete marked native fields: 25
- Save errors: 0

## Operator findings

The D4 sanity review exposed three distinct false-evidence appearances:

1. ordinary recurring grid/street responses;
2. inverted-grid responses that select die interiors rather than streets;
3. sparse pings in null-die structures.

The response contains 91 accepted strokes: 58 false-detection removals, 30
real-defect reclassifications, and 3 missed-defect additions. The real-defect
marks include 27 Scratch reclassifications, 3 missed Scratch paths, and compact
Particle controls. They are the sensitivity lock for any correction.

Explicit grid comments are present on T02, T03, and the operator reports the
same structural failure mode in T07. The review was intentionally stopped
before every field was assessed; unreviewed pixels are not Normal truth.

## Governing correction contract

- Do not use a blanket grid-pitch, direction, recurrence, or component-size veto.
- Do not treat same-lot or same-line recurrence as proof of Normal; a common
  manufacturing defect remains possible and requires golden/common-condition
  sentinel handling.
- Attribute every reviewed false and real stroke to accepted core and each
  disjoint confirmation branch before changing eligibility.
- Preserve native BF/DF scale 1:1, holder exclusion, physical edge eligibility,
  scribe exclusion, and the separately frozen frontside chipout engine.
- A false-response correction must retain the marked Scratch and Particle
  controls and must not manufacture pixel-exact truth from display halos.
- All work remains review-only, training-ineligible, XML-ineligible, and
  production-ineligible.

## Current state

`ATTENTION_D4_STRUCTURAL_FALSE_EVIDENCE_EXPOSED`

No detector or review authority changed at this checkpoint.
