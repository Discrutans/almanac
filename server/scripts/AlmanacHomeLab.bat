@echo off
REM Инструкция: AlmanacHomeLab.md в этой же папке
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_home_lab.ps1"
if errorlevel 1 pause
