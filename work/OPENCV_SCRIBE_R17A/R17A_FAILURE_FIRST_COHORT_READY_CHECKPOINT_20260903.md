# R17A Failure-First Existing-Crop Cohort Ready Checkpoint

Date: 2026-09-03
Revision: `OCV02_R17A_FAILURE_FIRST_EXISTING_CROPS_20260903`
Classification: `PENDING_GATE`

## Outcome

R17A freezes the first small failure-first scribe cohort from exact current-reader
state. It does not infer failure from an absent confirmation. The pinned signed
queue contains 966 frontside rows, of which 156 have no resolved wafer ID and
152 retain exact proposal plus BF/DF source paths. The cohort validator passed
against the previously signature-verified response ZIP without reading wafer
image bytes.

The selected remote cohort contains eight unresolved physical acquisitions:
four development and four blind-validation wafers. Four are from Post2. Across
the eight, the existing reader recorded all three detector-relevant failure
classes: no checksum-valid proposal, incomplete segmentation, and a bounded
image-supported proposal still requiring operator confirmation. The four
noncanonical-checksum identity-policy holds are intentionally excluded because
they do not retain the same exact crop-addressable proposal contract and are not
an OCR-development failure class.

## Input strategy

R17A pulls the already-created scribe inputs. For every selected acquisition it
requests only:

- `SCRIBE_PROPOSAL.json`;
- `scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png`;
- `scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png`.

This is 24 bounded files. No 475 MB full-wafer BMP is requested, no crop is
regenerated, and no notch result is required. Full-wafer images remain provenance
and escalation evidence only.

Development and blind-validation physical identities do not overlap. Blind
validation pixels must remain unseen until detector bytes are frozen. Two Post2
validation wafers deliberately measure within-regime transfer; R17A does not
claim lot-family independence, and the next cohort must include fresh lot-family
validation.

## Regression and arbitration

Every iteration retains the independently operator-confirmed misplaced Post2
Slot17 truth `6KB71041XDE5` and the four clear R16A controls. The existing
OCR-driven grid/topology path is preserved for difficult or displaced scribes.
A geometry-first clear-scribe path may be added alongside it. Agreement may
advance to confidence/checksum gates; disagreement holds; neither strong holds;
and no least-bad candidate selection or automatic identity assignment is allowed.

Confirmed sibling scribes from the same catalog lot may be used only as a
diagnostic vocabulary/ranking signal. They are not truth for a selected wafer,
because the signed catalog demonstrates heterogeneous confirmed strings under
some folder-level lot labels.

## Exact evidence

- signed audit response ZIP SHA-256:
  `229C9B649716BF37883563DCC16B4DC69C3285A7D5F8546EBB248F04F92574BC`
- queue SHA-256:
  `BB740FEA504FCA97E1AA98EAF03C65B348875CF325D8EB7A671A80A41C05BA81`
- catalog SHA-256:
  `DE957D63D512F90412B6DB59A7C982629183787811EC2D70190B9D07C366AA5B`
- confirmed overlay SHA-256:
  `FFB1F4D0084BDF198AFE66403F26B4405D2FC9F0C4F98489E0865F7E46F2EB10`
- cohort SHA-256:
  `EA15D1AE228DB1FD1307D2F4209D57C61572D192FFE1D807EDA3D2C00472499D`
- data-pull definition SHA-256:
  `3266EFC50A4517278512CC07C4D623D20483351C2DACDF83C226B3BA26665246`
- validator SHA-256:
  `431111146EC310EB78AABB06D39848E8BFBD929E2DF1E8E69AC2700A6F7FCA2E`
- local cohort gate SHA-256:
  `92AE770FD1EFA8C6C4475FA4D4D13C1EC2AE0753534BE99E3183AD67BB138D96`
- source/extraction path gate SHA-256:
  `F5CE30EBB7B849DC136195D53E635AE6260857DEA1AD06A4E8D7E6B8D4B81739`

The source path maximum effective length is 187 and the planned `C:\R17A`
extraction maximum is 172, both with 32 reserved suffix characters. Both pass.
The complete portal round-trip path gate, exact signing/package validation, and
fresh-output checks remain required before publication.

## Authority and next action

No request was built, signed, published, or executed. No JBOD state, source
image, queue, task, process, detector installation, identity, hold, XML,
training, or production route was changed.

Next action: after an explicit `PUBLISH`, build and gate exactly one review-only
R17A `DATA_PULL` request for these 24 files, publish it once with no retry,
collect its matching signed terminal response, then analyze the four development
crops before freezing detector bytes and opening the four blind-validation crops.
