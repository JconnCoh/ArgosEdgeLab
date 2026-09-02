# OCV-03 O3F4 R8 targeted pass / O3F3 full acquisition continues

Disposition: `PENDING_GATE`

O3F3 exposed a frontside decision-layer defect: R7 found exactly one eligible
BF/DF notch around 90 degrees, but globally held the row because unrelated BF
tiles had incomplete topology. Frontside holders do not occlude the images;
no holder rule was added. In R7, incomplete BF tiles are discarded before
candidate emission, and pair eligibility still requires at least 0.95 measured
BF contour plus qualified full-360 DF evidence.

O3F4 R8 is the immutable R7 source with exactly two decision lines deleted:
the global BF-coverage veto after DF qualification and the zero/one/multiple
eligible-candidate decisions. R8 SHA-256 is
`068ECC0D4F547FCFD7A0A2AEDF673B71BB0C46207DE8EC0F47312A9030B0734B`;
R7 remains `A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B`.
The exact-delta/four-decision test passed. No threshold, topology operation,
candidate, pairing rule, angle prior, image source, overlay, or diagnostic was
changed. DF failure, zero eligible, and multiple eligible outcomes remain
holds.

The exact-JBOD draft transfer command
`A3F94A61172B740163FD9F0DE38ECD20BB76F427514176D315EBBB5332260EAE`
returned `PASS_O3F4_R8_TRANSFER` and reproduced the R8 hash under
`D:/O3F4RT`. The first targeted runner artifact under `D:/O3F4T` is terminal:
all five synthetics passed, exact 18-pair source selection
`95B0A5331ED6005AA82A339FCD373604665D5C1D84398FAF2C692765D1DA3C3C`
was frozen, and the 13-pair job was rejected before output/image read because
R7 accepts only one or three pairs per invocation. The outer command's missing
whitespace rendered `throw 'run'` as `throwrun` and masked that child error.
Post-failure observations `07DFE4991BB38F9ADE92B5DC91F19B599307E8409B3BD7941432227BB9777B17`
and `872B8D3279F940A9EDFF3D7936592E14933DAD93B704B227125B38A3816FC642`
prove no DEV13 output root or validation execution.

Fresh O3F4T2 reused the hash-locked selection and batched the exact same cohort
as 3/3/3/3/1 development and 3/1/1 holdout invocations. Direct command
`E6E39AD71A0C7F875A3FEC6A51CD43218E28B21FC58B882458FD8B6DE18D52D3`
returned `PASS_O3F4_R8_TARGETED_18`. Five synthetics passed; all eight exposed
O3F3 coverage holds became unique passes with candidate arrays, indices,
angles, and incomplete-tile evidence unchanged; the three frozen POST2 rows
remained passes; rare hotspot Slot16 remained
`HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH`; hotspot Slot19 retained one eligible
candidate. All five frozen-before-run current-recipe holdouts passed: three
PatternedFront and two UnpatternedFront.

Machine evidence is frozen at `work/O3F4/O3F4_LOCAL_DELTA_GATE.json`
(`884A1CEF383A0BE9E3F0EDAB11D36A0DB7D1628109B5EB6E970ADBB6CF8055BB`),
`O3F4_R8_TRANSFER_RESULT.json`
(`AD231C12B25A64751594D3EAA3D906C402CBABC3AA6121534F04AAADD7766CE2`),
`O3F4T_FAILURE_OBSERVATION.json`
(`3CDB20832821443D8313980F6225CA2560E25073CEED7091BDE3BF8F1DF5972B`),
`O3F4T2_TARGETED_RESULT.json`
(`DBDC3242428431669A011FA0858449061D0243FDDC3E39D8253E4E54D0E5AE9C`),
and `O3F3_PROGRESS_337_OBSERVATION.json`
(`824800FAD767C2F2D7AB4BB4701D22480622EA2DE8F9F44220E482FF59DFFB01`).

The already-running exact 978-pair O3F3 R7 acquisition remains the efficient
full-image evidence source because R8 changes only the terminal decision. At
337/978 it had zero source problems and empty stderr: 223 global-coverage
unique rows, 109 no-candidate holds, four DF-coverage holds, and one provider
error. A single exact-PID completion watcher is active. After completion,
mechanically apply R8 decision semantics, retain every true no/multiple/DF/
provider hold, reconcile all current PatternedFront and UnpatternedFront
identities, and retain rare hotspot Slot16 as an explicit hold. Do not launch a
redundant second 978-image run.

Review-only remains true. Training, XML, production routing, provider
activation, source mutation/deletion, existing task/process action, automatic
hold clearance, and result-driven threshold or selector changes remain false.
