# Front-metal D7 V12 clean-view release checkpoint - 2026-08-14

## Disposition

`FM7_V12_20260814T1745Z` is `RELEASED_REVIEW_ONLY` for operator review.
It replaces, but does not modify or inherit from, withdrawn V7. V12 was rebuilt
from the locked D6 reviewer root `FM6_V5_20260814T1500Z` and its locked D6
feedback save.

The detector, accepted masks, class-specific hold masks, raw BF/DF, component
geometry, strict frontside chipout branch, D4 feedback, D5 feedback, and D6
feedback remain unchanged. Training, XML, production, packaging, automatic
feedback promotion, and full-lot authority remain disabled.

## Exact response to the display-regression concern

The prior highlighter marks were not baked into the native BF/DF files or the
generated V7 heatmap PNGs. They were imported file-backed feedback strokes on
a runtime canvas that V7 made visible by default over every local panel. V7's
class-rule development also intentionally consumed the saved D6 stroke
coordinates and Scratch/Particle labels. The result was therefore
feedback-informed same-wafer review-only guidance, not a blind validation.

V12 preserves those saved strokes without overwriting them but initializes
both local and full-wafer imported feedback as hidden. The operator must use
the explicit `Show imported feedback` control to display them. Hiding the
feedback is presentation isolation only; it does not retroactively make the
rule blind.

## Clean-view corrections

- Default accepted heatmaps contain only the sparse accepted component mask.
- Default held heatmaps contain only sparse class-specific component holds.
- The broad technical/edge mask is a separately labeled optional amber layer,
  off by default and explicitly identified as not defects.
- Every local panel retains a clean raw or generated file-backed image beneath
  the optional feedback canvas.
- The drawing-state label is ASCII: `Drawing tool only - Scratch`.
- Generated `index.html` and `app.js` contain zero non-ASCII UI code points.
- T21 no longer maps its accepted/held panels to duplicate raw-DF assets.
- The title, lede, and status-card label all identify the clean-view class and
  coverage reviewer and explain the optional layers.

## Locked inputs kept distinct

- D4: review ID `FM_D4_CANONICAL_V3_20260813T223500Z`, 91 strokes, SHA-256
  `FD714DA87C377AD0AEFA5A646174BA54EF57B15B87205CF224F084B8A79D4476`.
- D5: review ID `FM_D5_CANONICAL_V4_20260813T184500Z`, 88 strokes, SHA-256
  `7E3E586F2CA7611935434932A93F74E5393C35ADD66553FE581A1F64A756D967`.
- D6: review ID `FM6_V5_20260814T1500Z`, 106 strokes across 70/98 fields and
  22 comments, SHA-256
  `60544E6D21E959E156854FD5848C66B5D56E12B0DBC07D4EC453CB3C0A086845`.

V12 preserves 28 unreviewed fields as unreviewed. It does not convert them to
Normal, training truth, or automatic pass authority.

## Build result

- reviewer root:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V12_20260814T1745Z`;
- `BUILD_RESULT.json` SHA-256
  `812AD581885C201748B39D3E1B34B0E492DF5DB10EEBFB1BB7EF2D50CC4FE8F8`;
- `REVIEW_MANIFEST.json` SHA-256
  `7A3CE06D874051245D26F8B6237A3EF96EC18404A16BB2AAB1FC0D27863E4768`;
- `index.html` SHA-256
  `81CAE463F51D1E6C8694615307CDDECCE8AEA1A2FCD9377C13C341212FE8B506`;
- `app.js` SHA-256
  `65C5227E1B239119BDD637F834BFCD68626D4A07622E8DD0CBD32725EFCC0D84`;
- canonical `styles.css` SHA-256
  `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`;
- builder SHA-256
  `9575C1C0BDCDB58F23D74B6DD75CA5F39CAF2869B974F353362BC0401CFD38C7`;
- build invocation SHA-256
  `53A0B32D32EFC1C573FF4E42012564D706DFF7950F9FF98A98DAF2FB8440C95A`;
- build: 70 reviewed fields, 28 unreviewed fields, 86 Scratch proposals,
  46 Particle proposals, 65 ambiguous accepted components, 33 local heatmap
  assets, zero duplicated raw-DF heatmaps, zero embedded payloads, and maximum
  effective build path length 198.

The two canonical T02 native inputs remain:

- BF SHA-256
  `1A340365DBE54F154CB46CF5C91AA650D6592933EE7EBC29C1B80869EEE2D6EA`;
- DF SHA-256
  `E3F9DCA045CE041162BB249E35EE5103CB84832C00475D36A04283B719EF303F`.

## Pixel and runtime audit

The machine-readable result is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7_V12_CLEAN_DISPLAY_AUDIT_V1_20260814T175000Z/RUN_RESULT.json`, SHA-256
`2F7DD6A0E623E48B6A4A7B8D643599ABB42B92FEBE3E6B27A9B9BB4E8E06F223`.

