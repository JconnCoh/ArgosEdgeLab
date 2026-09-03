# OCV-03 O3F13 signed R10 results / two provider holds / O3F14 next — 2026-09-03

Disposition: `PENDING_GATE`

O3F13 request `REQ_O3F13_20260902A` was published exactly once from commit
`696ced76ba580261764b1e2af85862bcdc82996e`. Publication gate SHA-256 is
`2B4CE80849856D7D6248052F6916977AF43B635E7C719594E4AA7C5AB87870C7`;
request ZIP SHA-256 is
`6CD1551EB5E7B71FD58542E6313B9528DB37E2CA35884B4BA3BAB39CBB701063`.
Matching signed response `R_01BB3D1DD345_20260903050345709_42ca30c9`, ZIP
SHA-256
`EEF55807A793D685AD8548E3183DFC19961FC9225E4D79C3E450BE55A5B9ABED`,
was collected with signature verified. Frozen response invocation SHA-256 is
`7E5B4862590D74B63BD6782157F02CF651B9F2B0792817B34042F60A8A4F2599`;
collection gate SHA-256 is
`05BFFB010EFA370112ECD1B4295F5EBB606FE97ED0DE66F2EF14EE62B8AA06FF`.

The endpoint completed and correctly returned the structured DEV6 exit-2
hold, validating the O3F13 result-projection correction. All six cases were
selected, four executed, and two became explicit provider holds. Exact state
counts are three
`PASS_REVIEW_ONLY_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCH_CANDIDATE`, one
`HOLD_MULTIPLE_R10_SYMMETRIC_LOCAL_CROSS_CHANNEL_NOTCHES`, and two
`HOLD_O3F12_R10_PROVIDER_ERROR`.

- `PatternedFront/Lot_62615-962/62615-962_20260830004716/Slot02|FRONT`
  retains the multiple-candidate ambiguity hold.
- `PatternedFront/Lot_62616-131/62616-131_20260825233731/Slot09|FRONT` and
  rare-hotspot
  `PatternedFront/Lot_62629-419_NotchBad_Hotspot/62629-419_20260824112405/Slot16|FRONT`
  retain provider holds. Both failed identically with `KeyError:
  'leftAngleDegrees'` in `candidate_mouth_interval` because the DF candidate
  did not propagate the required mouth start/end fields.

O3F13 is terminal and no-retry. Its projection contract passed, but R10 and
all returned outcomes remain diagnostic and are not an advancement or
publication parent. The three diagnostic passes do not clear prior holds.
O3F9 through O3F12 retain their withdrawn/no-retry/non-parent status.

Draft R11 at `work/O3F8/FullPerimeterWaferTopologyOpenCvR11.py`, SHA-256
`B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059`,
changes only exact DF start/end propagation plus its documentation revision.
Local runtime, dual-seed microtest, and the existing five-case synthetic gate
pass. That gate is `C:/A11T/SYNTHETIC_GATE.json`, SHA-256
`A4A85A46B61701EA9973DA768AF77D5240A682DBE4D1085FAF14BEAB21F8D937`.
R11 is not yet frozen, packaged, signed, published, or executed on the O3F14
six-case set.

All 184 O3F6/O3F7 holds remain explicit, including all twelve current
`PatternedFront` holds, Slot02 ambiguity, and rare-hotspot Slot16. Every
earlier backside hold and every scribe, fiducial-designation, map, pose,
coverage, sensitivity, registration, and alignment prerequisite remains in
force. No threshold or selector relaxation and no automatic hold clearance
are authorized. Review-only is true; training, XML, production eligibility
and routing, source mutation/deletion, provider activation, task/existing-
process action, and wafer action are false.

Next action: finish the permanent R11 regression without broadening its
two-field propagation fix, then build, fully gate, sign, and publish exactly
one fresh O3F14 six-case request through the recorded Project Portal route.
Collect only its matching signed terminal response; no RustDesk/manual
PowerShell input or retry. Only a lawfully returned complete six-case result
may advance targeted frontside BF/DF reconciliation; continue afterward in
recorded order to scribe, combined corpus/unified outputs, and site-bound
fiducial/alignment prerequisites. Production scoring remains blocked.
