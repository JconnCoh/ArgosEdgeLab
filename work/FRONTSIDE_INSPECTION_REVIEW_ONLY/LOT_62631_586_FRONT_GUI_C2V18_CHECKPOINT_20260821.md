# Lot 62631-586 FRONT GUI recovery — C2V18 checkpoint

Date: 2026-08-21

Disposition: `PENDING_GATE`

## Proven state

- The JBOD catalog contains exactly ten distinct `FRONTSIDE` acquisitions for
  lot `62631-586`, scan date `2026-08-19`, Slots 01 through 10.
- The JBOD dashboard still exposes only the seven-wafer backside session for
  `2026-08-19T17:33:17`; `frontsideAssetWafers` is zero.
- Slots 01, 03, and 04 hold at
  `HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR`.
- Slots 02 and 05 through 10 hold at
  `HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED`.
- The exact 20-record Argos response is independently proven sent by A14.
- No image file was read, no source was deleted, no inspection task or tray
  process was changed, no wafer was aborted, and XML and production routing
  remain disabled.

## Corrected diagnostic interpretation

C2V18 checked `response_queue` on JBOD. The exact installed JBOD scheduled
worker instead consumes `response_inbox`. Therefore C2V18 remains authoritative
for the catalog, route-state, and dashboard results, but its negative
target-package-location result is withdrawn. This new failure class and its
prevention are recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## Evidence

- C2V18 terminal gate:
  `work/JBOD_LOT_VALIDATE_C2V18/C2V18_TERMINAL_RESPONSE_GATE.json`
  SHA-256 `D5EF01A0EEEAA17D968B54F281B332A2F12ED4E99D8D2F2E9567C3F4F3E9C196`.
- A14 Argos relay terminal gate:
  `work/A14/A14_TERMINAL_RESPONSE_GATE.json`
  SHA-256 `C2C88DA99BB56534A7FA92AC182BFAB6DA22E39EB1F494D4C47F7D213FED32B5`.
- Locked JBOD worker source:
  `work/JBOD_INSITE_BRIDGE_ACTIVATION_C2I4/r/behavior/worker_revision_restart/bridge/Invoke-JbodAutomaticInsiteBridgeWorker.ps1`
  SHA-256 `4F60B9C9D5AE3CC6EABE8983A6A27D5EB391D6101C07E94406CDD570748B02B2`.

## Next bounded action

Build the fresh C2V19 successor from the exact C2V18 bytes, pin the C2V18
signed terminal as predecessor, and change only the JBOD package-location reads
to the worker-authoritative `response_inbox` roots. Determine whether the exact
target response was processed or failed before changing importer, route, or
scribe behavior. Final acceptance remains ten FRONT wafers visible in the JBOD
GUI.
