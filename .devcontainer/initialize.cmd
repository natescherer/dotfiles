@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0initialize.ps1"
exit /b %ERRORLEVEL%
