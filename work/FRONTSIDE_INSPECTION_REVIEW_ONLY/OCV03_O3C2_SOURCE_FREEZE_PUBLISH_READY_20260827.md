# OCV-03 O3C2 Source Freeze Publish Ready — 2026-08-27

Disposition: `PENDING_GATE`

The bounded O3C2 provenance-only source-freeze request is signed and ready for
one publication. It has not been published, accepted, or executed. No hotspot
source hash has yet been collected and no hotspot image has been decoded.

The checkpoint-promotion zero-recurrence audit passed as
`PASS_ARGOS_ZERO_RECURRENCE_PREACTION`. Contract:
`work/OPENCV_EDGE_NOTCH_O3C2/PREACTION_O3C2_PUBLISH_READY_CHECKPOINT.json`,
SHA-256
`C55087C11534062B62A3E420DE53376F04C1753C3BB9C8A9D11ECAE09206D984`.

## Exact frozen request

- Request ID: `REQ_20260827T151200111Z_62629419C3F2`
- Signed ZIP:
  `work/OPENCV_EDGE_NOTCH_O3C2/final_o3c2/REQ_20260827T151200111Z_62629419C3F2.ready.zip`
- ZIP SHA-256:
  `14C2408B3644CFC30D09CD0DAB175196EFF5F7254BB792DD1A68DEDAC4781402`
- Request manifest SHA-256:
  `AD876FFA4E09564AB99D39DFA6DAEA72F7CA1996A8994792EB8EE0E2AB3FB1AE`
- Request signature SHA-256:
  `8D2289B39387861997B277DFF2DD94F4591B57F888A6DDD6B00CBCA01386D731`
- Final-package gate SHA-256:
  `A3532F4D9604C73FC094D9706E9BA74FE905A5547B3786320EAAFB14D0B2257E`
- Exact-package rehearsal gate SHA-256:
  `10BDA7E7B359E596F7F2E9983470DAB575439AA646ACE905050C4C6EC502D9DF`
- Complete-route gate SHA-256:
  `2BCD47C9F3F06C7941416CE8F453242E52D1E809B6FA2985F56AB553C8CD1033`
- Current zero-pending persistent-`U:` observation SHA-256:
  `2C69A5A6C23F516399B133C61C279B191E7DE0314C8643284759E283C36CC633`
- Persistent-`U:` alias gate SHA-256:
  `0D0C574F910F3BC88647DEC3B0519F3E19AF44C24B2BDD7BFF001C29265E96C4`
- Frozen recovery-intent SHA-256:
  `C10DBBBECD1B5E63C8238C02A3D99275885E6D8334F88704433227174A7A8F2B`

The exact signed package passed Windows PowerShell 5.1 parsing, signature and
payload verification, absent-provider creation, target-hash idempotence,
unapproved-predecessor refusal, a 10-pair/20-leaf success rehearsal, and an
injected failure rehearsal. The injected failure wrote no result and removed
the temporary drive alias. The complete 44-row request/response route is below
the effective path hard stop; maximum planned effective length is 187 and
maximum component length is 53.

## Algorithm-integrity boundary

The source-freeze provider is generic and manifest driven. It consumes no
known notch location, notch-angle prior, or fixed angular search window. O3C2
only computes exact SHA-256 and acquisition fingerprints for the 20 frozen
frontside BF/DF leaves. It does not decode images or score pixels.

For subsequent detector work, every detector inference must scan the full
wafer perimeter without a known-angle input. Known correct notch locations may
be used only by the post-inference regression scorer to measure error. They
must never become a detector prior, crop/search constraint, threshold source,
candidate filter, or tie-breaker. This prevents the regression oracle from
poisoning production behavior.

## Exact next action

Commit and push this exact publish-ready state, fetch `origin`, and require a
clean worktree with matching local and remote
`codex/fiducial-opencv-d-drive` tips. Then rerun the clone, harness, wrapper,
zero-recurrence, exact Windows PowerShell 5.1 non-mutating publisher preflight,
continuity, and metadata-only session-safety gates. Publish request
`REQ_20260827T151200111Z_62629419C3F2`, ZIP SHA-256
`14C2408B3644CFC30D09CD0DAB175196EFF5F7254BB792DD1A68DEDAC4781402`,
exactly once through persistent `U:` with no retry. Gateway acceptance is not
execution evidence. Collect only its matching signed terminal response. If it
passes, freeze the exact 20 source hashes and 10 acquisition fingerprints,
then begin OpenCV V2 detector development on the frozen POST2
development/known-failure cohort before decoding the hotspot challenge lot.

The live provider remains disabled and the protected processor remains
untouched. `SCRIBE_REFERENCE_COVERAGE_HOLD`, the OCV-02 four-of-four
ambiguity/reference/localization/identity hold, Slot25 metadata-disclosed
qualification, `lot62631586FrontGuiRecovery` `PENDING_GATE`, every
map/pose/fiducial/alignment prerequisite, O2D14 withdrawal, and DFLY3005
exclusion remain unchanged. The fresh independent paired BF/DF validation
cohort remains frozen before inspection and uninspected. Authority remains
review-only, training-ineligible, XML-ineligible, and production-ineligible.
