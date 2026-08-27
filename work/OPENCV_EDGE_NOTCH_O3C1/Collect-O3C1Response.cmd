@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0Collect-O3C1Response.ps1"
set "ARGOS_MANIFEST=%~dp0O3C1_EXACT_RESPONSE_COLLECTION_INVOCATION.json"
if not exist "%ARGOS_SCRIPT%" exit /b 2
if not exist "%ARGOS_MANIFEST%" exit /b 2
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight
set "ARGOS_EXIT=%ERRORLEVEL%"
exit /b %ARGOS_EXIT%
