# Frontside Slot01 chipout preservation regression — 2026-08-12

## Outcome

The frozen strict frontside physical-edge branch was rerun at native resolution
against the operator-specified Slot01 source in `Slot1Slot3Slot17`. The known
large chipout beside the manufactured notch was retained with geometry and
evidence values identical to the frozen checkpoint. All 22 previously reviewed
non-damage edge/noise controls remained suppressed.

This was an edge/chipout-only preservation test. The front-metal surface branch
was not invoked or changed. No review images were generated.

## Provenance

- BF source SHA-256:
  `D03C10550401B3AC2AFE42CC066E192DA9CC8D3FFC8F1E2497FA9C7C39CA5052`
- DF source SHA-256:
  `C1759B44CE9D7ACA18D87413D10936578A67D35C018A0D646A78C45AFE5AA536`
- the specified `Slot1Slot3Slot17/Slot01` BF/DF files are byte-identical to the
  staged sources consumed by the frozen detector;
- scored dimensions: `14411 x 10995` in both channels;
- scored scale: `scaleX=1`, `scaleY=1`;
- no resampling before scoring.

## Frozen implementation

- tool:
  `tools/Run-Post2FrontsideStrictEdgeBevelRescanV1.mjs`
- tool SHA-256:
  `900881A6AA5E43690D77B780C93279F47980E013738DCEEA6BD71486BDFA6366`
- frozen anchor manifest SHA-256:
  `1387FA98A6D66A2ED492ABAD776CAAC6AE05FCF7DDE351FE488A2B9B514FAE99`

## Fresh bounded rerun

- output:
  `outputs/review_only/POST2_FRONTSIDE_STRICT_EDGE_BEVEL_RESCAN_V1_SLOT01_PRESERVATION_20260812T040000Z`
- state: `PASS_REVIEW_ONLY_STRICT_EDGE_BEVEL_RESCAN`;
- positive control retained: `true`;
- reviewed negative controls suppressed: `22/22`;
- output footprint: 5 JSON files, 0.599 MiB;
- final manifest SHA-256:
  `9250E2F5E0C5074A4C82674606EBE9705F76613243CFD6F8F9006FA14A43F193`;
- Slot01 result SHA-256:
  `C144F218F565714E35B68B98EC1A376545077272EEC6E024486BC06FC6CA1FF5`.

After removing only the fresh timestamp and two new null pose-metadata keys,
the complete Slot01 result is byte-exact to the frozen Slot01 result.

## Known notch-adjacent chipout

- center angle: `85.50363964412367` degrees image;
- arc length: `339.9993285566643` px;
- maximum BF inward displacement: `171` px;
- maximum DF inward displacement: `269` px;
- independent BF/DF physical support: `0.6205882352941177`;
- outside-dark-corridor support: `0.47058823529411764`;
- notch veto: `false`;
- qualified: `true`;
- disposition: `CONFIRM_EDGE_CHIPOUT`.

The chipout is therefore still active as an independent physical-boundary
finding. Surface scratch/residue tuning cannot suppress it.

## Authority

Review-only, training-ineligible, XML-ineligible, and production-ineligible.
Frontside bevel remains a separate confirmation-only class.
