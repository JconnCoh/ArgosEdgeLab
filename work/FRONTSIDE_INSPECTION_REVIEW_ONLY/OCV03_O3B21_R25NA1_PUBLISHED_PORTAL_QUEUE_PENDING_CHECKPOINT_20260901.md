# OCV-03 O3B21 R25NA1 published / portal queue pending — 2026-09-01

Disposition: `PENDING_GATE`

The operator explicitly authorized `PUBLISH R25NA1`. One fresh review-only
package was built, gated, signed, committed, pushed, and published exactly once
through the recorded persistent `U:` Project Portal route. The request is
`REQ_20260901T153112935Z_6B71EECCA83C`; its exact ZIP is 45,761 bytes with
SHA-256 `A96E29988C4DC9DE3FF4495823409BA14A54E6138616A2D9E873A4EBB0461D0D`.
The signed request manifest/signature hashes are
`DB753D47AEA10C13642B4737FF6AFDE4097CB2DD5DDB29AB6A6587DA96369BD1`
and `2DFE139CCB16A8792A34A09622017ADFD932C5D0956276DDF40591F950DF09C7`.

The package contains unchanged R25/R13, the exact frozen 24-pair NA1 selector
and source contract, a create-new `D:/R25NA1` output root, no task actions, and
the same-bytes installed carrier. Its entrypoint verifies the 24 canonical
source records against SHA-256
`EF8A4DBB63A821AA4B1BE412910AFF316288DCE8239FBA287C9AD1396497AF93`
before image decoding, executes in lexical order, and stops only after the
first candidate satisfying the frozen both-channel 2.0-to-12.0-degree
holder-boundary rule or after all 24. It cannot relax the selector, clear a
hold, infer ordinal 23, authorize the 953 corpus, or grant later authority.

Publication gate `work/O3B21/R25NA1_PUBLISH_GATE.json` has SHA-256
`9E3DC7B7761BEEC28C8B2C52C2B484A7B26B7A39250AFC2DE56DBC6B1216D63E`
and records `publishAttemptCount=1` with automatic retry disabled. A bounded
response watch through 2026-09-01T15:54:07Z found no response manifest naming
the exact request. A subsequent exact queue check found the same 45,761-byte
ZIP still present at `U:/ProjectPortalRO/requests`; therefore the share importer
has not consumed the request. Queue presence is not endpoint execution proof.

This is the single exact blocker for this attempt. Do not republish, retry,
restart a task/process, open another route, change transport, or investigate
portal infrastructure under detector authority. NA1 and ordinal 23 remain
explicit holds. Fresh 953 and every later phase remain unauthorized.

Exact next action: wait for the unchanged portal importer and return path to
produce the matching signed terminal response for the exact request. If the
operator wants portal recovery or infrastructure diagnosis instead, that is a
separate explicit authorization.
