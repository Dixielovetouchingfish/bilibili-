@echo off
chcp 65001 >nul
title Bilibili OneClick
powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0start.ps1" %*
set "DOWNLOAD_EXIT=%errorlevel%"
if not "%DOWNLOAD_EXIT%"=="0" pause
exit /b %DOWNLOAD_EXIT%
