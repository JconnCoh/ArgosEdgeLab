# Remaining Frontside Appearance Review V3.3 Checkpoint — 2026-08-07

Status: `HOLD_OPERATOR_APPEARANCE_REVIEW_OF_13_EXACT_CONTEXTS`

V3.3 is a display-only continuation for the other frontside contexts. It does
not inspect or classify defects and does not modify the JBOD processor.

## Frozen selection

- Source inventory: 215 metadata-ready exact frontside BF/DF physical wafers
  across 18 exact product/process/step contexts.
- Five contexts with an already recorded provisional appearance are excluded.
- Thirteen unresolved exact contexts remain.
- The bounded gallery selects 150 eligible physical wafers and 25 distinct
  representative physical wafers, at most two per context.
- BF and DF remain paired by exact lot, scan timestamp, and slot.
- Recipe-folder names are not identity or appearance authority.

## Review presentation

- Raw display-only BF/DF pairs; no accepted-defect overlay.
- No bounding boxes, heatmaps, defect masks, or inferred geometry.
- The user decides appearance from the images rather than process/step names.
- A mixed appearance within one exact context must be held.
- Saved response filenames include a UTC timestamp to prevent the older
  `(1)`, `(2)` response-file ambiguity.

## Package

`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_3_REMAINING_FRONTSIDE_APPEARANCE_REVIEW_20260807T014500Z.zip`

SHA-256:
`A5C53932EAFEBC5277E0BF2E50DB2007EDE0DC2B15B493FE22BA19E02330D5B7`

The package was copied without overwrite to the approved `InspectionRevs`
share. The superseded V3.0.1 share package was removed; its local audit copy
remains available.

Validation:

- package file hash failures: 0;
- PowerShell parse errors: 0;
- packaged manifest-only selection: 13/13 contexts;
- representatives: 25/25 distinct physical wafers;
- overlays, boxes, heatmaps, and defect masks: false;
- training, XML, and production eligibility: false.

## Next use

Run V3.3 independently of V3.2.2. Return the small, timestamped appearance
response JSON. Each context then routes separately to unpatterned transfer,
patterned registration, or an explicit mixed/unresolved hold. No response may
promote a detector, composite, or golden by itself.
