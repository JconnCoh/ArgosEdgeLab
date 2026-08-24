# OpenCV OCV-00 OLS3 Response Available / Pending Signature — 2026-08-24

Disposition: `PENDING_GATE`

`REQ_OLS3` was published exactly once through the established Project Portal
gateway after continuity, session, path, recurrence, queue, uniqueness, and
local/GitHub branch-tip gates passed. Local and remote tips both matched
`ecbda3205852550d7f9fdb4a4daf99b4a001e7da`. The create-new publish-gate
SHA-256 is
`8B0CE8CF044A28D8CFC79CB14A5970F2AEC73955DC4C907083CF3286FF5396D5`.
The gateway consumed the request; no retry is authorized.

One matching response is available as
`R_8D14080FA339_20260824191035127_9bace42e.ready.zip`, 10,299 bytes, SHA-256
`E71DA6D107335F4E6A21C698C513CE96708949F909C09CBF6C78B1607B979D06`.
Its bounded outer manifest identifies `REQ_OLS3`, source role `JBOD`, and
`PASS_MAINTENANCE_PATCH`, but those fields remain untrusted until verification
with the pinned JBOD signing certificate.

Unsigned diagnostic parsing indicates a metadata-only
`HOLD_INCOMPLETE` result with 131 directory rows, 40 BMP-leaf rows, and
`UNSAFE_PATH_SUBTREES_SKIPPED`. These values are not accepted as evidence yet.
They will be reported only if the exact signed response and the full
metadata-only row contract verify.

The next action is one create-new local collection at `C:\A3R`, pinned
signature verification, and exact terminal contract validation. Do not retry
or republish. No source image bytes or source hashes were read, no image
processing ran, no task/process was changed, and the healthy processor and all
existing holds remain unchanged. The migration order remains OCV-00, OCV-01,
OCV-02 scribe, OCV-03 perimeter/notch/global pose, then OCV-04 fiducials.
