# JBOD D3A2 signed exact-set verification pass — 2026-08-19

Disposition: `PENDING_GATE`

## Outcome

Matching signed response `R_560CBEB53926_20260820002901447_431d3f30`
proves the post-copy verification passed. The C: source trees and D:
destination trees contain the same exact 93,709 relative files and
232,912,232,897 bytes.

- response state: `PASS_MAINTENANCE_PATCH`
- verification state:
  `PASS_JBOD_STORAGE_FINAL_DELTA_EXACT_SET_AND_HASH_EVIDENCE_D3`
- final verification terminal pass: `true`
- exact relative-path set: `true`
- per-file copy/hash evidence count: `93,709`
- source metadata stable after final-delta hash: `93,709`
- destination length stable after final-delta hash: `93,709`
- signed held-launch/result-manifest binding: `true`
- manifest launch delta: `962 ms`

Tree totals:

- cache: 1,444 files / 83,174,610,824 bytes
- metadata: 92,021 files / 149,443,376,410 bytes
- dashboard outputs: 244 files / 294,245,663 bytes

## Exact evidence

- request ZIP SHA-256:
  `8905FBF20C5682361ADB185CE042DB5DE0E8D876AFB21DA4A1BC7F33E898C2E2`
- publication gate SHA-256:
  `BCC5109EB4390CBD9611585396A933AB776F9C7EA344864D9621004FBD48811A`
- response ZIP SHA-256:
  `EFFCBD33FF6F4C2F2B2FFEA81F85141680A45116008C6F563A77BC0486745B24`
- response manifest SHA-256:
  `987689474F6A200D049B53427453DFA9309F0B441EBE8A06E9252D4A1ED8A838`
- response signature SHA-256:
  `5F08FDA7EB3EC51B1463EA84707A3C73E770066ADDD3EBECFBBE93CD1CDF4F72`
- response recovery route gate SHA-256:
  `0887CF3C103811766C0419F46F26FB781D5EA0E5F5F08B13A87079455B7B97CC`
- terminal response gate SHA-256:
  `8706F06E28D9EAA1B88E0DDE7F87257571CA2318BF5842E5DE5EE65E46F04BF8`
- collector SHA-256:
  `69347AF4D9BA303A665CBC43DE7AD823A950A7AA12D888AE7B0C8A3ED41E7A50`
- final-delta manifest SHA-256:
  `5C42EFF1431867076DC3F3DEE15FA0FB20A0B0C204C2AA38B5E5BDBCD0806DEB`
- current Windows failure-prevention memory SHA-256:
  `A15E11BB701C0BAEFB0A13807A793A9F4197E7FE637BF180EED5724A1AD0C0AB`

The initially planned `C:\A3S` laptop response root was safely refused because
it contained an older D2S3 response. No file was overwritten or merged. The
exact signed response was instead path-gated and extracted under fresh
`C:\A8S`; this supplemental route is bound to the exact response ID and ZIP
hash.

## Authority and next gate

This checkpoint allows preparation and gated application of C2A/C2B. It does
not itself cut over D:, delete any C: source, restart the tray, clear the hold,
change an inspection task, or abort a wafer.

Before C2A/C2B, re-read their exact current artifacts and reject any stale hold
heartbeat comparison, occupied output root, stale endpoint-worker pin, path
budget, wrapper/harness, predecessor, or queue assumption. After their matching
signed pass, validate real D: consumers and Completed Lot before any exact-
target C: recovery. Finally return to PFC004 fiducial work with six passes and
the Slot07 notch hold preserved.
