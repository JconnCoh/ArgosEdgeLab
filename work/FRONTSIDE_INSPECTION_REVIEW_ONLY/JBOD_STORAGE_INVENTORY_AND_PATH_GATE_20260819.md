# JBOD storage inventory and path gate — 2026-08-19

Classification: `PENDING_GATE`

## Outcome

The bounded JBOD inventory and exact per-file D: projection completed through signed terminal response `R_335F1D1130A4_20260819150513542_6e7312c4` for request `REQ_20260819T145114120Z_9373F13C2510`.

The JBOD has about 9.85 GiB free on C: and about 434 TiB free on D:. Raw acquisitions already use `D:\KLARFExport`. Portal queue/ledger state, relay state, and `C:\P21E` are not migration targets.

The current high-volume state is:

| Tree | Files | Bytes | Projected maximum effective path at `D:\A2` | Hard-stop files | Component-over-80 files | Disposition |
|---|---:|---:|---:|---:|---:|---|
| `cache` | 1,444 | 83,174,610,824 | 176 | 0 | 0 | eligible for copy-first migration |
| `metadata` | 92,021 | 149,443,376,410 | 110 | 0 | 0 | eligible for copy-first migration |
| `dashboard_outputs` | 244 | 294,245,663 | 138 | 0 | 0 | eligible for copy-first migration |
| `identity` | 32,937 | 103,448,386,829 | 215 | 0 | 0 | hold six warning-depth files for a separately shortened layout |
| `outputs` | 431,960 | 260,566,845,066 | 240 | 20 | 804 | whole-tree junction/copy is refused until deterministic shortening and reference mapping are proven |
| `hotfixes` | 8,686 | 6,330,445,536 | 265 | 1,363 | 0 | leave on C: pending separate archive/short-name handling |

The immediately eligible copy-first scope is 232,912,232,897 bytes across 93,709 files. It can run in the background without stopping the processor. Source deletion and junction cutover remain prohibited until a safe processor loop boundary, final delta, per-file hash identity, consumer validation, and exact rollback evidence pass.

Historical `outputs` are mostly path-safe by byte volume, but a whole-tree junction would recreate known unsafe leaves. Twenty projected files are at an effective length of 230 or more and 804 file components exceed 80 characters. The deepest 20 are legacy Bare geometry artifacts; they require deterministic short names plus signed source-to-destination mapping and reference rewriting. This does not authorize omission or flattening without provenance.

## Completed-lot launch diagnosis

The installed viewer SHA-256 `39AEA256E4C08043A6F9AEFEADB32F4297217E878C8B71A4603D64FA570677A6` passed catalog validation against 44 sessions and 1,330 required artifact paths with zero missing files. `--catalog-check`, `--ui-smoke`, and `--side-selector-smoke` all exited zero in signed response `R_C7869E11EE0C_20260819144405493_56e28b26`.

The remaining silent-click defect is therefore in the tray launch/observability path, not the viewer catalog or completed-lot data. Patch the tray to perform the exact smoke preflight, create a durable launch log, retain the spawned process, and show an operator-visible error if launch exits. Do not change detector evidence or inspection tasks while repairing it.

## Exact evidence

- Storage inventory request `REQ_20260819T141937060Z_B1B4E5F25980`, signed response `R_8EAEBD611DEF_20260819142521386_d155145d`.
- Exact installed/configuration pull request `REQ_20260819T143107245Z_7BDB18C08DF1`, signed response `R_E1168A80C815_20260819143253478_713d7ee0`.
- Viewer catalog request `REQ_20260819T143934365Z_F5A6124E0471`, signed response `R_9885E0935E3C_20260819144033928_eaf11912`.
- Viewer UI-smoke request `REQ_20260819T144332229Z_95001BF7C65F`, response ZIP SHA-256 `2FF7E4F5B316EED30EBCF142D4BDADC23031992650491AA730A037333C923D09`.
- Path-depth request ZIP SHA-256 `7F876581CFAE3A5A0BBAF9FD01BB473A1D32F1A6ED150E3BAF602E316F3AD1B7`; prepublication gate SHA-256 `3F42578DA347B2D047A0E4726FC05540C85471EB5D681EB3E494B413544D27CD`.
- Path-depth signed response ZIP SHA-256 `60E75833BCC1B1AFFE2AC4911B8A190DC4BC096729CDEAE950D22A18CAA14BF6`; response manifest SHA-256 `FEC643558CED90C169D3C2EA11CE36801E4EFF9E95770907AA38882AD346A98B`.
- Exact path-depth stdout: `work/JBOD_STORAGE4/response/R_335F1D1130A4_20260819150513542_6e7312c4.ready/MAINTENANCE.stdout.txt`, SHA-256 `1F0A226683504AE1EF93F75843527A60CEAE65D72167F265A786B99A33A13E93`.

## Prerequisite order

1. Start background copy-and-hash snapshot for only `cache`, `metadata`, and `dashboard_outputs`; delete nothing.
2. Patch and rehearse future output/export short-name rules and the tray launch path.
3. Reach a cooperative processor loop boundary without aborting a wafer; run the final delta/hash gate.
4. Cut over exact approved configs/consumers, validate new D: output plus completed-lot launch, then recover only exact verified C: sources.
5. Resolve the historical-output short-name/reference map, then the six identity warning paths and hotfix archive separately.
6. Return to PFC004 alignment work: preserve six fiducial passes and keep Slot07 as an operator-visible notch hold.

No judgment raster, detector tuning, alignment-transfer, training, XML, production eligibility, or production routing is granted.
