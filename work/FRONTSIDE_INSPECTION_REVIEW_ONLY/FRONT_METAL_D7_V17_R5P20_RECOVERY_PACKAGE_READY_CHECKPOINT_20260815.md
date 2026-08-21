# Front-metal D7 V17 R5P20 recovery-package-ready checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P20`
- Parent: withdrawn incomplete `FM7V17R5P19_RUN`
- Disposition: `DIAGNOSTIC_ONLY`
- State: `PASS_LOCAL_RECOVERY_PACKAGE_GATE_JBOD_SOURCE_PREFLIGHT_PENDING`
- Qualification authority: prohibited
- T16/T17 scoring: prohibited
- Masks emitted: no
- Detector, source, threshold, M3, V16, reviewer, XML, and production state changed: no

## Recovery

R5P19 rendered six PNG sheets and then stopped before writing the mandatory
`DIAGNOSTIC.json`. Its sparse accepted target-site records correctly contain
absolute anchor and angle but no `Precise` object. The R5P19 evidence serializer
incorrectly dereferenced that missing object.

R5P20 removes that dependency. It obtains the target corrected frame for each
site and channel explicitly from the locked R5P9 parent pose plus the accepted
R5P13D channel correction. The target-site reference remains sparse and is used
only for its locked absolute anchor/angle. No registration model, threshold,
gate, source hash, hold, or counterfactual changed.

The deterministic test constructs a target record with `Precise=null`, builds
the complete site diagnostic, serializes it, verifies the target-frame field,
and performs no writes. It passes as
`PASS_FM7P20_DETERMINISTIC_SELF_TEST` with
`sparseTargetRecordSerialization=true`.

## Package

- ZIP: `work/FM7P20/pkg/FM7P20.zip`
- ZIP bytes: `418953`
- ZIP SHA-256: `B1B95B4CEB388589F0CB65FF863339B7D127DB46E55EC48100C4343F1D0AC63A`
- Single top-level directory: `FM7P20`
- Package manifest: `work/FM7P20/pkg/FM7P20/PACKAGE_MANIFEST.json`
- Manifest SHA-256: `CB6D9E0A1390BF5A3A2B657C631DE4E4C782433F8FBA0FE162213F93C188D52E`
- Manifest contents: 27 files, 852855 bytes, all verified
- Executable SHA-256: `BFD3A39146DCEA8E917A3DDBEC2268F26766AD9A33654EB9710D99DC3D14D3B4`
- Recovery source SHA-256: `656F530C92A34FF0D44E1B2476D4E5A26DDB85FB172100BE427D6DA4018E2FA1`
- PowerShell runner SHA-256: `94AAE7311ACC133B59E581DBCE9091BDE6FE331C7E97AD678350A69867EAFE41`
- Local gate: `work/FM7P20/pkg/FM7P20_LOCAL_PACKAGE_GATE.json`
- Local gate SHA-256: `716C025FE7AF774824D26E88E67E38F27B850B8F87E1BD96B8093B1EE5CBB818`

The network destination passed the path-budget gate at effective length 170.
The frozen ZIP was then copied without overwrite to
`\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\FM7P20.zip`.
The shared copy is 418953 bytes and hash-matches the sealed local ZIP exactly
at SHA-256
`B1B95B4CEB388589F0CB65FF863339B7D127DB46E55EC48100C4343F1D0AC63A`.

## Completed local gates

- planned source, package, extraction, feedback, and output paths:
  `PASS_PATH_BUDGET`;
- x64 Framework compile: pass;
- deterministic direct-clique, ambiguity-accounting, and sparse-target final-
  serialization tests: pass;
- exact full-native S03 BF/DF registration proof: 0 px BF/DF rigid RMS,
  1.0 BF/DF topology correlation, and 4/4 sites passed in each channel;
- package and contract file hashes: pass;
- exact preflight and run `.cmd`/PowerShell 5.1 wrapper gates: pass;
- final-ZIP extraction to a fresh root, one-top-directory layout, extracted
  manifest, extracted self-test, extracted native proof, and extracted wrapper
  gates: pass.

The exact extracted source preflight stopped before mutation because the
operator-confirmed `D:` source root is not attached locally. Exit code was 1
with the expected unavailable-root reason; `Q:` remained absent and
`D:\A\FM7P20O` remained absent. JBOD exact-source preflight and execution are
therefore still pending.

## Operator perimeter clarification

The previously discussed crescent is the broader darker-green arc just inside
the perimeter, including the marked lower arc and smaller upper-left segment.
It is not the orange ambiguity layer or the thin extreme edge. R5P20 preserves
that distinction in its audit as an operator-identified perimeter/process-
appearance label only; it is neither defect truth nor an alignment cue.

## Next action

On the JBOD workstation, extract the frozen ZIP to a fresh short path and run
only:

`FM7P20\RUN.cmd`

The wrapper establishes and removes its bounded `Q:` alias for the run, performs
path, package, sentinel, free-space, and all exact-source preflight gates before
the first output write, then writes one fresh directory under
`D:\A\FM7P20O`. Return the complete `FM7P20_<timestamp>` directory. Do not
rerun R5P19, interpret its partial PNGs, apply an alignment adjustment, or use
the R5P20 counterfactual for qualification authority.
