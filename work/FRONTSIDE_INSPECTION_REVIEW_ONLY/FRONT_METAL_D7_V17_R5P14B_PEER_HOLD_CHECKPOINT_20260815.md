# Front-metal D7 V17 R5P14B peer-qualification hold checkpoint

Date: 2026-08-15

Revision: `FM7V17R5P14B`

Disposition: `DIAGNOSTIC_ONLY`

## Result

The first target-excluded composite attempt stopped before creating a BF or DF
reference because only two of the three available physical peers passed the
unchanged strict six-edge line-quality rule at all four distributed fiducials.

- S03 passed 4/4 BF and 4/4 DF sites;
- S18 passed 4/4 BF and 4/4 DF sites;
- S13 passed 2/4 BF and 3/4 DF sites.

No composite, T16 sheet, T17 sheet, response mask, or detector threshold was
created or changed.

## Exact S13 exception

S13 failed only because L02 retained 74/78 direct samples, or 94.871795%, at:

- S25 BF;
- S20 BF; and
- S25 DF.

In all three cases the four missing samples are isolated: maximum unsupported
gap is one pixel. Every other edge is complete. The L02 p90 response width is
1.75 px and the p90 fitted residual is 0.154842-0.273799 px. The complete
six-edge rigid RMS remains 0.131496-0.158132 px at those panels.

This is numerically the same 74/78, one-pixel-gap pattern already retained as
the operator-accepted, non-autonomous S26 BF L02 exception. It is not silently
extended to S13 by this diagnostic.

## Registration and topology evidence

The absolute seven-component PM identity and the independent BF/DF rigid
registration are otherwise unusually consistent:

| Peer | BF four-site rigid RMS | DF four-site rigid RMS | BF topology correlation | DF topology correlation |
|---|---:|---:|---:|---:|
| S03 | 0.063114 px | 0.072467 px | 0.998653 | 0.998626 |
| S13 | 0.045436 px | 0.058188 px | 0.998837 | 0.998656 |
| S18 | 0.112614 px | 0.126288 px | 0.998450 | 0.998062 |

The target remains excluded from every peer reference. BF and DF transforms
were fitted independently. The live target was not resampled. The separate
possible Argos stitch fault was not evaluated.

## File-backed operator gate

Review:

`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P14B/PEER_REGISTRATION.png`

The sheet is 2160 x 2050 pixels. It shows S26 independently for BF and DF for
each peer. Green is the accepted six-edge channel-local solution. The audit
contains all four sites and all six per-edge metrics for both channels.

The operator decision is whether the visually thin, coherent S13 solution may
retain the same bounded 74/78 L02 exception at the three listed panels. If
accepted, one fresh three-peer composite may be built without changing any
other gate. If rejected, the composite remains held because only two already-
available peers qualify and no additional completed FP2F4 peer wafer is
available in the current workspace.

## Provenance

- audit:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P14B/AUDIT.json`
  (`762E96AABA22C11BF713DE4CC55CB4EC1D3AFBFEA9AEA9A56D6F7CE0DF08843A`);
- registration sheet:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/analysis/FM7V17R5P14B/PEER_REGISTRATION.png`
  (`0EC93056C09023B09A0F2A80FE4482D7A2F24766452E4A921C7FE8355D536756`);
- input:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/FM7V17R5P14_INPUT.json`
  (`D634B553920C02530CECCA723A9EA51925AD3CF9BC06A1E123B4D2D4EF546B39`);
- source:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17QualifiedCompositeAuditV1.cs`
  (`1A2E37214A19F86265F250F9F13FD9C8C36120FEFF7680D11A518556F27F1F3D`);
- executable:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/tools/Build-FM7V17QualifiedCompositeAuditV1.exe`
  (`BB420E97985F7D4CD1BD747C617DB76A7D076AE490B6CE961E5EAFB75D346328`).

The earlier `FM7V17R5P14` and `FM7V17R5P14A` roots are stopped developmental
partials and are not authority. R5P14B is the bounded hold record.

Deferred stroke 278, saved feedback, masks, M3, V16, XML, JBOD, production
routing, and the strict frontside chipout sibling remain unchanged.
