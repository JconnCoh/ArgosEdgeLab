# OCV-00 Gateway/JBOD Context — 2026-08-24

Disposition: `PENDING_GATE`

## Authority

- Authoritative repository: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab`
- Required branch: `codex/fiducial-opencv-d-drive`
- Verified matching local/GitHub tip: `ecbda3205852550d7f9fdb4a4daf99b4a001e7da`
- Exact JBOD lot: `D:\KLARFExport\PatternedFront\Lot_62619-433`
- Immediate purpose: complete OCV-00 exact image-processing inventory, source-path authority, and frozen regression baselines for the all-image-processing OpenCV migration.
- Bin/null-die 34/36 remains a neighborhood clue only, never fiducial identity or site authority.

The locked work-package order is `OCV-00` inventory/source authority, `OCV-01`
configuration-selected provider platform, `OCV-02` scribe deciphering and
`OCV-03` perimeter/notch/global pose, then `OCV-04` reusable fiducials.
Fiducials are not the first migration implementation.

## Access route

The Codex shell runs on the engineering laptop. The JBOD `D:` volume shown in
the operator's remote desktop is not a laptop filesystem drive and must not be
tested as one. The established access path is:

`Engineering laptop -> signed Project Portal gateway -> Argos relay -> JBOD endpoint -> signed response -> gateway -> engineering laptop`

Use the existing gateway/relay/JBOD route for JBOD evidence. Do not substitute
laptop `D:` probing, direct SMB guesses, or a stale local catalog.

## Current exact state

1. `REQ_OLS2` reached the JBOD and ran the bounded metadata-only lot inventory.
2. The installed entrypoint rejected the result because at least one frozen
   `COMPLETE` predicate was false. The signed stderr is:
   `OLS2 output bounded subtree inventory did not complete safely.`
3. The exact entrypoint moves a rejected produced inventory from
   `C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV00_OLS2_LOT_INVENTORY.json`
   into its timestamped JBOD maintenance evidence root as `failed_probe.json`
   before restoring the qualified predecessor worker.
4. `REQ_O2OBS1` then requested the former stable output path, not the preserved
   timestamped `failed_probe.json`. Its signed failure is:
   `DATA_PULL source not found: OCV00_OLS2_LOT_INVENTORY.json`.
5. The lot and source images have not been proven missing. No BF/DF path has
   yet been resolved for Lot 62619-433.

## Continue from here

Classify the next action under the two-failure recovery stop-loss before any
new request. Prefer, in order:

1. Recover the already-produced timestamped `failed_probe.json` through the
   established gateway if its exact path can be derived from existing signed
   endpoint evidence.
2. If the exact preserved path cannot be resolved using an installed
   read-only route, review and explicitly clear the stop-loss for one minimal
   generic metadata-only endpoint improvement that returns the partial bounded
   inventory as `HOLD_INCOMPLETE` instead of discarding it.
3. Use that partial inventory to narrow to exact acquisition subtrees, then
   obtain a complete exact BF/DF path inventory for OCV-00 source authority.
4. Complete the remaining OCV-00 installed image-processing operation inventory
   and freeze current family outputs/semantics as regression baselines.
5. Proceed next to OCV-01 provider-platform schemas and configuration. Scribe
   and pose follow as OCV-02/OCV-03; fiducials remain OCV-04.
6. Stop before source hashing or image-byte reads unless the operator has
   explicitly authorized the next provenance/image step.

Do not restart or change the healthy processor. Preserve all PFC003/PFC010,
map, pose, appearance-regime, fiducial-site, registration, scoring, XML,
training, production, deletion, and wafer-action holds.

## 2026-08-24 durable short-path correction after signed OLS3 hold

The signed OLS3 result proved that a process-local alias anchored at the broad
`D:\KLARFExport` root is not sufficient for deep KLARF leaves. Forty children
were rejected by the path budget, and the provider returned only a count.

Future source discovery must:

- anchor its temporary alias at the exact requested subtree (the deepest
  verified common source ancestor), not the broad configured root;
- perform filesystem I/O only through the path-gated alias;
- retain the configured-root-relative canonical spelling as provenance only;
- record every rejected child's bounded identity and exact rejection reason
  before skipping it; and
- require zero skip rows for `COMPLETE`.

No source hashing or image work may proceed from the OLS3 broad-inventory hold.
One fresh, generic, metadata-only capability correction must pass the new
Windows PowerShell 5.1 alias/skip-identity controls before any further JBOD
request is considered.
