# OCV-02 R18E signed terminal collection checkpoint

Date: 2026-09-03

Disposition: `APPROVED_BASELINE` for exact returned read-only evidence only

R18E request `REQ_20260903T192241716Z_R18E` was published exactly once and
must never be retried or republished. Matching JBOD response
`R_D1D4956AA344_20260903194752479_47abca21` reports `PASS_DATA_PULL`.

Cryptographic and exact-content pins:

- response ZIP SHA-256: `72FA6467CC8DF2020B7D21027BCEFEFC50B93AA0035FD74DF6B4619498C747C2`
- response manifest SHA-256: `44079A8FA69F9BF7E3C239F9389278363F04E16EB206D8F56B06459BA76162C4`
- response signature SHA-256: `F7D1FF9A1B50848DC0442D06D6012C8EA8AB7E5D1E6E65619D983EF6725BD40A`
- result SHA-256: `6F684002DA901D2980883CC0D62CF257268FBFCD7D6AC861598661FBE770EB1C`
- payload SHA-256: `E419F20505881EF95D2399C42FD62DE39B884C879458E34AFB5D29FE5141EE62`
- terminal collection gate SHA-256: `9AD57983849DCBF7AAA3B021A9E5045C421456664A6A86E03EDE90AD6465B140`

The pinned JBOD certificate and standard response verifier passed. Create-new
collection produced exactly four outer response files under `C:\R18ER` and
exactly 24 hash-matching payload files under `C:\R18E`: eight proposal JSON
records plus sixteen paired BF/DF oriented scribe crops. Total source bytes are
26,073,436. No image pixels were decoded during publication, verification, or
collection.

Next action: verify exact frozen R18D provider, local gate, supplement, and all
returned source hashes; then run R18D on only the four development acquisitions.
Freeze those outputs before opening or evaluating the four blind-validation
acquisitions. Preserve blank/not-localized as no-string holds, use checksum only
to verify image-first candidates, and do not automatically accept identities or
reference glyphs. Missing `I/O/V/Y` coverage, independent W/Z validation, and
single-example K/X remain explicit holds unless this bounded evidence resolves
them. No full KLARF run, retry, activation, XML, training, production, task,
process, source, wafer, or automatic hold-clearance action is authorized.
