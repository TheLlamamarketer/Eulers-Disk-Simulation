@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "BUILD=build_gfortran"
set "VIEWER=%BUILD%\edisk_ic_viewer.exe"
set "INPUT_FILE=%~1"

if exist "C:\Strawberry\c\bin" set "PATH=C:\Strawberry\c\bin;%PATH%"

if not "%INPUT_FILE%"=="" if not exist "%INPUT_FILE%" (
  echo Initial condition file not found: "%INPUT_FILE%"
  exit /b 1
)

if not exist "%BUILD%" mkdir "%BUILD%"

if exist "%VIEWER%" (
  powershell -NoProfile -Command "if ((Get-Item '%VIEWER%').LastWriteTime -ge (Get-Item 'edisk_ic_viewer.c').LastWriteTime -and (Get-Item '%VIEWER%').LastWriteTime -ge (Get-Item 'view_initial.bat').LastWriteTime) { exit 0 } else { exit 1 }"
  if not errorlevel 1 goto open_viewer
)

where gcc >nul 2>nul
if errorlevel 1 (
  echo gcc was not found. Install Strawberry Perl or add gcc to PATH.
  exit /b 1
)

gcc edisk_ic_viewer.c -o "%VIEWER%" -mwindows -lglut -lopengl32 -lglu32 -lm
if errorlevel 1 exit /b %errorlevel%
if exist "C:\Strawberry\c\bin\libfreeglut__.dll" copy /Y "C:\Strawberry\c\bin\libfreeglut__.dll" "%BUILD%\libfreeglut__.dll" >nul

:open_viewer
if "%INPUT_FILE%"=="" (
  start "" "%~dp0%VIEWER%"
) else (
  start "" "%~dp0%VIEWER%" "%~dp0%INPUT_FILE%"
)
exit /b 0
