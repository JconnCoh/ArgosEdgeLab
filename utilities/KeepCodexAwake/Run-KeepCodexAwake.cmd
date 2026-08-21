@echo off
setlocal
title Codex Keep Awake
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Keep-CodexAwake.ps1" %*
if errorlevel 1 (
    echo.
    echo Keep-CodexAwake ended with an error.
    pause
)
endlocal
