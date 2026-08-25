@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0AUDIT_O2A1.ps1"
set "ARGOS_MANIFEST=%~dp0INVOCATION.json"
if not exist "%ARGOS_SCRIPT%" exit /b 90
if not exist "%ARGOS_MANIFEST%" exit /b 91
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%"
set "ARGOS_RC=%ERRORLEVEL%"
echo.
if not "%ARGOS_RC%"=="0" echo O2A1 failed closed with exit code %ARGOS_RC%.
if "%ARGOS_RC%"=="0" echo O2A1 read-only observation completed and returned O2A1R.zip.
pause
exit /b %ARGOS_RC%

