# Front-metal D7 V17 R5P21 expanded-fiducial package-ready checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P21`  
Parent: `FM7V17R5P20_EXPANDED_FIDUCIAL_REQUIREMENT`  
Disposition: `DIAGNOSTIC_ONLY`

## Operator requirement addressed

The previous engine searched only four fixed fields: S26, S25, S31, and S20.
The observed isolated L02 support gaps did not establish damaged or missing
fiducials and were not sufficient reason to declare S14, S21, or S23
unalignable. R5P21 therefore performs an expanded fiducial search before any
five-edge fallback or wafer-level alignment hold is considered.

## Frozen expanded search

- Candidate positions are generated only from the locked S02 two-phase
  lattice. S20-S25 and S31-S25 are the two lattice basis vectors; S26 is the
  verified half/half phase location.
- Twenty-eight additional candidate locations are retained inside the
  physical wafer by a fixed 700-source-pixel interior margin and the exact
  native crop bounds.
- Candidate qualification uses the unchanged seven-component identity model
  and six observed straight-edge model independently in BF and DF at native
  `14411 x 10995`, scale 1:1.
- Target candidates must pass in both BF and DF. Up to 12 additional sites are
  then selected by a deterministic farthest-point distribution rule. No peer
  outcome is available to or consumed by target site selection.
- Every peer/channel is fit by deterministic maximum direct-site consensus
  over all separated site pairs, followed by one rigid X/Y/theta refit. This
  is not sequential align-all-and-drop-the-current-worst behavior.
- A channel requires at least six consensus sites, at least 70% of all
  selected target sites, at least three wafer quadrants, rigid RMS and maximum
  inlier residual no greater than 1.25 px, and maximum leave-one-site mapping
  change no greater than 0.35 px.
- BF and DF remain independent. A wafer qualifies for inspection pose only
  when both channel gates pass. Otherwise it emits an explicit alignment hold;
  it is never silently skipped and cannot emit Normal or Reject authority from
  an unqualified transform.
- The darker-green perimeter crescent, speckled die, QR-code region, edge
  chipout, detector masks, and T16/T17 outcomes are not alignment cues.
- The five-edge leaveout method is not used by R5P21 and remains a last-resort
  diagnostic only.

## Local native expanded-path proof

The complete expanded path was exercised against the unchanged full-native
S03 BF and DF files. The result is
`PASS_FM7P21_NATIVE_EXPANDED_ONE_ITEM_PROOF`:

- generated additional candidates: 28;
- target-qualified in both channels: 27;
- selected additional sites: 12;
- selected total sites including the four locked originals: 16;
- target quadrants: 4;
- S03 BF direct/consensus sites: 16/16;
- S03 DF direct/consensus sites: 16/16;
- BF rigid RMS: 0.036945927489 px;
- DF rigid RMS: 0.036019553313 px;
- BF maximum leave-one mapping change: 0.012280661727 px;
- DF maximum leave-one mapping change: 0.009003461384 px.

The deterministic synthetic gate also passed with one deliberately
inconsistent observation excluded by direct consensus, without sequential
worst-site removal.

## Frozen portable package

- ZIP: `work/FM7P21/pkg/FM7P21.zip`
- ZIP bytes: 445669
- ZIP SHA-256:
  `C133E4BD9556F5BC55B0F92A233D6E0759AD951A0EE32052E044AD2F2435D5AB`
- package manifest SHA-256:
  `B700BE0DA7B037D33A7869006B6B88BB89A6BA10DF2056D80B8A5D599657974D`
- contract SHA-256:
  `487D8CF290DCD520E6086DD2F9EC135223B3209340D8398E61B8BA6FE7FBF3B5`
- executable SHA-256:
  `2F24165880D071540990C9B7A6456EFF1E9E7295F922D99CABDB082464DF5FB8`
- source SHA-256:
  `92BB50E1568188200BBA3CC9F7A23973F557EFC5B2863BECC2636D307E23D081`
- local package gate:
  `work/FM7P21/pkg/FM7P21_LOCAL_PACKAGE_GATE.json`
- local package gate SHA-256:
  `A5300542EBB7DD4C8CC56CB7CDE604F983BF318B030C177D6648874F03E41ECE`

Path budget, compile, package manifest, exact one-root ZIP extraction,
extracted deterministic self-test, extracted full-native expanded one-item
proof, and both extracted Windows PowerShell wrapper checks passed. The exact
24-source JBOD preflight remains pending because the operator-confirmed `D:`
source root is not attached locally; the packaged PowerShell 5.1 preflight
failed closed at that missing-root check without creating Q: or output.

## Next action

Copy the frozen ZIP without overwrite to the operator-provided
`InspectionRevs` folder. On the JBOD workstation, extract it and run only
`FM7P21\RUN.cmd`. Return the complete `D:\A\FM7P21O\FM7P21_<timestamp>`
directory. The required result is `EXPANDED_ALIGNMENT.json` plus the target
grid and expanded-alignment summary sheets.

No defect inspection, mask, detector threshold, M3, V16, reviewer authority,
XML, production routing, stitch authority, deferred-stroke, or strict-chipout
state changes at this checkpoint.
