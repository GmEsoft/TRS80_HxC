@echo off

set NAME=HXC
set ZMAC=zmac\zmac
set MAIN=%NAME%_ZMAC.ASM

if not exist Release mkdir Release

call DATETIME
echo.>%MAIN%
echo	DATE	MACRO >>%MAIN%
echo		DB	'%DATE8%' >>%MAIN%
echo	ENDM >>%MAIN%
echo	TIME	MACRO >>%MAIN%
echo		DB	'%TIME8%' >>%MAIN%
echo	ENDM >>%MAIN%
echo	ZMAC	EQU	1 >>%MAIN%
echo		ORG	0000H >>%MAIN%
echo	*GET	%NAME%_SEGS >>%MAIN%
echo		END >>%MAIN%


%ZMAC% --mras %MAIN% -P1=4 -P2=1 -o %NAME%.CIM -o %NAME%.LST -o %NAME%.BDS --od .
if errorlevel 1 goto :eof

mk_autoboot
