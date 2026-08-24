# OpenCV OCV-00 exact source-path resolution checkpoint — 2026-08-24

Disposition: `PENDING_GATE`

Revision: `OCV00_EXACT_SOURCE_PATH_RESOLUTION_OEL1_20260824`

## Outcome

OCV-00 remains fail-closed. The read-only installed-operation inventory and
working-family baseline freeze are preserved from
`work/OPENCV_OCV00/OCV00_READ_ONLY_INVENTORY_DRAFT_20260822.json`, SHA-256
`3C7FAEEE0CF2D7C25E53EF14BE3DA84C352073D9363BF19D9588C13FE1132E2A`.
The operator then authorized exactly one bounded generic metadata-only
exact-leaf capability under the configured JBOD `D:\KLARFExport` root.

The matching signed terminal response proves:

- PFC003 BF and DF are exact contained ordinary leaves with no reparse point
  or reparse ancestor. Each is 475,379,874 bytes. Their current source hashes
  were not acquired.
- The exact catalog PFC010 BF and DF paths are both absent. No fallback,
  alternate instance, or replacement development identity was selected.
- No path enumeration, file-content read, image-byte read, source hash, image
  processing, provider activation, task/process action, processor restart,
  source deletion, or wafer action occurred.

The complete machine record is
`work/OPENCV_OEL1/OCV00_EXACT_SOURCE_PATH_RESOLUTION_20260824.json`, SHA-256
`C75A1144A9B2A3F7B469410C93DC55A3CD528E1A629232F49C96EC80A91CB207`.

## Exact paths

PFC003 BF:
`D:\KLARFExport\PatternedFront\Lot_62628-281\62628-281_20260813112015\Slot02\BrightfieldFrontsideWafer\resizedImage\62628-281_Slot02_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`

PFC003 DF:
`D:\KLARFExport\PatternedFront\Lot_62628-281\62628-281_20260813112015\Slot02\DarkfieldFrontsideWafer\resizedImage\62628-281_Slot02_DarkfieldFrontsideWafer_PM2_resizedImage.bmp`

PFC010 expected BF, observed absent:
`D:\KLARFExport\PatternedFront\Lot_62616-115\62616-115_20260807120245\Slot23\BrightfieldFrontsideWafer\resizedImage\62616-115_Slot23_BrightfieldFrontsideWafer_PM2_resizedImage.bmp`

PFC010 expected DF, observed absent:
`D:\KLARFExport\PatternedFront\Lot_62616-115\62616-115_20260807120245\Slot23\DarkfieldFrontsideWafer\resizedImage\62616-115_Slot23_DarkfieldFrontsideWafer_PM2_resizedImage.bmp`

## Signed execution evidence

- Request: `REQ_OEL1`; exact ZIP SHA-256
  `8EF99A665162C5C1974FB6B448EAE85D817390F5469208CAB0CD5DA4B6648AAA`.
- Response: `R_39E9C66836AD_20260824153249150_8bff586c.ready`; exact ZIP
  SHA-256 `57F64F758A7470E3E26E4D5B5F5C18DE564C763343D846C9890B0F6947BAD44D`.
- Terminal gate: `work/OPENCV_OEL1/OEL1_TERMINAL_RESPONSE_GATE.json`,
  SHA-256 `047E9460EC5E71989FCD952665CF8427914378946DB2752E253D6467FBE9A7CE`;
  state `PASS_OEL1_SIGNED_TERMINAL_RESPONSE`.
- Complete route gate SHA-256
  `30E2A04438770BF9D1515BF9515FC91584EF8A84ACD9C2EF05BBF789F21C95B3`.
- Final package gate SHA-256
  `373B3B57A9DA8690A48B3F77547AB3618A800ABBE9F341D8A2135BF3A404F6F0`.
- Clone-remediation R2 gate SHA-256
  `FD37FB37E525DAB96CA864FBAF9B87C8CDF70AA4901A25667864CC2648E3A5D6`.
- Worker inheritance gate SHA-256
  `5CDC6E515FBC5AAAD35D52BF30B35D249015E4E5D1C532D59C77936E0003ECAD`.
- Six-case entrypoint gate SHA-256
  `B6315433FE0D14D1C1AF3705ED3EF2EAE2E406C73E0A2380202AE4087904D352`.

The first local DRAFT entrypoint rehearsal stopped at the documented
230-character path hard stop before endpoint contact. Its `C:\AO1T` tree is
retained as non-reusable local failure evidence. A fresh `C:\AO1U\OEL1V2`
rehearsal with data root `C:\O1D` passed all six cases; maximum canonical
effective length was 225 and alias effective length was 198. No signed or
published artifact was altered in place.

## Preserved holds and authority

The healthy processor remains untouched. The FSO1 signed running-state
observation remains the processor-health authority; OEL1 performed no task or
process action. R10 and AVS1 remain `WITHDRAWN`. Global FS15, fiducial
composite/registration/scoring, XML, training, production, deletion,
source-deletion, and wafer-abort holds remain unchanged. Review-only authority
is unchanged.

The continuity record previously carried stale SHA-256
`1F23F0C8DDB844E26554C7D1A45627EE34ED99917AA9CC164B6084275DB4C1F1`
for `work/ARGOS_OPENCV_ALL_IMAGE_PROCESSING_MIGRATION.md`. This checkpoint
explicitly corrects that record to the current file SHA-256
`A5E93D72409FD4A5627970EAF4CABDE3AEAC3A088F4394F09649B7B7B19D701C`;
the machine-readable companion remains unchanged.

## Next action

Await operator selection of a fresh replacement PFC010 development identity
or an exact alternate native BF/DF pair. After that identity is fixed, obtain
explicit authority for a separately bounded current-source SHA-256 acquisition.
Do not write or run OpenCV image-processing code until the replacement pair
and exact current source hashes are frozen.
