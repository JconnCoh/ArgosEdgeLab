# GUIR2 signed response available; collector stop checkpoint — 2026-08-22

Disposition: `PENDING_GATE`

## Authoritative boundary

The authoritative repository remains
`C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab` at commit
`bb09223748c446f0b9e38656d80ca996049a3e55`. The healthy AVC1 processor was
not touched. Fiducial work remains paused. R10 and AVS1 remain `WITHDRAWN`.
Global FS15 and all XML, training, production, deletion, image-byte, and
wafer-abort boundaries remain unchanged.

## One bounded read-only request

GUIR2 request `REQ_GUIR2_0822_X1` was published exactly once from signed ZIP
SHA-256 `5DC363E67B3A9DDFA6B431521A11A3EFDA582C40902D2F9896D3079757FE63C6`.
The one-shot publisher recorded zero pending requests before publication,
performed no overwrite, and changed no task, process, installed file,
processor, inspection, or wafer state. No retry or successor request is
authorized.

The request left the queue and its processed archive is present. Exactly one
matching response is present:

- response ID: `R_8F8FC98120E8_20260822175659802_990ddd4c`;
- response ZIP bytes: `455508`;
- response ZIP SHA-256:
  `A2E819087308147239374453A4F257D5A4372050F632A223C7ABCF398D8C1242`;
- signed endpoint state: `PASS_DATA_PULL`;
- result schema/state: `argos_project_portal_data_pull_result_v2` /
  `PASS_DATA_PULL`;
- approved root: `JBOD_PROCESSOR_REVIEW`;
- returned source count: `14`;
- nested payload bytes: `17597071`;
- nested payload SHA-256:
  `980C4CBB6463056B123BCFE99E07B4DD4AC2BAD1E4990F512EC0120DEDE9CB7E`.

Collector C2 verified the matching JBOD signature, outer signed file hashes,
exact request/source role/time identity, DATA_PULL v2 contract, exact fourteen
requested `relativePath` identities, exact fourteen payload `entryPath`
mappings, and aggregate path-budget PASS in memory. Its non-mutating output
projection then failed because it referenced nonexistent general path-gate
property `maxEffectiveLength`.

## Stop boundary

Collectors C1 and C2 are `WITHDRAWN` preflight-only artifacts and cannot be
replayed or used as parents. C1 incorrectly read top-level
`definition.relativePaths`; C2 corrected that schema but guessed the optional
path metric. Neither created `C:\G2R`, a route gate, or a terminal gate. Neither
changed the portal queue, JBOD, a task, process, installed file, source, image,
or wafer.

To prevent a local bug loop, no C3 collector is authorized in this task. The
signed response remains intact on the share. Continue only after explicit
operator direction. A future C3, if authorized, must be a fresh namespace,
must enumerate the exact general `Confirm-ArgosPathBudget.ps1` result property
set before execution, and must not republish or retry GUIR2.

No GUI repair has been built, signed, published, installed, or enabled. The
planned tray callback/timeout reliability fix and all-dates Completed Lots fix
remain pending behind successful local collection and reconciliation of these
fourteen signed current sources.
