@echo off
setlocal enabledelayedexpansion

echo ========================================
echo  libvt build docs
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

rem --- ensure docs\ exists ---
if not exist docs\ mkdir docs

rem --- compile utils ---
echo  [1/3] Compiling utils...

<nul set /p "=    apidump  ... "
"!FBC!" utils\apidump.bas -x utils\apidump.exe >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
echo OK

<nul set /p "=    vthgen   ... "
"!FBC!" utils\vthgen.bas -x utils\vthgen.exe >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
echo OK

<nul set /p "=    vth2html ... "
"!FBC!" utils\vth2html.bas -x utils\vth2html.exe >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
echo OK

echo.

rem --- run apidump ---
echo  [2/3] Generating API dump...
<nul set /p "=    apidump vt ... "
utils\apidump.exe vt >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
move /y libvt_api_dump.txt docs\ >nul
echo OK

echo.

rem --- run vthgen ---
echo  [3/3] Generating docs...

<nul set /p "=    vthgen vt vt.vth ... "
utils\vthgen.exe vt vt.vth >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
echo OK

rem    vth2html needs vt.vth in root still, move after
<nul set /p "=    vth2html vt.vth libvt.html ... "
utils\vth2html.exe vt.vth libvt.html "LibVT API Reference" >nul 2>&1
if !errorlevel! NEQ 0 ( echo FAILED & exit /b 1 )
echo OK

rem    now move both to docs\
move /y vt.vth docs\ >nul
move /y libvt.html docs\ >nul

echo.
echo ========================================
echo  All done! Docs are in docs\
echo ========================================
echo.
exit /b 0