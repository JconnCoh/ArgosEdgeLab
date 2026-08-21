# Front-metal D7 V17 R5P24 zero-blank composite package-ready checkpoint — 2026-08-17

Disposition: `PENDING_GATE`

Revision: `FM7V17R5P24`

Parent: `FM7V17R5P23_RESULT` (`DIAGNOSTIC_ONLY`)

## Purpose

R5P24 addresses the operator-rejected black reference regions in the R5P23
T16/T17 controls. The existing R5P23 strict unique-clique route is retained
unchanged wherever it forms at least three target-excluded peers. A separately
labeled fallback route is used only where that strict route cannot resolve a
unique peer population.

The fallback consumes all photometrically eligible target-excluded peers,
uses their median as the reference, trims at most one low and one high peer
from the acceptance envelope when peer count permits, and retains the locked
4-DN residual deadband. It never consumes the target as its own reference and
does not spatially invent peer pixels. Strict and fallback route pixels are
counted and rendered separately.

The diagnostic PASS gate requires all canonical BF/DF cells and every valid
T16/T17 control pixel to route through strict or fallback reference. Any
direct-native or unassigned pixel is a stop. This package emits no defect mask,
defect outcome, Normal truth, reviewer, XML, training, or production authority.

## Frozen package

- run ID: `FM7P24_20260817T152704Z`;
- ZIP: `work/FM7P24/FM7P24.zip`;
- ZIP bytes: `99322`;
- ZIP SHA-256: `860CCB62BDBDD91192EB97A86BD6BCF85C8BDA60D7ED634A9855191ACBE1F296`;
- contract SHA-256: `7A858D4F4CDD920B767608E8784A1BC2CBA64C9F9DE1856D313EDE3B5220EE01`;
- executable SHA-256: `CE1DE951BE60B47B78F8EFD7CFDDF9E89E7B263D1DDFEC6A5A863E4DA0D976A8`;
- source SHA-256: `5C97C5B9D62B2E064B99AE92BE23C97038E2829745FEC368081806C3A03E7726`;
- local gate: `PASS_FM7P24_LOCAL_PACKAGE_GATE_EXACT_JBOD_PREFLIGHT_PENDING`.

Path planning passed with maximum effective length 164. The C# source compiled
as x64 and passed `PASS_FM7P24_DETERMINISTIC_SELF_TEST`. Both packaged wrapper
definitions passed the static Windows PowerShell 5.1 gate. The final ZIP
extracted to one root, all manifest hashes matched, the extracted executable
passed the same deterministic self-test, and the exact packaged preflight
failed closed locally only because the JBOD `D:` source root is absent. No
output root was created locally.

## Next action

Build and fully rehearse one fresh signed Project Portal maintenance request
that installs this exact package under a new `FM7P24` diagnostic namespace,
establishes and verifies a short JBOD source alias, and runs under Windows
PowerShell 5.1. Publish only after continuity, session-safety, path, exact
predecessor/create-new, final-ZIP, and signed-package gates pass. After a signed
zero-blank run, pull the bounded 41-file result and return it create-new to
`InspectionRevs` for file-backed operator review.

The accepted patterned-fiducial metadata request
`REQ_20260816T033053168Z_802B9D0EC0B4` remains pending and must not be
duplicated.
