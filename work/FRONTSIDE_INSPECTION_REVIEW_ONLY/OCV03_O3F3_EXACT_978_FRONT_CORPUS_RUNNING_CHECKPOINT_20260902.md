# OCV-03 O3F3 exact-978 frontside corpus running

Disposition: `PENDING_GATE`

The R35 exact-953 backside gate is complete. O3F3 now runs the unchanged,
already-qualified full-circumference frontside R7 engine at
`C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03CorpusR1/FullPerimeterWaferTopologyOpenCvR7.py`,
SHA-256 `A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B`.
No detector threshold, configuration, pattern suppression, candidate selector,
or production/provider setting changed.

The exact-front selection wrapper
`work/O3F1/Run-FrozenFrontCorpus.py`, SHA-256
`EDD263C7A530AE12D8C963EFC60DD3F3B1A95DCF2A88440F823C32FE7C671499`,
passed all five focused local identity/path/cardinality/source-problem controls.
Its transfer passed an exact Windows PowerShell 5.1 decompressed-SHA rehearsal
and reproduced the same hash at `D:/O3F3RT/Run-FrozenFrontCorpus.py`.

O3F1 and O3F2 are terminal/no-retry initialization artifacts. O3F1 created
only `D:/O3F1RT` before an ambiguous PowerShell 5.1 compression-constructor
failure. O3F2 created only an empty wrapper and copied frozen runner under
`D:/O3F2RT`; its returned wrapper SHA was the empty-file hash. Neither reached
inventory, decoded an image, started a worker, or changed a source/provider/
task/process/hold/authority state.

The O3F3 inventory-and-start command SHA-256 is
`82A4456C0689DC2319DF82794F9D724B4969BEDAB7EF5A927737C4A1B86D4D20`.
It discovered exactly 978 FRONT BF/DF pairs with zero source problems and froze
their exact identities and paths in `D:/O3F3INV/inventory.json`, SHA-256
`7320331752A094F51C44F713A9C644AB41A059B0226DE0F8E0BD8E1D0ABCA056`.
Only after that gate passed did it start owned worker PID `35628`, created
`2026-09-02T19:35:46.3829568Z`, under fresh `D:/O3F3C978`.

This execution is frontside notch acquisition only. The frozen R2 harness
records `HOLD_SCRIBE_ENGINE_NOT_CONFIGURED` because the separate scribe stage
has not begun; those rows are not frontside-notch outcome failures. Evaluate
the `notch` stage independently. Preserve the three POST2 O3P8 passes as
development evidence and retain rare hotspot Slot16 as an explicit hold if
the normal R7 method remains unresolved. Do not tune after seeing corpus
outcomes without a fresh frozen targeted design.

Allow PID 35628 to complete without retry, restart, stop, or modification.
Observe only atomic progress/terminal metadata, then reconcile every frontside
notch hold and any changed state before proceeding automatically to scribe.
Review-only remains true; training, XML, production routing, provider
activation, source mutation/deletion, existing task/process action, automatic
hold clearance, and hotspot extrapolation remain false.
