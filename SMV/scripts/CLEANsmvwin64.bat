@echo off
Title Cleaning Smokeview for 64 bit Windows 

set envfile="%homedrive%\%homepath%"\fds_smv_env.bat
IF EXIST %envfile% GOTO endif_envexist
echo ***Fatal error.  The environment setup file %envfile% does not exist. 
echo Create a file named %envfile% and use SMV/scripts/fds_smv_env_template.bat
echo as an example.
echo.
echo Aborting now...
pause>NUL
goto:eof

:endif_envexist

call %envfile%

%svn_drive%
echo.
echo cleaning INTEL_WIN_64
cd %svn_root%\SMV\Build\INTEL_WIN_64
echo Cleaning INTEL_WIN_64

erase *.obj 

echo.
echo cleaning MPI_INTEL_WIN_64
cd %svn_root%\SMV\Build\MPI_INTEL_WIN_64
echo Cleaning MPI_INTEL_WIN_64

erase *.obj 

pause