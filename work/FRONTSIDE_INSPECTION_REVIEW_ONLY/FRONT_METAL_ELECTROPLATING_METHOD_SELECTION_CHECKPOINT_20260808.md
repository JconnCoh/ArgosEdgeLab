# Front Metal electroplating method-selection checkpoint

State: `HOLD_SELECTOR_NOT_YET_QUALIFIED_REVIEW_ONLY`

## Operator identification

The operator identified the patterned frontside wafers currently under
development as **Front Metal electroplating** material. This is a distinct
frontside appearance family. It is not Scratch Test, BowComp, Bare, or a
generic patterned-front family.

No JBOD detector package or route change is authorized by this identification.

## Required method selector

The future method key is:

`FRONTSIDE_FRONT_METAL_ELECTROPLATING`

The selector must be based on process authority, not image appearance:

1. exact confirmed 12-character wafer scribe;
2. exact acquisition timestamp and frontside handedness;
3. read-only Insite history resolved for that scribe at the acquisition time;
4. an approved product/revision plus process-lineage rule showing the required
   Front Metal electroplating move completed before the scan; and
5. no conflicting product, step, lot/slot, or acquisition lineage.

Recipe-folder names, `POST2`, wafer color, metallic brightness, and visual
similarity are not selector authority. Appearance admission may raise a
mismatch hold after metadata selects the family, but it may not grant the
family.

Any missing, ambiguous, or conflicting input emits:

`HOLD_FRONTSIDE_METHOD_UNQUALIFIED`

## Current saved metadata evidence

The saved read-only snapshot
`MES_SNAPSHOT_62546-481_62624-803_62624-869_20260731T162500Z.json`
records lot `62546-481` as:

- product/revision: `1414010 / A00`;
- product type: `VCSEL-6`;
- process block: `SEED REMOVAL`;
- step: `AVI_PD_GREYSCALE`;
- operation: `INSPECT_AUTO`;
- resource: `5-5-RUDOLPH-01`;
- spec: `PS6_WF_AV0_AVI_PD`.

This establishes a saved inspection/WIP context and a set of human-verified
lot/slot scribes. It does **not** establish the prior Front Metal
electroplating transaction responsible for the surface. The selector remains
held until exact scan-time history supplies that predecessor and the operator
approves the resulting rule.

The operator clarified that `INSPECT_AUTO` and `AVI_PD_GREYSCALE` are
measurement steps used to verify that the Front Metal process completed
properly. They are downstream inspection context only and are never sufficient
to assert that Front Metal is present.

## Process-lineage selector candidate

The supplied Insite history example contains the authoritative process
signature before the Argos acquisition:

- operation: `FRONT_METAL_ELECTROPLATING`;
- process block: `P-METAL ELECTROPLATING`;
- step: `ELECTROPLATING`;
- resource: `6-6-PLATE-01`;
- transaction sequence includes `MoveIn`, `DataCollection`, and the later
  standard move recorded before inspection.

The future selector must require a **completed** qualifying electroplating
sequence before the exact acquisition timestamp. A `MoveIn` alone is not
completion authority. The resource must belong to an operator-approved Front
Metal plate-tool allowlist; a broad string match on `PLATE` is not sufficient
until the tool list is approved. The first evidenced candidate tool is
`6-6-PLATE-01`.

A later metal-removal or rework event that can invalidate Front Metal presence
must be evaluated before granting the method. Missing completion, ambiguous
ordering, lineage conflicts, or an unapproved plate resource remain
`HOLD_FRONTSIDE_METHOD_UNQUALIFIED`.

Front Metal presence and photoresist state are separate material-state axes.
The operator explicitly identified the completed `PLATING PR STRIP` transition
after the qualifying electroplating event as `RESIST_REMOVED`. It changes the
resist state but does not remove or invalidate the deposited Front Metal. A
qualifying Front Metal history without a later strip event is only a
`RESIST_PRESENT_CANDIDATE`; absence of a strip row is not positive production
authority for resist presence. Missing or ambiguous history remains
`HOLD_RESIST_STATE_UNQUALIFIED`.

The first bounded correlation controls are operator-declared no-resist lots:

- `AVI_PD_GREYSCALE`: `62626-046`, `62626-010`, `62625-899`, `62626-991`;
- `AVI_0`: `62613-847`, `62616-080`, `62621-592A`, `62616-094`,
  `62619-451`, `62618-307`, `62551-820B`.

The read-only history diagnostic is frozen under
`work/MES_INSITE_READ_ONLY/front_metal_resist_history`. It checks exactly
those lots for the electroplating anchor, the subsequent `PLATING PR STRIP`
transition, and the stated scan-stage context. It does not modify Insite,
detectors, tasks, XML, training, or production state.

