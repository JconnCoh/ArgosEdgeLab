# OCV-03 O3B21 R25NA1 signed timeout / post-failure observation blocker — 2026-09-01

Disposition: `PENDING_GATE`

The gateway ShareBridge recovery achieved its bounded operational purpose.
Fresh direct R25G1 verified the exact pending R25NA1 request and qualified
GWQ2 bridge/config hashes, changed only
`ArgosProjectPortal.Gateway.ShareBridge.RO` from `Ready` to `Running`, and the
unchanged importer moved the exact R25NA1 ZIP into `requests/processed` with
its original SHA-256. The separate response receiver was not changed.

R25G1's direct maintenance envelope is terminal `FAILED` because the frozen
manifest declared the rehearsal state while the production entrypoint emitted
`PASS_R25G1_CURRENT_REQUEST_SHAREBRIDGE_RESTART`. This mismatch occurred after
the authorized restart. R25G1 is no-retry and non-reusable.

R25NA1 traversed the full portal route and returned matching signed response
`R_4F03779373C2_20260901165154762_ff1dc2c1`. ZIP SHA-256 is
`2248CA852A00CCA9566DBBD3B316EC1E8FB584B18077D4B02347DE98C5ACA2B9`.
The pinned JBOD signature verifies terminal `FAILED`: the endpoint stopped
`Invoke-R25NA1.ps1` after its fixed 900-second child timeout. Stdout and stderr
are empty. R25NA1 is withdrawn/no-retry; its selector gate did not complete.

One recovery-policy-required direct post-failure observation was attempted
after the exact JBOD hostname probe passed. The bounded metadata-only command
targeted only `D:/R25NA1/J00..J23.json` and
`D:/R25NA1/O00..O23/RESULT.json`. It timed out after 60 seconds without an
exact nonce-bound clipboard result. That observation namespace is no-retry;
output-root existence, partial ordinals, and reusable partial evidence remain
unproved. No alternate route or successor is authorized in this execution
attempt.

Exact next action: stop. A future continuation requires one fresh,
separately authorized post-failure observation that proves the deterministic
R25NA1 output state before any mutation or successor design. Do not retry or
republish R25NA1 or R25G1, infer an eligible control from elapsed time or file
names, relax the selector, infer ordinal 23, or authorize the 953 corpus.

NA1, ordinal 23, frontside, scribe, combined outputs, fiducial/alignment,
training, XML, production, source deletion, and every prior explicit hold
remain unchanged.
