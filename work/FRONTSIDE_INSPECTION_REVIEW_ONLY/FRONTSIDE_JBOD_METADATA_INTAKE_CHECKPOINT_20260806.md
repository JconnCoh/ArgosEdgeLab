# Frontside JBOD metadata intake checkpoint - 2026-08-06

## State

`PASS_SCAN_TIME_METADATA_AND_METADATA_ONLY_FRONTSIDE_INVENTORY_REVIEW_ONLY`

This checkpoint does not enable a frontside detector. It creates no defect,
Normal, training, XML, reference-promotion, or production authority.

## Scan-time Insite context

The read-only pending-scribe response was enriched with acquisition-local
history. For each exact acquisition key, the query records:

- the last Insite `MoveIn` at or before the Argos acquisition timestamp;
- the next `MoveIn` after the acquisition;
- the most recent resource-bearing `MoveIn` at or before the acquisition for
  `Last Tool` when the immediate prior state has no resource.

Recipe-folder names are not used for process, step, tool, appearance, or
backside-regime authority.

The final bounded response is:

`work/MES_INSITE_READ_ONLY/snapshots/ARGOS_JBOD_PENDING_INSITE_RESPONSE_V2_2_20260806T213647Z.json`

Its SHA-256 is
`5ABFA3EADBC5AFDCAC7C5EA9CEC9010116F09CD5C88E7F88F40EBFF552793730`.
It contains 117 scribe records, 110 exact-complete records, seven held records,
208 acquisition contexts, and 201 exact prior-MoveIn contexts. The new
`62631-586` lot has 18 exact contexts and two explicit no-prior-MoveIn holds;
all 18 exact contexts have a bounded `Last Tool` value.

## V2.8.2 compatibility corrections

The first V2.8 package changed the active metadata-state token. The existing
JBOD catalog gate intentionally admits only the established
`SCRIBE_CONFIRMED_MES_SNAPSHOT` state, so that package was superseded before
operator installation. V2.8.1 preserves that stable admission token and
carries exact scan-time authority in dedicated fields.

The first V2.8.1 operator run installed the corrected importer and performed
its bounded merge, then its final report encountered older preserved metadata
rows that predated the optional `scanTimeContextAuthority` field. The detector
and scribe reader continued running. V2.8.2 changes only that final validation
to treat the absent optional field as empty while still requiring all 200 new
exact rows and all 18 new-lot `Last Tool` values.

Regression `TEST_V28_INSITE_SCAN_TIME_CONTEXT.ps1` passed with:

- 200 active rows;
- 200 exact scan-time rows validated;
- 18 `62631-586` rows, all with `Last Tool`;
- repeat-import row count and content stability;
- two synthetic inventory rows admitted through the deployed inventory gate,
  both retaining `Last Tool`;
- training, XML, and production authority false.

The current install/recovery package is:

`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V2_8_2_SCAN_TIME_METADATA_HOTFIX_20260806T224104Z.zip`

SHA-256:
`A8118A3144FAC3E32CB9F38773624DDB8C6CA87214B1B0BC1A054115A1C1D0DF`.

The matching network handoff copy has the same hash. Superseded packages must
not be rerun.

## Metadata-only frontside development inventory

`Export-JbodFrontsideDevelopmentInventory.ps1` reads the existing catalog and
exports no image bytes or detector pixels. It records native source paths,
BMP header dimensions, stability, confirmed scribe, scan-time process/step/
tool context, and exact pairing state.

Frontside BF and DF are paired only by exact physical identity:

`lot + acquisition timestamp + slot`.

A backside record is associated only when it has that identical physical
identity. Frontside/backside records from different timestamps, slots, or lots
cannot be paired by the exporter. Recipe-folder text is retained only inside
the source path as a locator and is explicitly non-authoritative.

Regression `TEST_V29_FRONTSIDE_DEVELOPMENT_INVENTORY.ps1` passed with one
synthetic exact native BF/DF pair, the exact matching backside identity,
confirmed wafer ID, scan-time `Last Tool`, no image bytes, and all decision
authorities disabled.

The operator package is:

`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V2_9_FRONTSIDE_DEVELOPMENT_INVENTORY_20260806T223108Z.zip`

SHA-256:
`FCD514B6C78EFE6F43CD9B3C1D767BDD7C402282EABCE44AF61B5F1F642CAEFD`.

The network handoff copy has the same hash.

## Exact operator order

1. Allow the active scribe review/save/import cycle to finish naturally.
2. Extract and run V2.8.2 on the JBOD. It does not stop the detector or scribe
   reader.
3. Allow one catalog refresh.
4. Extract V2.9 and run `RUN_FRONT_SIDE_INVENTORY_ON_JBOD.cmd`.
5. Return the generated
   `ARGOS_FRONTSIDE_DEVELOPMENT_INVENTORY_*.json` from Downloads for bounded
   cohort selection.

Do not run the superseded V2.8/V2.8.1 packages. Do not enable frontside decisions from
the inventory alone. Patterned/unpatterned/dielectric appearance still
requires native appearance review, and every target-excluded composite needs
sufficient independent physical peers.
