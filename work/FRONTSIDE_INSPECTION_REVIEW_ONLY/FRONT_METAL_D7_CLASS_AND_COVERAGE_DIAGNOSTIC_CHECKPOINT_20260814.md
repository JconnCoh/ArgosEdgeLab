# Front-metal D7 V7 class and coverage diagnostic checkpoint — 2026-08-14

## Disposition

Current phase: `FRONT_METAL_D7_CLASS_AND_COVERAGE_DIAGNOSTIC_RELEASED`.

Reviewer `FM7_V7_20260814T154000Z` is `RELEASED_REVIEW_ONLY`. It supersedes
the D6 presentation for the next operator review, while preserving D6 as its
file-backed source. D7 changes presentation and proposed subclass metadata
only. It does not rerun or retune the detector, alter accepted or hold masks,
change native component geometry, change the strict frontside chipout branch,
train a model, establish XML or production authority, run a full lot, or
create a package.

## Locked D6 operator response

The new save is locked at:

`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T145011Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`

Its SHA-256 is
`60544E6D21E959E156854FD5848C66B5D56E12B0DBC07D4EC453CB3C0A086845`.
The matching `SAVE_COMPLETE.json` SHA-256 is
`A9819E56A348280FDC055D0DAA1F826250CA01814A412085B5D3D1D590750A8B`.
The response contains 70 reviewed fields out of 98, 106 native-coordinate
strokes, and 22 nonempty field comments. It preserves the exact 88 D5 strokes
and adds 18: two missed Scratch strokes, fourteen Scratch
reclassifications, and two Particle reclassifications. The totals are 78
Scratch strokes and 28 Particle strokes. The 28 unreviewed fields are all in
`T22_R04C01`, `T27_R05C01`, and `T29_R05C03`; they remain unreviewed and are
not converted to Normal.

D5 remains a distinct prior locked input at
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260814T002521Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
SHA-256
`7E3E586F2CA7611935434932A93F74E5393C35ADD66553FE581A1F64A756D967`.
D4 remains strictly separate at
`human_feedback/ARGOS_CANONICAL_DEFECT_REVIEW_20260813T222605Z/ARGOS_CANONICAL_DEFECT_REVIEW_COORDINATES.json`,
SHA-256
`FD714DA87C377AD0AEFA5A646174BA54EF57B15B87205CF224F084B8A79D4476`.

## Reconciled display findings

The operator's observations were correct:

- the cyan quick swatch described only the active drawing tool, so selecting
  Particle did not enumerate saved Scratch guidance in the field;
- 19 comments identified component metadata with no visible heatmap because
  the class-specific confirmation layer existed but was disabled by default;
- three comments identified repeated darkfield views; for `T21_R04C00`, both
  inherited enhanced-panel URLs were byte-identical raw DF fallbacks.

D7 explicitly labels the quick swatch `Drawing tool only`, displays saved
operator Scratch/Particle counts separately for the active field, and adds
two file-backed 2400 by 2000 local heatmaps for each of all 11 tiles:
accepted physical-damage presence in magenta and holds in cyan/amber. All 22
heatmaps are unique and none is byte-identical to any raw DF source. The
unchanged D6 file-backed full-wafer accepted, held, class-hold, and evaluated-
coverage views remain available. No image bytes, Base64, data URL, or runtime
canvas serialization is embedded.

## Bounded automatic proposed class

`CLASS_RULE.json` records a conservative extreme-geometry diagnostic for the
197 already accepted physical-damage-presence components:

- propose `Scratch` when `AreaPx >= 144` or bounding-box major axis is at
  least 27 pixels;
- otherwise propose `Particle` when `AreaPx <= 26` or the major axis is at
  most 6 pixels;
- otherwise retain `SCRATCH_OR_PARTICLE` as a confirmation hold.

The D5 development cohort contains 94 directly labeled components: 66 receive
the correct automatic proposal, zero receive a wrong automatic proposal, and
28 are held. The independently reserved D6-new `T16` cohort contains 12
components: nine correct automatic proposals, zero wrong proposals, and three
holds. Across all 197 accepted components D7 proposes 86 Scratch, 46 Particle,
and 65 ambiguous holds. It promotes zero class-specific presence holds and
does not copy human labels directly as automatic class.

This rule is same-wafer and human-feedback-developed. It is a review-only
proposed-class diagnostic, not training, learned classification, independent
production validation, or authority to infer missed pixels.

