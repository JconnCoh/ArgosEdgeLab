# Front-metal D6 V5 release checkpoint — 2026-08-14

## Disposition

Current phase: `FRONT_METAL_D6_CATEGORIZED_HEATMAP_REVIEW_RELEASED`.

Reviewer `FM6_V5_20260814T1500Z` is `RELEASED_REVIEW_ONLY`. It supersedes
withdrawn V4 and is the only D6 reviewer eligible for operator presentation.
It is a canonical BowComp-derived presentation revision. It does not change
detector masks, thresholds, native component geometry, frontside chipout,
training eligibility, XML authority, production authority, or packaging.

## Released reviewer

Root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM6_V5_20260814T1500Z`

Verified artifacts:

- build result SHA-256:
  `A0C1A3CE7E34137CBE9F36B73A6BBA334AA2DC642F6BAFD210F843EA22C8CF00`;
- review manifest SHA-256:
  `3C9926BC7C3CA010E4B79C30BF0E82D8C48AB56079C4FD4B9640C30C2298B516`;
- staged categorization guidance SHA-256:
  `ED3A799C0A34EF91F688946403596344DE0BE16D21C63EE063FB5FACE28B5CF0`;
- presentation audit SHA-256:
  `EAED8BC743A782B35716CFBE1BA4AE3D4F46C8905294F0F575F71C7F1411B804`;
- launcher CMD SHA-256:
  `EA0D51BE60F6DD3FC70356CE15001C7D8EE66ED56619BEC3B12F3A5124CDA802`;
- launcher script SHA-256:
  `EA507F87EB413C9C37C1B82D69430535193E05E100610E581346F062C18850D5`;
- launcher invocation SHA-256:
  `93BCB88FE4A59D579ECDE1DA0B09ABDFA7F7476C267D37A59AA41218DA70E30A`.

The output has 57 files and 13,790,165 bytes. Its complete post-build path
scan checked 71 paths and passed with a maximum effective length of 197
characters.

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

All four file-backed views use the unchanged 1800 by 1373 BF overview as
their display base and project only the 11 evaluated native 2400 by 2000
fields:

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
- the corrected launcher port probe calls `EndConnect`; refused connections
  are not misclassified as occupied ports;
- bounded server runtime returned HTTP 200 for health, page, manifest, and the
  exact D5 feedback, then stopped;
- frontside chipout tool SHA-256 remains
  `900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`;
- frontside chipout anchor SHA-256 remains
  `1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.

After this checkpoint was installed in the authoritative continuity record:

- project continuity passed with 13/13 V5 artifacts verified;
- the bounded runtime listener was found still serving this exact V5 review,
  was stopped by its verified PID, and port 8877 was confirmed free;
- the exact Windows PowerShell 5.1 target preflight then passed with
  `MutationPerformed=False`;
- the metadata-only session guard passed at 3.443 MiB, below the 128 MiB
  checkpoint threshold, without reading session content.

## Superseded revisions

- `FM_D6_V1_20260814T134500Z`, `FM_D6_V2_20260814T140000Z`, and
  `FM6_V3_20260814T1415Z` remain `DIAGNOSTIC_ONLY` and must never be
  presented or reused.
- `FM6_V4_20260814T1430Z` is `WITHDRAWN`. Its content checks passed, but its
  launcher contained the false-positive asynchronous port probe. It was not
  presented and must never be launched or reused.

## Next gate

The operator may review D6 V5 through `START_FM6.cmd`. Confirm that the
accepted, all-held, class-specific-held, and evaluated-field coverage views
express the intended full-wafer presentation and that imported D5
Scratch/Particle guidance remains staged. Additional saved feedback is a new
locked input; it must not automatically retune or promote the detector.
Training, XML, production, packaging, full-lot execution, and frontside
chipout changes remain unauthorized.
