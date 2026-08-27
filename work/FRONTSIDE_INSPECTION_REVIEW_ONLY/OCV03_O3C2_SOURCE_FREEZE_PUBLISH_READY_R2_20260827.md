# OCV-03 O3C2 Source Freeze Publish Ready R2 — 2026-08-27

Disposition: `PENDING_GATE`

This R2 checkpoint supersedes the R1 publish-ready checkpoint after the R1
publisher's exact Windows PowerShell 5.1 non-mutating preflight stopped on a
keyword/variable token-boundary defect. The R1 publisher is withdrawn and
non-reusable. The failed preflight performed no share write: the target ZIP,
upload path, and publication gate all remained absent. No publication attempt
occurred.

Withdrawal evidence:
`work/OPENCV_EDGE_NOTCH_O3C2/O3C2_PUBLISHER_R1_WITHDRAWAL.json`, SHA-256
`30AC361BCEC5D0843A6243E56791071AA387D85E2DEAC738B80BB97ABC56A2CB`.
The supersession zero-recurrence audit passed. Contract:
`work/OPENCV_EDGE_NOTCH_O3C2/PREACTION_O3C2_PUBLISH_READY_R2_CHECKPOINT.json`,
SHA-256
`7209E90542BBF9C5296613DBB7596BC31FF93F1713F23ECBB72D37B2508AA3A0`.

The signed request itself is unchanged, valid, and unpublished:

- Request ID: `REQ_20260827T151200111Z_62629419C3F2`
- ZIP SHA-256:
  `14C2408B3644CFC30D09CD0DAB175196EFF5F7254BB792DD1A68DEDAC4781402`
- Final-package gate SHA-256:
  `A3532F4D9604C73FC094D9706E9BA74FE905A5547B3786320EAAFB14D0B2257E`
- Exact-package rehearsal gate SHA-256:
  `10BDA7E7B359E596F7F2E9983470DAB575439AA646ACE905050C4C6EC502D9DF`
- Complete-route gate SHA-256:
  `2BCD47C9F3F06C7941416CE8F453242E52D1E809B6FA2985F56AB553C8CD1033`
- Persistent-`U:` alias gate SHA-256:
  `0D0C574F910F3BC88647DEC3B0519F3E19AF44C24B2BDD7BFF001C29265E96C4`

Create a fresh R2 publisher from the separately qualified O3C1 publisher with
the O3C2 pins, explicit token-boundary correction, and fresh R2 namespace. R1
is withdrawal evidence only and must not be a template or parent. Guard the source and R2
bytes, run clone remediation, scan explicitly for keyword-variable adjacency,
run the exact Windows PowerShell 5.1 non-mutating preflight, and retain one
create-new publication with no retry. Commit/push/fetch and require clean
matching branch tips before publication. Collect only the matching signed
terminal response; gateway acceptance remains non-execution evidence.

The source-freeze provider consumes no known notch location, angle prior, or
fixed angular window. Future detector inference must scan the full perimeter;
known correct locations remain post-inference regression labels only. No
hotspot source hash or pixel result exists yet.

The live provider remains disabled and the protected processor remains
untouched. `SCRIBE_REFERENCE_COVERAGE_HOLD`, the OCV-02 four-of-four
ambiguity/reference/localization/identity hold, Slot25 metadata-disclosed
qualification, `lot62631586FrontGuiRecovery` `PENDING_GATE`, every
map/pose/fiducial/alignment prerequisite, O2D14 withdrawal, and DFLY3005
exclusion remain unchanged. The fresh independent paired BF/DF validation
cohort remains uninspected. Authority remains review-only,
training-ineligible, XML-ineligible, and production-ineligible.
