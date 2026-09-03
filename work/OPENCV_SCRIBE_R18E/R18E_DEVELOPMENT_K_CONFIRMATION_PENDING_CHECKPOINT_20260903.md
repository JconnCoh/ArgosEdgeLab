# OCV-02 R18E development / K confirmation pending checkpoint — 2026-09-03

Classification: `PENDING_GATE`

## Frozen development results

- Frozen R18D provider SHA-256:
  `39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1`.
- The development runner read exactly four predeclared development crops and
  zero blind acquisitions. Runner SHA-256:
  `1AC53DC99C7DAA793F647C169308FB0BF9846AE3CF1A30D700C762DFC15010A0`.
- Repository development gate SHA-256:
  `E62F8BEDBB96DB0A186402DF32547A7A2BA14F7BFE70A8E6CEF1A7F67FD12911`.
  It byte-matches the gate written by the completed development run under
  `C:\P2COHORT\results\R18E_R18D_DEVELOPMENT_20260903A`.
- `62633-726_20260818204139_Slot20` is visibly
  `148AW102SUG6`; R18D reads it exactly. This is an independent W validation.
- `62627-098_20260729105955_Slot16` is visibly
  `1480J017SUH0`; R18D reads it exactly.
- `62625-907-PRE_20260709123021_Slot14` is a blank/wrong-location
  crop; R18D correctly returns no string and `HOLD_SCRIBE_NOT_LOCALIZED`.
- `62546-481-POST_20260713041740_Slot22` is visibly
  `13DCK060SUF5`; R18D returns invalid `11DCR060SUF5`. Localization and the
  12-cell grid are correct. The two OCR defects are position 2 `3 -> 1` and
  position 5 `K -> R`.
- Mechanical M12 verification, performed only after the visual read, proves
  `13DCK060SUF5` has expected check characters `F5` and remainder zero.
  Checksum did not select or rewrite either glyph.

## Bounded arbitration experiment

- The position-2 topology rank is unambiguous: `3` score
  `0.9861172576606678`, margin `0.12457148115551986`, while appearance chose
  `1`. R18D's frozen margin floor `0.15` alone prevented the override.
- One local in-memory candidate lowered only the topology margin floor to
  `0.12`; no provider file was changed. It changed Slot22 only from
  `11DCR060SUF5` to `13DCR060SUF5` and passed all nine frozen visible strings
  plus all five blank/wrong-location controls.
- Candidate gate SHA-256:
  `1BFDDE7FA915E7D7BB60894C947CAF85B8DB80B4205D0ECA3C5A9ABDC78AE8C2`.
  The reused regression detail byte-matches frozen R18D local gate SHA-256
  `0E3D94DBA81B37C83667FE7AE61E17D06476DDC4B466F86C58502EA52471609D`.
- The position-5 `K` cannot be fixed by the margin change: the existing
  single-example K ranks twelfth by appearance and is not topology-first.
  This is a reference-generalization failure, not localization, checksum, or
  grid selection.

## Operator review gate

- OpenCV-only review builder SHA-256:
  `F1814B83C9ABDCAFC00728E4D36FED76EB284CEC0F82ABCE18AF397BE6969D80`.
- Exact marked context:
  `C:\P2COHORT\results\R18E_SLOT22_REVIEW_20260903A\SCRIBE_CONTEXT_MARKED.png`,
  SHA-256
  `F610E5B442AD6762636A93F81B7DA610CEF951DF4402FCE27691CAD4339167C4`.
- Native position-5 K candidate is the exact 96x230 cell at `(795,268)`,
  derived from source SHA-256
  `3D41F41B0E6F99940ED8C7243DE665FC063EDB4A8408A442C3EDBDD844E40F18`.
  Enlarged review candidate SHA-256:
  `1E51DE9B3E0DF3DBE6E253A470A55EC47F223DFB89DD6D8DF12A4D86104619D5`.
- Review manifest SHA-256:
  `A2C4DD9A96E55FE34C3FEA8A464B5CC89E8B50BB83081B86747A8F43B6DB2A08`.
- Repository analysis SHA-256:
  `88DE5491246661133134BDA9DF76148BB1DD70946DAE3C45FB70DA959893CB0B`.

## Exact next action

Obtain the operator's explicit confirmation that the boxed position-5 glyph
is `K` in visible string `13DCK060SUF5`. If confirmed, build fresh R18F with
the generic `0.12` topology-margin correction and one operator-confirmed
native K reference, then rerun the complete frozen visible/blank regression
and this four-case development cohort. Freeze R18F before opening any of the
four blind-validation acquisitions.

No K reference has been admitted yet. R18D remains byte-for-byte unchanged.
R18E remains no-retry/no-republish. Review-only is true; activation, automatic
reference admission, identity acceptance, automatic hold clearance, XML,
training, production, JBOD, portal, queue, task/process, source-image, wafer,
and detector-family authority remain false.
