# Front-metal D7 V17 T16 reciprocal Scratch audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator asked to defer the
second unsupported Scratch addition and focus only on the first. It records
one quick native-pixel response test and pauses for visual feedback. It does
not supersede the passing V17 M3 classifier, release a V17 reviewer, or
authorize JBOD work.

## Operator observation

For stroke 238 in `T16_R03C00 / FIELD_09_3_3`, the operator reports that the
scratch is physically supported by both channels, with visibility alternating
along its length:

- in BF it is bright on a dark background;
- in DF it is dark on a bright background.

The prior unsigned response sweep over-selected strong null-die and metal-grid
structure while leaving the actual Scratch unmarked. That is a failed response
ordering for this target. The second target, stroke 278 in `T21_R04C00`, is
explicitly deferred and was not evaluated in this revision.

## Bounded reciprocal diagnostic

Output root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R2`

The diagnostic scores the unchanged native `2400 x 2000` BF/DF tile at
`scaleX=1`, `scaleY=1` inside the same 96-pixel-margin local crop. It searches
four orientations for a narrow bright BF ridge paired with a dark DF valley.
A symmetric-side penalty reduces broad step-edge response. To preserve the
operator-observed channel alternation, a scored native pixel may use reciprocal
support from the other channel no farther than four observed pixels along the
same tested axis. A pixel with no current BF or DF evidence remains empty.

The operator box is used only for the yellow reference rectangle and audit
metrics. It is not rasterized into response pixels. The method performs no
complete-line inference, gap filling, global scribe rule, broad null-die mask,
or source/current-mask mutation.

Artifacts:

- `AUDIT.json` SHA-256
  `62E04175ACEFC56224E05B13964465BFF108FCD9EB10783D44F0572D80C33E01`;
- `T16_S238_RECIPROCAL_AUDIT.png` SHA-256
  `B32CB3DEAA0DC8D3FEC378ADC4702A5DDE1F770B6684F474436C99686B029F28`.

Tooling:

- source: `tools/Audit-FM7V17ScratchReciprocalV2.cs`, SHA-256
  `07595E4DBAF08D6EF92659BE9F480F57A464788B0DA577161B00808A7F029E6C`;
- input: `tools/FM7V17R2_INPUT.json`, SHA-256
  `88143EEC21AE83817E40A304D2DEF4F2089F5DF8A228E9C9A5AA3D8F3E28AACF`;
- executable: `tools/bin/Audit-FM7V17ScratchReciprocalV2.exe`, SHA-256
  `39A59E1E5FC98DF90DA330D28984377DAF8ED129D129438FC5B4459FCB6EDC47`.

The planned paths passed with a maximum effective length of 192 and maximum
component length of 64. The exact non-mutating preflight passed the locked BF
and DF source hashes, native dimensions, T16-only identity lock, output-root
absence, and free-space reserve before the first output write.

## Result and limit

The signed reciprocal ordering materially increases response inside the
operator box:

- prior unsigned R1 maximum percentile: `0.940005`;
- reciprocal R2 maximum percentile: `0.988491`;
- reciprocal R2 target p90 percentile: `0.958647`;
- target pixels at or above crop p90/p95/p98: `123 / 71 / 25`.

The strictest displayed panel therefore retains 25 response pixels inside the
reference box. This numerical result is sufficient to present the bounded
sheet, but it is not sufficient to claim that the magenta pixels follow the
physical Scratch or that null-die overkill is acceptably suppressed. That is
the pending operator visual gate.

V17 M3 remains byte-unchanged and `PENDING_GATE`:

- `EVALUATION.json` SHA-256
  `CB092E201A0E0C21AA4A74F868F69BE2FF1E70AC108A601310E85D8AA345FE6B`;
- `MODEL.json` SHA-256
  `986A8FF4F859EBC8CC46CAB917A767463CE613183351D59FB7D72EDB25B5871A`;
- `PREDICTIONS.json` SHA-256
  `3D34856FAD88EF65874355E1047CFC840FF2111965472256CB6B0385231B24EF`.

## Next action

Pause for operator review of the single T16 sheet. The operator should report
which of the top 10%, top 5%, or top 2% magenta panels best follows the actual
Scratch, and whether remaining response around the null die is acceptable.
A bounded crescent on the first few scribe-adjacent rows may be acceptable
collateral when limited to the known slightly discolored/speckled die. That
does not make those pixels defect truth and does not authorize a broad scribe
sector, null-die exclusion, or global threshold relaxation.

Do not inspect stroke 278, start a longer recovery study, change V17 masks,
build or present V17, run raster smoke, package JBOD, emit XML, enable
production routing, or alter the strict chipout sibling before this feedback.
