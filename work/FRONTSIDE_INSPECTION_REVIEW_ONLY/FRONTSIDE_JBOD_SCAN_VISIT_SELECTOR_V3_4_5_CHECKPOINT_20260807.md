# Frontside JBOD scan-visit selector V3.4.5 checkpoint

Date: 2026-08-07

## Corrected operator contract

One table row represents one exact `lot + scanTimestampLocal` visit. FRONT
and BACK are not separate table rows. When both inspection-side sessions are
available for that visit, the row's first cell is a FRONT/BACK dropdown. The
chosen side selects the corresponding side-specific session for the existing
BF/DF popup.

The frontside and backside detector results, source paths, accepted masks,
and generated dashboard folders remain separate. This UI grouping does not
merge wafer records or inspection evidence.

## Regression result

- four catalog sessions representing FRONT and BACK for two timestamps group
  into exactly two visit rows;
- a catalog fixture with one FRONT session and one BACK session at one exact
  lot/timestamp renders exactly one row with `FRONT/BACK` choices;
- both choices generate independently named `_FRONT_` and `_BACK_` dashboard
  folders;
- catalog, UI, side-selector, and two-view inspection-window smoke checks
  pass;
- packaged installer replay passes from the installed V3.4.4 hashes;
- the dashboard manifest is unchanged;
- detector, scribe, Insite, cache, XML, and production-routing state are
  unchanged.

## Package

`work/STANDALONE_APP/packages/hotfixes/ARGOS_JBOD_V3_4_5_SCAN_VISIT_SIDE_SELECTOR_20260807T193434Z.zip`

SHA-256:
`B530A36EFEEA6521E7E32243FABF2D1C8153E9802135D0B9A2B1DF8D3A3EC8CD`

Verified network handoff:

`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ARGOS_JBOD_V3_4_5_SCAN_VISIT_SIDE_SELECTOR_20260807T193434Z.zip`

The package contains no images or credentials and remains review-only,
training-ineligible, XML-ineligible, production-ineligible, and
production-routing-disabled.
