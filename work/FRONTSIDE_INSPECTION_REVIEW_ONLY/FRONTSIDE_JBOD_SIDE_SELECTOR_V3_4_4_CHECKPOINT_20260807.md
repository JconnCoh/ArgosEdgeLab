# Frontside JBOD side selector V3.4.4 checkpoint — 2026-08-07

## State

`PACKAGE_PASS_V3_4_4_FRONT_BACK_SIDE_SELECTOR_REVIEW_ONLY`

This revision changes only the completed-lot review selector and generated
dashboard folder naming. It does not change detector scoring, accepted masks,
the processor queue, scribe identity, Insite metadata, reference caches,
source images, XML state, or production routing.

## UI behavior

- `Side` is the first selectable column.
- Each side-specific inspection result is labeled `FRONT` or `BACK`.
- `FRONT` is listed before `BACK` for the same lot and scan timestamp.
- Full-row highlighting is disabled; the selectable label is the Side cell.
- The Open button reads `Open selected side BF / DF`.
- Generated dashboard folders include `FRONT` or `BACK`, preventing a
  same-second front/back output-name collision.

The front and back results remain separate inspection results. The UI does
not combine, pair, or alias their masks or image artifacts.

## Validation

The exact same-visit fixture contained one frontside and one backside result
for lot `62631-586` at `2026-08-06 15:21:40`.

- catalog check: pass;
- UI construction smoke: pass;
- Side-column contract: pass;
- rendered Side order: `FRONT`, then `BACK`;
- front dashboard generation: pass;
- back dashboard generation: pass;
- generated folders carried distinct `FRONT` and `BACK` tokens;
- installer regression from the V3.4.2 viewer: pass;
- dashboard manifest changed by installation: false;
- detector, scribe, and Insite tasks stopped by installation: false.

## Package

`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_4_4_FRONT_BACK_SIDE_SELECTOR_20260807T191937Z.zip`

SHA-256:
`5F62614023B10B66697C6D8D0BC774E24E2BAC04F37F3E9C5250FA8E438C3177`

The ZIP was copied without overwrite and hash-verified in the approved
`InspectionRevs` handoff folder.

The package is review-only, training-ineligible, XML-ineligible,
production-ineligible, and contains no image payload.
