# OCV-03 O3B21 R28C953L1 inventory cardinality failure — 2026-09-01

Disposition: `PENDING_GATE`

The one authorized fresh-corpus launch request
`REQ_20260901T204837729Z_FE997FDF83C6` returned matching pinned-JBOD signed
terminal response `R_43247A7F250D_20260901205134388_9b20f910`, endpoint state
`FAILED`. Response ZIP SHA-256 is
`0D6E1729CD94D08FAC0B76FA7C5DA564A46C63A3A51B7AE28C1348B6B5CA9A34`.

The exact frozen package passed 33/33 detector tests and created its fresh
runtime and inventory roots. Its read-only BACK inventory then completed but
did not equal the frozen expected cardinality of 953, so the fail-closed guard
raised exactly `R28C953 pair cardinality changed.` The corpus worker was never
started and `D:/R28C953` was not used for image processing. No source image,
existing task/process, provider, training, XML, production, or hold state was
changed.

This executed signed artifact is terminal, withdrawn from reuse, and no-retry.
Do not guess the new count, broaden the corpus, or silently substitute the
current discoverable set for the frozen 953 identities. Before any later
corpus mutation, one direct read-only post-failure observation must return the
exact `D:/R28C953INV/inventory.json` cardinality and identity set. Mechanically
reconcile that set against the frozen R20 953 identity set and classify every
added, missing, or changed source identity. Only a separately authorized fresh
namespace may then launch the intended frozen-953 corpus.

The completed O23 gate remains passed. The notch-adjacent zero-control result
remains an explicit hold. Frontside, scribe, combined outputs, and
fiducial/alignment phases remain ordered after a complete backside corpus gate.

Terminal failure gate:
`work/O3B21/R28C953L1_SIGNED_TERMINAL_FAILURE_GATE.json`, SHA-256
`D00C728BC1A83CA485AB34AC52543409D6BA143C77D78B9638FF852B3F71EF22`.

Review-only remains true. Retry, selector relaxation, training, XML,
production, provider activation, source mutation/deletion, existing
task/process action, and automatic hold clearance remain false.
