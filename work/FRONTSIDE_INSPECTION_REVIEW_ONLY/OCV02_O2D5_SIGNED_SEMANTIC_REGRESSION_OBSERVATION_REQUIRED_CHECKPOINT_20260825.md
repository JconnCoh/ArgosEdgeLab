# Argos checkpoint — OCV-02 O2D5 signed semantic regression; installed-proposal observation required

Date: 2026-08-25

Revision: `OCV02_O2D5_SIGNED_SEMANTIC_REGRESSION_20260825`

Disposition: `PENDING_GATE`

## Signed terminal evidence

O2D5 ran exactly once on JBOD `A1025645101`. Its preflight pinned the frozen
engine, reference bundle, job, BF, and DF hashes and passed. The bounded child
completed without any installed task/process restart, provider activation,
source mutation/deletion, wafer action, hold clearance, XML, training, or
production action.

The matching signed response is cryptographically verified:

- request: `DIRECT_O2D5_20260825T190855Z_54B4C08C`
- response: `R_ADD3BF802E2F_20260825193812855_dbc9bb56`
- response ZIP bytes: `67,852`
- response ZIP SHA-256:
  `A1EF71116AB6571DC537A66A2ECD85A8E828DECA4F9F1C466760E632B9BDC4A4`
- signed manifest SHA-256:
  `867547FCCB653842ACDD5FD8A1909712AB73F2220A915271952A69A89264DCF6`
- result SHA-256:
  `F26875AA38B5346B9F3AEC0A6A2F6B75E0D69A972E94A0E8DDC39E21B63ED4B3`
- run-gate SHA-256:
  `3C1AF40B7774FE2B1A1F0B77830AE99A0FDD3230389D30E9467F515A347E8A6B`

The immutable collection gate at
`work/OPENCV_SCRIBE_O2D5/O2D5_TERMINAL_RESPONSE_GATE.json` correctly proves
signature, payload hashes, source provenance, and protected invariants. Its
downstream `slot16DevelopmentFrozen` and `slot17Authorized` booleans were
premature and are withdrawn by the separate semantic adjudication. The
collector and that gate are non-reusable.

## Semantic regression

The engine reported image-first string `699F999999F6` with a checksum-valid
M12 pair, but `eligibleIdentity=false`, with zero accepted hypotheses and zero
accepted candidates. The operator rejected treating that far-off string as a
credible scribe read.

This was not a missing-library failure. O2D5 used the same accepted
456-reference manifest SHA-256
`AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229`
and the accepted reference coverage remains intentionally incomplete only for
`IJKOQVWXYZ`.

The exact regression is localization and decision precedence:

- the live job contained zero pose-bound expected regions;
- the selected region came from whole-image exception texture at score
  `0.544673502445221` and state `UNQUALIFIED_DEVELOPMENT`;
- OCR grid score was sorted ahead of localization confidence;
- no localization-confidence threshold rejected the exception candidate;
- standard and exception results were combined into one winner list;
- 124 checksum-valid strings remained; and
- the reference-coverage hold masked the localization-confidence and
  multiple-valid-candidate failures.

That violates the locked accepted baseline, which requires qualified
notch/pose-relative localization, distinct exception-search disposition,
native-crop authority, preserved image-first evidence, and mechanical parity
with the accepted V4 reader. The accepted reader's frozen current-corpus gate
is 15/15 correct top physical-holdout proposals with 4/4 duplicate-view
agreement.

Semantic-adjudication SHA-256:
`9CF9D0B843D08F3A16C18F2282D7645EF0A0EA9BB3CDDC201786A6CA9F002E0E`.
O2D5 is `DIAGNOSTIC_ONLY`, executed, withdrawn, and non-reusable. Slot16 is
not frozen. Slot17 is not authorized.

## Provenance correction

The executed package and signed result used the correct 64-character DF hash:
`6FAC812536C19F07D1C3DAD5263741350E94460A07867F2AEE0D2EEEA8C19ED9`.
The earlier frozen-ready checkpoint and continuity record omitted characters
from that textual DF hash. The package ZIP/job hashes remained exact, and the
live preflight proved the correct source. The earlier checkpoint is therefore
non-reusable as a publication parent and is superseded by this checkpoint.

## Exact next action

Recovery is `OBSERVE`. Build and fully gate one fresh direct-admin read-only
package that derives the installed helper/proposal paths from the exact
installed caller and collects only current-acquisition Slot16 JSON/source-code
metadata: proposal, multi-channel reader summary or hold, caller/helper hashes,
and declared crop paths/dimensions. It must not read, hash, copy, decode, or
return image bytes; must not start/stop/restart a task or process; and must not
change the queue, ledger, provider, source, wafer, or hold state.

Only after that direct observation is pinned may the OpenCV implementation be
changed in a fresh namespace. A corrected implementation must reject
unqualified exception texture before checksum adjudication and pass the
accepted V4 15/15 plus 4/4 regression before another real-wafer request.

Review-only authority, disabled live provider, healthy-processor preservation,
`SCRIBE_REFERENCE_COVERAGE_HOLD`, and every existing hold remain. Slots22-25
remain unseen. O2D5 must not rerun. O2D4, JEO1, CDM1, CDO1, and O2A2 must not
run. DFLY3005 remains excluded.
