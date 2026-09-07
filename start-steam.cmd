@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch.ps1" -Steam
if errorlevel 1 pause
