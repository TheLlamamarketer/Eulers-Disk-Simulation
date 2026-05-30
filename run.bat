@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "BUILD=build_gfortran"
set "SIM=%BUILD%\edisk_headless.exe"
set "VIEWER=%BUILD%\edisk_gl_viewer.exe"
set "FFLAGS=-w"

if exist "C:\Strawberry\c\bin" set "PATH=C:\Strawberry\c\bin;%PATH%"

echo Euler disk workflow
echo.

if /I "%~1"=="--build-only" goto build_only
if not "%~1"=="" goto run_input_file

if exist "animat.txt" (
  set "ANS="
  set /p "ANS=View previous simulation? [Y/n] "
  if /I not "!ANS!"=="N" if /I not "!ANS!"=="NO" goto view_existing
)

:new_simulation
echo.
set "ANS="
set /p "ANS=Use default simulation values? [Y/n] "
echo.
set "USE_DEFAULTS=1"
if /I "!ANS!"=="N" set "USE_DEFAULTS=0"
if /I "!ANS!"=="NO" set "USE_DEFAULTS=0"

echo Building simulation...
call :build_simulation
if errorlevel 1 exit /b %errorlevel%

if "%USE_DEFAULTS%"=="0" goto run_interactive

set "EDISK_DEFAULTS=1"
"%SIM%"
set "SIM_STATUS=%ERRORLEVEL%"
set "EDISK_DEFAULTS="
if not "%SIM_STATUS%"=="0" exit /b %SIM_STATUS%
goto view_new

:run_interactive
"%SIM%"
if errorlevel 1 exit /b %errorlevel%
goto view_new

:build_only
echo Building simulation...
call :build_simulation
if errorlevel 1 exit /b %errorlevel%
echo Build finished: "%SIM%"
exit /b 0

:run_input_file
set "INPUT_FILE=%~1"
set "CLEAN_INPUT=%BUILD%\input_responses.tmp"
if not exist "%INPUT_FILE%" (
  echo Initial condition file not found: "%INPUT_FILE%"
  exit /b 1
)
echo Using initial condition file: "%INPUT_FILE%"
echo.
echo Building simulation...
call :build_simulation
if errorlevel 1 exit /b %errorlevel%
powershell -NoProfile -Command "$in=$env:INPUT_FILE; $out=$env:CLEAN_INPUT; Get-Content -LiteralPath $in | ForEach-Object { $line = ($_ -replace '#.*$','').Trim(); if ($line.Length -gt 0) { $line } } | Set-Content -LiteralPath $out -Encoding ascii"
if errorlevel 1 exit /b %errorlevel%
"%SIM%" < "%CLEAN_INPUT%"
if errorlevel 1 exit /b %errorlevel%
goto view_new

:view_existing
echo.
if /I "%EDISK_NO_VIEW%"=="1" exit /b 0
echo Opening existing animat.txt.
call :build_viewer
if errorlevel 1 exit /b %errorlevel%
start "" "%~dp0%VIEWER%" "%~dp0animat.txt"
exit /b 0

:view_new
if not exist "animat.txt" (
  echo Simulation finished, but animat.txt was not created.
  exit /b 1
)
echo.
if /I "%EDISK_NO_VIEW%"=="1" exit /b 0
echo Opening newly generated animat.txt.
call :build_viewer
if errorlevel 1 exit /b %errorlevel%
start "" "%~dp0%VIEWER%" "%~dp0animat.txt"
exit /b 0

:build_simulation
where gfortran >nul 2>nul
if errorlevel 1 (
  echo gfortran was not found. Install Strawberry Perl or add gfortran to PATH.
  exit /b 1
)

if not exist "%BUILD%" mkdir "%BUILD%"
taskkill /IM edisk_headless.exe /F >nul 2>nul
taskkill /IM edisk_gl_viewer.exe /F >nul 2>nul
del /q "%BUILD%\*.o" "%BUILD%\*.mod" 2>nul

