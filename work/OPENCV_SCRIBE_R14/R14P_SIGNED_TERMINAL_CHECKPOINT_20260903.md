# R14P Signed Terminal Checkpoint — 2026-09-03

State: `PENDING_GATE`

## Isolation and authority

- Worktree: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv`
- Branch: `codex/opencv-scribe-deciphering`
- Publication tooling parent commit: `db432ce`
- Review-only execution. No identity acceptance, automatic reference admission, training, XML, production routing, provider activation, hold clearance, source mutation/deletion, or task/process restart.
- The frozen R14P request was published exactly once. No request retry occurred.

## Exact publication and signed response

- Request: `REQ_20260902T204408092Z_R14P`
- Frozen request ZIP SHA-256: `AE6FA994449ADF478ABF6EA6A0551D0C9E09CAE28F0D4B73B9B21570DD987900`
- Publication state: `PASS_R14P_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW`
- Publication UTC: `2026-09-03T12:01:04.9789030Z`
- Response: `R_EBC95A67AB32_20260903120903951_4583d653`
- Response ZIP SHA-256: `E0D7510A65931CDB036E3E63F17A315A442E18C69D239EE1362E2F5D514D8D7A`
- Endpoint state: `PASS_MAINTENANCE_PATCH`
- Source role: `JBOD`
- Signer thumbprint: `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`
- Signature verified: `true`
- Returned bundle SHA-256: `CDBF65F8BF1FE91A486BABD0CC9707BF3672CCAF087124E9C38F279C36A6E534`
- Collection gate: `work/OPENCV_SCRIBE_R14_RESPONSE_R4/R14P_EXACT_RESPONSE_COLLECTION_GATE.json`
- Collection gate SHA-256: `5A9CAD7C1868F2945B36435B5A77D8BA7F1AA7462434E3B7B37DE7E382633511`
- Collection state: `PASS_R14P_EXACT_SIGNED_TERMINAL_RESPONSE_AND_BUNDLE_COLLECTED`

## Execution result

- Batch gate SHA-256: `4FD1631429960DD3674D7A9F8511E83CDF0116986908A874899D9B6BD198EA36`
- Execution SHA-256: `30DE35E213DFBD3378DF0161019AADD22CCD0CCC7F9D76EBFD8B9D63BD9E12D6`
- Four of four provider children completed; four of four decoded pixels; zero launch failures.
- All six full-perimeter candidates, both BF/DF channels, and both directions were evaluated for every case (24 region/channel/direction attempts and 192 grids per case).
- All four cases ended `HOLD_R14_GRID_NON_TARGET_TRUTH_MISMATCH`. No proposed scribe and no alphabet reference admission are authorized.

| Case | Truth | Selected image-first string | Non-target truth matches | Selected source | Selected grid SHA-256 |
|---|---|---|---:|---|---|
| K25V | `13DCK076SUG1` | `47666A76SUG1` | 6/11 | DF forward, smooth candidate 00 | `299D971993A2CDEBFB98B39FEEF49D4043E5EC68B87DB13C4D2599654CD76676` |
| X18V | `146XF111SUG7` | `16606EE1E2E7` | 4/11 | BF forward, smooth candidate 02 | `BF86CB9102E8D00AF0A58154AA2CB41A30D954FB68EC0F06DA6BD5633CE57901` |
| JQ16D | `147JQ122SUB6` | `121911L6E1A7` | 2/10 | BF forward, smooth candidate 02 | `5A6101C4C761CF932B0942E6F68995ED48D1455074DF5F66A95FF3EC412DEA39` |
| JQ20V | `147JQ117SUD6` | `0414401EA1E6` | 3/10 | BF reverse-180, smooth candidate 00 | `422A9C13A92A73363FE9460AC2F65D4F5DD1DC9D28D778B8C4FDAAFFBD35B641` |

## Interpretation and next action

R14P successfully exercised the intended bounded real-image matrix, but candidate/grid selection did not locate the true 12-character scribe grid in any of the four cases. The returned selected-grid rasters visibly contain sparse dot structures, yet the non-target canonical mismatch proves they are the wrong grid alignments or wrong perimeter regions. This is useful detector evidence, not a successful alphabet-library expansion.

Next action is local detector analysis against these exact signed case records and selected grids, followed by a fresh detector revision. R14P itself is terminal and must not be republished or retried.
