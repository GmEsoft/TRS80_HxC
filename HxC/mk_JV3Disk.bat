@echo off
call vcvars32.bat
if errorlevel 1 pause && exit /B %ERRORLEVEL%
cl JV3Disk.c
if errorlevel 1 pause && exit /B %ERRORLEVEL%
del JV3Disk.obj