gfortran %FFLAGS% -c screen\mchr.f90      -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\mchr.f90.o"      || exit /b 1
gfortran %FFLAGS% -c screen\mn2c.f90      -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\mn2c.f90.o"      || exit /b 1
gfortran %FFLAGS% -c screen\mio.f90       -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\mio.f90.o"       || exit /b 1
gfortran %FFLAGS% -c screen\mcalc.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\mcalc.f90.o"     || exit /b 1
gfortran %FFLAGS% -c screen\mui.f90       -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\mui.f90.o"       || exit /b 1
gfortran %FFLAGS% -c model2\disk_data.f90 -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\disk_data.f90.o" || exit /b 1
gfortran %FFLAGS% -c model2\cdata.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\cdata.f90.o"     || exit /b 1
gfortran %FFLAGS% -c model2\prop.f        -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\prop.f.o"        || exit /b 1
gfortran %FFLAGS% -c model2\disk0.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\disk0.f90.o"     || exit /b 1
gfortran %FFLAGS% -c model2\disk.f90      -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\disk.f90.o"      || exit /b 1
gfortran %FFLAGS% -c model2\ztime.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\ztime.f90.o"     || exit /b 1
gfortran %FFLAGS% -c model2\solout.f90    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\solout.f90.o"    || exit /b 1
gfortran %FFLAGS% -c model2\post.f90      -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\post.f90.o"      || exit /b 1
gfortran %FFLAGS% -c model2\input.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\input.f90.o"     || exit /b 1
gfortran %FFLAGS% -c model2\integ.f90     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\integ.f90.o"     || exit /b 1
gfortran %FFLAGS% -c model2\main.f90      -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\main.f90.o"      || exit /b 1
gfortran %FFLAGS% -c zeroin.f             -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\zeroin.f.o"      || exit /b 1
gfortran %FFLAGS% -c hairer\hinit.for     -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\hinit.for.o"     || exit /b 1
gfortran %FFLAGS% -c hairer\cdopri.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\cdopri.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\contd5.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\contd5.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\contd8.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\contd8.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\dop853.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\dop853.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\dopri5.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\dopri5.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\dopcor.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\dopcor.for.o"    || exit /b 1
gfortran %FFLAGS% -c hairer\dp86co.for    -J "%BUILD%" -I "%BUILD%" -o "%BUILD%\dp86co.for.o"    || exit /b 1

gfortran -o "%SIM%" ^
  "%BUILD%\mchr.f90.o" ^
  "%BUILD%\mn2c.f90.o" ^
  "%BUILD%\mio.f90.o" ^
  "%BUILD%\mcalc.f90.o" ^
  "%BUILD%\mui.f90.o" ^
  "%BUILD%\disk_data.f90.o" ^
  "%BUILD%\cdata.f90.o" ^
  "%BUILD%\prop.f.o" ^
  "%BUILD%\disk0.f90.o" ^
  "%BUILD%\disk.f90.o" ^
  "%BUILD%\ztime.f90.o" ^
  "%BUILD%\solout.f90.o" ^
  "%BUILD%\post.f90.o" ^
  "%BUILD%\input.f90.o" ^
  "%BUILD%\integ.f90.o" ^
  "%BUILD%\main.f90.o" ^
  "%BUILD%\zeroin.f.o" ^
  "%BUILD%\hinit.for.o" ^
  "%BUILD%\cdopri.for.o" ^
  "%BUILD%\contd5.for.o" ^
  "%BUILD%\contd8.for.o" ^
  "%BUILD%\dop853.for.o" ^
  "%BUILD%\dopri5.for.o" ^
  "%BUILD%\dopcor.for.o" ^
  "%BUILD%\dp86co.for.o" || exit /b 1

exit /b 0

:build_viewer
if not exist "%BUILD%" mkdir "%BUILD%"
if exist "%VIEWER%" (
  powershell -NoProfile -Command "if ((Get-Item '%VIEWER%').LastWriteTime -ge (Get-Item 'edisk_gl_viewer.c').LastWriteTime -and (Get-Item '%VIEWER%').LastWriteTime -ge (Get-Item 'run.bat').LastWriteTime) { exit 0 } else { exit 1 }"
  if not errorlevel 1 exit /b 0
)

where gcc >nul 2>nul
if errorlevel 1 (
  echo gcc was not found. Install Strawberry Perl or add gcc to PATH.
  exit /b 1
)

gcc edisk_gl_viewer.c -o "%VIEWER%" -mwindows -lglut -lopengl32 -lglu32 -lm
if errorlevel 1 exit /b %errorlevel%
if exist "C:\Strawberry\c\bin\libfreeglut__.dll" copy /Y "C:\Strawberry\c\bin\libfreeglut__.dll" "%BUILD%\libfreeglut__.dll" >nul
exit /b 0


