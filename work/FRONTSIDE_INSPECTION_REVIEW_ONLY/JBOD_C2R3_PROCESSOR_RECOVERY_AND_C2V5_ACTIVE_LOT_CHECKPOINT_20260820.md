# JBOD C2R3 processor recovery and C2V5 active-lot checkpoint

Status: `PENDING_GATE`  
Authority: review-only diagnostics and processing; no XML, training, production
scoring, or production-routing authority.

## Completed recovery

- C2W installed Insite worker
  `4F60B9C9D5AE3CC6EABE8983A6A27D5EB391D6101C07E94406CDD570748B02B2`,
  correcting the strict-mode read of absent optional
  `productionRoutingEnabled`.
- C2I4 replaced the stale resident bridge process and produced verified
  metadata coverage for all seven confirmed physical acquisitions in
  `62631-586_20260819173317`.
- C2V4 proved 14 metadata-matched catalog rows while also proving the resident
  all-wafer runner had not consumed the D-root overlay.
- C2R attempted the bounded all-wafer task refresh and returned signed terminal
  failure `R_2C5FF0DF0894_20260820050900952_276a760c`. Its exact stderr SHA-256
  is `EDFCC1F6A26C38F8137D0AF05FF89CF9C4DC8A699E3D44E24030F16860B83E7B`:
  the new runner exited immediately because it repeated the already-known
  strict-mode optional-property defect. The failure is withdrawn and recorded
  in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.
- C2R3 fixed the entry-point runner with absent/false/unsafe-true config-shape
  regressions and atomic-swap rollback coverage. Exact endpoint rehearsal
  exercised the old predecessor, target idempotence, unapproved refusal,
  runtime rollback, and a later signed control request.
- Signed terminal C2R3 response
  `R_C57E232B3681_20260820052535470_afeba1f7` installed runner
  `46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4`
  and started exact processor PID `14036` at
  `2026-08-20T05:25:25.4913680Z`. All 14 overlay-matched rows left
  `HOLD_INSITE_*`; six rows remain correctly held for three unconfirmed
  physical scribes. No protected task definition/principal, source wafer, XML
  output, or production route changed.

## C2V5 live lot validation

Matching signed read-only response
`R_F0A477265489_20260820053132943_4ab6321c` reports:

- lot `62631-586`, scan `2026-08-19T17:33:17`, 20 latest acquisitions;
- processor `PROCESSING` on
  `62631-586_20260819173317_Slot05__BOWCOMP_BACKSIDE`;
- 14 verified metadata matches, two job configs, one terminal/completed result,
  and one verified result file;
- zero invalid D-root output rows and zero post-cutover writes to the old C:
  output roots;
- D-root contract remains `D:\A2\o`, `D:\A2\d`, `D:\A2\c`, and
  `D:\A2\m\verified`;
- seven backside rows are admitted for BowComp method qualification; seven
  frontside rows remain explicit
  `HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED`; six catalog rows remain
  explicit scribe-confirmation holds.

The C2V5 disposition is
`PENDING_LOT_PROCESSING_OR_CONSUMER_REFRESH`, which is expected while the
processor is active. It is not an Insite-wait failure. Completed Lot/dashboard
counts remain zero until later terminal results are consumed.

## Required continuation order

1. Let the active review-only backside work reach terminal state; perform a
   fresh signed read-only lot validation before any exact C: duplicate recovery.
2. Preserve the three unconfirmed physical scribe rows as operator-visible
   holds. The Insite transport/retry/consumer issue is repaired for every
   confirmed acquisition.
3. Resume the patterned-frontside gate from the locked PFC004 fiducial workflow:
   operator-designated model, native straightened crop, axis-only line model
   with inner/outer arrow-corner ignores, automatic calibration, and multi-wafer
   validation. Do not bypass the frontside appearance/fiducial prerequisite.
4. Preserve Slot07 as a notch-review hold until native BF/DF physical-boundary
   evidence resolves it. Never select a notch by deepest indentation or fixed
   angle, and never let a thumbnail-only candidate establish pose.
5. Historical deterministic short-name remediation and final static
   cutover/Completed-Lot validation remain next-revision items as previously
   directed; do not mix them into active wafer processing.

Session safety is metadata-only `CHECKPOINT_ONLY_CONTINUE` at 218,037,193 bytes
(207.936 MiB). Continue file-backed and checkpoint-only; rotate before
268,435,456 bytes and do not produce image payloads in this task.
