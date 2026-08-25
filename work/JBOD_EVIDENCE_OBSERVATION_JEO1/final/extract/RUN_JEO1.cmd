@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ARGOS_SCRIPT=%~dp0AUDIT_JEO1.ps1"
set "ARGOS_MANIFEST=%~dp0INVOCATION.json"
set "ARGOS_LOG=D:\A2\x\JEO1_LAUNCH.log"
if not exist "%ARGOS_SCRIPT%" (
  echo JEO1 audit script is missing.
  pause
  exit /b 90
)
if not exist "%ARGOS_MANIFEST%" (
  echo JEO1 invocation manifest is missing.
  pause
  exit /b 91
)
if not exist "D:\A2\x\" (
  echo JEO1 cannot start because D:\A2\x is absent.
  echo No target state was changed.
  pause
  exit /b 91
)
if exist "%ARGOS_LOG%" (
  echo JEO1 refuses a repeated launch because %ARGOS_LOG% already exists.
  type "%ARGOS_LOG%"
  pause
  exit /b 93
)
echo JEO1 launch started %DATE% %TIME%>"%ARGOS_LOG%"
echo Running exact non-mutating preflight...>>"%ARGOS_LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight >>"%ARGOS_LOG%" 2>&1
set "ARGOS_RC=%ERRORLEVEL%"
type "%ARGOS_LOG%"
if not "%ARGOS_RC%"=="0" (
  echo JEO1 preflight failed closed with exit code %ARGOS_RC%.
  echo The persistent log is %ARGOS_LOG%.
  pause
  exit /b %ARGOS_RC%
)
echo Running bounded read-only collection...>>"%ARGOS_LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" >>"%ARGOS_LOG%" 2>&1
set "ARGOS_RC=%ERRORLEVEL%"
type "%ARGOS_LOG%"
if "%ARGOS_RC%"=="0" (
  echo JEO1 returned JEO1R.zip. No task, process, queue, ledger, source, image, or wafer was changed.
) else (
  echo JEO1 failed closed with exit code %ARGOS_RC%.
  echo Local evidence remains at D:\A2\x\JEO1 and D:\A2\x\JEO1R_LOCAL.zip when collection began.
)
echo The persistent launcher log is %ARGOS_LOG%.
pause
exit /b %ARGOS_RC%