## Coverage contract

The two new missed-Scratch strokes and all 22 comments remain staged coverage
guidance. They were not painted into detector masks or converted directly to
new pixels. Accepted-mask, class-specific-hold, and technical-hold pixel
counts are unchanged. Uncolored pixels are not Normal, and the 28 unreviewed
fields remain explicit review/coverage debt. A later native-pixel coverage
correction requires a separately bounded evidence rule and regression gate.

## Released artifacts

Root:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/outputs/review_only/FM7_V7_20260814T154000Z`

- `BUILD_RESULT.json`: `E2691FB223A8F6F28F79D9CF7A86CC328787018DAE8F27CB13A12F63A0472E14`;
- `REVIEW_MANIFEST.json`: `8C4BA5DB0962F57826A6F5D51094456FB8DF9BE75672CAFA196096D1680F72A8`;
- `D6_GUIDANCE.json`: `33768EC2F67A0AB7E6B5FB54A53A62012879C2DDAF378CAC37719DD0BA9551DF`;
- `CLASS_RULE.json`: `C52162EB628B2C86F7E55A37E18E969A540C3C67D29872D7D4954BCC6B9A1B2D`;
- `COVERAGE_AUDIT.json`: `39660CD844C839E67CFCB1224E8F811E92F6D955EFF96CA699B696B55E74FD68`;
- `PRESENTATION_AUDIT.json`: `81A632AC3D2647ACEAD634C127DA81ECBA6354E2F0914396E4E5751B3B4655AC`;
- `START_FM7.cmd`: `D40BACC2B9C286D94C198F246A33429BD9AF8FA74402641BC2F9F4FB31479A4B`;
- `START_FM7.ps1`: `7B9CF1AA0A3D90B724BE95A182B3FF31262A9EB762220965221D2851051C0084`;
- `FM7_INVOCATION.json`: `F81029EA82DC1E05583E228D530973417D0247D7C73D8DEF3911696127AED4C6`.

The output contains 81 files and 202,915,793 bytes. The complete path scan
passed at a 199-character maximum effective length. The canonical UI gate
verified 27 required controls, four actions, and byte-identical canonical
`styles.css`. All 113 unique manifest assets resolved. All 11 component-table
URLs target the D7-generated CSVs, with zero row/ID mismatches and zero changes
to nonaccepted component classes or frozen physical-evidence fields. The
wrapper static gate passed with no `%*` forwarding or `Start-Process` hop.

After the initial checkpoint was installed in the authoritative continuity
record:

- project continuity passed with all 12 D7 reviewer artifacts verified;
- the exact Windows PowerShell 5.1 launcher target preflight passed with
  `MutationPerformed=False` on port 8878;
- bounded HTTP requests returned 200 for health, page, the exact D7 manifest,
  and the exact D6 feedback; the served IDs were
  `FM7_V7_20260814T154000Z` and `FM6_V5_20260814T1500Z`;
- the direct test server process was identified by its port and explicit
  server command, stopped by verified PID 25968, and port 8878 was confirmed
  free;
- the final 82-path root-plus-children inventory passed at 199 effective
  characters, and all D4, D5, D6, strict-chipout-tool, and chipout-anchor
  hashes matched their distinct recorded identifiers;
- the metadata-only Codex task-size guard passed without reading session
  content; the largest recent eligible task was 8.059 MiB against the
  128 MiB warning threshold.

The strict frontside chipout tool SHA-256 remains
`900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`;
its anchor SHA-256 remains
`1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`.

## Withdrawn and diagnostic D7 roots

`FM7_V1_20260814T1500Z` through `FM7_V5_20260814T152500Z` remain
`DIAGNOSTIC_ONLY`. `FM7_V6_20260814T153000Z` is `WITHDRAWN` because its
manifest still loaded D6 component tables despite generating D7 CSVs. None
may be launched, presented, or reused.

## Next gate

The operator may review D7 V7 through `START_FM7.cmd`. The reviewer now shows
the corrected local heatmaps and bounded proposed Scratch/Particle classes.
The operator need not repeat already saved review work. The remaining 65
ambiguous accepted components, the two missed-Scratch coverage signals, and
28 unreviewed fields stay fail-closed. Further detector coverage work must be
separately authorized and validated. Training, XML, production, packaging,
full-lot execution, and chipout changes remain unauthorized.
