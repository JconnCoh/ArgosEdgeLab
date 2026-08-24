# OCV-00 OLS5 timeout post-failure observation — 2026-08-24

Disposition: `PENDING_GATE`

The required direct post-failure observation is complete. Exact signed
read-only DATA_PULL request `REQ_O5OBS1` returned terminal detail
`DATA_PULL source not found: OCV00_OLS5_FRONT_SOURCE_HASHES.json`.
Response `R_BBFC9922A3C5_20260824205146738_05fc36fc.ready.zip` is 1,611 bytes,
SHA-256 `A074800D4FDF37B8CC9DE6EC64572044BB80656F8906BB1F37933777B3FE4D09`;
the pinned JBOD signature passed.

The exact absent-output gate is
`work/OPENCV_OLS5/O5OBS1_SIGNED_ABSENCE_GATE.json`, SHA-256
`46F430F8C70B8AA63CA19FDE74F77CE83E9FBA191086150A32FCC4059E8586CF`.
The recovery observation is
`work/OPENCV_OLS5/O5OBS1_POST_FAILURE_OBSERVATION.json`, SHA-256
`936DAE7A1166B09218C6F3A523F057958904ADC9ACA1D0FB0945EFE5CAD16119`.

This proves that the 900-second OLS5 timeout left no promoted hash result.
OLS5 remains withdrawn and cannot be retried. The supported successor is a
fresh, bounded chunked hash workflow using the already proven provider-aware
stream, with two complete BF/DF slot pairs (four leaves, 1,901,519,496 bytes)
per request and five sequential requests for Slots 16-25. Each request must
finish and return a pinned signed response before the next is published.

No image was decoded and no image processing ran. The observation read no
image bytes and changed no installed code, task, process, source, processor,
wafer, or hold. Review-only, no-XML, no-training, and no-production boundaries
remain active.
