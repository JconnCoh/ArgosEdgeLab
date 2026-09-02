# OCV-03 O3B21 R34C953R2 direct exact-953 corpus running

Disposition: `PENDING_GATE`

R34 is the smallest conservative successor to R33. Its only detector change
allows the sole both-channel exterior-clean candidate pair to resolve a
pre-existing multiple-pair hold only when its unchanged finite R17 score is
strictly greater than every exterior-dirty pair score. Ties, missing or
non-finite scores, and a stronger dirty pair remain explicit holds. Candidate
formation, holder masking, angle logic, numeric thresholds, source identity,
and R33 local-prominence behavior are unchanged. Detector SHA-256 is
`3B3B9F6E461BC8F7C5498763A6ED9A46A404E55E5E3C69B10235C3489B3FF066`.

The exact JBOD composite gate passed state
`PASS_R34_COMPOSITE_141_SYNTHETIC_9_TARGETED_301_UNION_8_ROTATION` with
summary SHA-256
`89A2736EF6CAAFD9598CF632ADBE5CA0F1DA1AF9B04E20F411215536BE8A6D42`.
It contains 141/141 synthetic assertions, 9/9 targeted real-image cases,
301/301 union cases with zero outcome or invariant mismatch, and 8/8
rotation/holder executions. The targeted, union, and rotation summary hashes
are respectively
`F306E96974267144FC4C8B8CAE2D0FE607CB5BB932EA7B039E21262D6B274C2C`,
`E701395956FD51F08A5FFD2C855B3148A1703441804ABDB4AE602CCE1B82DD37`,
and `CFB1683EB083CC9259DDAF8B1F6057F1EF610CCFDC0826C1CBA0EC29A4410B16`.

The first fresh corpus namespace `D:/R34C953` is failed/no-replay. Its owned
PID 36444 exited before the first image with `Current discovery count changed`.
No summary or image result was produced. A first metadata observer namespace
never started and created no target output. Fresh metadata-only inventory
`D:/R34C953INV3/inventory.json`, SHA-256
`D6DF4E260A9B6B559B2A13ED4159F6DA7F3648E3CFABBF080F2171BB4D5D110C`,
then proved the current BACK inventory is byte-for-byte identical to the
frozen 978-pair inventory: 978 pairs, zero BACK source problems, zero added
rows, and zero missing rows. Therefore no selector or exclusion-set change was
made; the first failure was a transient discovery snapshot rather than a
detector or frozen-selector defect.

Fresh runtime `D:/R34C953R2RT` and output `D:/R34C953R2` were then created.
The R34 gate, exact current inventory, Python, selection wrapper, frozen R2
corpus runner, selection contract, R34 detector, and R13 configuration were
hash-pinned immediately before launch. Owned worker PID 15648 was created at
`2026-09-02T15:54:48.7853739Z`. Its first bounded observation passed at 11
completed pairs with zero failures, empty stderr, and the process still
present. The selected-corpus inventory SHA-256 is
`B2F7C2B2557FA27841216364CEF5ADF856A1CA7F97FC51AA7B764D42B73C5667`.

No source image was modified or deleted. No existing task or process was
acted on, no provider was activated, and no hold was automatically cleared.
Review-only remains true; training, XML, and production remain false. Allow
PID 15648 to complete without retry, restart, stop, or modification. At the
complete backside gate compare all exact 953 outcomes and preserve every
explicit hold, then continue automatically to applicable frontside BF/DF
acquisition, scribe, combined corpus/unified outputs, and fiducial/alignment
prerequisites in the recorded order.
