@echo off
setlocal
set "ARGOS_SCRIPT=%~dp0DELETE_CDM1.ps1"
set "ARGOS_MANIFEST=%~dp0INVOCATION.json"
set "ARGOS_TEMP=D:\A2\x"
set "ARGOS_LOG=D:\A2\x\CDM1_LAUNCH.log"
if not exist "%ARGOS_SCRIPT%" exit /b 90
if not exist "%ARGOS_MANIFEST%" exit /b 91
if not exist "%ARGOS_TEMP%\" exit /b 92
if exist "%ARGOS_LOG%" exit /b 93
set "TEMP=%ARGOS_TEMP%"
set "TMP=%ARGOS_TEMP%"
echo CDM1 started. Exact preflight runs before any deletion; all temp and evidence stay on D:.>"%ARGOS_LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" -Preflight >>"%ARGOS_LOG%" 2>&1
set "ARGOS_RC=%ERRORLEVEL%"
if not "%ARGOS_RC%"=="0" goto SHOW
echo CDM1 preflight passed. Starting exact D-mirror hash verification and retired-C deletion.>>"%ARGOS_LOG%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%ARGOS_SCRIPT%" -InvocationManifest "%ARGOS_MANIFEST%" >>"%ARGOS_LOG%" 2>&1
set "ARGOS_RC=%ERRORLEVEL%"
:SHOW
type "%ARGOS_LOG%"
echo.
if not "%ARGOS_RC%"=="0" echo CDM1 failed closed or was incomplete. Keep D:\A2\x\CDM1 and the launch log.
if "%ARGOS_RC%"=="0" echo CDM1 deleted the exact verified duplicates and returned CDM1R.zip.
pause
exit /b %ARGOS_RC%
