# Frontside nitride scratch-test JBOD V3.1 checkpoint

## State

`PASS_V3_1_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY`

This checkpoint enables only the qualified frontside nitride/dielectric
scratch-test route. General patterned-frontside inspection remains disabled.
The work is review-only, training-ineligible, XML-ineligible, and
production-routing-ineligible.

## Route authority

- Exact process anchor: process block `SACRIFICIAL NITRIDE DEP {1}`, step
  `NITRIDE_DEP`, resource `6-4-CVD-02`.
- A same-block follow-on is eligible.
- After leaving the block, only an Eagle or LV150MM/LV1150MM inspection
  resource is eligible.
- Recipe directory names are not route authority.

The full lot `62631-586` read-only Insite snapshot contains 20 acquisition
contexts. Eighteen contexts are route-confirmed. Scribe `0737S071FEB3` has no
exact MES lineage/history and its two acquisition contexts remain held.

## Native detector and display contract

- Native source size: `14411 x 10995`; scored scale is `1 x 1` with no
  resampling.
- Frontside handedness: `flipImageHorizontal=false`.
- Each target is excluded from its own lot composite and requires at least
  two other physical wafer peers.
- The observed scribe row is excluded before candidate formation. A scribe is
  identity evidence only and is never a defect or bin.
- No frontside holder mask is created from hardware behind the wafer.
- Accepted defect evidence must remain inside the qualified physical wafer
  boundary. The accepted-hardware, accepted-scribe, and accepted-outside-wafer
  overlap gates are all exactly zero.
- Surface classes enabled for this checkpoint are Scratch, Residue,
  Contamination, Particle, and Stain.
- EdgeChipout, EdgeMicroDamage, and BevelDamage remain explicit holds because
  frontside edge authority is not yet qualified. HotSpot remains disabled
  because no examples exist.
- Human review uses exactly two sparse-overlay views: `Composite Accepted BF`
  and `Composite Accepted DF`.

## Verification evidence

- Slot23 native checkpoint:
  `work/FRONTSIDE_INSPECTION_REVIEW_ONLY/confirmation/FRONTSIDE_NITRIDE_DIELECTRIC_SLOT23_V2_20260807T001000Z`
- End-to-end coordinator result:
  `work/FRONT_JBOD_TEST/RUN_SLOT23_V7/JOB_RESULT.json`
- Installer rehearsal result:
  `work/FRONT_JBOD_TEST/INSTALLER_REHEARSAL.V3_1_INSTALLER_TEST_ONLY/hotfixes/V3_1_20260807T010646813Z/HOTFIX_RESULT.json`
- Packaged ZIP:
  `work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_1_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_20260807T010629Z.zip`
- ZIP SHA-256:
  `A0E2998FFD30EA83C83C76DB04F4729AD509A68DB6A8FCB2396BA5DD34D837CA`

The packaged installer was rehearsed against an isolated processor root. All
18 payload hashes matched, 18 qualified acquisition rows imported, and the
review-only, XML-disabled, production-disabled safety state was preserved.

## Network handoff

The package was copied without overwrite to:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_JBOD_V3_1_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_20260807T010629Z.zip`

