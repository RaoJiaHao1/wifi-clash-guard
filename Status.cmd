@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Manage.ps1" -Action Status
if errorlevel 1 echo Operation failed. See the message above.
pause
