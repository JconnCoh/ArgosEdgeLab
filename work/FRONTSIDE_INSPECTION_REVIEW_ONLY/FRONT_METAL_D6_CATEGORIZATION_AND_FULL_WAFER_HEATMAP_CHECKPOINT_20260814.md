# Front-metal D6 categorization and full-wafer heatmap checkpoint — 2026-08-14

## Superseding withdrawal notice

This checkpoint is historical and `WITHDRAWN`. The final V4 target preflight
found that its asynchronous port probe could misclassify connection refusal as
an occupied port because it did not call `EndConnect`. `FM6_V4_20260814T1430Z`
was never presented to the operator and must not be launched or reused. A fresh
V5 build from the corrected source supersedes everything below.

## Disposition

Current phase: `FRONT_METAL_D6_CATEGORIZED_HEATMAP_REVIEW_RELEASED`.

Reviewer `FM6_V4_20260814T1430Z` is `RELEASED_REVIEW_ONLY`. It is a
canonical BowComp-derived reviewer presentation revision. It does not change
detector masks, thresholds, native component geometry, frontside chipout,
training eligibility, XML authority, production authority, or packaging.

## Released reviewer

Root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM6_V4_20260814T1430Z`

Verified artifacts:

- build result SHA-256:
  `961D4164F6418CD7A1E734690959BD6AE62FD6427EA427546EFB7411622E77FE`;
- review manifest SHA-256:
  `899C3E0CBDADD11DDE35E56C8BF28F91C4D45BED3B79BE3991AC02CA9FE59E1B`;
- staged categorization guidance SHA-256:
  `1C48168E13DA491EF8624D88214CBF190BC887B57EEC2C038412C434268BE817`;
- presentation audit SHA-256:
  `275DCD1B21064F68210695A24D624857CE9FA019F634BD8E7B82E81A3EE60C20`;
- launcher CMD SHA-256:
  `EA0D51BE60F6DD3FC70356CE15001C7D8EE66ED56619BEC3B12F3A5124CDA802`;
- launcher script SHA-256:
  `4B42D22CC28D3B02CD68B4B7820F235043438B90F64A1F9B10FA48B973E58F8E`;
- launcher invocation SHA-256:
  `67E47B0888F4E391ABE7A9A4E7C3D99E2BC307CE7B044A8E5A1487E0D90C62D6`.

The output has 57 files and 13,789,909 bytes. The complete post-build scan
checked 71 paths and passed with a maximum effective length of 197 characters.

## D5 categorization guidance

The only current operator input is the completed D5 response:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T002521Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

Its SHA-256 remains
`7E3E586F2CA7611935434932A93F74E5393C35ADD66553FE581A1F64A756D967`.
D6 represents all 43 explicitly reviewed fields: 28 contain marks and 15 are
reviewed zero-stroke fields. The exact source contains 88 native-coordinate
strokes: 74 reclassifications, 14 missed-defect additions, 62 Scratch, and 26
Particle.

The D6 guidance file is a deterministic index into that locked response. The
exact stroke corridors remain only in the source feedback. No stroke is
converted automatically into detector pixels, component geometry, training
truth, XML geometry, or a rule for unreviewed components.

D4 remains strictly separate at
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T222605Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
SHA-256
`FD714DA87C377AD0AEFA5A646174BA54EF57B15B87205CF224F084B8A79D4476`.

## Full-wafer heatmap views

All views use the unchanged 1800 by 1373 BF overview as their display base.
They project only the 11 evaluated native 2400 by 2000 fields:

- `FM6_ACCEPTED.png`: magenta accepted review-only physical-damage support,
  69,623 native source pixels; SHA-256
  `23E9803978025F825749734891C54A797E40E1C4B97640F1A1458AD148D16E79`;
- `FM6_HELD.png`: cyan class-specific holds plus amber technical/common-
  condition holds; SHA-256
  `F5ED2DEF0B5B4E0D769B402ADF839BBBFB10578164118174BA64115B8D0AD025`;
- `FM6_CLASS_HOLDS.png`: cyan-only class-specific hold view, 2,876 native
  pixels; SHA-256
  `3F379F16926626CDBECCC63AF4EA3E40386980CE8A7E6B4B3FD9C2AA8F5E0798`;
- `FM6_COVERAGE.png`: the exact 11 evaluated tile rectangles; SHA-256
  `60224A1AA8FA3B2B0C253FC40EEC9C1ECCD2C398FB349BD1E6765C49594B1ACE`.

The 145,047 technical/common-condition pixels remain holds, never Normal.
Overview color reduction and visibility passes are display-only. All native
masks remain unchanged at scale X=1 and scale Y=1. Uncovered or uncolored
wafer space is not full-wafer negative truth.

## Validation

- canonical controls, tabs, actions, and byte-identical `styles.css` passed;
- `app.js` remained byte-identical to the approved D5 derivation;
- 112 referenced manifest assets passed; embedded image/Base64 payloads: zero;
- all 11 required combined component tables and all 20 optional auxiliary
  tables retained their hashes while receiving short filenames;
- build and reviewer wrapper static gates passed;
- exact Windows PowerShell 5.1 build and reviewer preflight paths passed after
  continuity reconciliation;
- bounded server runtime returned HTTP 200 for health, page, manifest, and the
  exact D5 feedback, then stopped;
- frontside chipout tool SHA-256 remains
  `900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`;
- frontside chipout anchor SHA-256 remains
  `1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.

## Preserved diagnostics

These incomplete or path-ineligible roots are `DIAGNOSTIC_ONLY` and must never
be presented or reused:

- `FM_D6_V1_20260814T134500Z`: stopped before heatmaps because zero-stroke
  reviewed fields were omitted from the first grouping;
- `FM_D6_V2_20260814T140000Z`: complete content but failed the post-build path
  gate at 220 effective characters;
- `FM6_V3_20260814T1415Z`: stopped because optional legacy CSVs were assumed to
  exist for every tile.

## Next gate

The operator may review D6 through `START_FM6.cmd`. Confirm that the accepted,
all-held, class-specific-held, and evaluated-field coverage views express the
intended full-wafer presentation and that the imported D5 Scratch/Particle
guidance remains staged. Additional saved feedback is a new locked input; it
must not automatically retune or promote the detector. Training, XML,
production, packaging, full-lot execution, and frontside chipout changes remain
unauthorized.
