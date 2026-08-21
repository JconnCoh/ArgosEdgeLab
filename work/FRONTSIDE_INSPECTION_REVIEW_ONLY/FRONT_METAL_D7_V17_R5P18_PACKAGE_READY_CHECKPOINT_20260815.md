# Front-metal D7 V17 R5P18 package-ready checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P18_PACKAGE`
- Disposition: `PENDING_GATE`
- State: `PASS_LOCAL_PACKAGE_GATE_JBOD_SOURCE_PREFLIGHT_PENDING`
- Authority remains review-only. No peer has yet been qualified from the JBOD and no composite or full-wafer rerun has been produced.

The short-path portable package authorized by the R5P18 handoff is built and locally verified. The exact operator-confirmed source root is not attached to this workstation, so the packaged Windows PowerShell 5.1 source preflight stopped before mutation and the JBOD qualification remains pending.

## Frozen package

- ZIP: `work/FM7P18/pkg/FM7P18.zip`
- ZIP bytes: `399492`
- ZIP SHA-256: `74411E8EF5BEA421DC14C42CD62A7FD28C37012BF264860E7851BC71DD6439A8`
- ZIP layout: exactly one top-level directory, `FM7P18/`
- Package manifest: `work/FM7P18/pkg/FM7P18/PACKAGE_MANIFEST.json`
- Package-manifest SHA-256: `CD9D49A93993833EEAB91885937F020DB88C7CA1BEAB54DC3E0C863A1CDB722C`
- Manifest coverage: 23 payload files, 793395 total listed bytes, every path/byte count/hash verified both before and after ZIP extraction
- Local gate artifact: `work/FM7P18/pkg/FM7P18_LOCAL_PACKAGE_GATE.json`
- Local-gate SHA-256: `52C4DDCD9D1DF4DD91538C15D24CD963622B5E6065B477BD80BF3481B87D7382`
- Executable SHA-256: `BFA2276701A7BE60B366FF3CBBFB4FFBC48EBA9035E6F1E2B17ACFE5B8FDC210`
- New source SHA-256: `75328D1188861A841D36B7EB24262E6A93E46E1DB43ED12A103E0F522C838B82`
- Windows PowerShell runner SHA-256: `8514143EE4A233006B7B61B0394092B58CE81E84F41D0F55045B8AF63D4EA6E8`

## Local gates passed

1. Path planning passed with a 32-character suffix reserve. The packaged workflow uses the verified short alias `Q:\` for the exact source root and short output root `D:\A\FM7P18O`.
2. Both `PREFLIGHT.cmd` and `RUN.cmd` passed the mandatory wrapper gate. Each invokes exactly one quoted `RUN.ps1` with Windows PowerShell 5.1, `-NoProfile`, `-ExecutionPolicy Bypass`, a bounded UTF-8 invocation manifest, and no `%*`, `-Command`, `start`, or `Start-Process` hop.
3. The deterministic test passed direct-clique/no-chaining behavior, competing-population hold behavior, RLE encoding, and no-write behavior.
4. The extracted final ZIP passed a native one-item S03 proof against the full `14411 x 10995` BF/DF sources at scale 1.0. All four BF and all four DF sites passed; identity-comparison rigid RMS was `0.0 px` in both channels and topology correlation was `1.0` in both channels. No proof output was written.
5. The final ZIP extracted into a fresh root with the intended package layout. The extracted manifest, executable self-test, and both wrapper gates passed.
6. The exact extracted `PREFLIGHT.cmd` was executed under Windows PowerShell 5.1. It exited `1` solely because `D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2` is absent. `subst` state and output-root state were unchanged.

## Frozen qualification contract

- Slot02 remains the unchanged target and is excluded from its own reference.
- The candidate pool is S14, S16, S18, S19, S20, S21, S22, S23, S24, and S25. S13 is retained only as the declared replay control.
- Every BF and DF source must match the recovery ledger hash and exact native `14411 x 10995`, 24-bit BMP layout before analysis.
- BF and DF registration remain independent. Each peer uses the accepted nonrepeating PM identity and six orthogonal native straight-edge solution across S26, S25, S31, and S20 with a no-scale rigid transform.
- Target-excluded spatial contribution masks are channel-specific. They use direct pairwise population support, never nearest-neighbor chaining. Competing independent populations fail closed to a local coverage hold.
- A possible approximately five-die-row perimeter crescent is not Normal, is not absorbed into the peer envelope, and is not an automatic whole-wafer disqualifier. Broad interior mismatch may hold a peer; perimeter contribution loss remains spatial.
- Every scored cell requires at least three locally eligible peers. T16 and T17 use the fixed 4-DN deadband and return bounded sheets plus compact metrics. The package also returns registration, BF/DF spatial, perimeter, and interior sheets before any full-wafer rerun.

## Exact next action

On the workstation where the operator-confirmed `D:` source root is attached, extract the frozen ZIP and run the single bounded command `FM7P18\RUN.cmd`. The runner must pass its own manifest, source-hash, native-dimension, short-alias, disk-space, and Windows PowerShell 5.1 gates before it creates a fresh timestamped output under `D:\A\FM7P18O`.

Return only compact `AUDIT.json`/`MASKS.json` metrics and the bounded T16, T17, registration, BF/DF spatial, perimeter, and interior file-backed sheets. Stop for operator review before any full-wafer V17 rerun. Preserve the separate possible stitch fault for a future fail-closed `STITCH_GEOMETRY_HOLD`.

No source image, detector evidence, mask, threshold, classifier/M3, V16 artifact, reviewer, XML, production route, deferred stroke 278, or strict chipout-sibling state changed at this checkpoint.
