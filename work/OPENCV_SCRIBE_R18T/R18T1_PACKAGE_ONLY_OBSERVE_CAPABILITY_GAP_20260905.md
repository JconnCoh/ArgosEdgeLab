# R18T1 package-only OBSERVE capability gap

Created UTC: `2026-09-05T12:26:16.0940284Z`

State: `BLOCKED_NO_QUALIFIED_TEXT_ONLY_ROUTE_TO_R18T_OUTPUT_ROOT`

The exact signed REQ_R18T1 launch response is frozen by `R18T1_SIGNED_LAUNCH_RESPONSE_CHECKPOINT_GATE.json` (SHA-256 `DFE9E2FC8B428245AED0BE9CD123E74AD71EFA8442F02FFECA4AF99EA17D73D8`). It proves only `PASS_R18T_LIVE_ONLY_WORKER_STARTED`, with 20 configured cases and output root `D:\A2\o\ocv\R18T1`. It contains no inventory, progress, terminal, or per-case result artifacts.

The frozen corpus contract writes only bounded text/JSON state at that root: `INVENTORY.json`, `RUNNING.json`, terminal `COMPLETE.json` or `FAILURE.json`, and one `c/<caseId>/RESULT.json` per completed case. The contract is established by:

- `work/OPENCV_SCRIBE_R18P/Run-R18PReferenceIsolatedCorpus.py` — SHA-256 `5B6AA224E844FCEA22DEC6A9D10C863437F039CA73EC258C263DF539905791D0`
- `work/OPENCV_SCRIBE_R18T/Run-R18TExecutionEnvelope.py` — SHA-256 `23F52C8FEC096F6587521B78AF8242C80E8687040457F9AE197858DB0B00AED7`

The installed qualified read-only capability evidence does not establish a safe route to those files:

- `STATUS` reads only the endpoint configuration's fixed `status.jsonFiles` and fixed log paths. A request cannot select an R18T JSON path.
- `DATA_PULL` accepts relative leaf paths only under a named entry in the endpoint configuration's `approvedDataRoots` and refuses an unconfigured root before reading it.
- `STATUS_CAPABILITY_INVENTORY.json` records `requestSpecificJsonSelector` as a limitation and records the only exercised approved data root as `JBOD_KLARF_EXPORT`.
- The preserved live endpoint-config evidence file named by prior gates is not present in this dedicated worktree; only its recorded hash is retained. No frozen record establishes `D:\A2\o\ocv\R18T1` (or `D:\A2\o`) as an approved data root or fixed STATUS JSON target.
- Path traversal from `JBOD_KLARF_EXPORT` is prohibited by the qualified worker's safe-child check and is not an acceptable substitute.

Relevant qualified evidence:

- `work/OPENCV_OLS3/OLS3_ENTRYPOINT_TEST_GATE.json` — SHA-256 `4BECCB3A5C1A7EF5A3E508CE11CA41854EEC77C06181EAB0000876AE750AF95B`, state `PASS_OLS3_ENTRYPOINT_TEST_GATE`, including unapproved-root refusal.
- `work/OPENCV_OLS3/OLS3_COMPLETE_ROUTE_GATE.json` — SHA-256 `932C792DA3095FA43FF1749775D7F4BD3473FA6043ABE86C449FBA16A3914F3A`, state `PASS_OLS3_COMPLETE_ROUTE_GATE`.
- `work/OPENCV_BACKSIDE_NOTCH_STATUS_O3B5/STATUS_CAPABILITY_INVENTORY.json` — SHA-256 `FA0FCB880AC845FBE7D674C4B039F75543A467E25B0D228E6ADB8324D480CAB9`.
- `work/OPENCV_BACKSIDE_NOTCH_STATUS_O3B5/STATUS_DEFINITION.json` — SHA-256 `0AB9C58CA57DF36EA64C1AC3FA0BD4004D847F00B776E73AAE9265BB2A17C4F6`.
- `work/OPENCV_BACKSIDE_NOTCH_PULL_O3B6/DATA_PULL_DEFINITION.json` — SHA-256 `342EE92422BA4FECF4508DCAAF8F5C27160B179B1E6178510DCA9392809189B9`.

Consequently, no fresh OBSERVE request was built, signed, or published. Publication count for an OBSERVE request is zero. There was no retry or republication of REQ_R18T1, no second execution request, no MAINTENANCE_PATCH use, and no GUI/RDP/direct-JBOD access. No task/process state, source image, crop, overlay, reference image body, or unrelated root was read.

Signed-evidence outcome remains `PENDING_UNPROVEN`: configured cases `20`; signed terminal per-case outcomes `0`; exact PASS/HOLD/failure counts unavailable. The six existing holds, Slot24 exclusion, no-retry rule, R18S prohibition, identity prohibition, and unrelated-global-phase boundary remain unchanged.

Required next authority/capability: an already-installed and independently qualified read-only mapping or request-specific JSON selector anchored exactly at `D:\A2\o\ocv\R18T1`. Installing or mutating such a capability is outside the current authority.
