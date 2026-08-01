@echo off
setlocal
cd /d "%~dp0"

echo Starting OpenCode story loop...
echo.

powershell.exe -NoLogo -NoProfile ^
  -File ".\tools\story-loop-controller.ps1" ^
  -ProjectRoot "%CD%" ^
  -MaxStories 0 ^
  -HardPassLimit 20 ^
  -MaxNoProgress 3 ^
  -MaxTransientFailures 5

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Loop exited with code %EXIT_CODE%.
echo Status: .agent-logs\overnight-status.md
pause

exit /b %EXIT_CODE%
