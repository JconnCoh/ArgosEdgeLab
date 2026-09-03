# OCV-02 scribe R16A local supplemental-glyph checkpoint — 2026-09-03

## State

- Revision: `OCV02_R16A_SUPPLEMENTAL_GLYPHS_LOCAL_DRAFT_20260903A`
- Disposition: `DIAGNOSTIC_ONLY`
- Local gate: `PASS_R16A_LOCAL_SUPPLEMENT_BUILT`
- Publication, provider activation, identity acceptance, reference admission,
  hold clearance, XML, training, and production authority remain false.

## Exact result

The four signed-terminal R15E BF rectified rasters were consumed locally by
OpenCV after exact SHA-256 verification. A dark-dot projection found exactly
12 separated character runs on each 1600x400 raster and produced 48 complete
cells. The previous R13B/R14 target filenames were not reused because pixel
inspection showed their selected grids were misphased and their target crops
were incomplete.

The create-new R16A result contains six correct supplemental references:

- `J`: JQ16D P04 and independently held-out JQ20V P04
- `Q`: JQ16D P05 and independently held-out JQ20V P05
- `K`: K25V P05, single-example provisional
- `X`: X18V P04, single-example provisional

Both J cells classify as J using only the other lot position, with cosine
similarity `0.9964587092399597`. Both Q cells classify as Q using only the
other lot position, with cosine similarity `0.999252200126648`. K and X each
classify correctly within the target-only bank but remain explicitly
single-example provisional; they are not represented as independently
validated.

The unchanged operator-confirmed S17 regression record remains hash-exact and
continues to prove topology string `6KB71041XDE5`. It was not rerun because its
source/code premise did not change.

## Frozen hashes

- Builder: `work/OPENCV_SCRIBE_R16A/Build-R16ASupplementalGlyphs.py`
  - SHA-256 `78B12A89F0135BFE67181960515F5F474150F4176758BAC94F9A44080768DBAA`
- Inputs: `work/OPENCV_SCRIBE_R16A/R16A_INPUTS.json`
  - SHA-256 `9D80D8743E8175E888174870BE26A1FC2744E251D8F2740CFCC3771A574B921C`
- Supplemental manifest:
  `work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json`
  - SHA-256 `9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC`
- Local gate: `work/OPENCV_SCRIBE_R16A_LOCAL_RESULT_R3/R16A_LOCAL_GATE.json`
  - SHA-256 `7829946E283FE1CD22C10D6F86A8CDB0A912FF71A2302B2CAFE321E77A7D864D`
- Deterministic 56-file result-tree listing digest:
  `A8CCF3DE15F20B81F2A7BC4D4F15546A95F1E3AF8BCB06167E00714C6CD98D97`
- A second create-new build produced the same 56 relative paths and hashes.

## Coverage and next action

The frozen base was missing `IJKOQVWXYZ`. This local supplement supplies
`JKQX`; remaining missing labels are `IOVWYZ`. The next local detector step is
to load this supplement beside the frozen base references in a fresh provider
revision, preserve J/Q cross-lot validation and K/X provisional status, and
mechanically select known-lot examples for `I/O/V/W/Y/Z` plus independent
`K/X` examples before a complete KLARF scribe run. R15E must not be republished.
