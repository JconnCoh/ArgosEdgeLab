@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0Invoke-O3TR2EqualLengthRehearsal.ps1"
set "ARGOS_MANIFEST=%~dp0O3TR2_INVOCATION.json"
if not exist "%ARGOS_SCRIPT%" exit /b 2
if not exist "%ARGOS_MANIFEST%" exit /b 3
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight
if errorlevel 1 exit /b %ERRORLEVEL%
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Gate
exit /b %ERRORLEVEL%
