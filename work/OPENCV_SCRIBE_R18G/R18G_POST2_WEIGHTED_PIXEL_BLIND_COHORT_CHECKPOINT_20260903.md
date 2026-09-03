# OCV-02 R18G POST2-weighted pixel-blind cohort checkpoint — 2026-09-03

Classification: `PENDING_GATE`

- The pinned 966-row scribe identity queue was read as metadata only; its
  SHA-256 remains
  `BB740FEA504FCA97E1AA98EAF03C65B348875CF325D8EB7A671A80A41C05BA81`.
- All 24 exact acquisitions previously selected by R17A, R18A, and R18E were
  excluded mechanically. The remaining eligible unresolved population is 128.
- R18G freezes eight fresh current-reader failures across seven lot families.
  Both remaining eligible POST2 acquisitions are included. The other six
  cover one additional POST context, one segmentation-incomplete failure, and
  four checksum-invalid failures.
- Development and blind-validation partitions were frozen before any new
  scribe pixels were transferred, decoded, or inspected. Exact acquisition
  overlap with every prior cohort is zero.
- Cohort manifest SHA-256:
  `91A367581F02709301A03D972E7A96C68FC1371A33DC7E13B02997442220E2BA`.
- Exact 24-file existing-crop DATA_PULL definition SHA-256:
  `D38269F2D4C04D6EC130E616800AFFDBC70835DF62CC35117625A3A0EED29C72`.
- Selection gate SHA-256:
  `980A86CEF6CCD2324EAD4CD3297ACF1E10B1A9C20559EB7A3F9020650E8D3B6F`.
- Planner SHA-256:
  `A40E736F3025727C7EAFA2926F0ED13E424AC71F582A8105F7D1D471EA2EA9B0`.
- Frozen R18F remains unchanged. Missing reference labels `I/O/V/Y` remain
  explicit coverage holds. Checksum remains downstream verification only.

No portal or JBOD contact occurred. No image bytes were read. Review-only is
true. Identity acceptance, automatic reference admission, activation,
automatic hold clearance, XML, training, production, source mutation, task or
process action, and full-corpus execution remain unauthorized.

Exact next action: build and locally gate one fresh signed R18G `DATA_PULL`
package for these 24 existing files. Do not publish it unless the operator
explicitly says `PUBLISH` for R18G. One publication maximum and no retry.
