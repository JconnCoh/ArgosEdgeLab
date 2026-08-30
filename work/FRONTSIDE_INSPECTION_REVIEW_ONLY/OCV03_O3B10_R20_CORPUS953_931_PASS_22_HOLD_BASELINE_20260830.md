# OCV-03 O3B10 R20 corpus 953 / 931 pass / 22 retained holds — 2026-08-30

Disposition: `APPROVED_BASELINE`

R20 completed the exact 953-pair backside corpus at
`D:/KLARFExport/_ArgosReview/C15RUN4`. The terminal signed evidence records 931
`PASS_REVIEW_ONLY_UNIQUE_BACK_BF_DF_NOTCH`, twenty-one
`HOLD_BACK_NOTCH_NOT_FOUND`, one
`HOLD_BACK_NOTCH_CHANNEL_ANALYSIS_FAILED`, zero source problems, and twenty-two
failure rows. Terminal `SUMMARY.json` SHA-256 is
`4852D80B4D1A45063154DE74B538E9279EAAB8B18B71396343F136B84FFB8246`;
`RESULTS.csv` is
`B74B86ED07D9632B61A5B4BB02B61597AC364E132645648202EA92F3138D5DE5`;
`FAILURES.json` is
`01025DACD167930D9C88D1AA364D4CE3AAED27D4819CEC41FCA0864FEF127B71`.

Mechanical comparison covers every identity, terminal state, and shared-pass
angle. Against frozen R18, R20 has 908 unchanged passes, 23 rescues, zero
regressions, 22 unchanged holds, zero changed holds, and a maximum shared-pass
angle delta of exactly 0 degrees. Against frozen R15, it has 898 unchanged
passes, 33 rescues, zero regressions, 22 unchanged holds, zero changed holds,
and the same zero-degree maximum delta. No identity is missing or new in either
comparison.

All 22 `RESULT.json` files and all 44 associated BF/DF review rasters were
collected through one qualified signed pull and inspected before cause was
assigned. Twenty-one wafers have no unique eligible cross-channel BF/DF pair;
their visible fixture contacts, edge texture, or unconfirmed edge irregularity
were conservatively rejected rather than selected as the notch. The sole
channel-analysis hold is
`PST_BRKFULLMETAL/Lot_LotIDStringNotSet/ProcessJob11/Slot25|BACK`: its DF trace
failed radial-profile qualification, so no pose was inferred from that failed
channel. These 22 identities are unchanged holds, not R20 regressions.

The machine-readable terminal analysis is
`work/OPENCV_BACKSIDE_NOTCH_O3B10/R20_TERMINAL_CORPUS_ANALYSIS_20260830.json`.
R20 is accepted as the backside-notch review-only baseline with its explicit
holds retained. This does not clear a wafer hold, authorize tuning from an
unlabeled hold, consume backside results, or grant training, XML, production,
provider, task, process, or processor authority.

Next, return to the already-authorized all-KLARF detector matrix and record the
remaining frontside-notch and scribe outcomes in prerequisite order. Begin
fiducial migration only after that matrix is complete and its required
notch/scribe inputs are frozen. The parked frontside hotspot remains deferred;
all withdrawn/no-retry/non-parent records, stranded-console restrictions,
fiducial/map/pose/alignment gates, and every other existing hold remain.
