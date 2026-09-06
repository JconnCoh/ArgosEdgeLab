# R18ZS Slot21 exact local checkpoint — 2026-09-06

Classification: `DIAGNOSTIC_ONLY`

## Outcome

The authenticated current Slot21 BF/DF pair now deciphers image-first as
`13HFX135SUE3` through the public multi-hypothesis provider chain. The selected
hypothesis is `BF / DARK / FORWARD`, has selection score
`0.9117836040446633`, is boundary-complete, and is checksum-valid.

This supersedes the wrong diagnostic `11HFX135SUE3`. A held wrong value was
not counted as success.

## Frozen generic evidence before Slot21

- Provider: `ArgosOpenCvScribeV1R18ZS.py`
- Provider SHA-256: `FD46B5F91189691A469B72EC29D8C07FA7FE0119950D24AD8FFD549AE01FF094`
- Development gate SHA-256: `707E6BB6B07DFAA68E9ABC2FC23F707D8977A560C223D0E176ACA9565AAF7CBD`
- 475/475 exact-lineage LOO queries evaluated.
- Accepted wrong: 0.
- Lost previously accepted-correct queries: 0.
- Harmed previously upstream-correct queries: 0.
- Generic upstream corrections: 5.
- Newly admitted sparse references accepted: 0.
- Slot/lot/truth/checksum exceptions: 0.
- New numeric thresholds: 0; the rule composes existing frozen topology,
  run-structure, appearance-deficit, appearance-leader, and reciprocal-margin
  bounds.

## Exact Slot21 evidence

- BF SHA-256: `96046D91BBD6DF81E678224525560BD9C77C0DC09DD89A25992B07F8D1213B93`
- DF SHA-256: `8DFD50AE1E0958CE01D7E32E0936978F157C2FECD0CB910BCC27DF9F7CE63CB8`
- Signed terminal checkpoint gate SHA-256: `AFE5D75B4ED250C961961A756A52B0BA8D46E50B336E9B11924CBCD9F6E1F335`
- Returned-file inventory SHA-256: `24B2629838E774938CF69D69EE7DD863413E29136145B56A2734FCAB16113E8F`
- Qualification state: `LOCAL_AUTHENTICATED_SIGNED_PULL_ORIENTED_DETECTOR_INPUT`
- Legacy proposal/summary paths or hashes synthesized: false.
- All eight BF/DF × DARK/BRIGHT × FORWARD/REVERSE views attempted: true.
- Retained evaluated hypotheses: 4; the other 4 were rejected by the unchanged
  pre-OCR structure gate as `HOLD_SCRIBE_NOT_LOCALIZED`.
- Full result SHA-256: `5E536BF3D03D2B6A98F5850F800FC3F50DC651D0A9B67A57B871A1ABC64BB8D9`
- Slot21 validation gate SHA-256: `C1CAEFF31D083CE5767FDD848E33C54BF15F5616BCD45BB20F39B615F8DB6753`
- Compact evidence SHA-256: `5A43560EA2D56882B65F9C2DFC7ED706C97937A26D435D56C4BB7CF755A551A0`

At position 2, appearance proposed `1`, while topology and ordered-run
structure independently proposed `3`. Their existing frozen margins passed the
generic reciprocal dual-structure rule. The unchanged R18Z envelope then
accepted `3` with normalized distance `0.8015045902144889`; no envelope
threshold was changed.

## Remaining holds and authority

The result-level state remains `SCRIBE_GLYPH_ENVELOPE_HOLD` solely because
position 3 (`H`) is outside all enforceable envelopes and position 5 (`X`) has
sparse reference coverage. These are conservative coverage holds; the exact
image-first string is not wrong or ambiguous.

Identity acceptance, reference admission, training, XML, provider activation,
production routing, and publication remain unauthorized and were not
performed. No portal/JBOD contact, repull, retry, source-image mutation, queue
or process management, or external detector activation occurred.

All patched provider bindings restored and the shared runtime lock was
available after the run.