## Appearance/reference subfamilies after selection

Front Metal may remain present across multiple later process steps and may
look darker or brighter at those steps. Therefore process lineage selects the
common detector family, while the reference/composite key remains narrower:

`product + revision + scan-time process block + scan-time step + material side`

The resist state is an additional required key once qualified:

`product + revision + scan-time process block + scan-time step + material side + resist state`

Wafers from different scan-time steps or different resist states must not be
mixed into one composite merely because both have Front Metal. The target
wafer is always excluded from its own reference. `AVI_PD_GREYSCALE` and
`AVI_0` remain separate reference cohorts until the same frozen detector is
shown to transfer without loss.

Appearance admission is a secondary consistency gate. A visual outlier is
still inspected, but it is held from contributing to the accepted composite.
Appearance alone never selects the Front Metal method.

## Detector taxonomy clarification

The operator clarified that the underlying detector/model truth is
`FrontMetalPhysicalDamage`. Bright physical damage on the metal may be long,
short, compact, round, or stamping-like. Those morphologies must not redefine
the general Scratch visual class.

Keep these concepts separate:

- physical detector class: `FrontMetalPhysicalDamage`;
- optional morphology: linear/scratch-like, compact, round, stamping-like, or
  unknown physical-damage morphology;
- downstream operator bin: `Scratch`.

Thus a compact bright event may be binned as Scratch without teaching the
general model that scratches are inherently compact or round. Long-line
geometry is supporting morphology evidence, not a mandatory
physical-damage-presence gate. A supported event whose morphology remains
uncertain may emit `CONFIRM_FRONT_METAL_PHYSICAL_DAMAGE`; it is not Normal.

The detector must still distinguish repeating die/metal pattern brightness
using target-excluded native BF/DF evidence. Ambiguous events may be presented
as native-resolution BF/DF close-ups for operator categorization. Those
confirmations are review-only references; they do not authorize training,
XML, production decisions, or JBOD deployment.

## Gate before any JBOD package

1. finish the native BF/DF marked-positive and marked-false detector
   regression for Front Metal;
2. collect exact read-only scan-time Insite history for the confirmed scribes;
3. write an explicit allow/hold route table for product, predecessor process
   step, and resource lineage;
4. obtain operator approval of that table;
5. test qualifying and nonqualifying controls with fail-closed outcomes; and
6. run the exact packaged installer rehearsal required by `AGENTS.md`.

Until all six gates pass, the Front Metal method remains development-only and
must not be installed on the JBOD.

HotSpot is expected to be important when resist is present, but it must be
enabled only under a positively qualified `RESIST_PRESENT` route. A
no-resist method may not silently serve as the resist method, and the same
resist/no-resist separation applies to every future frontside or backside
inspection family where resist changes the visible surface.

## Live route-evidence and image-availability result

The signed live Insite correlation confirmed ten development controls with
the same process sequence:

- `P-METAL ELECTROPLATING / ELECTROPLATING`;
- exact plate resource `6-6-PLATE-01` (10/10 qualifying MoveIn rows); and
- a later explicit `PLATING PR STRIP` flow before the stated scan stage.

This is sufficient to label those ten history rows
`FRONT_METAL_HISTORY_CONFIRMED / RESIST_REMOVED` for review-only selector
development. It is not yet an approved production selector. The complete
fail-closed table is saved beside this checkpoint as
`FRONT_METAL_RESIST_REMOVED_ROUTE_EVIDENCE_TABLE_20260809.csv`.

The subsequent exact JBOD catalog pull found zero current acquisitions for
all eleven history-control lots. Therefore the history controls cannot be
used as visual peers, composite members, or detector-transfer evidence. The
current `62546-481 POST2` native family remains the only available bounded
Front Metal image-development family. A future image cohort must be acquired
or imported before the `AVI_0` versus `AVI_PD_GREYSCALE` visual-transfer
question can be tested.

## Latest bounded detector result

The two-tile original-native Front Metal physical-damage presence audit is
recorded in
`FRONT_METAL_PHYSICAL_DAMAGE_PRESENCE_CHECKPOINT_20260809.md`. It supported
5/5 bounded operator positives, cleared 4/4 exposed false controls, and
repeated with a byte-identical proposal table. This closes the current bounded
presence-regression step but does not qualify the route selector or authorize
JBOD deployment. The method-selection state therefore remains
`HOLD_SELECTOR_NOT_YET_QUALIFIED_REVIEW_ONLY`.
