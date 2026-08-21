# Gateway response-publication repair V1 released checkpoint — 2026-08-17

## State

`GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1` is `RELEASED_REVIEW_ONLY` for one
administrator-run repair on exact gateway `TXSH-DPMZ0295HR`. It is not yet
applied. The 41-file FM7P24A result pull remains unsigned.

The repair is pinned to the operator-audited live state:

- gateway bridge predecessor SHA-256
  `CA10063B850C8355616D0EF4686E83EF68C3AAB70321FC14032209598E5FA033`;
- gateway share-config predecessor SHA-256
  `EED10A33058C75D7764AE096502D8C339BB0D6B6495EE607785C2608F47BA83F`;
- untouched response-receiver-config invariant SHA-256
  `C2317E9C40FB51FDD24F3D765E60BFE2A6F9652C64AE5719FB5F2AFC379FFE5C`;
- share task `ArgosProjectPortal.Gateway.ShareBridge.RO`, interactive user
  `fab.op`, run level `Highest`, and its exact canonical action.

Any computer, file hash, task identity/action, alias collision, path, or
review-only mismatch is refused before mutation.

## Exact package

The published ZIP is 21,479 bytes with SHA-256
`049E65ED47D0F7E7120811F300F96007C669A5E2AC8054368ADBC4656D89551A`.
Its package-manifest SHA-256 is
`D1D1100409DF6278960F2AAE500589E11C92115A3ACF759A041C5B12E8439271`.

The exact ZIP and three machine-readable gates were copied create-new through
a verified persistent short `I:` mapping to the operator-provided
`InspectionRevs` root. Every share hash matched, and the temporary mapping was
removed:

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1.zip` | 21,479 | `049E65ED47D0F7E7120811F300F96007C669A5E2AC8054368ADBC4656D89551A` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1.PATH_PREFLIGHT.json` | 1,005 | `1DDA3E189CFEBD4912D03D308FF4826BDE87DE18ECB95BDC869239CD0A4E8D43` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1.REHEARSAL_PASS.json` | 1,088 | `B4FB0AAEDA25DE900EA3BB8430F47C7D46C9AF6366005E34120554EDD693DD62` |
| `ARGOS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_V1.FINAL_PACKAGE_GATE.json` | 2,242 | `DFBA5381058A2ED10B50CD85B4EA3F47D6955F64134649E311BD1AF4E52E2BB2` |

## Exact final-ZIP rehearsal

The final ZIP was extracted fresh to `C:\GRZ\X1`, its ten files and all
manifest hashes were verified, both exact installed predecessor copies were
exercised, and both extracted wrappers passed. Windows PowerShell 5.1 then
passed eight functional controls from fresh fixture root `C:\GRZ\T1`:

1. non-mutating preflight;
2. exact approved-predecessor apply;
3. task-context alias create/read/delete write proof;
4. only the share task restarted;
5. idempotent target acceptance without a second restart;
6. unapproved hash refusal before mutation;
7. alias-collision refusal; and
8. injected post-replacement failure with exact rollback.

The rehearsal exposed and corrected one Windows PowerShell 5.1/.NET issue:
`File.Replace` rejected a null backup argument. The released repair uses an
explicit bounded backup path, preserves the replaced file, and proved rollback.
The durable prevention rule is recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`.

## Authorized live behavior

The repair creates `C:\APR\S` as a directory symbolic link to the existing
canonical `ProjectPortalRO` engineering-share root, replaces exactly the
gateway share bridge and `gateway_share.json`, and restarts only
`ArgosProjectPortal.Gateway.ShareBridge.RO`. The replacement uses a bounded
`rz_<guid>.partial.zip` temporary leaf while preserving exact final signed ZIP
identity and binds only `shareResponseRoot` to `C:\APR\S\responses`.

The restarted `fab.op` task must itself prove create/read/delete access through
the alias and write a fresh local `WATCHING` status before the repair passes.
The response receiver task/config is never stopped or changed. Any failure
restores both exact predecessors, removes only the exact new alias, restarts
the predecessor share task, and writes rollback evidence. Production routing
remains disabled.

## Operator action

On gateway `TXSH-DPMZ0295HR`, extract the released ZIP to a fresh short local
folder such as `C:\GWR1`. Run `PREFLIGHT_ONLY.cmd` as Administrator. Continue
only after `PASS_GATEWAY_RESPONSE_PUBLICATION_REPAIR_PREFLIGHT`, then run
`RUN_REPAIR.cmd` as Administrator and return the terminal result. A success
writes `C:\GWR\REPAIR_RESULT.json`.

After a live PASS, rerun the complete 41-file route gate before signing the
FM7P24A pull. No detector, alignment, composite, defect, Normal, XML, training,
or production authority changed.
