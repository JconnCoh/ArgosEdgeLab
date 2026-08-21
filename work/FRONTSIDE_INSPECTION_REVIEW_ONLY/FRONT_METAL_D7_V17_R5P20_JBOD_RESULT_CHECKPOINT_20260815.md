# Front-metal D7 V17 R5P20 JBOD-result checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P20_JBOD_RESULT`
- Parent: `FM7V17R5P20`
- Disposition: `DIAGNOSTIC_ONLY`
- Returned state: `PASS_FM7P20_EVIDENCE_ONLY_DIAGNOSTIC_OPERATOR_REVIEW_PENDING`
- Integrity state: `PASS_FM7P20_RETURN_INTEGRITY`
- Alignment decision: `NO_FIXED_ALIGNMENT_ADJUSTMENT`
- Peer-qualification authority applied: no
- Masks emitted: no
- T16/T17 scored: no
- Detector, source, threshold, M3, V16, reviewer, XML, and production state changed: no

## Returned evidence

The complete return is
`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P20_20260816T001746Z`.
It contains the required `DIAGNOSTIC.json` and six PNG sheets.

- `DIAGNOSTIC.json`: 242377 bytes, SHA-256
  `9CA2A604A52426C8F5BD5BD0381E264B40555F2985DF3803DD8D5B8F7F447475`
- `BF_GATE_ACCOUNTING.png`: 59126 bytes, SHA-256
  `E4046D1DA4174AC58B41E06E53F58BB62489BCB843355F1F131CD0AE128A10B1`
- `DF_GATE_ACCOUNTING.png`: 60073 bytes, SHA-256
  `9D371F0CF5A4BBAD2DBE82BA12BA8552603B0B4D4BF3C80A1A67865A7889B451`
- `REGISTRATION_S20.png`: 1851580 bytes, SHA-256
  `AC97A34A903421336BCF299F45707B883D1A970D41830160098006002F7125AE`
- `REGISTRATION_S25.png`: 1852650 bytes, SHA-256
  `9353590D3D4F356488989059A087DC0082141660C6BB11A92DF0B34BF5CBBEFD`
- `REGISTRATION_S26.png`: 1872872 bytes, SHA-256
  `295EB16D386BC72D9B70039EDCAC896F68702AB9EC61FDD20513F6C5BF50FA13`
- `REGISTRATION_S31.png`: 1852234 bytes, SHA-256
  `32E161F939543D565926A7D4AFAABC979829099256665ABA77940408DE773821`

All six serialized sheet hashes and byte counts match the files. All 24 source
rows match the frozen contract hashes and byte counts at 14411 by 10995,
scaleX=1, and scaleY=1. All authority, feedback, incomplete-return, crescent,
recovery-ledger, pose-manifest, and accepted-registration-source hashes match
the frozen R5P20 contract.

## Gate-accounting result

R5P20 confirms the R5P18 diagnosis.

- BF: 577/4257 interior cells are globally ambiguous (13.554146%). After
  separating global ambiguity from peer-specific mismatch, eight peers are
  counterfactually whole-peer eligible: S13, S16, S18, S19, S20, S22, S24,
  and S25. The remaining counterfactual holds are 577 interior global-
  ambiguity cells plus 147 perimeter cells, 724 total.
- DF: 657/4257 interior cells are globally ambiguous (15.433404%). The same
  eight peers are counterfactually whole-peer eligible. The remaining holds
  are 657 interior global-ambiguity cells plus 88 perimeter cells, 745 total.
- Every non-globally-ambiguous interior cell reaches the frozen minimum local
  coverage of three in the counterfactual. The counterfactual maximum is eight
  peers in both channels.
- The result is diagnostic only. It confirms that globally ambiguous cells
  were incorrectly charged as individual peer mismatch, but it does not itself
  approve peers or change the legacy R5P18 hold.

S14, S21, and S23 remain geometry-ineligible under the unchanged direct line-
support contract. Every exposed failure is L02 and remains a local support-gap
hold:

- S14 BF/S31: support 0.961538, maximum gap 3 px;
- S21 DF/S31 and DF/S20: support 0.935897/0.974359, maximum gap 2 px;
- S23 BF/S26, BF/S20, and DF/S26: support
  0.935897/0.910256/0.923077, maximum gap 2 px.

No threshold or retained exception is changed.

## Alignment assessment

For the eight geometry-eligible peers, BF rigid RMS ranges from 0.053456 to
0.640013 px and DF rigid RMS from 0.052621 to 0.648460 px. Maximum site
residual is 0.951153 px BF and 0.971882 px DF, below the unchanged 1.25 px
rigid gate.

The mean residual vectors by site are strongly channel-consistent:

- S26: BF `(0.029968, -0.434082)` px; DF `(0.008362, -0.455627)` px;
- S25: BF `(0.273376, 0.144226)` px; DF `(0.272522, 0.158447)` px;
- S31: BF `(-0.295593, 0.357056)` px; DF `(-0.298950, 0.368530)` px;
- S20: BF `(-0.007874, -0.067993)` px; DF `(0.018677, -0.070862)` px.

The BF-versus-DF difference between corresponding residual vectors has a
median magnitude of 0.022814 px and maximum of 0.063982 px. This is coherent
wafer/site shape variation, not a BF/DF channel registration disagreement.

A bounded leave-one-peer-out test applied a fixed per-site target correction
estimated from the other seven eligible peers, then recomputed the unchanged
no-scale four-site rigid fit. It improved only 5/8 peers in each channel and
worsened S16, S24, and S25. S25 moved from 0.053456 to 0.402100 px BF RMS and
from 0.052621 to 0.403317 px DF RMS. A universal alignment correction would
therefore trade one valid wafer shape for another and is not justified.

Decision: preserve the current target frames and global no-scale rigid model.
Do not apply a fixed alignment-line adjustment. The operator-observed small
shift is real, bounded, channel-coherent, and already inside the frozen gate.

## Perimeter clarification and next bounded decision

The broader darker-green arc remains the operator-identified perimeter
crescent. It is distinct from orange global ambiguity and the thin extreme
edge. Nothing in R5P20 makes it defect truth, Normal truth, or an alignment
cue.

The next bounded engineering step, if authorized, is a fresh R5P21
qualification rerun with unchanged alignment and thresholds. It would apply
only the proven accounting correction—global ambiguity remains a local
coverage hold but is excluded from each peer's individual whole-hold
denominator—retain S14/S21/S23 as geometry holds, and regenerate spatial
coverage plus bounded T16/T17 evidence. R5P20 itself cannot provide that
authority.
