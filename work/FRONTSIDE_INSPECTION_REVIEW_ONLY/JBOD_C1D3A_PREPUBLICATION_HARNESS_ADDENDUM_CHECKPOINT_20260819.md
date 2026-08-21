# JBOD C1D3A prepublication harness addendum checkpoint — 2026-08-19

Disposition: `PENDING_GATE`

Parent checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/JBOD_C1D3A_TRAY_METADATA_CONSUMER_PACKAGE_READY_CHECKPOINT_20260819.md`,
SHA-256
`1ED80D6C2BA32A7BB242E1BA85A7C6B577BC21E1BC533E2BF50AC910F878ADD2`.

## Reason for addendum

After the parent checkpoint, the C1D3A publication preflight repeated a
documented PowerShell provider failure: `Join-Path` attempted to resolve a
planned `U:` leaf before `New-PSDrive` created the alias.  The preflight failed
before mapping, upload, publication, or any local evidence write.

The publisher now composes the planned `U:` leaf provider-independently, reads
the portal queue through the exact UNC root, creates and exact-root-verifies
`U:` only inside `-Apply`, and removes only the mapping it created.  Its exact
non-mutating preflight passes with zero pending requests and proves no `U:`
mapping or publish gate was created.

## Prevention revision

- Updated failure memory SHA-256:
  `DEBEC9549224F24C97AB23DB0D5EBCBB9B843DED475BA7F51281C41B98DE1F5E`.
- Updated C1D3 failure-prevention audit SHA-256:
  `1E58A69E2F23AEE91097064799E3C2E4CB124244AD9F6F5DCA61A0A117748801`.
- Updated harness-safety guard SHA-256:
  `51AD2182FDAE06440E9B85617C3E96056A8C07EFF9BE62132EBF01EADDCA1311`.
- Publisher SHA-256:
  `A0EF3E47710C41114D7553C55D959453F25A93450AED6CB1ABE4619B247F18E9`.

The harness guard now rejects `Join-Path` use of a variable assigned to a drive
that the same script declares through `New-PSDrive`.  Wrapper and harness
safety both pass on the corrected publisher.  Publication preflight reports
`PASS_C1D3A_PUBLISH_PREFLIGHT`, `pendingRequests=0`,
`pathState=PASS_PATH_BUDGET`, and `mutationsPerformed=false`.

## Package and authority unchanged

The signed request manifest remains
`1050E8A7FE5B5B0F5F40A31FB9DF625355D64E80CE7BB7F9BA717D87F6C90DB1`.
The exact 12,423-byte ZIP remains SHA-256
`FF5796221F1B24AB3975A21D03FA3C4BA4A13AF4C04445F7D9D6A4ACCD300CFD`,
and its final gate remains SHA-256
`37E78DE6B4736F540FC5F23A527114256609F9EB3FA80BDFCF61BC025FCFFDC4`.

`REQ_C1D3A` is still unpublished.  No JBOD file, task, hold, D: path, C: source,
detector evidence, or wafer changed.  Migration remains limited to exact Argos
inspection roots and never includes the entire C: drive.

## Next action

Run continuity and session safety again, rerun the exact publisher preflight,
then publish only `REQ_C1D3A`.  Require its matching signed terminal response
and installed tray target hash.  Do not restart the tray, clear the storage
hold, publish D3, cut over a path, delete a C: source, or abort a wafer.
