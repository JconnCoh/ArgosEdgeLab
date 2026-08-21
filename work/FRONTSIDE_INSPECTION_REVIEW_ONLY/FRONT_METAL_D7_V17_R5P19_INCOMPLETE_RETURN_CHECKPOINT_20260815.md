# Front-metal D7 V17 R5P19 incomplete-return checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P19_RUN`
- Disposition: `WITHDRAWN`
- State: `INCOMPLETE_NO_FINAL_AUDIT`
- The partial output is ineligible for alignment, gate-accounting, peer-qualification, mask, T16/T17, reviewer, XML, or production authority.

The operator returned `FM7P19O\FM7P19_20260816T000121Z` under the approved `InspectionRevs` share. The directory contains the four requested registration sheets and two gate-accounting sheets, but the required `DIAGNOSTIC.json` completion artifact is absent. The run therefore did not complete and must not be interpreted from its PNG files.

## Partial file inventory

- `BF_GATE_ACCOUNTING.png`: 59126 bytes, SHA-256 `6D71C8CAC8A59084237BB1CF28198772009037D886CC45F80261596A61C3A68B`
- `DF_GATE_ACCOUNTING.png`: 60076 bytes, SHA-256 `81580F84DC0BB0D9DE129A32FAB20BC7B4E2958697B7B6A27B2F91115327E3F1`
- `REGISTRATION_S20.png`: 1851603 bytes, SHA-256 `D20F987A8246A2634FCF2B8ED9FB21317112DF288134AA731E697DF56D986DFC`
- `REGISTRATION_S25.png`: 1852642 bytes, SHA-256 `1FA0AC2291DEF47A38CB196B156219B21FEC0713A2D813422967392BF834BE01`
- `REGISTRATION_S26.png`: 1872861 bytes, SHA-256 `C2249CDE0D5380CF638D04DA53F4D0361E8EC177E1BCB5AC795B89ACDD45108F`
- `REGISTRATION_S31.png`: 1852222 bytes, SHA-256 `57D1BAE35A19EB1B06AE1C6B312F2DB9422B66821CB79ABCDF167A5E2EBD0107`

## Failure signature and cause

The executable renders all six sheets before constructing and serializing the final diagnostic dictionary. The accepted `TargetSites` helper populates target reference site, absolute anchor, absolute angle, and pass state only; it intentionally leaves `Precise` null. R5P19 then dereferenced `target.Precise.CorrectedX/Y/Angle` while building each peer's target-relative site audit. This null dereference occurred after rendering and before `DIAGNOSTIC.json` was written.

This is an evidence-serialization boundary failure, not detector, source, registration, spatial-mask, or operator error. It has been recorded in `ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md` with a required target-record serializer preflight.

## Recovery

Do not rerun R5P19 and do not delete or patch the returned directory. Issue a new R5P20 evidence-only package that obtains the target corrected frame explicitly from the locked R5P9/R5P13D model records rather than dereferencing the sparse target reference object. Add a deterministic serialization test using a target record with `Precise=null`. Preserve every source hash, threshold, hold, and diagnostic-only authority boundary, then rerun the full compile, native proof, wrapper, manifest, ZIP, and extraction gates.
