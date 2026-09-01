# OCV-03 O3B21 R25 NA1 cohort frozen / source-record schema timeout — 2026-09-01

Disposition: `PENDING_GATE`

One fresh exact-host probe passed JBOD `A1025645101` without mutation. A fresh
header-only read of hash-locked R20 `RESULTS.csv` then returned a matching
nonce-bound PASS and proved the exact metadata schema. A separate compact state
count also passed: 931 review-only unique-notch rows, 21 not-found holds, and
one channel-analysis hold.

Before any candidate identities were returned, the source-discovery selector
was frozen at
`work/O3B21/R25_NA1_LEXICAL_PASS_SOURCE_DISCOVERY_SELECTOR.json`, SHA-256
`DD642F800ED0C5140980348E13BCD5E06EA7730671360F3BDE0B39AE56ECBD31`.
It selects the lexical-first R20 pass metadata rows, excludes the exact 32
already-executed R25 identities, retains at most 24 distinct identities, and
uses no lot, slot, appearance, or angle preference. Its existing eligibility
rule remains exactly one paired candidate whose retained notch is outside all
excluded spans and 2.0 to 12.0 degrees from the nearest holder boundary in both
channels. Post-result relaxation remains forbidden.

The bounded 32-row metadata query passed without truncation. The deterministic
retained cohort contains 24 distinct identities, has zero overlap with the
exact executed R25 population, and is frozen at
`work/O3B21/R25_NA1_LEXICAL_PASS_SOURCE_DISCOVERY_RESULT.json`, SHA-256
`3F5BFABB7E8C9221D07537F07D26F8AA95F8C372DB353CAEFD3EB8C731534FAC`.

One subsequent 219-character read-only query attempted to return only the
property names of the first cohort member's existing R20 `RESULT.json`. Command
SHA-256 was
`9E1190FD828AEC64051BA930ADF233ACAAA22AC99DEF3B8EB118557F01864AF6`.
It terminated with the exact blocker `Timed out waiting for the exact JBOD
clipboard response after 60 seconds.` No nonce-bound result returned, and this
command namespace is withdrawn/no-retry.

No source image bytes were read, detector was executed, output root was
created, existing task/process was acted on, provider was activated, or source
or wafer was mutated. R25/R13 remain unchanged. The notch-adjacent eligibility
test has not been executed on the new cohort, ordinal 23 remains BF-unqualified
with two DF candidates, no hold is cleared, and the fresh 953-pair corpus plus
all later phases remain unauthorized.

Exact next action: stop this execution attempt. A future continuation may use
one fresh bounded nonce-bound observation on the recorded route to resolve the
existing source-record field names for the frozen NA1 cohort, but must not retry
the timed-out command namespace. Only after exact BF/DF source paths and hashes
are frozen may a bounded fresh R25 NA1 real-image run be designed. Ordinal 23
must still be resolved independently without angle, identity, slot, peer, or
appearance inference.

Review-only remains true. Training, XML, production, provider activation,
existing task/process action, source mutation/deletion, automatic retry, and
automatic hold clearance remain false.
