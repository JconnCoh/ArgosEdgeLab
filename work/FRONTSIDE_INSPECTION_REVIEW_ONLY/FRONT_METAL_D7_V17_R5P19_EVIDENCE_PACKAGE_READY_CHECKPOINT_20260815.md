# Front-metal D7 V17 R5P19 evidence-package checkpoint — 2026-08-15

## State

- Revision: `FM7V17R5P19`
- Disposition: `DIAGNOSTIC_ONLY`
- State: `PASS_LOCAL_PACKAGE_GATE_JBOD_SOURCE_PREFLIGHT_PENDING`
- Parent: `FM7V17R5P18_JBOD_RESULT`
- Authority: evidence only; peer qualification and alignment adjustment are prohibited until operator review.

The operator authorized continuation after reporting alike interior crops, expected speckled/edge-chipout/QR-gray-square/residue perimeter variation, and a small visible shift between the fiducial alignment lines. R5P19 is a bounded follow-up that determines whether the shift is systematic and corrects only the diagnostic accounting error that charged globally ambiguous cells as peer-specific mismatch.

## Frozen package

- ZIP: `work/FM7P19/pkg/FM7P19.zip`
- ZIP bytes: `413468`
- ZIP SHA-256: `03272E182F83E823B428BAF10C46948F9D818B960BDFDDED3403B215F901F959`
- Layout: exactly one top-level `FM7P19/` directory
- Package manifest: `work/FM7P19/pkg/FM7P19/PACKAGE_MANIFEST.json`
- Package-manifest SHA-256: `5F7A17B77502F2A1D957C2A42D50C0FE852C88F7152A1CD85DDE63CADFD7405B`
- Manifest coverage: 25 payload files, 840450 total listed bytes, with every path/byte count/hash verified before and after final-ZIP extraction
- Local package gate: `work/FM7P19/pkg/FM7P19_LOCAL_PACKAGE_GATE.json`
- Local-gate SHA-256: `BAA017235AA962A461EAE48009EA84E1C17947CF147FC9348FD94B14A43F921A`
- Executable SHA-256: `8BB79FAF4E943A2D99DF39524749B1D94EECE7D730A17D6008842B6E999AC64D`
- Diagnostic source SHA-256: `CF64E9EE2D9A274BC6DBA42593C2858BB4D97F3310B33B4F909B1CCFB42C76EE`
- Windows PowerShell runner SHA-256: `3F0D4255229EDAB12B3B82A2929C50F022220CAA9B33CE84B5F4ECC4F90B999A`

## Frozen diagnostic contract

R5P19 replays the exact 24 R5P18 native source hashes, target exclusion, BF/DF independence, accepted nonrepeating PM identity, six straight-edge model, four sites, no-scale rigid transform, line thresholds, topology threshold, direct-clique rule, five-die-row perimeter definition, minimum three-peer local coverage, and 15% whole-peer limit.

It adds only evidence:

1. `REGISTRATION_S26.png`, `REGISTRATION_S25.png`, `REGISTRATION_S31.png`, and `REGISTRATION_S20.png`, each using nearest-neighbor display of the unchanged native crop with magenta direct first-transition runs and the green final six-edge solution in independent BF and DF panels.
2. Per-site corrected X/Y/theta, local line RMS/P90, correction magnitude, absolute anchor, rigid-predicted anchor, X/Y residual vector and magnitude, target-relative corrected frame, and signed segment intercept/slope offsets.
3. Per peer/channel legacy held fraction and peer-specific held fraction. Globally ambiguous interior cells remain local coverage holds but are excluded from the peer-specific mismatch numerator and denominator.
4. A non-authoritative coverage counterfactual and BF/DF gate-accounting sheets. It cannot approve peers or change legacy R5P18 holds.

R5P19 emits `DIAGNOSTIC.json` and six file-backed PNG sheets only. It emits no accepted masks, does not score T16/T17, and cannot create a reviewer or inspection result.

## Local gates passed

- Path budget passed for the package, ZIP, extraction root, longest short-alias source path, and longest output path; maximum effective length is 174 with 32 reserved suffix characters.
- Deterministic test passed direct-clique/no-chaining behavior, competing-population holds, RLE, and explicit separation of global ambiguity from peer-specific mismatch.
- Full-native S03 identity proof passed at `14411 x 10995`, scale 1.0, with 4/4 BF and 4/4 DF sites, 0.0 px identity rigid RMS, and 1.0 topology correlation.
- Both CMD/Windows PowerShell 5.1 wrapper gates passed.
- Final ZIP extraction, extracted manifest, extracted executable tests, and extracted wrapper gates passed.
- The exact extracted preflight stopped without mutation because the operator-confirmed `D:` source root is not attached to this workstation. `subst` and output-root state were unchanged.

## Exact next action

On the JBOD workstation, extract the frozen ZIP and run the single bounded command:

`FM7P19\RUN.cmd`

The runner must pass its own package-manifest, source-hash, native-dimension, short-alias, path-budget, disk-space, and Windows PowerShell 5.1 checks. It writes one fresh `D:\A\FM7P19O\FM7P19_<timestamp>` directory. Copy that complete directory to the approved `InspectionRevs` share and stop for review.

Do not apply an alignment adjustment, loosen a line or 15% gate, fill a gap, approve a peer, rerun FM7P18, absorb perimeter evidence into Normal, or change any detector, mask, threshold, classifier/M3, V16, reviewer, XML, production, stitch, deferred-stroke, or strict chipout-sibling authority.
