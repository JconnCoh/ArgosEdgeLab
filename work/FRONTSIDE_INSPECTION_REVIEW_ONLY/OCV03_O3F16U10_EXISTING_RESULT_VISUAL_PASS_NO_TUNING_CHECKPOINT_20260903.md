# OCV-03 O3F16 U10 existing-result visual pass / no tuning checkpoint — 2026-09-03

Disposition: `DIAGNOSTIC_ONLY`

The existing `D:/O3F16U10` result was observed without rerunning it. Its
49-file, 97,198,423-byte tree was staged once as a byte-pinned archive beneath
the already approved read-only portal root, returned by one signed
`DATA_PULL`, and extracted create-new. The signed response and every returned
byte passed provenance checks. No source image or U10 result was modified or
deleted, and no existing task, process, provider, hold, training, XML, or
production state changed.

## Exact provenance

The staged archive
`D:/KLARFExport/_ArgosReview/O3F16U10OBS1_20260903.zip` is 76,479,713 bytes,
SHA-256
`5947DD4FE271C2F275630679A8CB9FAF3523059C31D9ACBE63881980D991E5B4`.
One signed request, `REQ_20260904T011547893Z_A5EB49CD10A1`, returned matching
response `R_61F3CAD40107_20260904011738470_715b8268` in state
`PASS_DATA_PULL`. The response ZIP SHA-256 is
`AFE0B706C55295D6AAE0668AB56815586CAA94ED775B544D1FD3A605A1E80A04`;
its signature verifies against pinned JBOD signer thumbprint
`DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`.

The returned `SUMMARY.json` is 81,358 bytes, SHA-256
`2D1A46CBB7C69782CF60C621A4F746998F18F392F42748537EC2433DF792C378`.
It reports 4/4 complete cases and the exact corrected annular engine SHA-256
`6B28925E04839D411838CB3D6C7D39E523AFC3AE89EDBAC83034351D27ED814C`.
All 48 declared BF/DF assets are unique and match their declared byte sizes and
SHA-256 values: eight each of clean, mask, overlay, edge-review,
normalized-review, and damage-review rasters. The complete asset set totals
97,117,065 bytes.

Machine-readable terminal visual gate:
`work/OPENCV_EDGE_UNWRAP_O3F16U10/O3F16U10_OBS1_TERMINAL_VISUAL_GATE.json`,
SHA-256
`7F0CDF880CD8A4E5FB348068830339486630C8AA6911F8CC1131C33DDFB46BF9`.

## Ultra visual decision

Every one of the 48 BF/DF rasters was inspected at original detail. Across
Slot16, Slot17, Slot18, and Slot20, the accepted red reference path becomes
genuinely horizontal in the path-centered normalized sheets while the green
fixed-circle trace retains the removed radial drift. Local scallops, roughness,
and edge relief remain visible rather than being flattened away.

The separate damage sheets retain the full 180-pixel inward and 55-pixel
outward radial envelope. No visible notch, bay, chipout-like relief, or edge
roughness is clipped at either radial boundary. The detector does not use that
wide evidence envelope to select its reference path.

Large low-evidence sectors remain explicitly magenta. The two longest BF
intervals are Slot16 178.893–219.965 degrees (3,692 columns) and Slot18
72.582–95.821 degrees (2,093 columns). They coincide visually with genuine
dark/occluded or holder-like sectors and are bridged instead of being falsely
reported as measured edge. The Slot17 DF wraparound interval crossing
359.258–4.487 degrees is cyclically continuous. No artificial 2,048-column
review-sheet stitch step or 0/360 wrap seam is visible in any case.

Rear-holder-like circles, blades, and support regions remain visible in the
wide damage views, especially near 90 degrees and in the 0/180-degree sectors,
but the accepted path does not climb onto them. This is a visual correspondence,
not an automatic holder classification: U10 correctly reports
`holderClassificationPerformed=false`.

All eight channels keep imputed reference segments ineligible as notch or
damage evidence. The visual gate therefore passes with zero detector errors.
There is no evidence-based reason to tune the R10 detector, relax a threshold,
or build a successor detector package. The operator's detector/successor-
detector-package failure stop-loss is not triggered: 0 failures were observed
against the limit of more than 3. The sole package built and published here was
the explicit observation `DATA_PULL` ZIP recorded above.

## Next action and preserved holds

Retain R10 unchanged as the diagnostic annular reference for the next
detector-only edge-damage/notch interpretation step. Preserve every magenta
interval as non-evidence and preserve the 180-in/55-out damage envelope. A
future diagnostic revision should add an explicit numeric 0/360 seam assertion
before any broader corpus; this recommendation does not authorize a successor
detector package or run.

Do not return to T5, authorize the frontside 978 corpus, clear any existing
hold, activate a provider, mutate or delete a source, or enter scribe from this
worktree. Review-only remains true; training, XML, production, and production
routing remain false.
