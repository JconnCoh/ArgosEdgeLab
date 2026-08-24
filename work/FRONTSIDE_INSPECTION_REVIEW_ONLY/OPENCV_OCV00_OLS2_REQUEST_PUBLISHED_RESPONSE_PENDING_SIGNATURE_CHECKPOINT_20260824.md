# OpenCV OCV-00 OLS2 Request Published, Response Pending Signature Checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

The authoritative Desktop repository was on
`codex/fiducial-opencv-d-drive`; local and GitHub tips both resolved to
`ecbda3205852550d7f9fdb4a4daf99b4a001e7da` immediately before publication.
The exact create-new `REQ_OLS2` ZIP was published once at
`2026-08-24T17:31:02.6281226Z`. Its SHA-256 is
`D72CE5040E0EADF624A80A536BFCE7DE2755AD6264E556BCD558A657C7CF23FE`,
its publish-gate SHA-256 is
`F7B6671E9990AA3E46A1678B04C2E8A257C544EC36033B41A190D69F667CAB31`,
and the gateway consumed it into the share's processed directory.

A matching response ZIP is present:
`R_CC18FEEA00BD_20260824173017440_aae41c8c.ready.zip`, 2,248 bytes,
SHA-256
`D6C4C56ECEA086FE29CB31704E1BA61E783E0D887EE6A9827B597E2225C84673`.
Its bounded manifest names `REQ_OLS2` and carries an untrusted `FAILED` state.
That state is not yet accepted because the pinned JBOD signature has not yet
been verified and the exact failure files have not yet been collected.

No retry, duplicate, or successor request is authorized. The next action is
one create-new local collection through the failure-only signed-response
collector, followed by exact failure classification. Collection may copy and
extract only this pinned response ZIP into `C:\AS2F`; it must not touch JBOD,
read lot file contents or image bytes, hash source images, process pixels,
change a task/process, restart the healthy processor, delete a source, or act
on a wafer.

All PFC003/PFC010, replacement-lot exact-pair, bin/null-clue-only,
fiducial-site, global FS15, notch, map, pose, composite, registration,
defect-scoring, reviewer, R10/AVS1, XML, training, production, deletion, and
wafer-action holds remain unchanged.