It passed with:

- 33/33 sparse masks preserving alpha semantics;
- zero opaque-grayscale masks;
- 22/22 accepted/held composites changing zero pixels outside the union of
  their documented masks;
- 11/11 optional technical layers present and excluded from default held
  heatmaps;
- exact 69,623 accepted-mask changed pixels and 2,876 class-hold changed
  pixels, with zero outside-mask changes;
- imported feedback default-hidden in both local and full-wafer state;
- feedback rasterization absent from the builder; and
- clean ASCII drawing label present with the corrupted literal absent.

## Bounded rendered-browser audit

Only bounded local screenshots were written to disk; no image bytes, Base64,
or data URLs were placed in task history or project JSON.

- `visual_audit/V12_T02_PANELS_DEFAULT.png`, 1265 by 712, SHA-256
  `370FF5EA22D4D3EB629441DA2A26A5B2F5C2A3A836D0F99DEB1F4C3C4FB2A7DC`:
  clean T02 default panels with no imported feedback strokes.
- `visual_audit/V12_T02_HEATMAPS_DEFAULT.png`, 1265 by 712, SHA-256
  `43C894805AD36DBE08B906FF9DBA4428376ADCADDCDA8B4AA691D3376988D39D`:
  accepted and class-hold panels without the technical edge ring.
- `visual_audit/V12_T21_HEATMAPS_DEFAULT.png`, 1265 by 712, SHA-256
  `AA01E3707B5CD1399D5272140FD3BBB055CC654C1C3CCC7418F3774A17518249`:
  T21 raw and generated panels are distinct and the operator comment remains
  visible.
- `visual_audit/V12_T02_IMPORTED_FEEDBACK_EXPLICITLY_SHOWN.png`, 1265 by 712,
  SHA-256
  `D411A0397F8BE4B1A9917485CE9DB4C171607EFC9CC8706C86CA9FF1272F43B7`:
  the old feedback layer appears only after the explicit toggle; the button
  returned to `Show imported feedback` after the audit.

## Superseded build attempts

- V8 is `DIAGNOSTIC_ONLY`: numerical fixes passed, but rendered inspection
  found stale D6 title and explanatory text.
- V9 is `WITHDRAWN`: the strict ASCII gate stopped the partial copied tree.
- V10 is `WITHDRAWN`: the strict ASCII gate again stopped the partial copied
  tree after distinguishing real Unicode from legacy display mojibake.
- V11 is `DIAGNOSTIC_ONLY`: pixel audit passed, but rendered inspection found
  a stale D6 manifest label in the status card.

None of V8-V11 is eligible for operator launch or parentage.

## Preserved sibling authority

The strict frontside chipout tool remains SHA-256
`900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`.
Its frozen anchor remains SHA-256
`1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.

## Final entry-point and continuity gates

- Metadata-only Codex session guard: `PASS_SESSION_SIZE`; active task 16.431
  MiB, no session content read, far below the 128 MiB warning threshold.
- Static Windows PowerShell wrapper guard:
  `PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT`; exact script, CMD wrapper, and
  bounded invocation manifest verified; target not executed by the static
  check.
- Exact launcher path budget: `PASS_PATH_BUDGET`; maximum effective entry-point
  length 184 including the 32-character suffix reserve.
- Exact launcher target preflight under Windows PowerShell 5.1:
  `PASS_FRONT_METAL_D7_REVIEWER_PREFLIGHT`; mutation false; port 8878 free.
- Project continuity: `PASS_ARGOS_PROJECT_CONTINUITY`; 12 reviewer artifacts,
  the V12 display audit, canonical reviewer files, D6 save, and phase
  checkpoint verified.
