# OCV-03 O3F14 R11 DEV6 signed portal ready — 2026-09-03

Disposition: `PENDING_GATE`

Fresh review-only request `REQ_O3F14_20260902A` is frozen and signed but has
not been published or executed. Request ZIP SHA-256 is
`BD45851010D4683218DA3F431CBCF37FED3799BCA7FF2BA4D9698230FA26C9A4`;
manifest SHA-256 is
`F1AF92C99E6477861BF175FB37EFB4ACDFD4E5DA5BA8F80FAC52CCA405379C5D`;
signature SHA-256 is
`E7DB5308834347F33F15EB62C3917E512E1E0DEC4A80DB1110B27B1C2283B947`.

R11 at `work/O3F8/FullPerimeterWaferTopologyOpenCvR11.py`, SHA-256
`B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059`,
changes only preservation of the DF seed `startAngleDegrees` and
`endAngleDegrees` fields through the existing `R6_BF_DF_PHYSICAL` and
`R6_DF_ONLY` reductions, plus the provider revision text. It does not change
thresholds, eligibility, pairing, holder exclusion, result selection, or any
post-result selector. Exact staged runner
`work/O3F8/Run-O3F14Staged.py` is
`CAAFD1AC8C19E33D95BA8283963A4D0ED0189FF566C9923822BF3EC37956171E`;
the permanent focused regression
`work/O3F8/Test-O3F14R11SeedAngles.py` is
`03EBD2130C17FEA0DDDEB36F3A5E75DAA0014440734C7767690E2A47348435AA`.
Local focused, dual-seed, and synthetic assertions pass.

The exact endpoint rehearsal gate SHA-256 is
`F068228C654CFA83FB69DEE47B07DE0A344D7780929ED11F9F7C98AA2F213C02`.
It covers successful and structured-hold exits, injected failure, timeout and
owned-alias cleanup, malformed/two-object/stderr rejection, and preoccupied
`Q:` refusal. The final package gate SHA-256 is
`46FED06B6EE6035B905FE91D48821DA301B26C4541B79C5BCAB4E5F99606D2A8`;
the exact Windows PowerShell 5.1 package rehearsal gate SHA-256 is
`CD788368AEA454DC71DD0AAF184AF3AD9819A3473A82DB4BF7912ACD20AAC87F`.
It verified all 16 payload hashes, the signed ZIP, approved predecessor,
idempotent target, unapproved predecessor refusal, and both exit-0 and
structured exit-2 result paths.

The complete route gate SHA-256 is
`C9FFC71C2A80D83CE3393AAEAD037A00E4AC63144E4B15C5C83ADAA2950FE373`.
It passed 2,602 constructed leaves, including all 24 BF and all 24 DF
candidates per case, four assets per candidate, partial and final JSON,
synthetic outputs, and success and quarantine roots. Maximum planned effective
length is 227 only at the locked canonical source and therefore requires the
recorded short alias; all 12 actionable alias rows pass and maximum actionable
effective length is 193. Maximum component length is 72. Corrected clone
accounting gates are
`14E5DD18C550E2105A919FA76A7F13FB3DF8449E59588D14A64E4221E2A97F6A`
and
`47F08112CBDB8AF8121F547BBCF3652A4E0A7A13A4F69B9F8581229EAA3C147B`;
O3F13 is authorized only as a proven source-structure clone and remains
non-reusable and non-parent for publication or advancement.

Read-only share observation SHA-256 is
`6E8EAE1AEBFA903948FA665CF9ECE21210EA7C8567E4440C9B35D9A65B57A69D`.
It proves the recorded persistent `U:` mapping, zero pending portal requests,
zero unresolved accepted requests, and signed terminal closure for O3F9
through O3F13. No RustDesk, clipboard, PowerShell GUI, operator Enter, source
image read, or remote mutation was used for this observation.

O3F13 remains terminal/no-retry and R10 remains diagnostic/non-parent. All 184
O3F6/O3F7 holds remain explicit, including all twelve current
`PatternedFront` holds, Slot02 multiple-candidate ambiguity, and rare-hotspot
Slot16. Every backside hold and every scribe, fiducial-designation, map, pose,
coverage, sensitivity, registration, and alignment prerequisite remains in
force. No hold is cleared by a selected or executed O3F14 case.

Review-only is true. Training, XML, production eligibility and routing,
provider activation, source mutation/deletion, existing task/process action,
wafer action, threshold relaxation, selector relaxation, automatic hold
clearance, and retry are false.

Next action: commit and push the exact gated bytes, then publish O3F14 exactly
once through the unchanged recorded Project Portal route and collect only its
matching signed terminal response. Do not use RustDesk or request manual
operator input. If the unchanged route fails once, stop that execution attempt
and report the exact blocker without retry or infrastructure redesign. Only a
lawfully returned complete six-case result may advance targeted frontside BF/DF
reconciliation; continue afterward in recorded order to scribe, combined
corpus/unified outputs, and site-bound fiducial/alignment prerequisites.
Production scoring remains blocked.
