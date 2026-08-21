# Front-metal D7 V17 bounded miss audit checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`

This is the continuation authority after the operator requested a short,
bounded look at the two unsupported Scratch additions before any longer
detection development. It does not supersede the passing V17 M3 classifier,
does not release a V17 reviewer, and does not authorize JBOD work.

## Governing state

- Project continuity resumed with
  `PASS_ARGOS_PROJECT_CONTINUITY`.
- Locked operator feedback remains
  `human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260815T002456Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
  SHA-256
  `1CB24A30C23BC3E92CDB568C32D453D506BE12DC7FC5D7D4E77773CF0F7E50DE`.
- The two bounded audit targets remain:
  - stroke 238, `T16_R03C00 / FIELD_09_3_3`, source box
    `(4293.494,7143.628)-(4312.542,7169.342)`;
  - stroke 278, `T21_R04C00 / FIELD_02_0_2`, source box
    `(3867.699,7613.301)-(3871.509,7617.110)`.
- Both additions remain operator guidance for observed-pixel recovery, not
  detector pixels or pixel-exact truth.
- V17 M3 remains byte-unchanged:
  - `EVALUATION.json` SHA-256
    `CB092E201A0E0C21AA4A74F868F69BE2FF1E70AC108A601310E85D8AA345FE6B`;
  - `MODEL.json` SHA-256
    `986A8FF4F859EBC8CC46CAB917A767463CE613183351D59FB7D72EDB25B5871A`;
  - `PREDICTIONS.json` SHA-256
    `3D34856FAD88EF65874355E1047CFC840FF2111965472256CB6B0385231B24EF`.

## Bounded diagnostic

Output root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R1`

The audit scores only the native 1:1 BF/DF pixels in a 96-pixel-margin crop
around each approximate operator box. The same four-orientation line-response
and local raw-residual calculation runs over every pixel in each crop. The
operator box is used only for audit metrics and the yellow display rectangle.
It is not rasterized into the candidate response. The diagnostic infers no
complete line and modifies no source or current mask.

Artifacts:

- `AUDIT.json` SHA-256
  `2FFC836E502026DFEAD4D205609C03C9EC039A0B74F478A0DAB44D3FF0020E55`;
- `T16_S238_AUDIT.png` SHA-256
  `44C891C61B746E9D40FB6919E21C3CE664DE16F4A964B36E581DD4A761AD3D94`;
- `T21_S278_AUDIT.png` SHA-256
  `62003BACA8946F346FA6AA4A32962D1E2FEAF03F7536149358CF75594FD94EBB`.

Tooling:

- source: `tools/Audit-FM7V17ScratchMissesV1.cs`, SHA-256
  `EA391A80A7F7F0EAD4A9EBB26F6EBD7D686F5B352476E9DD3C189F6D0F420CA1`;
- input manifest: `tools/FM7V17R1_INPUT.json`, SHA-256
  `54D60E4F30AE8904FBC3DD3C20A38D36D75499E60D7A6B8A5740D4B888A836F9`;
- executable: `tools/bin/Audit-FM7V17ScratchMissesV1.exe`, SHA-256
  `69070541A2BD9AEC7A6C876EDDA848389A55F1DC7A5C81512B379CEE77CDF127`.

The exact non-mutating preflight passed two targets, source hashes,
`2400 x 2000` native dimensions, output-root absence, and free-space reserve.
The verified `X:` alias maps to the canonical workspace with identical
`AGENTS.md` bytes. The complete path plan passed with maximum effective length
192 and maximum component length 64.

Two preflight-only executables are preserved as diagnostic failure evidence.
They created no output root. Their JSON-array CLR collection mismatch is now
recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`:

- `Audit-FM7V17ScratchMissesV1_FAIL1.exe` SHA-256
  `05676978DA3D11B13BE70085379810F4E72AC46357B3E18C6750716FD3B3D783`;
- `Audit-FM7V17ScratchMissesV1_FAIL2.exe` SHA-256
  `A75110FE508C999AFB23030DCA759FFF986AFAAAFDD0C736A4F39C4AA715439A`.

## Result

Neither target produces a clean high-ranked response under this quick method:

- T16 stroke 238:
  - crop source bounds: `x=4197, y=7047, width=187, height=220`;
  - target maximum response percentile: `0.940005`;
  - target p90 response percentile: `0.866290`;
  - target pixels at or above the crop p99.0/p99.5/p99.8 thresholds:
    `0 / 0 / 0`.
- T21 stroke 278:
  - crop source bounds: `x=3771, y=7517, width=198, height=198`;
  - target maximum response percentile: `0.897041`;
  - target p90 response percentile: `0.833692`;
  - target pixels at or above the crop p99.0/p99.5/p99.8 thresholds:
    `0 / 0 / 0`.

Therefore the fast raw line-response sweep is not eligible to recover either
miss. Lowering the threshold would admit stronger metal-pattern responses
elsewhere in the same bounded crops. No diagnostic pixels are promoted into
V17, no class counts change, and neither target becomes Normal.

## Next action

Pause for operator review of the two file-backed audit sheets. The operator
should report whether any of the three magenta threshold panels follows the
physical scratch, or whether the raw BF/DF panels show a different footprint.
The operator added that a bounded crescent response on the first few rows
around the scribe may be acceptable collateral if it is the known slightly
discolored and speckled die population and the two scratches become visible.
This is local review guidance only: it does not make the crescent a defect,
does not authorize a broad scribe-sector exclusion, and does not authorize a
global threshold relaxation.
Do not start a longer periodic-neighbor, multiscale, or component-recovery
study until that feedback arrives. Do not build or present the V17 reviewer,
run raster smoke, package JBOD, emit XML, enable production routing, or alter
the frozen chipout sibling branch while this feedback gate is pending.
