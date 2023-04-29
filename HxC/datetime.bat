@echo off
for /F "tokens=1-6 delims=-./: " %%a in ("%DATE: =0% %TIME: =0%") do (
	set YEAR=%%c
	set DATE8=%%a/%%b
	set TIME8=%%d:%%e:%%f
)
set DATE8=%DATE8%/%YEAR:~-2%
echo %DATE8% %TIME8%
