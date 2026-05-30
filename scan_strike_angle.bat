@echo off
setlocal
cd /d "%~dp0"

rem Edit ARGS if you want a different fixed setup without typing in a console.
rem Example:
rem set ARGS=--release-angle -50.73 --impact-angle 45 --angle-min 0 --angle-max 90 --angle-step 2.5
set ARGS=--release-angle -40 --impact-angle 20 --angle-min 0 --angle-max 90 --angle-step 2.5

call run.bat --build-only
if errorlevel 1 (
  echo.
  echo Build failed. Scan was not started.
  pause
  exit /b 1
)

set RUNPY=import runpy, sys; sys.path.insert(0, 'tools'); sys.argv=['tools/strike_angle_scan.py']+sys.argv[1:]; runpy.run_path('tools/strike_angle_scan.py', run_name='__main__')
py -3 -c "%RUNPY%" %ARGS%
set STATUS=%ERRORLEVEL%
echo.
if "%STATUS%"=="0" (
  echo Finished. Strike-angle plots are written to the generated folder.
) else (
  echo Scan stopped with exit code %STATUS%. No new files may have been written.
)
pause
exit /b %STATUS%
