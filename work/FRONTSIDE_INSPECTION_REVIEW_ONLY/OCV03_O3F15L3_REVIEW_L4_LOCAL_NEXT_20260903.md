# OCV-03 O3F15L3 stop-loss workflow review / O3F15L4 local next

Date: 2026-09-03

Disposition: `PENDING_GATE`

## Mechanical finding

The second signed premise failure is classified by
`work/OPENCV_EDGE_NOTCH_O3F15L3/O3F15L3_FAIL_CLASS.json`, SHA-256
`657ACE8E03F4BB24B42D3B08F1B25DE17F17FFCCC11C6F2F08EE4AE7B7598DC2`.
The immutable Slot19 BF canonical provenance path is 207 characters; with the
frozen 32-character reserve its effective length is 239, so direct use remains
forbidden by the unchanged hard stop. The intended child input is the `Q:`
alias, whose effective length is 146 and must continue to satisfy the unchanged
exclusive `<200` alias budget.

Exact runner `DCE1E1F3B42FBD38ED73FF7D346F19C3BAE013EE3003B3485E91A41DAF573C48`
calls canonical `is_file/stat` and the asserting direct-use budget before it
creates the alias. R11 later receives only `aliasPath`, but frozen alias code
`CAAFD1AC8C19E33D95BA8283963A4D0ED0189FF566C9923822BF3EC37956171E`
would then call `os.path.samefile(aliasPath, canonicalPath)`. L4 therefore may
reuse only its low-level mapping/query/create/remove primitives, not its
`owned_case_alias` context. The 239-effective canonical leaf must remain a
lexical provenance string and never be filesystem-touched.

All 265 current PatternedFront and UnpatternedFront rows precede the 713
historical rows. Reaching this BackSide_BowComp row therefore proves the same
path planner traversed all current rows. The planner is fail-fast, so the
complete historical alias-required set is not yet enumerated and must be a
machine gate before any build or live action.

## Workflow decision

Observation
`E80112B31B8DD36FD1ABCB461CA5CE9FD3131F95F6EF4B8F4104511C526B0E2C`,
path gate `82E1976283C138FE8FFB00F1AC299BC20330D901C2B3F7438E96B6D62923B879`,
and workflow review
`9B68606B1B0D06B7FE28072221D1E87BA31D9479CF1AE0F26AA269C4F23E94DE`
select the smallest design:

- Predeclared path holds are safe but overconservative because they turn
  immutable provenance length into a detector/source hold even though the
  provider can receive a safe alias with exact mapping and lexical-suffix proof.
- A physical same-hash staging copy is broader: it adds source-byte reads,
  writes, capacity, collision, rollback, retention, and cleanup premises while
  providing no shorter child path than the existing alias.
- O3F15L4 must remove canonical `is_file/stat`, use a lexical measurement, and
  record effective 239 as `directUseAllowed=false` and
  `verifiedShortAliasRequired=true`. Effective length below 200 is direct-safe;
  200 through 229 requires an alias; 230 or greater is a direct-use hard stop.
  An O3F15-owned context must pre-gate the short slot root and alias, verify the
  exact normalized mapping plus lexical relative suffix, use alias-only
  `is_file/stat`, pass only `aliasPath` to unchanged R11, and remove only its
  owned mapping. No canonical `samefile`, source-path hold, or physical copy is
  allowed. Frozen O3F14 and R11 remain unchanged.

Fresh recovery intent
`754DCC0D57D8483B2021061E642D8C73710E09A6CE71463FF5BA92C96BB528C8`
passes exact PS5.1 recovery gate
`D6F5AEEAB213AF19B3DADAD75400511B1C28F8B25DB68AB778529910C219DF1E`:
two signed failures are proved and mutation stop-loss is false only for one
fresh local DRAFT correction plus its synthetic/file-backed path test.
Checkpoint preaction
`C11FDF98D076C335A1679180057D9C9631935D6709E61E18127CADF3023BE845`
passes.

No O3F15L4 source, package, signature, portal request, process, output root, or
image result was created or executed. Build, signing, publication, live
execution, image reads, source mutation/deletion, existing task/process action,
provider activation, selector/threshold change, retry, and automatic hold
clearance remain unauthorized.

## Preserved state and exact next action

All 184 frontside holds and all twelve current PatternedFront holds remain,
including Slot02 ambiguity and rare-hotspot Slot16. Every backside, scribe,
combined-output, fiducial, map, pose, coverage, sensitivity, registration, and
alignment prerequisite remains ordered and explicit. Review-only is true;
training, XML, production eligibility, and production routing are false.

Next action: create exactly one fresh local DRAFT O3F15L4 runner and focused
test implementing lexical-only canonical classification and the O3F15-owned,
zero-canonical-touch alias context above. Test effective boundaries 199, 200,
229, and 230 plus exact mapping, lexical suffix, alias-only metadata, cleanup,
and child/job path controls without image reads. Do not alter O3F14 or R11, and
do not build, sign, publish, or live-execute. Before any later build,
mechanically enumerate all 978 frozen rows with zero unknown, duplicate, or
omitted identities. Any later live work must use the recorded signed Project
Portal route without operator input. Do not use RustDesk.
