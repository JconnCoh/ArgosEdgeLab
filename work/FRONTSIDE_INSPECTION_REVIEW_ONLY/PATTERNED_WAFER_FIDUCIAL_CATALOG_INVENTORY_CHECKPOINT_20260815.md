# Patterned-wafer fiducial catalog inventory checkpoint — 2026-08-15

## Revision and authority

- Revision: `PATTERNED_FIDUCIAL_INVENTORY_V1_CATALOG`
- Parent: `PATTERNED_FIDUCIAL_INVENTORY_V1_REQUIREMENT`
- Disposition: `PENDING_GATE`
- Authority: review-only catalog inventory and deterministic source selection.
- This checkpoint grants no alignment-model, detector, training, XML, or
  production authority. No image pixels were loaded to make the selection.

## Signed current-catalog pull

- Request: `REQ_20260816T014557623Z_73DA2C2A3FB8`
- Signed request ZIP SHA-256:
  `252F6CCC0539B93A47A3E2190992E9B21C0380A80D3523C4EA1B884DCEDA183A`
- Response: `R_3EEDAE5F94EC_20260816014741131`
- Response state: `PASS_DATA_PULL`
- Signed response ZIP SHA-256:
  `9556F98D6201E7F45F87917B75A56348A67735ACFECB7593806CA7B5FB379645`
- Response manifest SHA-256:
  `27A38374B6A55B7948E8BC1F253EF9A80104767929DD0261873A72C53E4E5EE3`
- Exact returned catalog:
  `C:\A23\in\R_3EEDAE5F94EC_20260816014741131.ready\data\JBOD_PROCESSOR_REVIEW\catalog\ALL_WAFER_CATALOG.json`
- Catalog bytes: `10,248,525`
- Catalog SHA-256:
  `AC689B5C60DDD467061FCE1A88603C44772A0BBCC709FBC8D357639DA295D715`
- Catalog `generatedUtc`: `2026-08-14T22:27:42.8339018Z`
- Catalog scan contract: filename metadata plus 54-byte BMP headers only; no
  image pixels loaded, no image bytes embedded, and no detector execution.

## Exact combination inventory

The catalog contains 1,685 acquisitions, including 843 frontside
acquisitions. Exactly 415 frontside acquisitions have an exact product,
well-formed `visualStateKey`, and paired stable native 24-bit BF/DF BMPs with
matching dimensions. They form 31 image-relevant product/layer combinations
across eight products.

The combination key retains exact VisualStateKey fields 1 through 7 and the
exact operation. It excludes only field 8, the transient `IN QUEUE` / `IN
PROCESS` state, so an unchanged physical layer image is not duplicated because
its MES queue status changed.

Combination counts by exact product are:

- `1427010/A01`: 2
- `1470174/A00`: 5
- `1477419/A00`: 1
- `1480861/A00`: 11
- `1491551/A00`: 9
- `1498994/A00`: 1
- `1509314/A00`: 1
- `1627304/A00`: 1

One physical acquisition per combination was selected before any crop or
appearance review. The fixed rule is the lexicographically first
`physicalIdentity`, then `identity`, among acquisitions with complete exact
metadata and paired stable native BF/DF. The 31 selected physical identities
are unique.

## Explicit catalog holds

The remaining 428 frontside acquisitions are not silently grouped or skipped:

- 380: `HOLD_MISSING_EXACT_PRODUCT`
- 48: `HOLD_MISSING_VISUAL_STATE_KEY`

These rows remain identity/metadata holds. They are not Normal truth and do
not establish additional unique product/layer combinations until the missing
metadata is resolved.

## Product-map gate

The 219-file local template set was searched by exact XML `LayoutId`, not by
filename similarity or product-family proximity.

- 30 combinations across seven products have exactly one product layout with
  at least one bin 34 or bin 36 position and are
  `PENDING_NATIVE_POSE_AND_BIN_34_OR_36_CROP`.
- The single `1498994/A00` combination is
  `HOLD_MAP_TEMPLATE_NOT_FOUND`: no template has exact `LayoutId="1498994"`.
  The nearby catalog product-family value `3393-901` is not accepted as a map
  substitute.

The seven resolved exact product layouts and their bin counts are preserved in
the inventory JSON. Five layouts contain bin 34 only, one contains both bin 34
and bin 36, and all resolved layouts contain at least one eligible bin. A crop
still requires exact per-wafer source hashing, verified macro pose, map-based
projection, native 1:1 extraction, and paired BF/DF provenance.

## Artifacts

- Inventory:
  `work/PATTERNED_FIDUCIAL_INVENTORY/catalog/V1_20260816T014800Z/INVENTORY.json`
  - SHA-256:
    `68CE326946BF88132ABBEC1C742FCECA0FEFDECA19E2E9A9D53841233EC8FD39`
- Combination table:
  `work/PATTERNED_FIDUCIAL_INVENTORY/catalog/V1_20260816T014800Z/COMBINATIONS.csv`
  - SHA-256:
    `783AB6922A9CAD744941E73D4AEEE3742B3F8282935A774E8E32905545DB15E8`
- Held-acquisition table:
  `work/PATTERNED_FIDUCIAL_INVENTORY/catalog/V1_20260816T014800Z/HELD_ACQUISITIONS.csv`
  - SHA-256:
    `C4A036811371260DD40C495BC4DF585352080166C2A1CA9ACB452A4EF1858DDB`
- Inventory builder:
  `work/PATTERNED_FIDUCIAL_INVENTORY/tools/Build-PatternedFiducialCatalogInventoryV1.py`

## Next action

Build a bounded JBOD review-only crop package from this frozen selection. For
each of the 30 map-resolved combinations, verify the exact BF/DF hashes and
dimensions, qualify macro pose without a fixed-angle deciding rule, project a
deterministically selected bin 34 or 36 site from the exact product map, and
write paired native 1:1 BF/DF crops plus file-backed provenance. Any pose,
map-projection, source, or model ambiguity is an explicit hold. Resolve the
missing exact `1498994` layout separately; do not guess it.
