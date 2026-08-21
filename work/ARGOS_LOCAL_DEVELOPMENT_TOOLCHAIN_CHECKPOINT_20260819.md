# Argos local development toolchain checkpoint

Date: 2026-08-19

Disposition: `APPROVED_BASELINE`

Scope: local development-computer tooling and Codex plugin availability only.
This checkpoint grants no detector, wafer, JBOD, inspection, storage-cutover,
XML, training, or production-routing authority.

## Verified local programs

| Capability | Verified version | Exact usable entry point |
|---|---:|---|
| Visual Studio Code | 1.124.2 | `C:/Program Files/Microsoft VS Code/bin/code.cmd` |
| Node.js | 26.7.0 | `C:/Program Files/nodejs/node.exe` |
| npm | 11.19.0 | `C:/Program Files/nodejs/npm.cmd` |
| Git for Windows | 2.55.0.windows.4 | `C:/Program Files/Git/cmd/git.exe` |
| PowerShell | 7.6.5 | `C:/Users/joshua.conn/AppData/Local/Microsoft/WindowsApps/pwsh.exe` |
| .NET SDK | 10.0.400 | `C:/Program Files/dotnet/dotnet.exe` |
| Chocolatey | 2.7.4 | `C:/ProgramData/chocolatey/bin/choco.exe` |
| System Python | 3.14.7 | `C:/Python314/python.exe` |
| Argos Python | 3.13.2 | `C:/ArgosPy313/Scripts/python.exe` |

PowerShell 7 uses the current winget MSIX layout and was smoke-tested through
its registered WindowsApps alias. It coexists with Windows PowerShell 5.1;
Windows PowerShell 5.1 remains mandatory for JBOD compatibility and exact
package rehearsals. The .NET 10.0.400 SDK and Node/npm/Git/VS Code entry points
all returned their expected versions. No reboot-required registry marker was
present after installation.

Node 26 is usable for local tooling, but it is a Current release rather than
the originally recommended LTS line. Do not use its unpinned version as
production runtime authority; project package locks and explicit engine gates
remain required.

## Argos Python environment

The short, isolated environment is `C:/ArgosPy313`. It deliberately uses the
existing Python 3.13.2 base for broad wheel compatibility; the separately
installed system Python 3.14.7 remains available but is not the Argos analysis
interpreter.

Installed and verified distributions:

| Distribution | Version |
|---|---:|
| numpy | 2.5.2 |
| opencv-python-headless | 5.0.0.93 |
| scipy | 1.18.0 |
| scikit-image | 0.26.0 |
| Pillow | 12.3.0 |
| lxml | 6.1.2 |
| pytest | 9.1.1 |

`pip check` reported `No broken requirements found`. A synthetic 32 by 32
local array containing one square produced 60 OpenCV Canny edge pixels;
`smokePass=true`. No wafer image or binary task payload was read or emitted.

## Visual Studio Build Tools interruption

The user-initiated Chocolatey chain successfully installed Python 3.14.7 and
the Visual Studio Build Tools bootstrapper. The subsequent
`visualstudio2026-workload-vctools` modifier ended with Windows status
`-1073741510` (`0xC000013A`). Chocolatey's terminal log marked the command
abnormal and an elevated `setup.exe` remained after its parent exited.

The exact orphan was PID 26860 at
`C:/Program Files (x86)/Microsoft Visual Studio/Installer/setup.exe`, with
recorded parent PID 25912 absent and zero CPU delta over five seconds. Only that
exact orphan was stopped. Visual Studio inventory then reported instance
`66f5335c`, version `18.9.12112.369`, state 13, `isComplete=false`, and
`isLaunchable=false`. MSBuild and x64 `cl.exe` files are present, but the
workload has no successful terminal qualification and is not Argos authority.
The interrupted workload was not rerun because it is not required for the
current Python wheels, PowerShell, or .NET SDK.

The failure signature, preflight, and exact recovery are recorded in
`ARGOS_WINDOWS_FAILURE_PREVENTION_MEMORY.md`. The setup also exposed one
read-only recurrence of the documented Windows PowerShell 5.1 inline-compound
expression parser trap; it made no mutation and the corrected probe used
separate scalar statements.

## Codex plugins and connections

| Plugin | Installation | Connection/access result |
|---|---|---|
| GitHub | Installed and enabled | Connected login `JconnCoh` |
| Codex Security | Installed and enabled | TAC status `not_granted`; enrollment is required before security scans |
| Sentry | Installed and enabled | No Sentry tools are callable in the already-open task; task/app reload and an account/project connection remain required |

Codex Security's manifest also reports unresolved required access app
`connector_openai_codex_security_access`; the live access probe confirms that
the user has no TAC grant. GitHub Enterprise is an optional unresolved manifest
entry and does not block the connected public GitHub account.

## Preserved authority and next action

Parent checkpoint:
`work/FRONTSIDE_INSPECTION_REVIEW_ONLY/ARGOS_CODEX_SESSION_HEALTH_CALIBRATION_V2_CHECKPOINT_20260819.md`,
SHA-256
`57F281C1CBE94A5E5C20105B149968D2DC929792EAEA9BA9AFAE9CBFC53C2005`.

The JBOD storage final-delta gate is unchanged. D3, C:/D: cutover, deletion,
hold clearance, C: recovery, and tray restart for C1D3A alone remain blocked.
No inspection or production authority changed. The new runtimes are local
development capabilities only and must not be installed ad hoc on the JBOD.
