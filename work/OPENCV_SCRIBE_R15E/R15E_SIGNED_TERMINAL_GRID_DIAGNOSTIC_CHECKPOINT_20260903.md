# OCV-02 R15E signed terminal grid diagnostic — 2026-09-03

Classification: `DIAGNOSTIC_ONLY`
Disposition: `PENDING_GATE`

The operator-authorized R15E request was published exactly once. Request
`REQ_20260903T124500000Z_R15E`, ZIP SHA-256
`8016B63D69CE01972079378FE66556D3733C17BEC6AAA21452FC74C4BEA2CAB7`,
was accepted by the gateway at `2026-09-03T12:55:29.3637467Z`. No retry or
second publication occurred or is authorized.

The matching JBOD response is
`R_DFC67231460F_20260903130325702_19f6600d`, response ZIP SHA-256
`2E424D1DCC9AC1E0C2ACD0E2EFE14725432EEF03B8242A70C5A4F53DA76FC1E5`.
The pinned standard verifier passed the RSA-SHA256-PKCS1 signature from JBOD
signer `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`; all three signed response
leaves match their declared byte counts and hashes. Endpoint state is
`PASS_MAINTENANCE_PATCH` and the maintenance envelope state is
`PASS_R15E_SIGNED_RETURN_READY`.

The returned evidence bundle is 2,664,060 bytes, SHA-256
`80F15BF86251EA57576FB12869CC579BADD2DAFC5546FEDD744D049A568E76C0`.
Its exact 30-entry set and every declared artifact hash passed. Batch gate
`F26FDB2CD16AC9812BB5E1E48AC85AD873334F50390EF75808A6972356100DCB`
reports `PASS_R15E_BATCH_COMPLETE`; execution
`74AD037D3F41699302F0E27B2650FD195C5E3F03ED672CAA28862DBD3624B812`
reports `PASS_R15E_EXECUTION`. All four providers completed, all four exact
source pairs were hash-verified, and OpenCV decoded all four pairs.

## Returned case evidence

| Case | Physical source | Frozen region | Returned evidence |
|---|---|---|---|
| K25V | `62546-481_20260707164232_Slot25` | `PERIMETER_SMOOTH_DF_BRIGHT_00` | 1600×400 BF/DF plus 32 grid hypotheses |
| X18V | `62625-907-PRE_20260709123021_Slot18` | `PERIMETER_SMOOTH_DF_BRIGHT_02` | 1600×400 BF/DF plus 16 grid hypotheses |
| JQ16D | `62625-956_20260729122701_Slot16` | `PERIMETER_SMOOTH_DF_BRIGHT_02` | 1600×400 BF/DF plus 16 grid hypotheses |
| JQ20V | `62625-956_20260729122701_Slot20` | `PERIMETER_SMOOTH_DF_BRIGHT_00` | 1600×400 BF/DF plus 16 grid hypotheses |

Visual inspection of the exact returned rasters establishes that all four BF
rectified regions contain the complete, plainly visible scribe; the DF regions
also contain it. Localization is therefore not the present failure. The
remaining failure is grid/character scoring and incomplete frozen reference
coverage (`IJKOQVWXYZ`). R15E intentionally proposes and accepts zero
identities. All four cases remain
`HOLD_R15E_DIAGNOSTIC_EVIDENCE_RETURNED`.

The prepublished R2 collector was not used to accept the response because it
applies its 16-entry R15E transport limit to unrelated historical response
ZIPs before request-ID correlation. That produced a local false-positive stop
on an older response. The matching R15E response itself has the exact expected
five transport entries. Collection instead used bounded exact-request
correlation, in-memory signature/hash validation, the pinned canonical
verifier, safe create-new local extraction, exact bundle-entry closure, and
OpenCV raster decode checks. No portal or JBOD mutation was used to work around
the collector defect.

Terminal collection gate:
`work/OPENCV_SCRIBE_R15E_RESPONSE/R15E_EXACT_SIGNED_RESPONSE_COLLECTION_GATE.json`,
SHA-256 `221A0845750BEED6228712002C1741CD57EF0EE51C6CEDCE20610D043EDBB0E0`.

This is safe terminal review-only diagnostic evidence. It is not identity
acceptance, reference admission, training, XML, production, provider
activation, source mutation/deletion, task/process action, or hold clearance.
The next detector action is a fresh local draft correction to grid/character
scoring using these returned rasters and existing lot-derived labels, followed
by a bounded real-image regression. Publication is complete and must not be
retried.
