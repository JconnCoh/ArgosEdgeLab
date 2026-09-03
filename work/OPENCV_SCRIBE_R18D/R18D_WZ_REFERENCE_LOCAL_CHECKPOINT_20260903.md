# OCV-02 R18D W/Z reference local checkpoint — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`

## Operator confirmation and reference admission

- The operator explicitly confirmed the exact displayed candidates as `W` and
  `Z`. This confirmation authorizes only their labels in the local diagnostic
  glyph bank; it does not accept either wafer identity or grant training,
  activation, XML, production, or hold-clearance authority.
- The frozen R16A supplement remains unchanged at SHA-256
  `9F78AD34B8707DBB925AE5D569785FD5F67782B92E9FC35A664CD8887C63BBEC`.
- Fresh R18D extracts native 96×230 cells with OpenCV from the exact
  hash-locked BF detector inputs. The enlarged review PNGs are not used as
  reader references.
- `W` source identity `62633-726_20260818204139_Slot19`, position 5:
  source SHA-256
  `EF620DE8061FA1FD1585EC4CE39C95EAE2686E604ECF08D1E28F864BEF56F5AB`;
  native glyph SHA-256
  `618D64DB77382FB49E743D89035A845653D1DDE968C60F5891719BC297AA90C3`.
- `Z` source identity `62623-743_20260720111120_Slot04`, position 4:
  source SHA-256
  `DE2C242EB6AD0D188E071215D2065E44EDAE4DFE9B2FDD1FB21A03CB7BB77170`;
  native glyph SHA-256
  `7D218C7CC325B035CA88627ABA0F4D56A3D241A32C75F66AB3305C18DC644436`.
- Supplemental manifest:
  `work/OPENCV_SCRIBE_R18D/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json`,
  SHA-256
  `8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A`.
- Operator-confirmation record SHA-256:
  `E6298192D4C239A583D9538FCA7F408D2A2DE348816254BCAFED216AD9DBBF33`.
- The bank has eight supplemental references across `J/K/Q/W/X/Z`; `J/Q`
  retain independent validation and single-example `K/W/X/Z` remain
  provisional. Missing labels narrow from `I/O/V/W/Y/Z` to `I/O/V/Y`.

## Local integration and regression

- R18C image algorithm remains byte-for-byte unchanged at SHA-256
  `44654C1B3136F8BF93E84D93D272DA020D6C33E26E7DC5B66EF7F00D32518C17`.
- R18D diagnostic provider SHA-256:
  `39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1`.
- R18D exact-count/hash/authority loader SHA-256:
  `90859EAFB8996FA99B38DD048F57B1305454417A7D387D78F10F5F0361961430`.
- Completed full-image reference-integration results are:
  - `148AW103SUD5`, SHA-256
    `51C90E2F048384E5E86838B2C82FCB7DC47CBBBA66B3635E82C3A563DA907463`;
  - `147Z6157SUA5`, SHA-256
    `46B8C02DDECCAD4FDD3145170867354A083E4FB06EAFA5A39A01328CA2DE38CC`.
- These two outcomes prove the confirmed examples integrate correctly. They
  are self-reference development checks, not independent W/Z validation.
- Final local gate:
  `work/OPENCV_SCRIBE_R18D/R18D_LOCAL_GATE.json`, SHA-256
  `0E3D94DBA81B37C83667FE7AE61E17D06476DDC4B466F86C58502EA52471609D`.
- The gate passes nine additional known-visible exact strings and five
  known blank/wrong-location crops. Every blank remains below the frozen 0.60
  post-grid score floor and produces no string. The maximum blank score is
  `0.4153806639783699`.
- Checksum remains `VERIFY_IMAGE_FIRST_ONLY`; it cannot rewrite a glyph or
  select a hypothesis.

## Execution note

The first draft all-case harness completed the W result, then stopped on an
incorrect local Z cohort path. The path was corrected before any frozen gate.
A second draft run completed exact W and Z full-image results and was then
stopped deliberately before redundant full-image searches. The authoritative
finalizer used those exact hash-pinned results and frozen-grid/complete blank
regressions. No duplicate result counts as independent evidence.

## Exact next action

Select a fresh failure-first cohort containing examples not used to construct
the W/Z bank and run a bounded blind validation. Any independently observed
W/Z cases test generalization; unresolved `I/O/V/Y` examples remain explicit
coverage holds. Do not run the full KLARF directory yet.

Authority remains review-only. Provider activation, identity acceptance,
automatic reference admission, automatic hold clearance, XML, training, and
production authority remain false. No JBOD, portal, queue, task, process,
source-image, wafer, or hold state was changed.
