@echo off
setlocal
cd /d "%~dp0"

echo Starting OpenCode story loop...
echo.

powershell.exe -NoLogo -NoProfile ^
  -File ".\run-story-loop.ps1" ^
  -ProjectRoot "%CD%" ^
  -MaxStories 20 ^
  -MaxPassesPerStory 6

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Loop exited with code %EXIT_CODE%.
echo Status: .agent-logs\overnight-status.md
pause

exit /b %EXIT_CODE%
