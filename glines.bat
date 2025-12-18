@echo off
REM Gemini Line Selector for Windows CMD
REM Save this as: glines.bat
REM Place in a directory in your PATH (e.g., C:\Users\YourName\bin\)

setlocal enabledelayedexpansion

REM Set temp directory for extracted files
set "TEMP_DIR=%TEMP%\glines"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

REM Colors (requires Windows 10+)
REM Enable ANSI colors
for /f "tokens=*" %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "GREEN="
set "BLUE="
set "YELLOW="
set "RED="
set "NC="

REM Check arguments
if "%~1"=="" goto :usage
if "%~1"=="-h" goto :usage
if "%~1"=="--help" goto :usage
if "%~2"=="" goto :usage

REM Parse arguments
set "FILE=%~1"
set "SELECTION=%~2"

REM Strip @ prefix if present
set "FILE_CLEAN=%FILE%"
if "%FILE:~0,1%"=="@" set "FILE_CLEAN=%FILE:~1%"

REM Check if file exists
if not exist "%FILE_CLEAN%" (
    echo %RED%Error: File not found: %FILE_CLEAN%%NC%
    exit /b 1
)

REM Generate unique output filename
set "TIMESTAMP=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "OUTPUT=%TEMP_DIR%\gemini_selection_%TIMESTAMP%.txt"

REM Collect prompt (all remaining arguments)
set "PROMPT="
shift
shift
:collect_prompt
if "%~1"=="" goto :end_collect
if "!PROMPT!"=="" (
    set "PROMPT=%~1"
) else (
    set "PROMPT=!PROMPT! %~1"
)
shift
goto :collect_prompt
:end_collect

REM Process selection based on format
REM Check for range (contains hyphen not at start)
set "TEST_HYPHEN=%SELECTION:-=%"
if not "%TEST_HYPHEN%"=="%SELECTION%" (
    if not "%SELECTION:~0,1%"=="-" goto :range_selection
)

REM Check for pattern match (starts with /)
if "%SELECTION:~0,1%"=="/" goto :pattern_match

REM Check for last N lines (starts with -)
if "%SELECTION:~0,1%"=="-" goto :last_n_lines

REM Check for first N lines (starts with +)
if "%SELECTION:~0,1%"=="+" goto :first_n_lines

REM Check for comma-separated lines
set "TEST_COMMA=%SELECTION:,=%"
if not "%TEST_COMMA%"=="%SELECTION%" goto :multiple_lines

REM Otherwise assume single line
goto :single_line

:range_selection
REM Extract lines X-Y
for /f "tokens=1,2 delims=-" %%a in ("%SELECTION%") do (
    set "START=%%a"
    set "END=%%b"
)
set /a "LINE_NUM=0"
set /a "EXTRACTED=0"
(for /f "usebackq delims=" %%a in ("%FILE_CLEAN%") do (
    set /a "LINE_NUM+=1"
    if !LINE_NUM! geq %START% if !LINE_NUM! leq %END% (
        echo %%a
        set /a "EXTRACTED+=1"
    )
)) > "%OUTPUT%"
goto :check_output

:single_line
REM Extract single line N
set /a "LINE_NUM=0"
(for /f "usebackq delims=" %%a in ("%FILE_CLEAN%") do (
    set /a "LINE_NUM+=1"
    if !LINE_NUM!==%SELECTION% echo %%a
)) > "%OUTPUT%"
goto :check_output

:multiple_lines
REM Extract specific lines (e.g., 1,5,10)
set "LINES=%SELECTION%"
set /a "LINE_NUM=0"
(for /f "usebackq delims=" %%a in ("%FILE_CLEAN%") do (
    set /a "LINE_NUM+=1"
    for %%b in (%LINES%) do (
        if !LINE_NUM!==%%b echo %%a
    )
)) > "%OUTPUT%"
goto :check_output

:pattern_match
REM Extract lines matching pattern
set "PATTERN=%SELECTION:~1,-1%"
findstr /i /c:"%PATTERN%" "%FILE_CLEAN%" > "%OUTPUT%"
goto :check_output

:last_n_lines
REM Extract last N lines
set "NUM=%SELECTION:~1%"
powershell -Command "Get-Content '%FILE_CLEAN%' -Tail %NUM%" > "%OUTPUT%"
goto :check_output

:first_n_lines
REM Extract first N lines
set "NUM=%SELECTION:~1%"
powershell -Command "Get-Content '%FILE_CLEAN%' -First %NUM%" > "%OUTPUT%"
goto :check_output

:check_output
REM Check if extraction was successful
if not exist "%OUTPUT%" (
    echo %YELLOW%Warning: Extraction failed%NC%
    exit /b 1
)

REM Check if file is empty
for %%A in ("%OUTPUT%") do set "SIZE=%%~zA"
if %SIZE%==0 (
    echo %YELLOW%Warning: No lines extracted%NC%
    del "%OUTPUT%"
    exit /b 1
)

echo %GREEN%✓ Extracted to: %OUTPUT%%NC%

REM If prompt provided, show command to use with Gemini
if not "!PROMPT!"=="" (
    echo %BLUE%To use with Gemini:%NC%
    echo   claude -c !PROMPT! in the file "@%OUTPUT%" 
    echo.
    echo %YELLOW%Note: Auto-send requires Gemini CLI installed%NC%
) else (
    echo %BLUE%Use: @%OUTPUT%%NC%
    echo %OUTPUT%
)

exit /b 0

:usage
echo.
echo %GREEN%Gemini Line Selector for Windows%NC%
echo.
echo Usage: glines ^<file^> ^<selection^> [prompt]
echo        glines ^<@file^> ^<selection^> [prompt]
echo.
echo Selection Formats:
echo   10-20          Lines 10 to 20
echo   10             Line 10
echo   1,5,10         Lines 1, 5, and 10
echo   /pattern/      Lines matching pattern
echo   -10            Last 10 lines
echo   +10            First 10 lines
echo.
echo Examples:
echo   glines myfile.py 10-20
echo   glines @myfile.py 10-20
echo   glines myfile.py /def/ 
echo   glines myfile.py 10-20 explain this code
echo   glines @config.yaml 1-50 what are these settings
echo.
exit /b 0
