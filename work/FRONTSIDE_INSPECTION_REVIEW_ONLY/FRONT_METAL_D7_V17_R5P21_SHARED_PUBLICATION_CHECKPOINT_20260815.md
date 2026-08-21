# Front-metal D7 V17 R5P21 shared publication checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P21_PUBLISH`  
Parent: `FM7V17R5P21`  
Disposition: `DIAGNOSTIC_ONLY`

The frozen expanded-fiducial alignment package was copied without overwrite
to the operator-provided share:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P21.zip`

- shared bytes: 445669;
- shared SHA-256:
  `C133E4BD9556F5BC55B0F92A233D6E0759AD951A0EE32052E044AD2F2435D5AB`;
- local ZIP SHA-256:
  `C133E4BD9556F5BC55B0F92A233D6E0759AD951A0EE32052E044AD2F2435D5AB`;
- local and shared byte lengths and hashes match exactly;
- the shared path passed the mandatory path budget at 170 effective
  characters with suffix reserve;
- no existing shared file was overwritten.

This publication does not prove all-wafer alignment and does not bypass the
pending exact 24-source JBOD preflight. On the JBOD workstation, extract the
ZIP and run only `FM7P21\RUN.cmd`. Return the complete
`D:\A\FM7P21O\FM7P21_<timestamp>` directory containing
`EXPANDED_ALIGNMENT.json`, `TARGET_FIDUCIAL_GRID.png`, and
`EXPANDED_ALIGNMENT_SUMMARY.png`.

No wafer may be silently skipped. No defect inspection, mask, detector
threshold, M3, V16, reviewer authority, XML, or production state changed.
