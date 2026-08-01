@echo off
setlocal
cd /d "%~dp0"

set "GIT_BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined RALPH_ITERATIONS set "RALPH_ITERATIONS=500"
if not exist "%GIT_BASH%" (
  echo Git Bash was not found at "%GIT_BASH%".
  exit /b 2
)

echo Starting Ralph/OpenCode story loop...
echo.

"%GIT_BASH%" -lc "cd \"$(cygpath -u '%CD%')\" && ./.agents/ralph/loop.sh build %RALPH_ITERATIONS%"

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo Loop exited with code %EXIT_CODE%.
echo Ralph logs: .ralph\runs

exit /b %EXIT_CODE%
