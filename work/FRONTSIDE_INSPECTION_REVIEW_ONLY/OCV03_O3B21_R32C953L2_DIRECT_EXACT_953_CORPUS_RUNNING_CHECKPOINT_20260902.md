# OCV-03 O3B21 R32C953L2 direct exact-953 corpus running

Disposition: `PENDING_GATE`

R32C953L1 is withdrawn/no-retry. Exact read-only failure evidence proved it
stopped before its first image at `2026-09-02T00:27:44Z` because the selection
wrapper compared all discovered sides against the frozen 978-BACK inventory
before the unchanged corpus runner applied `--side BACK`. Current metadata has
1,956 pairs: all 978 pinned BACK identities remain, exactly 978 FRONT identities
were added, zero identities were removed, and source-problem count is zero.
The R32 detector did not fail.

The bounded correction filters pairs and source problems to BACK before the
frozen identity/path comparison. Wrapper
`work/O3B21/Run-R32Frozen953Corpus.py` SHA-256
`062AB46FD238AF85EAD2CEDD0FC34E0162D0D10272546D0D12D55263834F14BA`
and its mixed-side regression test SHA-256
`986F40DD9E92CDA2FD9D565549C8625213FC8CCACE9CC3CA79AD64E5D98D3271`
pass locally. Detector R32 SHA-256
`2E9D19DDCCCA751C21C545AF5E2B6AB62596E86891374AB0E13C84BEDEA48012`
and config R13 remain byte-for-byte unchanged.

Under the operator's explicit quickest-completion authority, exact-host direct
control prepared only fresh runtime `D:/R32C953L2RT` and launched one owned
review-only worker under fresh output `D:/R32C953L2`. Preparation command
SHA-256 `E9FF9FADD6F23B9C7F17B51BDC878EF9FF3EF228EF689094AB2D5D462274DA8C`
and launch command SHA-256
`CA9AF893C43F09346138B74FCBB8D3A020BA627768F1679AF4BA102A2CA8168B`
both returned exact-host PASS. Worker PID `30804` was created at
`2026-09-02T12:31:48.2177164Z`.

The first post-enumeration observation, command SHA-256
`79A1E712C93A74B0EBDA2CFEDA9206F8A722ABE49F2B6B05D069F3D2C6E56A65`,
proved PID 30804 remains present with `SUMMARY.json` at 16 completed pairs,
three explicit holds, and empty stderr. This passes the exact L1 failure point.
Counts are preliminary until the complete 953 result is observed.

No source image was modified or deleted. No existing task/process was acted
on, no provider was activated, and no hold was cleared. Review-only remains
true; training, XML, and production remain false. Next action is one bounded
read-only completion observation after the owned worker finishes, followed by
complete backside comparison with every explicit hold retained, then the
recorded frontside, scribe, combined-corpus, and fiducial/alignment sequence.
