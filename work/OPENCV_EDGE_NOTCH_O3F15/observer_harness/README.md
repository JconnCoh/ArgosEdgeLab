# O3F15 portal-only observers

State: `FROZEN_OBSERVER_HARNESSES_READY_NO_REQUEST_CREATED`; no request has been built, signed, published, or sent.

These harnesses use only the existing signed Project Portal `DATA_PULL`
capability with approved root `JBOD_KLARF_EXPORT`. They never use RustDesk,
clipboard transfer, a GUI PowerShell window, operator Enter, an alternate
transport, or direct JBOD contact. The frozen route pins are:

- endpoint worker `CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250`;
- installed config evidence `465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB`;
- inherited queue-safety gate `170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D`.

## Fixed sequence

1. The root-owned O3F15 launch must first have a matching signed terminal
   launch gate. Nothing here publishes or modifies that launch.
2. `P1` is one fresh request for only
   `_ArgosReview/F15S/PROGRESS.json`. Its build preflight remains a hold until
   a create-new `O3F15_P1_LAUNCH_BINDING_GATE.json` pins the exact signed
   non-withdrawn O3F15 L2-or-later launch gate, hash, state, and request ID.
   The withdrawn first launch revision is explicitly ineligible.
3. If signed P1 progress is `RUNNING_O3F15_FULL978`, stop and wait. Do not
   publish F1 and do not republish P1.
4. `F1` becomes eligible only when the signed P1 collection gate reports
   `COMPLETE_O3F15_FULL978` or `HOLD_O3F15_EXECUTION_STOPPED`. F1 is one fresh
   request for `PROGRESS.json`, `SUMMARY.json`, and `RESULTS.json` together.
5. `T1` is not part of the ordinary sequence. Its definition requests only
   `TERMINAL_FAILURE.json`, and it remains disabled unless a separate exact
   `O3F15_T1_ELIGIBILITY_GATE.json` binds a signed launch or signed P1 artifact-
   failure result. A missing file, elapsed time, or running state is not that
   evidence.

Every request is one-shot with no retry or republish. A gateway share move is
never treated as endpoint execution. Only the matching signed terminal
response can advance the sequence.

## Pre-action paths

The build script signs locally, so each flow has its own exact build/sign
pre-action contract. After the corresponding eligibility evidence exists, run
`New-O3F15ObserverPreaction.ps1 -Flow <P1|F1|T1> -Stage BUILD_SIGN -Preflight`
and then `-Freeze`. The create-new paths are:

- `PREACTION_O3F15_P1_BUILD_SIGN.json`;
- `PREACTION_O3F15_F1_BUILD_SIGN.json`;
- `PREACTION_O3F15_T1_BUILD_SIGN.json`.

After a flow is built and its exact ZIP/route gates exist, the same script with
`-Stage PUBLISH` freezes that flow's independent publish pre-action contract
and its exact publish invocation under `C:/F15O/<flow>/`. Publication is then
performed by the local non-GUI publisher; it atomically renames one `.upload`
leaf to one `.ready.zip` and never retries.

The short local roots are `C:/F15O/P1`, `C:/F15O/F1`, and `C:/F15O/T1`.
Response collection uses separate short create-new roots. The invocation
templates are documentation only and are deliberately non-executable until
every exact request, response, payload, result, and returned-file hash is
filled and the state is changed to the collector's frozen state.

## Protected boundaries

The observer requests read compact JSON only. They request no source image
bytes, mutate/delete no source, query or act on no existing process/task,
activate no provider, clear no hold, change no detector threshold/selector,
and grant no training, XML, production, or routing authority.
