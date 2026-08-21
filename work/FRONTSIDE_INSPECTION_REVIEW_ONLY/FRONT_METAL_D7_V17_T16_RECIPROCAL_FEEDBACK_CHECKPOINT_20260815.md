# Front-metal D7 V17 T16 reciprocal feedback checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after operator review of the bounded T16
signed reciprocal audit. It supersedes the pre-feedback pause recorded in
`FRONT_METAL_D7_V17_T16_RECIPROCAL_AUDIT_CHECKPOINT_20260815.md` without
promoting any diagnostic pixel into V17.

## Operator review

For stroke 238 in `T16_R03C00 / FIELD_09_3_3`, the operator reports:

- the physical Scratch is visible reasonably well in the signed reciprocal
  heatmap;
- only the lower half of the Scratch is marked in the top-10-percent magenta
  overlay;
- a large amount of magenta remains on known-good die structure;
- the result is closer, but is not an acceptable recovery mask.

Stroke 278 remains deferred and was not inspected.

## Exact scoring/display distinction

The operator's interpretation is correct. `FM7V17R2` computes channel-local
ridge evidence directly from the unchanged native 1:1 BF and DF pixels. It
pairs a bright BF ridge with a dark DF valley using no more than four pixels
of same-axis reciprocal support. It does not score the displayed
`BF + inverted DF` image, compare against a prior detector composite/current
heatmap, subtract a matched same-design die reference, or consult a layout
template.

The `BF + inverted DF` panel is display-only. The signed reciprocal heatmap
shows the continuous raw reciprocal score, including weak nonzero response.
The top-10-percent panel applies a hard crop-relative p90 cutoff to that same
raw score. Therefore a Scratch segment can remain visible in the heatmap while
falling below the magenta cutoff.

The known-good die lines remain magenta because many are narrow, locally
symmetric structures that also produce a bright BF ridge and dark DF valley.
Signed reciprocity improves the target ordering but does not by itself
distinguish a non-repeating physical Scratch from repeatable product geometry.
Lowering the percentile threshold would worsen this false response and is not
authorized.

## Preserved evidence and authority

The unchanged diagnostic root is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R2`:

- `AUDIT.json` SHA-256
  `62E04175ACEFC56224E05B13964465BFF108FCD9EB10783D44F0572D80C33E01`;
- `T16_S238_RECIPROCAL_AUDIT.png` SHA-256
  `B32CB3DEAA0DC8D3FEC378ADC4702A5DDE1F770B6684F474436C99686B029F28`.

V17 M3, all source/current masks, V16, XML/production state, JBOD state, and
the strict chipout sibling remain unchanged. The R2 response is useful
diagnostic evidence only and is ineligible for mask promotion.

## Next action

Await operator direction before another diagnostic. The smallest justified
next test is still T16-only: retain the raw reciprocal BF/DF evidence, then
compare it with an aligned same-design structural reference so repeatable die
geometry can be discounted while non-repeating observed Scratch response
remains eligible. This must be a bounded structural-residual comparison, not a
broad null-die mask, scribe exclusion, inferred line, or lowered global
threshold. No such comparison has been started or authorized by this record.

Do not inspect stroke 278, change V17 masks, build or present V17, run raster
smoke, package JBOD, emit XML, enable production routing, or alter the strict
chipout sibling before further operator direction.
