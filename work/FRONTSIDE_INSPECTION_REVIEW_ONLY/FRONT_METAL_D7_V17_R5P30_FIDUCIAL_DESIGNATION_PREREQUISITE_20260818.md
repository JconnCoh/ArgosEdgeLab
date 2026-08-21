# Front-metal D7 V17 R5P30 fiducial-designation prerequisite — 2026-08-18

Revision: `FM7P30_FIDUCIAL_DESIGNATION_PREREQUISITE`

Disposition: `LOCKED_INPUT`

## Operator correction

At 2026-08-18T15:34:44Z the operator corrected the production-transfer sequence: before production-wafer inspection, the applicable patterned-wafer fiducial must be designated from the previously delivered paired BF/DF crop sheet and the alignment method must be tested. Production-wafer scoring is therefore not the immediate next action.

R5P30 remains the operator-approved review-only defect-response baseline. This correction changes only the prerequisite and sequence; it does not mutate R5P30 or grant inspection authority.

## Recovered designation sheet

The exact previously delivered gallery is intact at:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\PatternedFiducials_V1E_20260816\index.html`

- Index SHA-256: `14DC86EF40137ED7618122E821F6C500090DC0EFAC1CF82B9BD43FCC2C682364`
- Combinations CSV SHA-256: `AB5078E4C756DCD2A6982B40BC28A6877DEE7B24B93DA8C5B46FDAD6397ECB8E`
- Audit SHA-256: `51D42C63627DEAED80FFF5D5692E48D259CE603BE6D6E7DBA558F5D314222201`

The gallery contains 31 exact product/process-image combinations across eight products. Twenty-one rows have paired native 1:1 BF/DF crops pending operator model confirmation. Nine rows remain `HOLD_MACRO_POSE_NOT_QUALIFIED`, and one remains `HOLD_MAP_TEMPLATE_NOT_FOUND`. Holds are visible and are not skipped, Normal, or Reject truth.

Candidate model structures 1 and 2 are the eligible feature family shown in the original annotated example. Line-array structures 3 and 4 are non-model controls and must not be selected because they merely have strong straight lines.

## Required gate before production-wafer inspection

1. The operator designates the eligible fiducial structure in each applicable paired BF/DF crop.
2. Save the designation matrix with exact combination, product/process identity, chosen structure, native coordinates, BF/DF source hashes, and any explicit ambiguity hold.
3. Build a fresh alignment-test revision without changing R5P30.
4. Test the designated model against the representative source wafer for every designated combination, requiring independent BF and DF alignment evidence and target-excluded registration checks.
5. Resolve or preserve all map/pose/model holds explicitly.
6. Only after the alignment transfer gate passes may representative production-wafer defect scoring begin under a fresh diagnostic root.

No automatic Reject, Normal, training, XML, or production-routing authority is granted.
