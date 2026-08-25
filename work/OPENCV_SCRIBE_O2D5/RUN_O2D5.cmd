@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0Invoke-O2D5Direct.ps1"
set "ARGOS_MANIFEST=%~dp0INVOCATION.json"
set "LOG=D:\A2\x\O2D5_20260825T190855Z_54B4C08C_LAUNCH.log"
if not exist "%ARGOS_SCRIPT%" (
  echo Missing O2D5 script: %ARGOS_SCRIPT%
  pause
  exit /b 1
)
if not exist "%ARGOS_MANIFEST%" (
  echo Missing O2D5 invocation manifest: %ARGOS_MANIFEST%
  pause
  exit /b 1
)
if exist "%LOG%" (
  echo O2D5 create-new launcher log already exists: %LOG%
  echo O2D5 is one-attempt only and will not run again.
  pause
  exit /b 1
)
echo O2D5 launch started %DATE% %TIME%>>"%LOG%"
echo Running exact non-mutating preflight...>>"%LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight >>"%LOG%" 2>&1
if errorlevel 1 goto :failed
echo Preflight passed; running the single bounded Slot16 development execution...>>"%LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" >>"%LOG%" 2>&1
if errorlevel 1 goto :failed
echo O2D5 completed. Local result: D:\A2\x\O2D5R_20260825T190855Z_54B4C08C.zip>>"%LOG%"
type "%LOG%"
echo.
echo O2D5 completed. This window will remain open.
pause
exit /b 0
:failed
set "RC=%ERRORLEVEL%"
echo O2D5 failed closed with exit code %RC%.>>"%LOG%"
echo Local evidence, when collection began, remains under D:\A2\o\ocv\O2D5_20260825T190855Z_54B4C08C and D:\A2\x.>>"%LOG%"
type "%LOG%"
echo.
echo O2D5 failed closed. This window will remain open.
pause
exit /b %RC%
