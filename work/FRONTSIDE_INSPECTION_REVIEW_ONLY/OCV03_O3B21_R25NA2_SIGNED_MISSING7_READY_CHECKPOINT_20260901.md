# OCV-03 O3B21 R25NA2 signed missing-seven ready checkpoint — 2026-09-01

Disposition: `PENDING_GATE`

Fresh R25NA2 preserves the frozen R25 detector, R13 configuration, 24-case
ordering, exact source hashes, and notch-adjacent eligibility rule. Its only
substantive change replaces the disproved all-24 create-new precondition: it
requires and reuses completed R25NA1 ordinals `00-16`, requires `17-23` to be
absent, writes only those missing cases under fresh `D:/R25NA2`, and aggregates
the results without selector relaxation. It neither reruns completed cases nor
embeds raster bytes in the portal response.

Signed request `REQ_20260901T173550248Z_264B5F546DD5`, ZIP SHA-256
`99D91E4A8E39A7240C1E116FCC666A316002583A3A9272F2501BE5F1397A71FD`,
45,958 bytes, passed build, clone-literal, harness, recovery-intent,
zero-recurrence, path, signature, fresh final-ZIP extraction, and packaged-entry
gates. It is not published. Publication is exactly once with no automatic
retry and only after clean matching branch tips and an empty portal request
queue.

NA1/O23 and every later phase remain held pending a matching signed terminal
R25NA2 response.
