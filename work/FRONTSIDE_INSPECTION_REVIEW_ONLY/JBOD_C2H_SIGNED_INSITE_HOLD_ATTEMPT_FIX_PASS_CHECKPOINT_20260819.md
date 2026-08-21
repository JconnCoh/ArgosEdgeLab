# JBOD C2H signed Insite hold-attempt fix pass — 2026-08-19

Disposition: `PENDING_GATE`

## Signed live result

Fresh request `REQ_C2H2` returned matching signed response
`R_CFFB69FEB267_20260820042607507_9e4d8190` with terminal state
`PASS_MAINTENANCE_PATCH`. The installed
`Import-JbodLiveInsiteSnapshot.ps1` SHA-256 is
`05C77B7AFC4B2EB1931EA88D1970989920C5463268B6FBCD123040A3414B4F91`.
The signed-response gate is
`work/JBOD_INSITE_HOLD_ATTEMPT_FIX_C2H/C2H_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`9E7654FBE8EA0CA913C4E4040E9E52C7B3CDDD22C44F35C3EC570ED9AD5CE549`.

The result observed seven confirmed acquisitions for
`62631-586_20260819173317`, zero current hold rows, zero terminal holds, and
zero rows requiring forced rearm at install time. It changed no scheduled
task, deleted no source, aborted no wafer, and left XML export and production
routing disabled.

## Corrected queue contract

The prior importer advanced `attemptCount` only when response content SHA-256
changed. A new signed retry package containing the same unresolved lookup
evidence was therefore mistaken for a replay: the count stayed at one and the
next retry was moved six hours forward indefinitely.

C2H now identifies the exact resolved response package and records
`lastResponseAttemptId`. A distinct package advances the bounded attempt count
even when its payload bytes match a prior response. Reprocessing the same
package remains idempotent. The behavior rehearsal proved same-package replay,
two distinct byte-identical unresolved responses advancing to terminal attempt
three, exact-hold clearance after a qualifying response, bounded epoch retry,
and bad-response quarantine without queue-head poison.

The final package exercised both approved installed predecessors, idempotent
target acceptance, refusal before mutation for an unapproved predecessor,
rollback of both importer and hold overlay after an injected runtime failure,
and a later signed control request. Five response signatures verified. The
complete route evaluated 120 paths; the maximum effective length was 190 with
a 32-character reserve and the maximum component length was 51.

Final request ZIP SHA-256:
`A25C0B69DFFBD59905886D4A731A8936831EE3328753475632FEF52EA8D05D5F`.
Final-package gate SHA-256:
`723251734482DFD56BCE7A3EA01863ED9AE2D19CE2E6AB39F3457431856D4491`.

## Next prerequisite

Run a fresh signed full-consumer validation for lot `62631-586`. Require the
latest exact scan to agree across the catalog, route ledger, jobs, D-root
results, dashboard, inspection log, and Completed Lot, and prove no new writes
to the migrated C-root outputs. Preserve any remaining proposal-review,
metadata, notch, map, pose, or fiducial row as an explicit operator-visible
hold. Do not recover C duplicates or resume patterned-wafer scoring before the
lot gate is known. Review-only authority remains unchanged; no XML, training,
or production-routing authority is granted.
