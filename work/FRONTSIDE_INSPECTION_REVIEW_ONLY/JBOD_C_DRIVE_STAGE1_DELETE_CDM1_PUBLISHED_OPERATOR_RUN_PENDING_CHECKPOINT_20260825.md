# Argos checkpoint — CDM1 exact retired-stage duplicate deletion published; operator run pending

Date: 2026-08-25

Revision: `JBOD_C_DRIVE_STAGE1_DELETE_CDM1_20260825`

Disposition: `PENDING_GATE`

## Outcome

The operator-authorized C-drive recovery has been narrowed to one exact
manifest-bound deletion. `ARGOS_CDM1.zip` is frozen, fully rehearsed, and
published create-new to the engineering share. It has not run on JBOD and no
retired source file has yet been deleted.

Published package:

- path: `\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_CDM1.zip`
- bytes: `12502`
- SHA-256: `E5ACE0AD4BAECA282C42B53AFC9F4EA3D017A3F1DB863EAF4C1FA429F9533CB3`
- publication gate:
  `work/JBOD_C_DRIVE_STAGE1_DELETE_CDM1/CDM1_PUBLICATION_GATE.json`
- publication-gate SHA-256:
  `A5BD731D5669571A8E982D0D656A4262398A0288F69AC4889F04CB39FC521749`

The adjacent machine path gate is
`ARGOS_CDM1_PATH_GATE.json`, SHA-256
`661D891C998360B2CA73B91B0E7BE95F2D5576FCA65C1CEB3CEA6880A366E9BA`.

## Exact deletion boundary

CDM1 may delete only the 93,709 files and 232,912,232,897 logical bytes bound
by locked manifest
`D:\A2\x\manifests\M1_20260819T172439962Z.jsonl`, SHA-256
`5C42EFF1431867076DC3F3DEE15FA0FB20A0B0C204C2AA38B5E5BDBCD0806DEB`.
The three exact source-to-mirror roots are:

1. `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\cache` to `D:\A2\c`
   — 1,444 files / 83,174,610,824 bytes.
2. `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\metadata` to `D:\A2\m`
   — 92,021 files / 149,443,376,410 bytes.
3. `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\dashboard_outputs` to
   `D:\A2\d` — 244 files / 294,245,663 bytes.

`C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\outputs` is explicitly
excluded. Its 431,960 files / 260,566,845,066 logical bytes were not mirrored
by stage 1 and remain a hold. No broad C-drive cleanup is authorized.

## Required verification before deletion

The exact D mirror of every locked row is SHA-256 verified during the live run.
The current C exact relative-file set, length, and locked last-write metadata
must match before and again after D verification. The installed processor
configuration must still hash to
`CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8`
and still select `D:\A2\o`, `D:\A2\d`, `D:\A2\c`, and
`D:\A2\m\verified`. Exactly one healthy processor process is required, and
its PID, creation time, and command-line hash must remain unchanged.

Only after every one of those gates passes does CDM1 delete the exact
manifest-bound C files, then only empty directories under the three retired
roots. It never starts, stops, or restarts a task or process and makes no
installed-file, queue, ledger, image, XML, training, production-routing, or
wafer change.

## Test and safety evidence

- frozen target SHA-256:
  `F903EDB6104BD1526461ED0285A8E0FC02E174381CA9328B28B2DBD96FDF2F76`
- frozen package-manifest SHA-256:
  `0756F8CC871C4626BFED989E6D82D38794BED8F1FE78C9D8F947774795490D5E`
- build-gate SHA-256:
  `5BB141C3F21BE32449A782937ADF8D7EE2445569F9C3F9CFD48858EFF59C0188`
- final extracted-package test-gate SHA-256:
  `E45D8F88A39E5ACECFEA02A4885357622ABB43441816956C9B0085D9B4206BBF`
- laptop-refusal gate SHA-256:
  `D642D66068C8819CB090A1BD252F68C55B5EE6BD08B2FA5BAB36049B1AB42B40`

Windows PowerShell 5.1 proved that a D-mirror hash mismatch and an unsafe
`..` relative path both fail before source deletion. The positive case deleted
only the complete six-file fixture set, left every D mirror unchanged, left
the excluded historical-output control unchanged, and preserved the processor
snapshot. The exact production preflight refused the engineering laptop by
computer name before mutation. Path budget maximum effective length is 185,
including a 32-character reserve.

The first unpublished DRAFT rehearsal exposed a malformed runtime regex before
any intended deletion. The new failure signature and prevention were added to
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`; the corrected frozen bytes passed
fresh development, frozen, and final-ZIP rehearsals. No JBOD contact or live
target mutation occurred from that draft failure.

## Preserved authority and holds

- Review-only authority remains unchanged.
- The live OpenCV provider remains disabled.
- Slot16 remains unfrozen; Slot17 remains blocked; Slots22-25 remain unseen.
- `SCRIBE_REFERENCE_COVERAGE_HOLD` and every other existing hold remain.
- The healthy processor must not be restarted or replaced.
- `REQ_O2D4` is non-reusable and must not be retried.
- `ARGOS_O2A2.zip` must not be run; its observation was superseded by the
  operator's explicit exact-deletion direction.
- `ARGOS_CDO1.zip` must not be run.
- No successor portal request is authorized by this checkpoint.

## Exact next action

On the JBOD computer only, create fresh `D:\CDM1`, extract the published
`ARGOS_CDM1.zip` into it, then right-click `D:\CDM1\RUN_CDM1.cmd` and choose
**Run as administrator**. Leave the window open until terminal completion.
Run it once only.

The launcher runs the exact non-mutating preflight first and continues into
the frozen deletion only after PASS. Verification hashes 232,912,232,897 bytes
on D and may take several hours. The persistent log and all evidence stay on
D. Terminal evidence is returned as `CDM1R.zip` in `InspectionRevs`.

After the run, collect and verify only that exact `CDM1R.zip`. If it is absent,
diagnose the already-authorized run/return path without rerunning CDM1. If it
reports failure or partial deletion, preserve the exact signed/file-backed
evidence and apply direct observation and stop-loss before any successor.
