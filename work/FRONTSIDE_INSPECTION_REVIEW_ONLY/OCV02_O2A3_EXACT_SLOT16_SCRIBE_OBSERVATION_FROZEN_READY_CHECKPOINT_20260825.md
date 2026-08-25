# Argos checkpoint — OCV-02 O2A3 exact Slot16 scribe observation frozen

Date: 2026-08-25

Revision: `OCV02_O2A3_EXACT_SLOT16_SCRIBE_OBSERVATION_20260825`

Disposition: `PENDING_GATE`

## Why O2A3 is required

O2D5 is signed terminal evidence but remains `DIAGNOSTIC_ONLY`, executed,
withdrawn, and non-reusable. Its `699F999999F6` image-first string came from an
unqualified whole-wafer exception-texture region, not from absence of the
accepted alphabet/reference library. Slot16 is not frozen and Slot17 remains
blocked.

O2A3 is the required `OBSERVE` step. It reads only the exact installed
current-acquisition Slot16 catalog/proposal/reader JSON and exact installed
source-code hashes. It does not open, hash, copy, decode, or return image
files and does not change any task, process, installed file, queue, ledger,
provider, source, wafer, or hold.

## Frozen package

- revision: `O2A3_20260825T195521Z_SLOT16`
- request: `DIRECT_O2A3_20260825T195521Z_SLOT16`
- exact physical identity: `62619-433_20260824005735_Slot16`
- package: `work/OPENCV_SCRIBE_O2A3/final/ARGOS_O2A3.zip`
- bytes: `12,290`
- SHA-256:
  `574FDA03A11C1E64451288CCB911C80558B96DE3E08EA539C51ECD4D7F1DC94B`
- final-gate SHA-256:
  `EC530B14EE3AF7CA694C0400002033BF5FA556FE6EFFF621A42C146427DDFD40`
- package-manifest SHA-256:
  `389416CE4B408C3C457F8E1D03E4A23E40FC154685F2C54A92963F4B406A9CE2`
- path-gate SHA-256:
  `9B23EC6C1A75DED33D1F15A211BB8F4E73C7BD69311659A3F5D788D8F5F6626A`
- maximum effective path length: `187`

The package pins the exact installed processor config, JBOD endpoint config,
response-sender config, and six installed source dependencies. The dependency
set includes the accepted 456-reference manifest SHA-256
`AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`,
accepted image reader SHA-256
`0E64D5FBE57556B7FC5A37D6764FDA65CBF780F96A3C994B73954CF985E67206`,
polarity implementation SHA-256
`94DFB1B7F38A1E5BF12C41F9D8FBEEDAFFDF888365E9646F1058C58A9F5DEF0C`,
multi-channel helper SHA-256
`E5EA835CA3E8BE32A8E19E9CE46E1E114DFC4823D6A6F186E01AE8BFFF5D6C73`,
and proposal caller SHA-256
`3B00E5CDE1BA28DCE347DD4BC83D28B301058E70160D70D4E23E878E5904915B`.

## Mechanical proof

The exact package-shaped entrypoint passed Windows PowerShell 5.1 with four
cases: proposal plus reader summary, proposal plus reader hold, exact evidence
absence, and injected outbound-response failure. Both present forms produced
and cryptographically verified a signed response. Exact absence produced a
signed hold observation rather than a crash or guessed successor. Injected
outbound failure retained the D-local result. Test-gate SHA-256 is
`560F77BB31B2046C0AC5A8B0C4DD0B7A1A9D28BBD22EF380A9EAAD6BDE5AB015`.

Every execution case held a declared fake BMP open with an exclusive lock.
The observer completed without trying to open it, proving the JSON metadata
projection does not read image bytes. The healthy processor PID and creation
time are captured before and after the live observation and must remain exact.

Recovery-intent SHA-256 is
`0739D7A5BDD65001ACDED7301E5F0AD7991A214A56E71CDA6F967407BDD5AEE2`.
Capability-inventory SHA-256 is
`BB0119D10FB5F137424C2F333EE635FC4046CA7F00F2227909CEE73BFA3D6306`.
Build preaction SHA-256 is
`A28475B29239CB5B5B3FE771FA6A7A6AF2EDEF7C72B8D000AB4A2B75BF1D91FA`.

## Exact next action

Commit and push the frozen package and checkpoint, require a clean worktree
with matching local/origin `codex/fiducial-opencv-d-drive` tips, then publish
only the exact package ZIP and adjacent path gate create-new to
`InspectionRevs`. One JBOD launch is authorized after publication. O2A3 must
not rerun.

After the matching signed response returns, inspect the exact installed
proposal/summary-or-hold and source hashes. Only then may a fresh OpenCV engine
revision be built. It must reject unqualified exception texture before
checksum adjudication and pass the accepted V4 15/15 plus 4/4 regression
before another real-wafer request.

The healthy processor, disabled live provider, review-only authority,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, every existing hold, and unseen Slots22-25
remain fixed. O2D5, O2D4, JEO1, CDM1, CDO1, and O2A2 must not run. DFLY3005
remains excluded.
