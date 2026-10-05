@echo off
chcp 65001 >nul
title Bilibili OneClick Update
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0start.ps1" -UpdateTools
set "DOWNLOAD_EXIT=%errorlevel%"
if not "%DOWNLOAD_EXIT%"=="0" pause
exit /b %DOWNLOAD_EXIT%
