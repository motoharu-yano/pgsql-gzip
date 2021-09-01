echo cleaning up previous build

rmdir /s /q .\build 2> NUL
mkdir build
cd build

echo configuring with cmake

rem there is a problem where you can not use 'NMake Makefiles JOM' generator.
rem this creates incorrect pgsql_install.bat file at work\build\code where last line that installs gzip.dll is incorrect
rem it contains 'Release' folder in the path like work\build\code\Release\gzip.dll
rem while binary is still put into work\build\code\gzip.dll
rem so the binary can not be copied and since installation is not properly done - postgres load test for gzip cartridge fails

cmake ^
    -G "NMake Makefiles" ^
    -D CMAKE_SYSTEM_PREFIX_PATH=%LIBRARY_PREFIX% ^
    -D CMAKE_BUILD_TYPE=Release ^
    -D CMAKE_INSTALL_PREFIX=%LIBRARY_PREFIX% ^
    ..

if errorlevel 1 exit 1

echo starting build

rem building with jom like this because building this recipe with cmake does not seem to parallelize

where jom 2> NUL
if %ERRORLEVEL% equ 0 (
    set MAKE_CMD=jom -j%CPU_COUNT%
) else (
    set MAKE_CMD=nmake
)

%MAKE_CMD%

echo finished build, installing postgres gzip extension

cd .\code
call pgsql_install.bat

set PGPORT=54322
set PGDATA=%SRC_DIR%\pgdata

rem cleanup required when building variants
rmdir /s /q $PGDATA 2> NULL 

pg_ctl initdb

rem ensure that the gzip extension is loaded at process startup
echo shared_preload_libraries = 'gzip' >> %PGDATA%\postgresql.conf

pg_ctl -D %PGDATA% -l %PGDATA%/log.txt start

rem wait a few seconds just to make sure that the server has started
ping -n 5 127.0.0.1 > NUL

echo starting the test

set "RDBASE=%SRC_DIR%"
ctest -V
set check_result=%ERRORLEVEL%

pg_ctl stop

exit /b %check_result%