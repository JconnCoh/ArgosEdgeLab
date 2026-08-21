# Front-metal D7 V17 R5P23A signed-JBOD path-alias recovery checkpoint

Date: 2026-08-15  
Revision: `FM7V17R5P23A`  
Parent: `FM7V17R5P23`  
Disposition: `PENDING_GATE`

The first signed JBOD request,
`REQ_20260816T012422561Z_13AD0BF27492`, was accepted by the portal and
returned the independently signed response
`R_8D90644C12ED_20260816012633931`. The response state is `FAILED`; the
runner stopped before native-source hashing, output creation, or composite
processing because the exact canonical `D:` source paths required a verified
short alias under the mandatory Windows path budget.

Failure evidence:

- response-manifest SHA-256:
  `5B601C2959F9013905DD89DB7CCC1CF7581886B823407062280F1AE5E56DDF6F`;
- failure-record SHA-256:
  `1D878214E10EBDDA7D0536035B43B7790E366C492F0D3B9614162B5103C29A54`;
- exact stderr SHA-256:
  `BF662CE5E06E7F1455B56B5BF136E28147ADEC7760E5038FB6ABE16D7CE2687F`;
- exact refusal: `Path gate failed:
  SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH`;
- stdout bytes: 0;
- defect/composite output created: false;
- inspection evidence produced: false.

That request is `WITHDRAWN` and will not be edited, replayed, or republished.
The portal's maintenance rollback preserves the failed request evidence and
removes its declared newly installed diagnostic files.

R5P23A changes only JBOD execution-path orchestration. A fresh signed
dispatcher now selects an unused drive from R through Z, creates `subst` for
the unchanged canonical source root, queries `subst.exe` without a drive
argument, requires exactly one mapping back to the canonical root, and hashes
the same first 1 MiB of one locked native source through both path spellings.
Only then does it create a bounded temporary invocation whose source root is
the short alias and call the unchanged packaged `RUN.ps1` under Windows
PowerShell 5.1 with `-NoProfile -ExecutionPolicy Bypass -File`. The dispatcher
uses neither `-Command` nor `Start-Process`.

On a successful run it preserves the exact runtime invocation and writes
`PATH_ALIAS.json` beside `AUDIT.json`, recording the canonical and alias roots,
mapping line, sentinel relative path, byte count, matching prefix hashes,
invocation hash, and `imageContentChanged=false`. The temporary package-local
invocation and `subst` mapping are removed in `finally`. A failure never
becomes the required all-wafer PASS state.

The frozen R5P23 executable, package manifest, contract, R5P21 evidence,
R5P22 evidence, 12-target/11-reference rule, transforms, thresholds, masks,
and review-only authority are byte-unchanged. The portable FM7P23 ZIP remains
SHA-256
`1C62151CE9EEA9641FEF55C0D88B89A1821B4329DF65C459712B54B2D5CE58F4`.

Recovery request:

- request ID: `REQ_20260816T013035046Z_29506570B1E1`;
- signed manifest SHA-256:
  `E987D04EF94B0FFD5B717BBD2DDE1B4C995841C5BCF0F3451B8B4F39730E7668`;
- signature SHA-256:
  `013D515B716BFB662266166BE550C390960805A6372CA6A970D5284A221FD306`;
- definition SHA-256:
  `358F979693EFFB300CB72FAF19930808F38F6EC926722015612C5AF434FEB8A9`;
- dispatcher SHA-256:
  `B765C83F01ACC6E0F02F0E6A84F62BE86AC71E17F2B05A6B6E1159A168FA76A0`.

The dispatcher parses under Windows PowerShell, the exact `subst` query and
byte-identity method passed a local rehearsal, all 17 signed payload files
match their declared installed hashes, all destination paths pass with a
maximum effective length of 195, and the required endpoint state remains
`PASS_FM7P23_ALL_12_TARGETS_PROCESSED_WITH_TARGET_EXCLUDED_COMPOSITES_REVIEW_ONLY`.

The separate portal-publisher temporary-component defect was corrected before
any share write by using a short GUID-only private local temporary name. The
unchanged first request then passed an exact local signing/publication
rehearsal. This client-side correction is recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`; it does not alter any signed
request ID or payload.

The next action is exact local publication rehearsal of the fresh recovery
request, signed share publication without overwrite, and verification of its
signed JBOD response. No detector, M3, V16, canonical reviewer, strict-chipout
sibling, deferred stroke, stitch, XML, or production authority changes.
