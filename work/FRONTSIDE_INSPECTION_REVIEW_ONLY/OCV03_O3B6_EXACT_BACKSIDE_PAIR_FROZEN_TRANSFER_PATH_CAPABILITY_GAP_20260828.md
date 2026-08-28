# OCV-03 O3B6 exact backside pair frozen; transfer path capability gap — 2026-08-28

State: `PENDING_GATE`

The exact clean Slot01 backside pair is now resolved directly on JBOD
`A1025645101` without reading image bytes during discovery. Both clean BMPs are
475,379,874 bytes. The separate operator-marked `Chipoutlocation.bmp` is
excluded from detector input.

- BF: `PatternedFront/Lot_62627-193/62627-193_20260820124250/Slot01/BrightfieldBacksideWafer/resizedImage/62627-193_Slot01_BrightfieldBacksideWafer_PM2_resizedImage.bmp`
- DF: `PatternedFront/Lot_62627-193/62627-193_20260820124250/Slot01/DarkfieldBacksideWafer/resizedImage/62627-193_Slot01_DarkfieldBacksideWafer_PM2_resizedImage.bmp`
- pair freeze: `work/OPENCV_BACKSIDE_NOTCH_STATUS_O3B5/O3B5_EXACT_BACKSIDE_PAIR_FREEZE.json`;
  SHA-256 `CEF8688BEE1B59DE36C952CA47EE7750BA7D1A235919D2870F131729DE9E3187`.

O3B3 was published exactly once and failed safely before mutation because its
worker predecessor pin was stale. O3B5 then proved the direct STATUS handler
does not expose the installed extended inventory parameters. Direct bounded
JBOD metadata enumeration supplied the exact pair instead.

O3B6 was a fresh exact two-file DATA_PULL. Its matching signed response
`R_7BEDC7E1740F_20260828222355212_16a91028` failed before source read because
the BF canonical path measured effective length 208 and the installed handler
requires a short alias. O3B6 is terminal and no-retry. Signed response ZIP
SHA-256 is `E433AC29490AC85E3987946AACC853B520177C33A7238D4B5D3DC3741183AF49`.

A direct process-local alias hash attempt was then issued for the two frozen
files. The direct-control transport timed out after its fixed 60-second wait
before returning hashes. That console or owned hash process may still be
finishing. Do not touch, query, kill, reuse, or send input to it.

Next action: preserve the exact pair and wait until the possible stranded hash
command has exited naturally. Do not retry O3B6. The remaining capability gap
is one timeout-safe, D-drive output route that reads the two frozen long-path
sources through an exact-ancestor process-local alias and returns their bytes
without source mutation or deletion. Hotspot remains parked; frontside POST2,
all holds, tasks, processors, thresholds, algorithms, XML, training, and
production authority remain unchanged.
