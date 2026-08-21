# JBOD storage migration path support C1A — 2026-08-19

Classification: `PENDING_GATE`

## Outcome

The delete-nothing Stage 1 copy/hash snapshot is running under SYSTEM as
`ArgosEdgeLab.StorageMigration.Stage1.ReviewOnly.V1`.  Its exact scope is the
path-safe C: `cache`, `metadata`, and `dashboard_outputs` trees, copied to the
short physical roots `D:\A2\c`, `D:\A2\m`, and `D:\A2\d`; worker state is
written under `D:\A2\x`.  No source was deleted, no consumer was cut over, and
no inspection task was stopped or restarted.

The latest signed progress observed at `2026-08-19T15:45:41Z` was
`COPY_HASH_IN_PROGRESS` on `metadata`: 30,700 files and 154,193,410,337 bytes
had been processed.  The original exact scope remains 93,709 files and
232,912,232,897 bytes.  This is progress evidence, not snapshot-complete or
cutover authority.

## Future output/export path diagnosis and correction

Signed diagnostic response `R_B413B0A748B5_20260819154729653_0cc39d7f`
enumerated the current historical output tree exactly: 431,960 files,
260,566,845,066 bytes, zero enumeration errors, 2,506 warning paths, 20 hard
stops, maximum projected effective length 240, and 804 over-80 filename
components.  All 804 long components are composite accepted-heatmap overview
filenames.  The 20 hard stops are five legacy Bare jobs whose full physical
identity is duplicated in the outer job directory and nested geometry path.
Historical outputs therefore remain on C: and require a separately signed
short-name/reference mapping; they are not part of Stage 1 and may not be
flattened, omitted, or deleted.

Compatibility release C1 installed deterministic short future output names
without changing the active config or output root.  Its stress-tested job
directory is 61 characters and its composite overview filename is 69
characters.  Full physical identity, image identity, and fingerprint remain
in `outputPathContract` metadata.  Planned paths at effective length 200 or
more and components over 80 are rejected before write.  Config schema v2 keeps
the existing C: behavior; schema v3 adds explicit `outputRoot`,
`dashboardOutputRoot`, `cacheRoot`, and cooperative-hold fields.

C1 production request `REQ_20260819T160343316Z_63CC7C2C54B3` returned signed
terminal response `R_029F5EF8FC3E_20260819160542680_15ab6040`.  The request ZIP
SHA-256 is
`27DA104AC4A6C134BD68E2271BADDE0E88416980A6FC8FCE33FB6B9EC267BC86`;
its prepublication gate SHA-256 is
`4AE6C7AFCA7E0F2AFBF0EFE134CF02688FAD56E3805BC13C5CFE7A1622340844`.
The signed response proves four installed files and no config cutover,
deletion, or scheduled-task change.

C1A then narrowed the safe boundary from only a processing-pass boundary to
both a pass boundary and the interval between completed wafers.  Installed
processor SHA-256 is
`C6A04EB8BC4057209A3EAB7E24627D1AE5A387E4EAACACC4A77228AB8040A459`.
The hold is cooperative: it never stops or aborts the wafer currently being
processed.  Its terminal states are `HELD_AT_PROCESSING_PASS_BOUNDARY` and
`HELD_BETWEEN_COMPLETED_WAFERS`.

C1A production request `REQ_20260819T160853453Z_C7E4F9CF358F` returned signed
terminal response `R_60D7E7CC5626_20260819161036408_17cd19b4`.  Request ZIP
SHA-256 is
`8F9D6EC8543F4CC40A579482481A28E00EFBAD9A36173866C95C8CEF350E1D85`;
prepublication gate SHA-256 is
`B1D65A93228D9FE4EC1B3C704DB59DCC47D7F7D050CC95D691A6E408B27904FE`.
Exact predecessor, idempotent target, and unapproved-predecessor cases passed;
the unapproved case refused before mutation.  No hold was activated, no
inspection task changed, and no wafer was interrupted.

The completed-lot viewer launch/observability defect was separately repaired
and its tray was restarted.  The viewer catalog and required assets remain
unchanged.  This does not substitute for validating the D: roots after the
actual cutover.

## Required cutover order

1. Wait for a signed Stage 1 `SNAPSHOT_COMPLETE` result.  A progress row is
   not sufficient.
2. Install a config-v3 predecessor-preserving hold config that keeps every
   current C: path and sets only the cooperative hold and its exact hold ID.
3. Wait for a signed matching hold acknowledgement at the next completed-wafer
   or pass boundary.  Do not stop or abort the current wafer.
4. While held, run an exact final delta/hash pass for only `cache`, `metadata`,
   and `dashboard_outputs`; require identical file sets, lengths, and
   per-file hashes.  Delete nothing.
5. Install the exact approved config-v3 cutover: future outputs to `D:\A2\o`,
   dashboard outputs to `D:\A2\d`, reference cache to `D:\A2\c`, and verified
   metadata to `D:\A2\m\verified`; clear the cooperative hold.  Raw
   acquisitions remain `D:\KLARFExport`.  Portal/relay state, processor state,
   and `C:\P21E` remain on C:.  The existing BowComp reference cache may remain
   at its already-D: root.
6. Validate a new D: output, dashboard publication, dynamic tray output-folder
   resolution, and the real Completed Lot launch.  Only after those checks may
   exact hash-verified Stage 1 C: source trees become eligible for bounded
   recovery.
7. Keep historical outputs, identity warning paths, and hotfixes on C: until
   each has its own short-name/provenance mapping and consumer validation.
8. Return to PFC004.  Preserve the six designated-fiducial passes and keep
   Slot07 as an operator-visible notch hold.

No judgment raster, detector tuning, alignment-transfer authority, XML,
training, production eligibility, or production routing is granted.
