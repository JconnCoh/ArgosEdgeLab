# Front-metal D7 V7 display-regression withdrawal — 2026-08-14

## Disposition

`FM7_V7_20260814T154000Z` is `WITHDRAWN` and is not eligible for operator
review, launch, reuse, or parentage.

The operator supplied two bounded screenshots showing presentation regressions
that the prior metadata-only asset audit did not detect:

- `codex-clipboard-c5647b58-fea2-4bd5-bc62-86192d2c3088.png`, 1578 by 975,
  SHA-256
  `75CDAC31198DD67FEB0A8874FEE613214C2992870B01F9B47236A057D1979DD2`;
- `codex-clipboard-23b482ce-816f-4576-ac2b-e9df84070069.png`, 1853 by 341,
  SHA-256
  `903DE09A3710FFCD631082BC46FD5F58169629D44C85F0D744BF6F6830EC0110`.
- `codex-clipboard-b694e49b-b404-45bc-bad5-599980c9f44e.png`, 1074 by 627,
  SHA-256
  `1ECCD1E0D4DB22AEAF0B806F51C8145AF0E9803BAF410A4D157BC4A8DBA269CC`.

The first screenshot shows a locally inverted/incorrect heatmap presentation
and a painted edge-boundary ring. The second shows mojibake in the cyan action
window. Direct UTF-8 inspection of the released `app.js` confirms that the
shipped string is `Drawing tool only â€”`, so this is a generated-source
encoding defect rather than a browser-only rendering anomaly.

The third screenshot shows imported operator highlighter strokes remaining
visible over local image panels. D7 intentionally loaded the locked D6
feedback and programmatically used saved stroke coordinates and class labels
for same-wafer rule development. It was therefore feedback-informed, not a
blind evaluation. The build did not intentionally rasterize feedback strokes
into detector masks, but exact file-hash, generated-PNG, and runtime-canvas
provenance must be completed before that distinction is reported as verified.
Regardless of storage location, carrying the strokes into the default review
view without an explicit clean-view state is a presentation regression.

No detector, accepted mask, hold mask, native component geometry, D4/D5/D6
feedback, or strict frontside chipout artifact was changed by this withdrawal.
The locked D6 response remains at SHA-256
`60544E6D21E959E156854FD5848C66B5D56E12B0DBC07D4EC453CB3C0A086845`.

## Required recovery

Do not patch or reuse V7. Audit the exact grayscale/alpha polarity of every
source mask, distinguish physical component evidence from edge/holder display
exclusions, and replace non-ASCII generated UI literals with an encoding-safe
form. Audit imported-stroke rendering and require a clean-view default with an
explicit feedback-overlay toggle. Build into a fresh root. A replacement must
pass numeric pixel-polarity and edge-zone assertions plus bounded visual
comparison of representative accepted, held, edge, zero-signal, and
feedback-bearing fields before presentation.

Training, XML, production, packaging, full-lot execution, automatic feedback
promotion, and frontside chipout changes remain unauthorized.

## Completed V7 forensic audit

The later read-only forensic audit is stored at
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7_DISPLAY_REGRESSION_AUDIT_V1_20260814T160000Z/RUN_RESULT.json`,
SHA-256
`CC3580562361218B49EBE7A4AD2347DEABC2DC3912E4800E15A8E459718D7B43`.

It established that all 33 V7 masks retained sparse alpha and all 22 generated
accepted/held images changed zero pixels outside their documented union masks.
The old marks were therefore not rasterized into native BF/DF or generated
heatmap files. V7 loaded all 35 saved T02 strokes and drew them at runtime over
each of four feedback canvases because `feedbackVisible` defaulted to true.
The broad technical mask contributed 145,047 pixels, including 58,354 within
32 pixels of a tile border, and was incorrectly composited into the default
held panel. The apparent inversion/ring was a presentation semantic failure,
not a detector-mask polarity inversion. V7 remains `WITHDRAWN`.
