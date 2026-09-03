# OCV-02 R18F four-of-four blind visual pass checkpoint — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`

- R18F blind outputs were frozen and committed before any image was opened.
  Unreviewed gate SHA-256:
  `7745BAF3B909712076327659F22940162A134E6CFCBA3168FF7C1A10F0A4D695`.
- Exact native BF and DF crops were then inspected for all four acquisitions.
- Every BF scribe is clear and matches its already-frozen image-first string
  character-for-character; each DF crop corroborates the same string.
- Blind results are:
  - `62633-726_20260818204139_Slot21`: `148AW101SUC4`;
  - `Lot-62546-481-POST2_20260713155808_Slot14`: `2969P018FEE3`;
  - `62624-869_20260720115731_Slot02`: `1478T009SUA0`;
  - `62625-956_20260729122701_Slot18`: `147JQ120SUA5`.
- All four strings independently pass M12 verification after visual reading.
  Checksum did not choose or rewrite any glyph.
- Visual exact count is 4; mismatch count is 0.
- Blind visual review gate is `work/OPENCV_SCRIBE_R18F/R18F_BLIND_VISUAL_REVIEW_GATE.json`.

R18F has now passed 9 frozen visible regressions, 5 blank/wrong-location
controls, 4 development cases, and 4 independent blind acquisitions. The
correct blank behavior and the previously misplaced-scribe behavior remain
preserved. This is strong bounded evidence, not yet a full-corpus result.

Exact next action: select another small metadata-only failure-first cohort,
weighted toward difficult POST2 and other current-reader failures, with no
overlap with R17A/R18A/R18E. Keep missing `I/O/V/Y` reference coverage as an
explicit hold. Pull only existing proposal/BF/DF scribe crops after a fresh
local package gate and explicit publication authority; do not run the full
KLARF directory yet.

Review-only is true. Identity acceptance, automatic reference admission,
activation, automatic hold clearance, XML, training, production, JBOD,
portal, queue, task/process, source-image, and wafer authority remain false.
