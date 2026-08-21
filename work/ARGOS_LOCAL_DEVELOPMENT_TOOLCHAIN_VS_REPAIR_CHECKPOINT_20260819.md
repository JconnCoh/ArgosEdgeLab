# Argos local development toolchain Visual Studio repair checkpoint

Date: 2026-08-19

Disposition: `APPROVED_BASELINE`

Scope: completion and verification of the existing local Visual Studio Build
Tools C++ workload only. This checkpoint grants no detector, wafer, JBOD,
inspection, storage-cutover, XML, training, or production-routing authority.

## Parent and reason

Parent checkpoint:
`work/ARGOS_LOCAL_DEVELOPMENT_TOOLCHAIN_CHECKPOINT_20260819.md`, SHA-256
`C24B6D0611F9B1581FF0921B5D2E4084A5701133C1D5DC022999D8B94843C21C`.

The parent correctly recorded Visual Studio Build Tools instance `66f5335c`
as incomplete after the operator's Chocolatey workload invocation was
interrupted. The exact orphaned elevated helper was already proven idle and
stopped. This additive checkpoint supersedes only that incomplete-instance
status; the parent remains immutable historical evidence.

## Controlled repair

The exact existing target was preflighted before modification:

- installer: `C:/Program Files (x86)/Microsoft Visual Studio/Installer/vs_installer.exe`;
- install root: `C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools`;
- instance ID: `66f5335c`;
- installation version: `18.9.12112.369`;
- prior state: incomplete and not launchable;
- active exact-root installer processes before launch: zero;
- machine reboot-pending state before launch: false;
- C: free space before launch: 38.02 GiB.

The path budget for this checkpoint passed at path length 122, effective
length 154 with the mandatory 32-character suffix reserve, and longest
component length 66.

Only the existing instance and intended workload were addressed:

```text
vs_installer.exe modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools" --includeRecommended --norestart --passive --add Microsoft.VisualStudio.Workload.VCTools
```

The bounded monitor reached terminal state without timing out. No exact-root
`setup.exe` or `vs_installer.exe` process remained. C: free space at terminal
was 36.76 GiB.

## Terminal qualification

Exact `vswhere` and local-file verification returned
`PASS_VS_BUILD_TOOLS_REPAIR_VERIFICATION`:

- instance ID: `66f5335c`;
- installation version: `18.9.12112.369`;
- `isComplete=true`;
- `isLaunchable=true`;
- instance `isRebootRequired=false`;
- exact root qualifies for `Microsoft.VisualStudio.Workload.VCTools`;
- compiler: `C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/VC/Tools/MSVC/14.51.36231/bin/Hostx64/x64/cl.exe`;
- compiler file version: `19.51.36256.0`;
- MSBuild: `C:/Program Files (x86)/Microsoft Visual Studio/18/BuildTools/MSBuild/Current/Bin/MSBuild.exe`;
- MSBuild file version: `18.9.1.35102`.

The actual startup smoke returned `PASS_VS_TOOL_STARTUP_SMOKE` after loading
the exact x64 developer environment. `cl.exe /?` exited zero and reported
Microsoft C/C++ compiler `19.51.36256` for x64. `MSBuild.exe -version
-nologo` exited zero and reported `18.9.1.35102`. No exact-root installer
process remained.

The workstation currently has 24 machine-level pending-file-rename values,
but zero contain a Visual Studio, BuildTools, or Visual Studio Installer path,
and the qualified instance itself reports no reboot required. This checkpoint
does not infer those machine-level values' ownership. A normal workstation
restart may be performed at the operator's convenience, but no restart is
required for this Visual Studio qualification.

The first startup probe used source-free `cl.exe /Bv` under stop-on-stderr.
The compiler printed its correct banner but returned its expected no-input
failure, which PowerShell promoted to `NativeCommandError`. It made no change.
The corrected zero-exit `cl.exe /?` probe passed. The signature, cause,
preflight, and recovery are now recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md` so the probe error is not
rediscovered.

## Preserved authority and next action

Visual Studio Build Tools with the C++ workload is now qualified for local
development and native compilation. The full Visual Studio IDE was neither
required nor installed by this repair. Existing Python, Node, Git,
PowerShell, .NET, VS Code, and plugin states were not reinstalled or changed.

The active Argos phase remains
`JBOD_STORAGE_FINAL_DELTA_TERMINAL_STATUS_GATE`. The JBOD storage copy/hash,
D3, tray restart, C:/D: cutover, source deletion, hold clearance, and C:
recovery gates are unchanged. No detector evidence, wafer result, inspection
task, JBOD file, XML, training eligibility, or production authority changed.
