# OCV-03 O3B10 R18 corpus 427 / eleven fixture regressions inspected

Date: 2026-08-29

Disposition: `PENDING_GATE`

The single signed R18 worker at create-new `C15RUN3` reached a matching
JBOD-signed file-backed `427/953`: 402 unique-notch passes, eleven
multiple-pair holds, fourteen not-found holds, and zero source problems. It
remains active and untouched.

Mechanical comparison against the frozen R15 terminal corpus proves all
fourteen not-found identities are unchanged R15 holds. All eleven
multiple-pair identities are R15 pass-to-hold regressions. Exact signed
`RESULT.json` records and BF/DF review images have been collected and visually
inspected for all eleven regressions.

Every regression has the same image-local explanation: the physical notch is
the bottom pair near 90 degrees with zero exterior brightness/support in both
channels, while the false second pair visibly follows a chuck contact near 134
or 226 degrees. The cyan trace follows the physical wafer perimeter. These are
not pattern responses, chipouts, or edge-detection failures.

The latest PST Break Dielectric Slot06 regression extends the already observed
fixture family without changing its classification. Its true pair is
`89.81299649397312` degrees. Its false chuck-contact pair is
`225.74999950404504` degrees with BF exterior support `1.0` and DF exterior
support `0.5833333333333334`. R18's current both-channel `0.70` fixture-support
requirement therefore does not suppress it. No detector/config correction is
permitted until the corpus is terminal and the complete regression/hold set is
known.

Latest signed summary:

- request: `REQ_20260829T202454426Z_5F5192007675`
- response: `R_9565FA8EE4AF_20260829202521089_fe2d6a8a`
- response ZIP SHA-256: `A1C7BBEF09DAAA1A1A8EE60DF376ED988EAFDBF3A55730FF06589AAF0509B7E0`
- summary SHA-256: `674653E9553C0AB82A6AC15D37CF6EB3FA54A5CE7401142EAA50509C5B402772`

Latest regression evidence:

- request: `REQ_20260829T202722948Z_B1D1CB1C4F2E`
- response: `R_4AFDDDAD5E70_20260829202752980_26366d61`
- response ZIP SHA-256: `76DCB92D58846EBD08E2DFC26AFBB9661D60169E56CFD436F516D49DB1E5D85E`
- Slot06 result SHA-256: `39C56BCA6E76BF1F7DFFF25C3EDC643BD0A79874D9B5BFEDE7DE3EB740DAC15F`

Continue the same worker through signed file-backed summaries. At terminal,
mechanically compare all 953 identities to R15 and inspect every newly surfaced
regression and every remaining hold before freezing the smallest symmetric
fixture-context correction. Do not query/manage/retry/relaunch the worker or
alter completed roots, source bytes, tasks, processes, providers, thresholds,
holds, XML, training, or production state. Preserve every prior prerequisite,
withdrawal, and authority limit.
