@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0Publish-O3C2R2.ps1"
set "ARGOS_MANIFEST=%~dp0Publish-O3C2R2.invocation.json"
if not exist "%ARGOS_SCRIPT%" exit /b 2
if not exist "%ARGOS_MANIFEST%" exit /b 2
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight
set "ARGOS_EXIT=%ERRORLEVEL%"
exit /b %ARGOS_EXIT%
