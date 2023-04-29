@echo off
echo :: Set Visual Studio environment ::
set VCVARS32="C:\Program Files\Microsoft Visual Studio 8\VC\bin\vcvars32.bat"
if not exist %VCVARS32% echo NOT FOUND: %VCVARS32% && exit /B 1
call %VCVARS32%
