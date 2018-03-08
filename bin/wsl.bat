@echo off
setlocal EnableDelayedExpansion

rem get the drive letter as lowercase
set drive=%CD:~0,1%
for %%i in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do set "drive=!drive:%%i=%%i!"

rem convert the path separator
set pathname="%CD:~3%"
set pathname=!pathname:\=/!

rem set the fully qualified linux path
set pathname=/!drive!/!pathname!

"%windir%\system32\bash.exe" /usr/local/bin/wslboot.sh -c "cd \""%pathname%\"" && exec bash"
