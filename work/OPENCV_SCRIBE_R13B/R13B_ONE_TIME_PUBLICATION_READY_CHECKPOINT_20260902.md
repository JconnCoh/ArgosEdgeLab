# R13B one-time publication-ready checkpoint

Created UTC: `2026-09-02T22:06:40.7308755Z`

Classification: `FROZEN_REVIEW_ONLY`

State: `READY_FOR_EXACTLY_ONE_AUTHORIZED_R13B_PUBLICATION`

## Isolated source

- Worktree: `C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab-scribe-opencv`
- Branch: `codex/opencv-scribe-deciphering`
- Pre-R13B branch tip: `50ed6cfa7596c24ac369fcc3531d0aea20fd5073`
- Publication is permitted only after the commit containing this checkpoint and every pinned R13B artifact is pushed, local and origin tips match, and the worktree is clean.
- The canonical Desktop checkout, ea39, c290, the targeted-backside lane, detector code, tasks, queues, processes, and unrelated JBOD state remain out of scope.

## Exact request

- Request ID: `REQ_20260902T204408092Z_R13B`
- Signed ZIP: `work/OPENCV_SCRIBE_R13B/final/REQ_20260902T204408092Z_R13B.ready.zip`
- ZIP bytes: `59619`
- ZIP SHA-256: `E03EF601339101663E4AABC1889A08C9DB92005F84F56DB3CF08955C8325A889`
- Request manifest SHA-256: `19EC131F8C73D8CBAB835776BA4390FECA5E8AF164D3C77224A61ACA5EDF9F77`
- Request signature SHA-256: `556CEAEFDB5961DCD94F66A24CF5CD789286941E3C9D950C793B9CBFCA44E19F`
- Target role/job class: `JBOD` / `MAINTENANCE_PATCH`
- Laptop signer thumbprint: `C82181052919C475CF888F49427C1B55AE65DC12`
- Official signed-package verification: `PASS_SIGNED_PORTAL_PACKAGE`

The final ZIP has exactly nine entries: seven manifest-bound payloads, the request manifest, and its signature. Every payload byte count and SHA-256 matches the signed manifest. Duplicate build/extraction trees were removed after verification; the immutable ZIP and all gates remain unchanged.

## Frozen provider and live invocation

- Provider `ArgosOpenCvScribeAlphabetCropR13B.py`: `995587862B6FA280C1D48907254AA82B5C4120F4B26A10CFE559A1E27BD9E0B3`
- Endpoint `Invoke-R13BAlphabetHarvest.ps1`: `4E7A7BFAE134FF8867F9D606ECB9B7BB32B51885D2594A3D0712FD150B4FBAE2`
- Configuration: `1F58C66A18C4ED58B5ED3EEE27BACF9D65948140F8609A194CFE8A68501D6F42`
- Live invocation: `34BE97AEB60E726666A18DB1AB4556A4C38DFBB91518ED0C2C145C131FDC10B9`
- Exact cases: `K25V`, `X18V`, `JQ16D`, `JQ20V`
- Runtime: `D:\AFCV1\rt`; installation SHA-256 `1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596`
- Reference ZIP SHA-256: `56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6`

## Current publication and collection chain

- Final package gate: `CA7644B6C4E89D4E8CEEB53651B6AE80FF6F9DD254A015787CCB7C5C7837BCF2` — `PASS_R13B_FINAL_SIGNED_PACKAGE`
- Complete route gate R3: `235034A7B75669F6E8DD6731EA407932901B4CCD46679E48C21A5BDB6250A47F` — 209 paths, maximum effective length 193.
- Current route/package/tooling binding gate R3: `BC5370F045471C9B49307F054897A5A37EBEBECB955149595891D36361B84212` — `PASS_R13B_COMPLETE_ROUTE_PACKAGE_AND_CURRENT_TOOLING_BINDING_GATE_R3`
- Endpoint clone-remediation gate: `5AFFA1AEB0BA998458B30C57F9CE683E6812F280C44EDC12BF13486E383EBFEB` — PASS.
- Package-tooling clone-remediation gate R3: `C5C0C5A5F89D6CDB22C069094DB40CDFBFC7202D96E8265A5F53F979A34DF714` — PASS.
- Zero-recurrence preaction R3: `F5C3B27D05509AE441502469BB7065CFF1B02BD4A4B6521F23587696634B7FE2` — 47 dependencies and ZERO/ONE/MANY collection cases PASS.
- Tooling supersession gate R3: `67D69283583A23FA1AE11F2B6728115C4C14267583FD4BB01E5ACE2E743B2A0C` — only the R2B/R3 publication chain is current.
- Publisher `Publish-R13B_R2.ps1`: `5698FDE56FD9FE3B3F96A4E283009D9FB56B71E74DCE3A0A699BAACCCB322939`
- Publisher invocation: `3AF365CCE4631C179C6A2FA008D2C1BA514A9D4968C4D840E242A11771D45F7C`
- Collector `Collect-R13BResponseR2.ps1`: `556FC3FDD0B174D1ED1BBA752F044A13619EFDE2C00FA17C2FA534822695E5E0`
- Collector invocation: `8C28C2DE0750A92FB36FE5854826037DDBCEDD4D2AE89DD553848D4037CBD09F`
- WinPS 5.1 collector rehearsal gate R2B: `11A6567907C71F73C4C9FC3FFCDEA7D7E6E2DDCF003ED345B2152ED8A5B3BAF3`

The collector rehearsal used Windows PowerShell 5.1 and `ZipFile::CreateFromDirectory`. It proved the raw nested name `CASE01\CASE_RESULT.json`, proved that native forward-slash `GetEntry` returns null, read the exact nested bytes through the normalized unique resolver, and rejected undeclared, directory, and separator-normalized duplicate entries. The publisher emits the exact collector, collector-invocation, and rehearsal-gate hashes into the create-new publication gate; live collection refuses to proceed without that exact gate.

## Independent audit

Independent read-only audit passed with no current artifact, code, signature, gate, or path blocker. It verified PowerShell harnesses/wrappers, clone remediation, zero-recurrence preaction, 210 local path/hash/state bindings, all JSON and Python parsing, exact signed-ZIP closure and payload hashes, and the Windows PowerShell 5.1 nested ZIP behavior. Project continuity also returned `PASS_ARGOS_PROJECT_CONTINUITY` without modifying global backside continuity records.

## Authority and next action

Publication authority is limited to one create-new publication of this exact ZIP. Retry and overwrite are not authorized. Review-only is true. Automatic identity acceptance, reference admission, training, XML, production, production routing, provider activation, source mutation/deletion, task/process restart, and hold clearance remain false.

After commit/push and clean/equal branch verification, run one fresh read-only queue observation. If it passes, run the exact R2 publisher once. Do not republish. Treat gateway processing as acceptance only. Wait for exactly one matching signed terminal response, collect it with the exact R2B collector, verify the JBOD signer thumbprint `DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC`, then inspect and checkpoint only the compact returned grids/cells/crops and provenance.
