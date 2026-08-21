# Gateway context audit V1 released checkpoint — 2026-08-17

## State

`GATEWAY_CONTEXT_AUDIT_V1` is `RELEASED_REVIEW_ONLY` for one non-mutating
administrator run on the Project Portal gateway. It is not a gateway repair
and grants no detector, alignment, composite, defect, Normal, XML, training,
or production authority.

Direct repair from the current workstation is unavailable. The workstation is
`TXSH-LUPW0JLTPR`, has no local `C:\ProgramData\ArgosProjectPortalRO`
installation, and has no configured WinRM session. Bounded probes to gateway
address `10.20.70.242` found no reachable SMB 445, WinRM 5985/5986, RDP 3389,
or portal transport 48718 connection. Engineering-share access is queue access,
not administrative execution on the gateway.

## Released artifacts

All four artifacts were copied create-new through a verified persistent short
`I:` mapping to the operator-provided `InspectionRevs` root. Every final share
hash matched its local source, and the temporary mapping was removed.

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `ARGOS_GATEWAY_CONTEXT_AUDIT_V1.zip` | 8,846 | `F4A736FA9F80FD20ADF6EBAB80670290F7FAADB03D2F348749517518A6C310F0` |
| `ARGOS_GATEWAY_CONTEXT_AUDIT_V1.PATH_PREFLIGHT.json` | 1,606 | `87711C4827CE38B81F287A263679D5213A767C13D4210662F37A1D84BB0F085D` |
| `ARGOS_GATEWAY_CONTEXT_AUDIT_V1.REHEARSAL_PASS.json` | 829 | `806C8C9ADF9F18BF5A3020CA6D21DA98BD512B8957DB593B52D2540A2EC09381` |
| `ARGOS_GATEWAY_CONTEXT_AUDIT_V1.FINAL_PACKAGE_GATE.json` | 1,651 | `3818A2FF972FF4070F1EA5F1AEC8F0EF2EE4C1D35862029C9BCD088552655AE8` |

The ZIP package manifest SHA-256 is
`3EC123815E058E4C699F4A78B221D95577D2EB839353A7BB5A3584CC5314FF70`.

## Exact-package gates

- The complete source tree and every planned local/package path passed the
  32-character-reserve path budget with no component above 80 characters.
- Both exact `.cmd` wrappers passed the mandatory PowerShell wrapper gate in
  the source tree and again after final-ZIP extraction.
- The exact 8,846-byte ZIP was extracted fresh to `C:\GZAT\X1` and exercised
  under Windows PowerShell 5.1 against fresh fixture root `C:\GZAT\F1`.
- All seven functional checks passed. The audit measured the legacy
  92-character staging leaf and the canonical 244-effective-character share
  upload route, refused an output collision, and changed no installed fixture
  content.
- The earlier isolated source rehearsal fixture at `C:\GAT\A1` remains on the
  workstation because automated cleanup was policy-blocked. It is not used by
  or included in the released ZIP.

## Audit scope and next action

The audit reads and hashes only the installed gateway share bridge and its two
bounded JSON configurations, captures the two gateway scheduled-task
principals/actions/states, enumerates current filesystem/network mappings and
the candidate `C:\APR\S` alias state, and writes only
`C:\GWA\GATEWAY_CONTEXT_AUDIT.json`. It does not read credentials or secrets,
stop or start tasks, edit configurations, create an alias, execute a portal
request, or enable production routing.

On the gateway, extract the released ZIP to a fresh short directory such as
`C:\GWA1`. Run `PREFLIGHT_ONLY.cmd` as Administrator and, only after its PASS,
run `RUN_AUDIT.cmd` as Administrator. Return the bounded terminal output. The
result will pin the actual installed predecessor/config hashes and exact task
identity needed to build the separately rehearsed gateway repair. Do not sign
the 41-file FM7P24A data pull before that repair passes the complete route gate.
