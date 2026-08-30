# OCV-03 O3B10 R18 full corpus launched / initial 26 with two fixture regressions

Date: 2026-08-29

Disposition: `PENDING_GATE`

## Signed launch

R18 launched exactly once at create-new
`D:/KLARFExport/_ArgosReview/C15RUN3`.

- request: `REQ_20260829T194621614Z_066B18809964`
- response: `R_1468946CF833_20260829194739387_a13c1b54`
- response ZIP SHA-256: `DE602F6FAD3750EC67AC71492B96AD204CA3F783FDD5D63ABFB9D50E386E0ECD`
- endpoint: `PASS_MAINTENANCE_PATCH`
- launcher: `PASS_O3B10_R18_BACKSIDE_CORPUS_ALL_LAUNCHED`
- owned worker PID evidence: `33528`
- owned worker creation UTC: `2026-08-29T19:47:36.3197969Z`
- existing task/process action: false
- source mutation/deletion: false

The PID is evidence only. The worker must not be queried, managed, relaunched,
or retried. Progress is observed only through signed file-backed summaries.

## Initial signed summary

- request: `REQ_20260829T195000166Z_D5C7EADD6E5B`
- response: `R_AD837A5F73BF_20260829195031703_b4681929`
- summary SHA-256: `60A27930A44CE0F1CB278834A46E3D55FD8447AD8159D11C44C526DE1045E724`
- observed: `26/953`
- unique notch passes: `24`
- holds: `2`
- source problems: `0`

Both holds are exact R15 pass-to-hold regressions and were inspected before
any tuning:

- `BackSide_BowComp/Lot_62625-956/.../Slot23|BACK`
- `BackSide_BowComp/Lot_62625-957/.../Slot25|BACK`

Signed evidence request `REQ_20260829T195230945Z_747B04101BF5` returned
response `R_F7A9415C7F3A_20260829195257971_b3c3d305`, response ZIP SHA-256
`9C3C83E5926C9319D18CB518C55AE997B80C5ADF519998BA74E95DAAC647963B`.

The BF/DF review images show the physical notch near 90 degrees and a
chuck-contact lookalike near 226 degrees. The physical candidates have zero
exterior brightness in both channels. The false contact candidates have
strong BF exterior support but only partial DF angular support (`0.5625` and
`0.4375`), below R18's current both-channel `0.70` fixture threshold. This is
an image-proven fixture-contact suppression boundary, not pattern response and
not a reason to alter perimeter tracing.

## Next action

Continue the same R18 worker to terminal completion through file-backed signed
summaries. Mechanically compare every terminal identity to R15. Pull and
inspect every new regression and every remaining hold. Only after the complete
family is known may one fresh detector revision make the smallest image-local
fixture-context correction and rerun frozen regressions. Preserve all prior
holds, prerequisites, and authority limits.
