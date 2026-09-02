# R13B one-time publication-ready correction checkpoint — 2026-09-02

State: `PENDING_GATE` — corrected local publication tooling is ready for commit, push, clean-state verification, publisher preflight, and the already authorized one-time publication.

## Scope and authority

- Request: `REQ_20260902T204408092Z_R13B`
- Branch: `codex/opencv-scribe-deciphering`
- Review-only sample collection; no identity acceptance, training, XML, production, routing, provider activation, source-image mutation, or retry authority.
- Maximum publication count: one.

## Frozen request bytes

- Package: `work/OPENCV_SCRIBE_R13B/final/REQ_20260902T204408092Z_R13B.ready.zip`
- SHA-256: `E03EF601339101663E4AABC1889A08C9DB92005F84F56DB3CF08955C8325A889`
- Bytes: `59619`
- Disposition: unchanged.

## Queue-observer correction

The original observer is withdrawn for publication because it scanned unrelated pre-boundary response ZIPs and required response timestamps to follow request timestamps. Portal correlation is instead the cryptographically signed exact request ID.

- Current observer: `Get-R13BCurrentShareObservationR2.ps1`
- SHA-256: `DCF2CB7B8ADE3B4D7FEEFE06F3E80AB01D1904990F08B2F4975EC9015F58ACE6`
- Invocation SHA-256: `079AA083683F9DA823E09642EF6FDA28ECE14874DAB2306E963EEB99E6526C01`
- Scan scope: `POST_PROVEN_ZERO_UNRESOLVED_BOUNDARY_ONLY`
- Correlation: `SIGNED_EXACT_REQUEST_ID`
- Correction gate SHA-256: `4FC86B805C64DA6B30348FEE21724BA4009A3AB87757C6A6CAF145C33F521421`

## Read-only route evidence

- JBOD endpoint observation SHA-256: `5A202B19968B02CA529C8E8BEC517A40E025A01A833ACB4B307FC5073A2921DC`
- Argos return-hop observation SHA-256: `63A3720F7DEEA2B3CA33D5AFF810F4CB282425BECDB394E96625725C5B75ABFC`
- Mutations performed: false.

Exact terminal correlations:

- `REQ_20260902T001500111Z_62619433S22M` -> `R_9D03623E2FC6_20260902001636908_a563741d` -> `PASS_STATUS_COLLECTED`
- `REQ_20260902T002400222Z_62619433S22P` -> `R_BA4CA7F9EB86_20260902001958594_9008033c` -> `FAILED`
- `REQ_20260902T003000333Z_62619433S22S` -> `R_01635D36C4B9_20260902002230623_f8d07c71` -> `PASS_DATA_PULL`

## Fresh current-share gate

- Evidence: `R13B_CURRENT_SHARE_OBSERVATION.json`
- SHA-256: `D01BDE41622D69A421935C52180975D7489CD0184E41489A2584025E2FC60A15`
- State: `PASS_R13B_CURRENT_SHARE_AND_QUEUE_OBSERVATION`
- Accepted after frozen boundary: 18
- Resolved accepted requests: 18
- Unresolved: 0
- Ambiguous: 0
- Pending: 0
- Target request absent from pending, processed, and responses: true.

## Publication binding

- Publisher: `Publish-R13B_R2.ps1`
- Publisher SHA-256: `5698FDE56FD9FE3B3F96A4E283009D9FB56B71E74DCE3A0A699BAACCCB322939`
- Current invocation: `Publish-R13B_R3.invocation.json`
- Invocation SHA-256: `9852BF01161C09C4AD35F20A06C722DF6CD170BB406982992BB1A19613522BB5`

## Exact next action

1. Validate these new local records and scripts.
2. Commit and push the isolated correction; require local HEAD and origin equality and a clean worktree.
3. Run the exact publisher `-Preflight` with the R3 invocation.
4. If and only if it passes, invoke `-Publish` exactly once.
5. Monitor only `REQ_20260902T204408092Z_R13B`; do not retry.
6. Collect and verify only its single matching signed terminal response.
