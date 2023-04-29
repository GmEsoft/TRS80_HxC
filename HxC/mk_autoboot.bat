@echo off
set HXCFE_DIR=C:\develop\HxC
jv3disk -C -1 -I:HXC.CIM -O:Release\AUTOBOOT.JV3
pushd Release
call %HXCFE_DIR%\import AUTOBOOT.JV3
popd
