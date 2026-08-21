# Front-metal D7 V17 R5P1 peer-separation audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator authorized the bounded
T17 null-die peer-separation audit. It exposes the exact R5 peer contributions
for visual correspondence review. It does not accept or reject a peer, alter
the R5 composite, or create detector evidence.

## Scope and method

The audit is limited to `T17_F10_S254_TO_S258` and the unchanged target-
excluded peers `S03`, `S13`, and `S18`. It replays the exact R5 64-pixel local
integer-shift grids, channel gains/offsets, and common one-pixel joint BF/DF
neighborhood choice. It then displays, separately:

- target BF and DF;
- the S03 BF and DF contribution selected by R5;
- the S13 BF and DF contribution selected by R5;
- the S18 BF and DF contribution selected by R5;
- the resulting three-peer median BF and DF reference.

All panels remain native 1:1 before nearest-neighbor display enlargement.
All five panels within one channel share the same p1-p99 display stretch. The
yellow operator box is display-only and was not scoring input. There is no
resampling of scored/source pixels, new alignment, peer eligibility decision,
new composite, heatmap, threshold, mask, or raw-feature detector.

## Exact run

Path budget, continuity, and current-session safety passed. The exact
executable preflight passed before the output root existed with
`R5_ALIGNMENT_REPLAYED=true` and `MUTATION_PERFORMED=false`.

Implementation bindings:

- source SHA-256:
  `05DE31CFF0BBF9B680C6B6B429A283BDFA08814250C6690DF7B521EEDA451A97`;
- input SHA-256:
  `C20EF2A70CD87B35159FBDDD1F92745E9982CA91912ACB12B66C8A409D3C9E7E`;
- executable SHA-256:
  `A0E782ABC3B7D379B1451F16EFE16CDCB2836A3FB8020663C2A2EA0E0F97C924`;
- output audit SHA-256:
  `4B26A142C912C8B983577CD3D86F4E7952FF69C3AF65F5588EE48665BF42DD8C`.

The completed state is
`DIAGNOSTIC_ONLY_T17_NULL_DIE_PEER_SEPARATION` under
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P1`.

## Bounded metrics

The operator-box mean absolute BF/DF differences from the target are:

- S03: `14.3069 / 27.3799`;
- S13: `13.4320 / 25.6117`;
- S18: `13.1490 / 24.6622`.

These aggregate numbers do not identify the patterned-die ghost and are not
structural eligibility authority. The review question is visual and local:
which peer carries patterned-die structure where the target has a null die,
and whether that structure survives into the median.

## File-backed review sheet

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P1/T17_NULL_DIE_PEER_SEPARATION_AUDIT.png`
is 6468 by 1206 pixels, 2216390 bytes, SHA-256
`517A57E803E3A87C6F8E6FA7E4EDE59C8C94A0CC21C2293514B4AB4A110523E6`.

## Preserved state and next action

R5 and R5P1 remain `DIAGNOSTIC_ONLY`. The T17 reference remains
`HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED` until operator review. Stroke
278 remains deferred. Source/current masks, thresholds, M3, V16,
XML/production state, JBOD state, and the strict chipout sibling remain
unchanged.

Pause for operator review of the sheet. Do not reject a peer, rebuild the
composite, add peers, perform raw-feature scoring, tune/promote R5, inspect
stroke 278, build/present V17, run raster smoke, package JBOD, emit XML,
enable production routing, or alter the strict chipout sibling before that
feedback.
