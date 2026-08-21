# Front-metal D7 V17 R5P5 XML-fiducial projection checkpoint - 2026-08-15

Disposition: `DIAGNOSTIC_ONLY`.

Current phase:
`FRONT_METAL_D7_V17_R5P5_XML_FIDUCIAL_PROJECTION_REVIEW_PENDING`.

## Operator-proposed registration hierarchy

The operator supplied the intended general patterned-wafer hierarchy:

1. qualify the physical wafer notch and wafer pose;
2. use the product map to nominate the expected fiducial area;
3. find one specific image fiducial inside that bounded area;
4. require enough additional expected fiducials to prove that registration did
   not move by one die or one PM/null structure.

The fiducials repeat by PM, so they are not global wafer-pose authority. A
weak or absent fiducial must exclude the peer or hold registration; it must not
expand the search to another PM. The bottom scribe PM remains an expected-
absence exception.

## Recovered clone geometry

The exact V17 MES product is `1414010/A00`, family `3164-901`. The workspace
does not retain a `3164.xml` alias record, and the operator confirmed that this
product uses a clone map. The operator then supplied the exact map die size:
`1.24 x 0.96 mm`.

Twenty-four workspace templates have that exact `1240 x 960 um` device size.
They reduce to six normalized map signatures. The operator's imported-map
screenshot shows the `4/6/6/6/6/4` PM-row arrangement and paired long white
fiducial areas. That topology matches one six-template normalized geometry
group exactly:

- `3001`, `3002`, `3024`, `3025`, `3027`, and `3028`;
- normalized map signature prefix `DAF7B925DDFD`;
- `CENTER_DIE=(60,75)`;
- 32 Bin-34 `DS9K` locations;
- 32 Bin-36 `UPM` locations;
- every Bin-34 location has one Bin-36 partner at die offset `(+2,+1)`.

The exact historical 3164-to-clone product alias remains unresolved. R5P5
therefore uses representative `3001.xml` only as a geometry-equivalent visual
projection, not as XML, product, or production authority.

## Bounded visual projection

R5P5 projects the 32 paired Bin-34/Bin-36 areas from the qualified Slot02
wafer center and notch-bottom orientation. The initial map phase simply places
`CENTER_DIE` on the qualified wafer center. It does not perform image-based
micro alignment or select a die/PM phase.

The file-backed sheet shows:

- all 32 paired areas on BF and DF full-wafer display overviews;
- the T17 native BF and DF tile with every intersecting paired area;
- a native-source zoom of the first fully contained T17 pair;
- Bin 34 in magenta, Bin 36 in cyan, paired search areas in yellow, the T17
  tile in orange, and the already-known faint-feature crop as an orange dashed
  box.

Four paired areas intersect T17 under this initial phase. Source pixels remain
unchanged; display scaling is confined to the contact sheet. No detector,
reference composite, mask, threshold, M3, V16, XML, JBOD, production, or
chipout state changed. Deferred stroke 278 was not evaluated.

## Artifacts

- Input manifest:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P5_INPUT.json`
  - SHA-256: `D39491A6A312C7FFBBF3232C275B573573A8247316FF7CDF7890D2A354B74E30`
- Source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17FiducialCloneAuditV1.cs`
  - SHA-256: `75634688E44507F1EAD287457E2B192531712DF731D9E04022D3D91903CE1399`
- Executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/bin/Build-FM7V17FiducialCloneAuditV1.exe`
  - SHA-256: `945EB5F10EF8A0A9F4CC71D4A27BD299FFF7FAE7AF2B2C71E75CA6C7B1FB9844`
- Audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P5/AUDIT.json`
  - SHA-256: `B9D90EAB64284E455E7CF41E7FB4C3A523076296CF750AB390930C66F5653C1B`
- File-backed sheet (`2160 x 2341`):
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P5/FIDUCIAL_CLONE_FEASIBILITY.png`
  - SHA-256: `C83A278FA0F5B5EC7649B61DCF8703B27DD975EF9A9A752792F4D50D5B7415A2`

## Next gate

Pause for operator review of the R5P5 sheet. The immediate question is whether
the magenta/cyan crosses and yellow paired areas land on the actual fiducial
structures with one consistent small offset. If yes, the next bounded step may
estimate only that small residual translation and require multiple mapped
fiducials to agree. If the projection is wrong, correct only the clone geometry,
orientation, or initial map phase; do not search an adjacent PM or rebuild a
reference.

T17 remains `HOLD_STRUCTURAL_CORRESPONDENCE_NOT_QUALIFIED`. Do not rebuild the
reference, resume Scratch recovery, inspect stroke 278, change masks,
build/present V17, run raster smoke, begin JBOD work, emit XML, enable
production routing, or alter the strict chipout sibling before feedback.
