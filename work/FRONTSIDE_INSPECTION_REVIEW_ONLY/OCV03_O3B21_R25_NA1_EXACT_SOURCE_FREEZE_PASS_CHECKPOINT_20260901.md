# OCV-03 O3B21 R25 NA1 exact source freeze pass — 2026-09-01

Disposition: `PENDING_GATE`

The source-independent NA1 selector remains frozen before detector execution.
It retains 24 lexical-first R20 unique-notch identities after excluding the
exact 32 executed R25 identities, uses no identity, lot, slot, appearance, or
angle preference, and preserves the unchanged 2.0-to-12.0-degree both-channel
holder-boundary eligibility rule.

Fresh parent-source-record observations returned the exact BF/DF path, byte
count, and SHA-256 fields for all 24 members without reading image bytes. The
corrected 985-character aggregate command, SHA-256
`AF623755869AA26C11931C1443FD0A4AA9AFFCCD44CEF67F8D24BC595BF640FB`,
returned nonce `aaaa12c7a4d04f8c810f5ae87ee984bf`, count 24, canonical
JSON length 16,201, and canonical JSON SHA-256
`EF8A4DBB63A821AA4B1BE412910AFF316288DCE8239FBA287C9AD1396497AF93`.
The operator observed no red error on this corrected namespace.

Two predecessor aggregate namespaces remain withdrawn/no-retry. Their only
error was the discarded `Measure-Object` byte-sum diagnostic: ordered
dictionaries do not expose `bfBytes` or `dfBytes` as properties, producing
`GenericMeasurePropertyNotFound`. The corrected command removed only those two
invalid sums; source selection, record fields, serialization, count, length,
and canonical JSON SHA remained identical.

Machine freeze: `work/O3B21/R25_NA1_EXACT_SOURCE_RECORD_FREEZE.json`, SHA-256
`D3481DA814F8F64EC6027FC8B9482924BDE5A2C572530FA36D8511E0C0804971`.

RustDesk closed after the qualified nonce-bound response returned and the
operator reopened it. Cause is unknown and transport investigation is not
authorized; the completed response is unaffected.

No detector executed, output root was created, source or wafer was mutated,
existing task/process was acted on, provider was activated, selector was
relaxed, or hold was cleared. NA1 eligibility and ordinal 23 remain held. Fresh
953 and every later phase remain unauthorized.

Exact next action: design and execute only one bounded fresh R25/R13 NA1
real-image run over these exact 24 frozen pairs using the recorded working JBOD
route and a create-new `D:` result root. Evaluate the already-frozen selector
mechanically. Do not tune after results, infer ordinal 23, rerun completed R25
cases, or begin the 953 corpus.

Review-only remains true. Training, XML, production, provider activation,
existing task/process action, source mutation/deletion, automatic retry, and
automatic hold clearance remain false.
