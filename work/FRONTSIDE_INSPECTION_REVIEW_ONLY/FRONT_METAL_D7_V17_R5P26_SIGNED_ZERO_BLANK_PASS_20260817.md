# Front-metal D7 V17 R5P26 signed physical-domain pass — 2026-08-17

Disposition: `DIAGNOSTIC_ONLY`.

R5P26 corrects only the validity-domain defect exposed by withdrawn R5P25.
It is rebuilt directly from the operator-approved R5P24A source, not from the
withdrawn R5P25 output. The fitted S02 wafer disk with zero generic inward
inset defines inspection pixels. Integer-coordinate edge cells are included
when they contain at least one physical-domain pixel, and their route evidence
is sampled only inside that physical domain. Exterior rectangle pixels are
counted and rendered separately; they are neither unassigned inspection
pixels nor Normal truth.

The exact package passed its parser, Windows PowerShell 5.1 wrapper and
non-mutating build preflights, 179-character maximum effective path gate,
compile, deterministic physical-pixel and edge-cell self-tests, final-ZIP
extraction, signature verification, create-new, idempotent, unapproved-
predecessor-before-mutation, and exact dispatcher rehearsal gates.

Pinned package evidence:

- run ID: `FM7P26_20260817T210000Z`;
- locked parent source SHA-256:
  `5C97C5B9D62B2E064B99AE92BE23C97038E2829745FEC368081806C3A03E7726`;
- generated source SHA-256:
  `F950BB2DB7EF715515BA03AA548A538BCB3743801FED22C6D1161697EBAD22C1`;
- contract SHA-256:
  `699A0160122B633A4C1E29EB5E8A7688784A6BF490CCF3F97FA563E1E2595EE5`;
- package ZIP SHA-256:
  `AFAB59CC1D58B2A730B0EA9E01AAF72302D377F8535C21BD8FAC12824B66DA75`;
- signed request ID: `REQ_20260817T204725267Z_8DB916158795`;
- signed request ZIP SHA-256:
  `64A3D5F20024919B64615362587E0C799142134510B717B239560014032CA1D7`.

The JBOD returned pinned-certificate signed response
`R_5EC2BB36113F_20260817205025700_af1e15e7`, ZIP SHA-256
`9D7BAA1DC3F5535A11B7312651FADBD8F9B991FD2B9BBE65F05E25D17EF3F38D`,
manifest SHA-256
`32A2CE4C952ED70AC72F2850CD5F3FCE96324018FBE83364A75FB1E926E67389`,
and endpoint state `PASS_MAINTENANCE_PATCH`. Its exact stdout SHA-256 is
`7361FEEDDBEA06BB176B8E06C22B4097B4A48A13C7B8F38236BEA4F6BE2177ED`.
The run state is
`PASS_FM7P26_S02_11_FIELD_ZERO_BLANK_TARGET_EXCLUDED_RESIDUAL_COMPARISON_REVIEW_ONLY`.
It processed one S02 target, eleven target-excluded reference wafers, and all
eleven frozen native fields with zero skipped controls and zero unassigned
BF/DF inspection pixels. The JBOD audit SHA-256 is
`E0E6A30CCB66932A14611EF37C83D1922F0E41C4C7D5EF3C0121FDF8BAD71580`.
The short-source-alias sentinel read 1,048,576 bytes and confirmed
`ImageContentChanged=False`.

No old V16 mask or saved feedback was consumed by the detector. The emitted
residual is class-neutral
`CONFIRM_FRONT_METAL_TARGET_EXCLUDED_RESIDUAL` evidence. This pass emits no
defect or Normal outcome and grants no training, XML, full-wafer, full-lot, or
production authority.

Next action: retrieve the exact signed audit and result assets, independently
verify physical-domain accounting and raster hashes, compare the unchanged-
threshold residual evidence against the V16 masks and saved operator feedback,
then derive the review-only page from the locked BowComp canonical reviewer.
