# OCV-02 R18G development visual review — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`

After the four development outputs were frozen and pushed, exact BF/DF visual
review produced three correct outcomes and one OCR defect:

- POST2 Slot17 correctly holds because the installed oriented crop contains no
  visible scribe;
- 62620-548 Slot05 is exactly `L0751037FEA2`;
- 62624-855 Slot08 visibly reads `1478T161SUG7`, while frozen image-first OCR
  returned `14787161SUG7`;
- POST Slot22 is exactly `146XF113SUA5`.

Slot08 position 5 ranked `7` at appearance score `0.7116968125187093` and the
visible `T` second at `0.7039707517526532`, a gap of only
`0.0077260607660561`. The checksum diagnostic independently contains the
visible string, but `checksumUsedForGlyphSelection` is false. Correction must
therefore remain image-first and must not promote checksum into character
selection.

Visual gate SHA-256:
`6961A9423C10A4D12248EB7B8F1FE4761E457DEF975E7F3976BF43198D6E9538`.
Exactly four development pairs and zero blind acquisitions were read. Visible
strings remain review candidates, not accepted identities.

No republish, portal/JBOD action, provider activation, automatic reference
admission, hold clearance, training, XML, production, source, task/process,
queue, or wafer mutation occurred.

Exact next action: correct the image-first `T` versus `7` ranking defect using
glyph evidence only, then run the smallest local visible/blank regression
before opening any R18G blind crop.
