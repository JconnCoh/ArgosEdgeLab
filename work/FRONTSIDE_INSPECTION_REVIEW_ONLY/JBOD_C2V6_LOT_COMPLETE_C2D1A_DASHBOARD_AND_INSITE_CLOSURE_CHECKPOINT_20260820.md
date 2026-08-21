# JBOD C2V6 lot completion, C2D1A dashboard, and Insite closure

Date: 2026-08-20

Disposition: `RELEASED_REVIEW_ONLY`

## Authoritative result

The short-D-root storage cutover, review-only processor reactivation, current
Insite admission repair, and incremental Completed Lot refresh are now proven
by matching signed terminal responses. This checkpoint does not authorize XML
export, training use, production scoring, production routing, source deletion,
or bypass of any scribe, appearance, notch, map, pose, or fiducial hold.

## Lot 62631-586 terminal D-root validation

Signed read-only request `REQ_C2V6` returned terminal response
`R_65B258069509_20260820054220693_429f35f9`. The verified terminal gate is
`work/JBOD_LOT_VALIDATE_C2V6/C2V6_TERMINAL_RESPONSE_GATE.json`, SHA-256
`D6DA336C4A91C33FAF9C1AC8E34589DEA1E58B351D81848AB1FEBDD405275ADD`.

For scan `2026-08-19T17:33:17`, it proves:

- 20 latest acquisitions;
- 7 completed ledger rows, 7 terminal rows, 0 held rows, and 0 failed rows;
- 7 verified result files and 7 valid job configurations;
- correct active roots `D:\A2\o`, `D:\A2\d`, `D:\A2\c`, and
  `D:\A2\m\verified`;
- 0 post-cutover writes under the retired C-root outputs;
- 6 explicit `HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR` rows and 7
  explicit `HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED` rows remain
  unrecorded by design.

The six scribe holds and seven frontside appearance holds are not Insite
failures and remain operator-visible prerequisites.

## Insite wait closure

The exact retry-attempt defect was corrected by C2H. Its signed terminal gate
is `work/JBOD_INSITE_HOLD_ATTEMPT_FIX_C2H/C2H_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`9E7654FBE8EA0CA913C4E4040E9E52C7B3CDDD22C44F35C3EC570ED9AD5CE549`.
The importer now distinguishes exact signed response-package attempts while
remaining idempotent for replay of the same package.

The active-runner stale-overlay defect was corrected by C2R3. Its signed
terminal gate is
`work/JBOD_PROCESSOR_RUNNER_FIX_C2R3/C2R3_TERMINAL_RESPONSE_GATE.json`,
SHA-256
`FE8FCD5CAA29F51100263AFCA0D9C868C7252C75F7928CF12837BD9288AF85F2`.
It reduced 14 metadata-matched `HOLD_INSITE_*` rows to zero and preserved all
six scribe-confirmation holds. C2V6 independently confirms that no current
route state for this lot is an Insite hold.

## Incremental Completed Lot root-cause patch

The installed processor previously wrote one durable completed ledger row per
wafer but refreshed `dashboard_manifest.json` only after the entire bounded
processing pass. A long pass could therefore leave valid completed results
invisible in Completed Lot while later wafers continued processing.

Local draft `REQ_C2D1` is `WITHDRAWN` and was never published. Its exact local
endpoint gate correctly rejected target-hash idempotence because the draft
omitted the target hash from `allowedInstalledSha256`. No JBOD or share state
was changed by that draft.

Corrected `REQ_C2D1A` passed both approved installed predecessors, target-hash
idempotence, unapproved-predecessor refusal, injected-failure rollback, later
control advancement, incremental-placement behavior, Windows PowerShell 5.1
path boundaries, the 125-leaf complete route, and exact final-ZIP extraction.
Its final ZIP is
`work/JBOD_DASH_REFRESH_C2D1A/final/REQ_C2D1A.ready.zip`, 13,402 bytes,
SHA-256
`E0A20EA8FBECE0E50126F694889E1C0EB62BC8B3DE422E4D9F694B79693C4D90`.
The final package gate SHA-256 is
`F3657674C872826CF8EC897C31844D086BD97F3B71FA18AB887C37FCBC72C68B`.

Matching signed response
`R_574D35BC7CC1_20260820055854141_6b67d049` installed processing-pass hash
`0B063D452CA76AE5EE3EC1BDF6726853259039683C36E208718B8FE937D23753`
and preserved dashboard-updater hash
`CEEC6828CD50E2903DEE2CBD442721EED39206E2DC216902437306D93770469F`.
The verified terminal gate is
`work/JBOD_DASH_REFRESH_C2D1A/C2D1A_TERMINAL_RESPONSE_GATE.json`, SHA-256
`D464A037C3ABC8C035795C3540D774F16EA82150DDC1289DC87D7AFC35E70BED`.

The live endpoint refreshed 62631-586 to exactly one dashboard session, seven
Completed Lot wafers, and 35 verified artifact paths. The processor remained
`PROCESSING` on exact identity
`62630-465_20260818084011_Slot01__BARE_BACKSIDE` before and after the refresh.
The dashboard-failure marker is absent. No tray or inspection task was
restarted, no wafer was aborted, and no source was deleted.

Future completed ledger commits invoke a bounded non-fatal dashboard refresh
immediately after the atomic ledger write. A dashboard rendering failure is
recorded without aborting inspection, and the end-of-pass refresh remains as
an idempotent reconciliation pass.

## Frontside continuation authority

PFC004 designated-fiducial qualification is already terminal and must not be
reopened. The authoritative checkpoint is
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/PFC004_TERMINAL_PASS_AND_STORAGE_MIGRATION_GATE_20260819.md`,
SHA-256
`54A4AAFDF7ADF8D0BEB5C2DC2D22282D70D981F912826C6D2F429882D6E8FEAD`.
Six of six pose-qualified wafers pass the locked crosshair model, Slot09 uses
the bounded DF recovery, and Slot07 remains a notch-review hold.

The remaining geometry action is the fresh-task FS15 direct-native notch
regression for the implemented V3 engine. Historical-output deterministic
short-name remediation and static cutover regression remain explicitly
deferred to the next revision as the operator requested. They must preserve a
signed source-to-result mapping and must pass the full route path budget before
the first write.

