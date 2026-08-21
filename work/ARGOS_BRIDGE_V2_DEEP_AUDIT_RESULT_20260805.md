# Argos Bridge V2 deep-audit result

Source: operator-returned `DEEP_AUDIT_RESULT.json`

Source SHA-256:
`6D9A040378BBA1DCFFA61E3B80C35F460AD980A519E92770E7BF2E0C4B8CC3BD`

## Confirmed

- Host: `DESKTOP-266P787`, administrator audit, zero errors and zero changes.
- `C:\ArgosBridgeTest` exists, is empty, is owned by
  `DESKTOP-266P787\lwm`, and retains inherited broad ACLs.
- No `ArgosBridgeTest` SMB share exists.
- SMB2 is enabled; SMB1 is disabled.
- TCP 445 listens on the wildcard address and SMB reports the Review,
  MueTec FabNet, and Customer FabNet interfaces.
- The existing `ArgosAuto` share remains unchanged.
- Both required interfaces use the Public network category, while the Public
  Windows Firewall profile is disabled.
- The enabled built-in SMB rule is scoped to `LocalSubnet`, but it is not an
  effective source restriction while the active firewall profile is disabled.
- The Argos still has no IP forwarding, RRAS, ICS, or network bridge.

## Decision state

`HOLD_ARGOS_BRIDGE_INSTALLATION_FIREWALL_NOT_ENFORCING_SOURCE_SCOPE`

Do not run the V1 Step 2 installer. Adding narrow firewall rules would not
enforce the advertised restriction. Enabling the Public firewall profile is
not authorized because it could interrupt existing tool, motion-control,
remote-access, or ArgosAuto traffic.

The deep-audit JSON represented the dedicated local user and group as empty
objects, so their existence, provenance, and safe reuse are unresolved. Do not
reset an account password or replace group membership without an explicit
follow-up audit or operator confirmation.

Safe candidates are:

1. a credential-restricted encrypted SMB test share, accepting that source IP
   is not enforced by Windows Firewall; or
2. an application relay bound explicitly to `172.16.0.11` and
   `10.20.70.241`, avoiding a new SMB share.

No system change has been approved between these alternatives yet.
