# Front-metal D7 V17 R5P23 all-wafer composite package-ready checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P23`  
Parent: `FM7V17R5P22_RESULT`  
Disposition: `PENDING_GATE`

The operator authorized direct JBOD execution of the all-wafer composite
integration. The frozen R5P23 package consumes the exact R5P21 independent BF
and DF rigid transforms and requires the exact R5P22 review-only alignment
stability result for all twelve wafers. It does not recompute, adjust, or
replace any accepted transform.

Every one of S02, S13, S14, S16, S18, S19, S20, S21, S22, S23, S24, and S25
is processed as a target. Each target's reference set contains exactly the
other eleven physical wafers; the target is excluded from its own BF and DF
composites. Target native pixels remain unchanged and are scored directly.
Only reference pixels are sampled through their frozen channel-specific
transform. Peer-specific contribution accounting excludes global ambiguity
instead of charging it as a mismatch, while insufficient local peer support
remains an explicit coverage hold and never becomes Normal truth.

The package creates bounded review-only T16 and T17 control sheets for both
channels, per-target coverage sheets, one all-wafer summary, compact
contribution-mask lineage, and a final audit. It emits no defect mask or
automatic inspection disposition. The operator-identified darker-green
perimeter crescent has no pose weight and cannot create a whole-wafer hold.

Local package evidence:

- run ID: `FM7P23_20260816T012800Z`;
- ZIP: `work/FM7P23/FM7P23.zip`;
- ZIP bytes: 88685;
- ZIP SHA-256:
  `1C62151CE9EEA9641FEF55C0D88B89A1821B4329DF65C459712B54B2D5CE58F4`;
- package-manifest SHA-256:
  `2112E664E51850EC1CB58D14603CBE2A494E93B7363B5A5A72F68E68F0A1AF09`;
- contract SHA-256:
  `0DE6F2B97B03E93FE22B640C31DDA0E32A52C13E31A789541EACC9AC034CBEF1`;
- executable SHA-256:
  `D37AD7439929CA591EEA415BB8857D974FCE2E8E83C18DAC0AC19D40F132B812`;
- source SHA-256:
  `E37F923FEC389F653B4C4E97EFE5981E4BC54DAF0C6865B0A96F6A3F1E3B47A0`;
- local gate:
  `work/FM7P23/FM7P23_LOCAL_PACKAGE_GATE.json`.

The path-planning gate, deterministic self-test, source/evidence hash checks,
both portable-wrapper static gates, final-ZIP one-root extraction, extracted
manifest verification, and extracted deterministic self-test pass. The exact
packaged Windows PowerShell 5.1 preflight fails closed locally at the expected
source boundary because the JBOD-only `D:` root is absent, with no output
root created. The exact 24-source native preflight and complete run remain
pending on the JBOD.

The approved signed review-only Project Portal is the execution route. The
next action is to submit a fresh signed maintenance request that installs this
exact package under the approved processor diagnostics root and executes its
file-backed invocation, require the declared all-twelve-target PASS state,
then use an exact signed data pull to return every declared output into the
operator's `InspectionRevs` folder without overwrite.

This package and any returned result remain review-only, exposed-data,
training-ineligible for new alignment authority, XML-ineligible, and
production-ineligible. Later independent-lot evidence remains required. No
M3, V16, canonical reviewer, detector threshold, strict-chipout sibling,
deferred stroke, stitch authority, XML, or production route changes here.
