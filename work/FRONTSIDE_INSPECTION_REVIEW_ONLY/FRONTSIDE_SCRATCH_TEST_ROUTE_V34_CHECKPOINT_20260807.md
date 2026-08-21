# Frontside scratch-test route V3.4 checkpoint

## State

`PASS_V34_ROUTE_DELTA_IDEMPOTENT_REHEARSAL`

The JBOD had the faster V3.2.1 frontside native/reference-cache engine but
did not have the earlier V3.1 inventory and route integration. V3.4 is a
version-gated delta that adds only the missing exact frontside scratch-test
route/inventory pieces and preserves the installed V3.2.1 inspection engine.

This remains review-only, training-ineligible, XML-ineligible,
production-ineligible, and production-routing-disabled.

## Route and inspection contract

- Recipe folder names are not authority.
- Exact route authority is the validated sacrificial-nitride lineage recorded
  in the V3.1 checkpoint and read-only Insite acquisition context.
- The full-lot `62631-586` route response yields 18 qualified acquisition
  contexts; incomplete or ambiguous lineage remains held.
- Each target remains excluded from its own composite and requires at least
  two other physical wafer peers.
- Frontside scribe pixels are excluded before candidate formation and never
  become defects or bins.
- No frontside holder mask is derived from hardware behind the wafer.
- Scratch, Residue, Contamination, Particle, and Stain remain the enabled
  review-only surface classes. Frontside edge authority and HotSpot remain
  held/disabled as previously recorded.

## Installed-file and prerequisite gates

The delta installs six missing route/inventory files only. It requires and
preserves the exact V3.2.1 prerequisite hashes for:

- frontside scratch-test acquisition;
- frontside scratch-test worker;
- native physical eligibility;
- dual-branch frontside inspection.

Unknown prior hashes are refused. A currently active detector wafer may be
interrupted, quarantined, and rerun cleanly; the scribe reader is not stopped.
Validated automatic Insite response packages are replayed after installation
so exact scan-time context can qualify without depending on current WIP.

## Verification evidence

- Two-pass isolated installer root:
  `work/FRONT_JBOD_TEST/V34_DELTA_RELEASE_REHEARSAL_20260807T153700Z.V3_4_INSTALLER_TEST_ONLY`
- Qualified route rows after both passes: `18`
- Installed route file hashes exact: `true`
- V3.2.1 prerequisite hashes preserved: `true`
- Recipe-folder authority: `false`
- Extracted release validation:
  `PASS_V34_EXTRACTED_RELEASE_VALIDATION`
- Packaged ZIP:
  `work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_4_FRONTSIDE_SCRATCH_TEST_ROUTE_DELTA_20260807T153234Z.zip`
- ZIP SHA-256:
  `5F353627426AD6CA7354C4EAAD939A569E3383A3947658F84638A7B248D156B4`

## Required physical verification

Run `RUN_THIS_ON_JBOD_AS_ADMIN.cmd` from the extracted V3.4 folder on the
JBOD. The expected terminal state is
`PASS_V3_4_FRONTSIDE_SCRATCH_TEST_ROUTE_DELTA_REVIEW_ONLY`. Physical route
activation is not claimed until that result is returned and audited.

## Physical JBOD result

Physical installation passed at `2026-08-07T15:48:09.4238320Z` with state
`PASS_V3_4_FRONTSIDE_SCRATCH_TEST_ROUTE_DELTA_REVIEW_ONLY`.

- Installed route/inventory files: `6`
- Qualified lot `62631-586` acquisition rows: `18`
- Replayed automatic Insite responses: `3`
- Active verified metadata rows: `498`
- Processor, Insite worker, and Insite relay: running
- Interrupted wafer: safely quarantined and scheduled to rerun
- Exact V3.2.1 reference cache preserved: `true`
- Detector thresholds changed: `false`
- Scribe reader algorithm changed: `false`
- Review-only: `true`
- Training, XML, production, and production routing: disabled

`productionRoutingEnabled=false` governs outbound production result/XML
routing. It does not disable read-only Insite process-route lookup. The latter
is active through `INSITE_MOVEIN_HISTORY_BEFORE_EXACT_ARGOS_ACQUISITION` and
is the authority that qualified the 18 scratch-test acquisition rows.

## Observed processor activation

The JBOD monitor subsequently entered the frontside-only
`QUALIFYING_NATIVE_NOTCH_AND_SCRIBE_EXCLUSION` stage for lot `62631-586` and
advanced from Slot04 scribe `0737S074FEG6` to Slot05 scribe
`0737S075FED5`. This confirms that the qualified frontside scratch-test route
is actively being processed.

The 18 qualified acquisitions comprise two nine-wafer sessions:

- `2026-08-06T13:35:57` — 9 wafers
- `2026-08-06T15:21:40` — 9 wafers

Because the target lot was already running, no additional queue-interruption
hotfix was deployed.

## Network handoff

The exact ZIP was copied without overwrite and its destination hash was
verified at:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_JBOD_V3_4_FRONTSIDE_SCRATCH_TEST_ROUTE_DELTA_20260807T153234Z.zip`

## V3.4.2 frontside popup-side correction

The completed-lot selector was already correct and remains visually and
functionally unchanged. V3.4.2 changes only the generated image popup and the
invisible manifest fields it consumes:

- frontside sessions use explicit frontside composite-accepted BF, DF, and
  enhanced-display DF paths rather than the legacy backside compatibility
  aliases;
- frontside generated images say `FRONT` / `FRONTSIDE`;
- the popup retains exactly the two `Composite Accepted BF` and
  `Composite Accepted DF` tabs;
- a mixed frontside/backside scan session fails closed rather than pairing
  images across sides;
- backside popup behavior is unchanged.

The frontside contract was tested with all legacy backside compatibility
paths deliberately replaced by nonexistent paths. Catalog validation, UI
smoke, and two-tab popup smoke passed. The unchanged backside fixture passed
the same three checks. The installer passed both a fresh exact-prior rehearsal
and an idempotent extracted-package rehearsal. No detector, reference cache,
scribe, Insite, queue, XML, or production-routing behavior changes.

- Release validation: `PASS_V342_EXTRACTED_RELEASE_VALIDATION`
- Local popup tests: `6/6`
- ZIP:
  `work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_4_2_FRONTSIDE_POPUP_SIDE_FIX_20260807T161354Z.zip`
- ZIP SHA-256:
  `2E004D79E764A11C460D0ED892EC8187FE2F8F960F3C898B0DFDC0D6CB040CF8`
- Network handoff:
  `\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_JBOD_V3_4_2_FRONTSIDE_POPUP_SIDE_FIX_20260807T161354Z.zip`

Physical JBOD installation is not claimed until the returned state is
`PASS_V3_4_2_FRONTSIDE_POPUP_SIDE_FIX_REVIEW_ONLY`.
