# Patterned fiducial designation fresh-chat checkpoint — 2026-08-18

Revision: `PATTERNED_FIDUCIAL_DESIGNATION_SOURCE_REVIEW_V1`

Disposition: `PENDING_GATE`

## Current authority

The immediate phase is patterned-wafer fiducial source review, operator designation, and alignment transfer. Production-wafer defect scoring has not begun and is blocked until this gate passes.

`FM7P30_20260818T1515Z` remains the immutable operator-approved review-only defect-response baseline. It grants no automatic Reject, Normal, training, XML, or production authority.

## Existing crop gallery

The exact previously delivered native BF/DF gallery is:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\PatternedFiducials_V1E_20260816\index.html`

- Index SHA-256: `14DC86EF40137ED7618122E821F6C500090DC0EFAC1CF82B9BD43FCC2C682364`
- Combinations SHA-256: `AB5078E4C756DCD2A6982B40BC28A6877DEE7B24B93DA8C5B46FDAD6397ECB8E`
- Audit SHA-256: `51D42C63627DEAED80FFF5D5692E48D259CE603BE6D6E7DBA558F5D314222201`
- 31 exact product/process combinations across eight products
- 21 paired native BF/DF crops awaiting designation
- nine explicit macro-pose holds and one exact-map hold
- candidate model structures 1/2; line-array structures 3/4 remain non-model controls

## Categorized source index

The provisional metadata grouping and exact raw-source lookup are:

- Human-readable index: `work/PATTERNED_FIDUCIAL_INVENTORY/review/PATTERNED_FIDUCIAL_CLASSIFIED_SOURCE_INDEX_20260818.md`
- Human-readable SHA-256: `45FAAB99A9148BBFC941306DC7A348552FA110E6C8972A8EB9E41D04D927E9EA`
- Exact CSV: `work/PATTERNED_FIDUCIAL_INVENTORY/review/PATTERNED_FIDUCIAL_CLASSIFIED_SOURCE_INDEX_20260818.csv`
- CSV SHA-256: `CC7AAB6FF7D85F15027772E1E780DAC48E251F14DED03E4CF37587F43DD6CA7D`
- Audit: `work/PATTERNED_FIDUCIAL_INVENTORY/review/CLASSIFICATION_AUDIT.json`
- Audit SHA-256: `6D476FD16818884A0853353A42ED9E68CC9CF4D7E659DD22E3C56204C449BF5E`

The provisional split is 16 `Patterned Dielectric`, 10 `Patterned Frontmetal`, and 5 `Unsure`. All 31 IDs, product/recipe identities, exact lot/acquisition folders, crop states, and crop references match the frozen catalog and delivered gallery. Classification remains operator-correctable metadata, not truth.

## Governance additions made before rotation

`AGENTS.md` now requires:

- exact reviewer URLs with `?manifest=` and browser verification of the loaded revision;
- exact full native-field membership in both reviewer queues;
- separate coverage, outside-domain, fallback, removed-response, and retained-candidate semantics;
- unresolved fiducial/map/pose/alignment prerequisites to block production-source scoring;
- direct use of existing constrained Argos maintenance access instead of repeated operator launchers;
- one persistent-log preflight-plus-apply launcher when operator-local execution is unavoidable;
- file-backed or single-scalar handling for array-valued PowerShell arguments, never comma-joined text.

`AGENTS.md` SHA-256: `E07DA055C7DCA7B708479B05E10B5646B6C464EA58C82F46BD0CC6DC036F2464`.

The newly observed comma-joined `powershell.exe -File` array failure is recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`, SHA-256 `E7A122DA9035384EFE7FCFEF9E444F82DD27AFA304A38040ED995198AE9B7D4E`.

## Exact next action

1. The operator reviews the categorized list and uses each exact raw acquisition folder to check any suspicious crop against its native BF/DF source.
2. Record operator corrections to `Patterned Dielectric`, `Patterned Frontmetal`, or `Unsure` without rewriting this source index.
3. For each crop-ready row, record structure 1, structure 2, both, neither, or explicit hold.
4. Build a new file-backed designation matrix with exact combination, product/recipe, physical identity, crop coordinates, BF/DF hashes, and operator disposition.
5. Run a fresh alignment-transfer diagnostic for every designated combination. Preserve all unresolved map, pose, and model holds.
6. Only after the alignment gate passes may representative production-wafer defect scoring begin under a fresh output root with R5P30 unchanged.

## Fresh-chat instruction

Start a fresh Codex task and say: `Continue from the current Argos continuity checkpoint.` Read the governing files in their mandatory order. Do not read or fork this task's JSONL; all required authority and next actions are file-backed here.
