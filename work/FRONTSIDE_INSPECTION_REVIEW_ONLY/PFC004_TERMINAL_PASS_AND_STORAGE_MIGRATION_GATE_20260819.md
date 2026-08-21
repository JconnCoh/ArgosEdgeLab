# PFC004 terminal pass and storage-migration gate

Date: 2026-08-19  
Revision: `PFC004_EXACT_RESUME_V2_TERMINAL_AND_STORAGE_MIGRATION_GATE`  
Disposition: `PENDING_GATE`

## Portal and PFC004 terminal state

The operator ran JBQ2B successfully. Its durable JBOD transcript is
`C:\ProgramData\ArgosProjectPortalRO\state\operator_logs\JBQ2B_20260819T134646238Z.log`.
The protected task definitions and inspection tasks remained unchanged.

The original PFC004 request then returned signed terminal `FAILED` response
`R_84F944855C1A_20260819134655003_0ae692cd`: the exact-resume verifier
incorrectly required deterministic extraction root `C:\P21E` to be fresh
before examining the existing successful output. Corrective request
`REQ_20260819T135450748Z_C4AD415BFD64` also returned signed terminal `FAILED`
response `R_7E5EACBB6C9F_20260819135831804_c77ab3d3`; maintenance rollback had
correctly removed the verifier created by the earlier failed request. Neither
failure reran detection or changed an inspection task. Both failure signatures
and their prevention rules are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

Self-contained exact-resume request
`REQ_20260819T140219354Z_FE8197A1D330` returned signed terminal response
`R_C35539E84CC7_20260819140439815_fc435397`, endpoint state
`PASS_MAINTENANCE_PATCH`. The response ZIP SHA-256 is
`57AFE3A49CA3DCCA3A615AA2B8402F3CDC5103863E2D18570F0CAD3A2C03F15F`.
The signed normal stdout proves:

- `PASS_PFC004SB2_TERMINAL_REVIEW_ONLY`;
- exact resume `PASS_PFC004_EXACT_RESUME_V2` against existing audit
  `D:\A21\PFC004SB2_20260818T231500Z\AUDIT.json`, SHA-256
  `2078C1695A13C1D33F7282E4C3711A5197A49515361FD3E907C05D4CD885A50E`;
- all 27 installed package-manifest files hash verified;
- six of six pose-qualified wafers pass the designated fiducial model;
- Slot09 uses the sealed paired-channel recovery;
- Slot07 remains `HOLD_NOTCH_NOT_QUALIFIED` for operator review;
- `DetectionRerun=False`, `InspectionTasksChanged=False`, and
  `productionRoutingEnabled=false`.

The exact response is stored at
`work/PFC004ER2/response/R_C35539E84CC7_20260819140439815_fc435397.ready`.
The request ZIP, exact-package rehearsal, route rows, and prepublication gate
are preserved under `work/PFC004ER2`.

## Immediate storage and viewer gate

The next operation is the separate JBOD C:-to-D: high-volume result migration
and export/catalog repair requested by the operator. Before any data mutation:

1. obtain a bounded signed inventory of C: and D: capacity, exact high-volume
   roots, counts/bytes, live producer/export/catalog configuration references,
   Completed Lot viewer inputs, and relevant task actions;
2. path-gate every source, D: destination, temporary copy leaf, verification
   manifest, rollback leaf, and viewer/export leaf;
3. copy to create-new D: roots and verify exact file identity before changing
   any producer, export, or catalog path;
4. switch only exact approved predecessor configurations, then validate new
   output/export behavior and the real Completed Lot launch;
5. retain the C: source until D: and every consumer pass. Recover C: space only
   after verification, through a recoverable exact-target operation.

Raw acquisitions already belong at `D:\KLARFExport`; they must not be copied
back to C:. Portal queue/ledger state under
`C:\ProgramData\ArgosProjectPortalRO` is not presumed to be high-volume output
and must not be moved without exact evidence. The small pinned PFC004 install
at `C:\P21E` remains exact-resume evidence and is not a storage-migration
target.

Fiducial qualification is terminal for all six pose-qualified wafers. Slot07
remains an operator-visible notch hold. No detector threshold, inspection
class, alignment-transfer, XML, training, or production-routing authority is
changed by this checkpoint.
