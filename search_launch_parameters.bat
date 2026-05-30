@echo off
setlocal
cd /d "%~dp0"

rem Edit ARGS if you want a different search without typing in a console.
rem Example:
rem set ARGS=--release-angles -75:-25:5 --impact-angles 15:50:5
set ARGS=--directions -180:0:20 --face-angles 0:180:20

call run.bat --build-only
if errorlevel 1 (
  echo.
  echo Build failed. Search was not started.
  pause
  exit /b 1
)

set RUNPY=import runpy, sys; sys.path.insert(0, 'tools'); sys.argv=['tools/launch_parameter_search.py']+sys.argv[1:]; runpy.run_path('tools/launch_parameter_search.py', run_name='__main__')
py -3 -c "%RUNPY%" %ARGS%
set STATUS=%ERRORLEVEL%
echo.
if "%STATUS%"=="0" (
  echo Finished. Search CSVs and plots are written to the generated folder.
) else (
  echo Search stopped with exit code %STATUS%. No new files may have been written.
)
pause
exit /b %STATUS%
