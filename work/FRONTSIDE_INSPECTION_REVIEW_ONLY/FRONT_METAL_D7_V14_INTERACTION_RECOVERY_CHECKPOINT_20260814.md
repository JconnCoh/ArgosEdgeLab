# Front-metal D7 V14 interaction recovery checkpoint - 2026-08-14

## Disposition

`FM7_V14_20260814T1915Z` is `RELEASED_REVIEW_ONLY` and supersedes V12 for
operator review. V12 is `WITHDRAWN` because hiding imported feedback also hid
the current draft and newly staged highlighter strokes, making the drawing
tool appear inoperative. `FM7_V13_20260814T1850Z` proved the UI correction but
is `DIAGNOSTIC_ONLY` because it still inherited the older blocking launcher.

No detector evidence, component masks, raw BF/DF, D4 feedback, D5 feedback,
D6 feedback, class rule, threshold, training state, XML state, production
state, packaging state, or strict frontside chipout authority changed.

## Operator product-pattern correction

The operator identified the cyan finding in
`62546-481_POST2_SLOT02 / T02_R00C01 / F02` as a human-readable coordinate
repeated in the product streets for every die. It is normal product structure,
not a foreign finding. Low contrast and small registration/contrast differences
against the target-excluded composite can leave a residual at that repeated
street glyph.

The exact frozen row is:

- component: `T02_R00C01_RAW_CONFIRM_000008`;
- disposition: `CONFIRM_SCRATCH_OR_RESIDUE_OR_CONTAMINATION_RAW_CONNECTED`;
- support: `ALIGNED_TARGET_EXCLUDED_COMPOSITE_SEED__RAW_BF_DF_FOOTPRINT`;
- area: 9 native pixels / 0.00189225 square millimetres;
- tile bounds: `(1671,700)-(1674,702)`;
- source bounds: `(5815,924)-(5818,926)`.

This was a fail-closed cyan confirmation hold, never an accepted foreign
particle or automatic reject. V14 adds the reviewer false reason
`NORMAL_PRODUCT_STREET_COORDINATE / Normal repeating street coordinate` so the
operator can save the correction directly. This guidance remains approximate,
review-only, and unapplied until the operator explicitly accepts and saves it.

## Interaction correction

V14 keeps imported local and full-wafer strokes hidden by default but draws
the current draft and every newly staged stroke regardless of the imported-
feedback toggle. Imported strokes receive runtime-only identity tracking, so
the toggle controls only imported history. Reload/import merges the immutable
baseline with locally staged strokes and gives current reviewed-field decisions
precedence instead of replacing current work with the baseline.

The original canonical DOM, stylesheet, full-wafer/native-tile tabs, zoom/pan,
four action tokens, palettes, native-coordinate capture, queue workflow, and
staged-feedback semantics remain present. `styles.css` is byte-identical to the
canonical lock.

## Evidence and validation

- V14 build state:
  `PASS_FRONT_METAL_D7_INTERACTIVE_FEEDBACK_REVIEW_ONLY_V7`;
- V14 build-result SHA-256:
  `9AEB6A37F0AF898978D60990A6A0FC128293385A049F8EC9BD35DBE55115C143`;
- `app.js` SHA-256:
  `227C7F5BB36B9CD2FD88FB1CF6EC17A425CDFAE849259A6F4303254B2EEA27C1`;
- `styles.css` SHA-256:
  `F0D1C31FE2DA28D00857486C9678A642B7AD1C837BB9249A1FB50BAB9036777E`;
- review-manifest SHA-256:
  `A7FCBA4F58D1886D40761F663F53270BE13483364D8FA964793B7E804781F2EF`;
- display-audit state:
  `CONFIRMED_FRONT_METAL_D7_DISPLAY_REGRESSION`;
- display-audit SHA-256:
  `ED4AFF1FACEB1EF8BA360BC77EE491526C6C0D113157AD4BBA62C4856365DABB`;
- 33 masks and 22 composites checked; zero opaque-grayscale masks and zero
  changed pixels outside documented masks;
- 79/79 `data`, `display`, and `local` evidence files are byte-identical to
  V12;
- path preflight passed with maximum effective length 198 including the
  32-character suffix reserve;
- embedded media/Base64 payloads: zero;
- live browser loaded review ID `FM7_V14_20260814T1915Z`, F02, the existing
  fail-closed row, hidden imported-feedback default, and the new repeating-
  street-coordinate false reason;
- exact output launcher wrapper and Windows PowerShell 5.1 target preflight
  passed;
- exact `START_FM7.cmd` execution returned
  `PASS_FRONT_METAL_D7_REVIEWER_OPENED` and safely reused the exact hash-
  qualified server already active on port 8878.

## Next action

Continue operator review only in V14. For this F02 finding select `Remove false
detection`, select `Normal repeating street coordinate`, mark the cyan finding,
accept the marked pixels, and later save the review. Do not train, write XML,
package, run a full lot, promote this same-wafer correction automatically, or
change the independent strict BF/DF chipout branch.
