# Missing Artifacts and Recovery Checklist

Inventory date: 2026-07-24

All artifact blockers for isolated targeted staging are resolved.

## Resolved authoritative inputs

| Artifact | Resolution |
|---|---|
| V2CT locked surface baseline | Canonical logical/package baseline is the V2CT render-only tool, notes, sample, and governing brief. Full extracted output not found and not required. |
| `latest_circle_fit_results.csv` | Present and accepted as authoritative same-lot AutoGeometryBootstrap geometry. |
| `edge_intrusion_segments_v6.csv` | Present and accepted as authoritative same-lot holder/notch prior geometry. |
| `notch_summary_v6.csv` | Present and accepted as authoritative same-lot notch seed. |
| Slot01/03/17 BF/DF images | `Slot1Slot3Slot17.zip` contains all six sufficient backside `resizedImage.bmp` working images and acquisition metadata. |

Bootstrap/prior markers and circle confidence near 0.621 are known accepted facts, not blockers. The geometry CSVs must remain unedited.

## Partial but usable artifacts

### V2CT

V2CT exists as a locked logical/package baseline; full extracted output folder not found in workspace. Do not substitute V2CR/V2CU/V2CW/V2CY.

### V2CX

Present:

- V2CX postprocessor package;
- six-row truth-lock feedback pack;
- analysis report naming 74 suppressed rows and six positive/action rows.

Missing:

- generated full 80-row truth table;
- generated 74-row suppressed-false/artifact CSV;
- full V2CX run directory and non-selected renders.

These full outputs are useful for provenance and later smoke-test comparison but are not permission to run the postprocessor now.

### V2DB/V2DC

Present:

- nested V2DB source package;
- nested V2DC source package;
- one V2DC residual-spike preview.

Missing:

- any prior V2DB run-output folder;
- any prior V2DC run-output folder, manifests, CSV results, and full preview set.

The supplied V2DC source is not approved for extraction, execution, or modification.

### Map/XML deployed-state evidence

The infrastructure document and processor/setup archives are present. Still missing or unverified:

- `Converter device setup.txt`;
- current deployed `C:\ArgosAuto\Move-ArgosXml-To-ShermanData.ps1`;
- scheduled-task exports;
- current production mappings, configuration, and templates;
- representative current mover/converter logs.

These are not V2DC algorithm blockers, but they are required before treating the map/XML document as a verified deployed-state record.

## Resolved since the original inventory

- [x] Browser-chat continuation supplied and read completely.
- [x] V2CT render-only tool and notes supplied.
- [x] V2CX postprocessor, analysis, and truth-lock feedback supplied.
- [x] V2DB prior source package supplied.
- [x] V2DC prior source package supplied.
- [x] Map/XML infrastructure notes supplied.
- [x] Three authoritative geometry seed CSVs supplied and hashed.
- [x] Six full-size working backside BF/DF samples supplied and declared sufficient.
- [x] Isolated work/scratch directories approved and created.
- [x] Copied inputs staged and targeted backside samples extracted from the copied archive.

## Remaining authorization checklist

- [ ] Explicit approval to create or modify full V2DC detector/package source code.
- [x] Explicit approval to create and run the isolated targeted contact-sheet harness.
- [x] Contact sheets generated with cyan expected edge, orange observed edge, gray tolerance band, and yellow accepted residual islands.
- [ ] Human acceptance of the contact-sheet results as the next V2DC design reference.
- [ ] Separate later approval for any build or package.

GUI launch, production XML, full-lot execution, training, and production packaging remain prohibited.
