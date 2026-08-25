@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0Invoke-O2A3Direct.ps1"
set "ARGOS_MANIFEST=%~dp0INVOCATION.json"
set "LOG=D:\A2\x\O2A3_20260825T195521Z_LAUNCH.log"
if not exist "%ARGOS_SCRIPT%" (
  echo Missing O2A3 script: %ARGOS_SCRIPT%
  pause
  exit /b 1
)
if not exist "%ARGOS_MANIFEST%" (
  echo Missing O2A3 invocation manifest: %ARGOS_MANIFEST%
  pause
  exit /b 1
)
if exist "%LOG%" (
  echo O2A3 create-new launcher log already exists: %LOG%
  echo O2A3 is one-attempt only and will not run again.
  pause
  exit /b 1
)
echo O2A3 launch started %DATE% %TIME%>>"%LOG%"
echo Running exact non-mutating preflight...>>"%LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight >>"%LOG%" 2>&1
if errorlevel 1 goto :failed
echo Preflight passed; collecting exact Slot16 scribe JSON and installed-source metadata...>>"%LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" >>"%LOG%" 2>&1
if errorlevel 1 goto :failed
echo O2A3 completed. Local result: D:\A2\x\O2A3R_20260825T195521Z.zip>>"%LOG%"
type "%LOG%"
echo.
echo O2A3 completed. This window will remain open.
pause
exit /b 0
:failed
set "RC=%ERRORLEVEL%"
echo O2A3 failed closed with exit code %RC%.>>"%LOG%"
echo Local evidence, when collection began, remains under D:\A2\x.>>"%LOG%"
type "%LOG%"
echo.
echo O2A3 failed closed. This window will remain open.
pause
exit /b %RC%
