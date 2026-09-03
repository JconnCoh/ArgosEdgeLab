# OCV-03 O3F15L4 DRAFT correction: synthetic pass, actual 978 pending

Date: 2026-09-03

Disposition: `PENDING_GATE`

The corrected DRAFT runner
`work/OPENCV_EDGE_NOTCH_O3F15L4/Run-O3F15L4FrontReconcile.py` has SHA-256
`EEE52358472C7B8086327C2B37E54BEDCE89BFF13154D6E3BD18EA9325F5FF99`.
The focused image-free test has SHA-256
`564DB7C7097A4965F6864B813B2889E1972CF54D3696F307B83200BE3B7C54A9`.
Frozen O3F14 and R11 were not modified.

The exact focused invocation passed 8 tests with 0 failures and 0 errors. Its
978 rows are machine-labeled `SYNTHETIC_978`; `actualFrozenCorpusClassified`
is false and actual classification counts are null. Executed coverage is
limited to Slot19/path boundaries, differing-path exact-hash stage handoff and
hash-mismatch rejection, Q wrong-target cleanup, preexisting-Q non-removal,
alias metadata/cleanup, and an isolated flat dependency-selection fixture.
The suite also executed the synthetic 1,956-source-leaf uniqueness, ordering,
per-class list cardinality, canonical metric, and planned alias metric
assertions.
Run-one timeout, cleanup-after-child, stdout/stderr preservation, final/partial
manifest salvage, safe job-path identity, and provenance bindings are labeled
`STATIC_SOURCE_COVERAGE`, not executed proof.

The runner now accepts an absolute, correct-leaf GATE path below effective 200
at any location, including the rehearsed ProgramData payload fixture, and
requires the identical runner SHA-256 at a flat fresh
`D:\O3F15*RT\Run-O3F15L4FrontReconcile.py` RUN stage. A successful Q creation
owns that mapping for cleanup even when after-create target verification fails;
the injected wrong-target case leaves Q absent and preserves unrelated
mappings, while a preexisting Q is never removed.

Machine gate
`work/OPENCV_EDGE_NOTCH_O3F15L4/O3F15L4_DRAFT_CORRECTION_SYNTHETIC_GATE.json`
has SHA-256
`8BA2205E7D29F18878D8670310A7CF059DF2B460A32E76CE34EC99EC3EB223E6`
and supersedes the overclaiming predecessor gate. Preaction contract SHA-256
`F6D595D23AD4BDA3EED3E0583082490A93711704FAC0454DCDBD23DC32366C38`
passed gate SHA-256
`18ED9273A268E2E0BF631B03570CAD91499DC79A9D13FA03D778A0D17AB38352`.

Actual complete frozen-corpus classification remains pending. It may be
claimed only from a later real `preflight_context`/GATE execution, whose
machine evidence must contain exact direct-safe, alias-required, and hard-stop
counts, 1,956 unique ordered source-leaf records, explicit deterministic
per-class leaf lists, and ordered identity/classification hashes. Each
alias-required or hard-stop leaf must include its planned alias metrics. This
checkpoint authorizes
no build, signature, publication, portal/JBOD/RustDesk action, operator input,
image read, source mutation/deletion, process/task action, provider activation,
retry, threshold/selector relaxation, or hold clearance.

All 184 frontside holds and all 12 current PatternedFront holds remain,
including Slot02 ambiguity and rare-hotspot Slot16. Review-only remains true;
training, XML, production eligibility, and production routing remain false.

Next action: stop locally and await separate explicit package authority. A
future authorized package flow must run the real pinned PREFLIGHT/GATE before
any RUN and must use the recorded signed Project Portal route without operator
input; no such action is authorized here.
