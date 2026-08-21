# Universal reference-admission checkpoint — 2026-08-07

State: local review-only implementation and regression checkpoint; not yet a
JBOD deployment package.

## Implemented safety change

`Invoke-JbodAllWaferInventory.ps1` now records and requires the exact
scan-time Insite context state and authority for detector admission.
`Invoke-JbodAllWaferProcessingPass.ps1` now:

- requires a human-confirmed canonical 12-character scribe;
- requires the last Insite MoveIn preceding the exact Argos acquisition;
- keys reference families by side/domain, product, revision, workflow,
  process block, and step;
- rejects the former BowComp same-lot/timestamp fallback;
- requires frontside peers to match both the exact lot visit and the verified
  product/process/step family;
- keeps every target out of its own composite; and
- applies the same context gate to Bare backside execution even though the
  current Bare detector does not consume a composite.

This prevents a wrong product, wrong wafer, reused slot, or legacy-font scribe
hold from entering any frontside or backside reference family.

## Regression evidence

`TEST_UNIVERSAL_REFERENCE_ADMISSION.ps1` passed with:

- 3/3 exact-context BowComp wafers admitted;
- 0/3 lot/timestamp-only BowComp wafers admitted;
- 3/3 exact-context frontside wafers admitted;
- 0/3 frontside wafers admitted when the three-wafer visit contained one
  wrong-product member and therefore neither family had two target-excluded
  peers;
- 1/1 exact-context Bare wafer admitted; and
- 0/1 unverified-context Bare wafer admitted.

The existing exact scan-time qualification regression passed, and the fixed
SEMI M12 vectors remained 19/19.

## Legacy-font finding

The portable reader already contains 156 human-confirmed legacy glyph
references from thirteen `62546_481` source-archive slot identities.  Those
references cover digits plus `A`, `B`, `C`, `D`, `E`, `F`, `N`, and `P`.
They do not cover `X` and several other generic letters.  The newer visible
`13HFX...` cohort therefore is not fully represented by the old legacy set,
even though its wafer imagery may come from the same historical lot number.

The operator-review count is acquisition-based, not physical-wafer-based.
Repeated scans of old wafers can therefore create many rows.  A slot-only
historical label must not be propagated to a timestamped acquisition: the
same lot/slot has already appeared with visibly incompatible 12-character
scribes, proving that lot and slot alone are not stable physical identity.

## Legacy-font reference propagation implemented

The acquisition-level correction is now implemented in the V3.5 review-only
hotfix.  The prior importer remembered a corrected acquisition identity but
did not propagate its independently confirmed glyph images to later reads.
That was the direct reason repeated old-font acquisitions continued to
produce the same proposal errors.

The new layer:

- harvests glyphs only from a canonical human-confirmed string when the exact
  acquisition's reader proposal was different or absent;
- crops the twelve cells from the saved complete V6 reader grid and records
  source-image, crop, response, acquisition, position, and SHA-256 provenance;
- excludes the exact acquisition from its own reference set;
- keeps slot-only legacy references separate from timestamped acquisition
  identity;
- retains a bounded, deterministic spread of at most 24 active variants per
  label so review history cannot grow into an unbounded reader workload;
- reevaluates one existing operator-review proposal per worker cycle using
  the saved oriented detector input, without rerunning notch localization;
- preserves every prior proposal and reader result in a timestamped revision
  audit before atomic replacement; and
- continues to require operator confirmation.  Checksum validity, a reader
  proposal, or a matching lot/slot never becomes identity authority.

`TEST_HUMAN_CONFIRMED_GLYPH_REFERENCE_PROPAGATION.ps1` passed with twelve
exact-acquisition references, twelve references available to a different
acquisition, exact self-exclusion, hash validation, and idempotent replay.
The package installer rehearsal passed with five exact target hashes and no
scheduled-task action.  The fixed SEMI M12 regression remained 19/19, and the
universal acquisition/reference regression remained unchanged.

Deployment artifact:

`ARGOS_JBOD_V3_5_LEGACY_SCRIBE_REFERENCE_PROPAGATION_20260807T214452Z.zip`

SHA-256:

`A077FD1B0DA52F6E2F9E9B2585D1A690F6A98080CE78DCC1C580D4609E66A932`

The installer stops and restarts only the scribe proposal task.  It does not
stop the detector or Insite tasks and refuses any installed predecessor hash
other than the exact expected V2.6/V2.9.1 sources.

All outputs remain review-only, training-ineligible, XML-ineligible, and
production-ineligible.
