@echo off
if exist "%~dp0CodexWelcome.exe" (
  start "" "%~dp0CodexWelcome.exe" --settings
) else (
  powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0launcher\Settings.ps1"
)
