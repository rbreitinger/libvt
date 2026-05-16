@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  libvt test suite - compile examples
echo ========================================
echo.

rem --- auto-detect fbc ---
set FBC=

where fbc32 >nul 2>&1
if !errorlevel! == 0 ( for /f "delims=" %%P in ('where fbc32') do set FBC=%%P )

if "!FBC!" == "" (
    where fbc >nul 2>&1
    if !errorlevel! == 0 ( for /f "delims=" %%P in ('where fbc') do set FBC=%%P )
)

if "!FBC!" == "" (
    for %%D in (
        "C:\FreeBASIC\fbc32.exe"
        "C:\Program Files\FreeBASIC\fbc32.exe"
        "C:\Program Files (x86)\FreeBASIC\fbc32.exe"
        "D:\fb\fb1-10-1\fbc32.exe"
    ) do (
        if "!FBC!" == "" (
            if exist %%D set FBC=%%D
        )
    )
)

if "!FBC!" == "" (
    echo  ERROR: FreeBASIC compiler not found.
    echo  Please add fbc32.exe to your PATH or install FreeBASIC to a standard location.
    echo.
    exit /b 1
)

echo  Compiler: !FBC!
echo.

rem --- compile examples ---
set EXAMPLES_DIR=examples
set PASS=0
set FAIL=0
set FAILED_LIST=

for %%F in (%EXAMPLES_DIR%\*.bas) do (
    set FILENAME=%%~nxF
    <nul set /p "=  Compiling !FILENAME! ... "
    "!FBC!" "%%F" >nul 2>&1
    if !errorlevel! == 0 (
        echo OK
        set /a PASS+=1
    ) else (
        echo FAILED
        set /a FAIL+=1
        set FAILED_LIST=!FAILED_LIST! %%~nxF
    )
)

echo.
echo ========================================
echo  Results: !PASS! passed,  !FAIL! failed
echo ========================================

if !FAIL! GTR 0 (
    echo.
    echo  Failed files:
    for %%X in (!FAILED_LIST!) do echo    - %%X
    echo.
    exit /b 1
)

echo.
exit /b 0