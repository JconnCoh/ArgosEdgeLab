# OpenCV OCV-02 O2A2 published / operator run pending — 2026-08-25

Disposition: `PENDING_GATE`

## Published exact artifact

The one authorized bounded `DIRECT_ADMIN_READ_ONLY` observation package is
published at:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_O2A2.zip`

The share readback is 8,816 bytes with SHA-256
`A60926D0EC26BB44B11B47AB70023EC72C08E4F19CE5DA97431CA5212C535C47`.
The publication gate is
`work/OPENCV_SCRIBE_O2A2/O2A2_PUBLISH_GATE.json`, SHA-256
`E02755F75D22D9064D7E02B845363C1CD3268C6014BCBC63620D32AD95B90380`.
It records matching clean local/origin tip
`7899c1ead979ead1233001ef64aa90d73c09c3b4` before publication. The return
leaf `O2A2R.zip` was absent after publication, so the package has not executed.

## Exact operator action now required

On the JBOD computer only:

1. Extract `ARGOS_O2A2.zip` to the fresh short folder `C:\O2A2P`.
2. Right-click `C:\O2A2P\RUN_O2A2.cmd` and choose **Run as administrator**.
3. Leave the window open until it reports completion or a failed-closed error.

The launcher performs its exact non-mutating preflight before creating the
fresh evidence-only `C:\O2A2` output. It installs nothing; starts, stops, or
restarts no task or process; changes no queue or ledger; reads no image bytes;
and performs no source, wafer, XML, training, or production action. It returns
`O2A2R.zip` to the same `InspectionRevs` share automatically. Do not run it a
second time and do not retry `REQ_O2D4`.

## Preserved authority and prerequisite order

After the one return arrives, collect and verify it before any successor. Use
its exact endpoint/ledger/outbox/D-work/task/process/alias evidence to resolve
O2D4. Only then may a fresh high-entropy corrected Slot16 successor be designed
and published. Slot16 remains unfrozen; Slot17 has not started; Slots22-25
remain unseen. The healthy processor, disabled live provider,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, all prior `PENDING_GATE` records, and every
existing hold remain unchanged. Production routing remains disabled.
