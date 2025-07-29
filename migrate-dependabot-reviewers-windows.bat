@echo off
REM Windows Batch wrapper for PowerShell migration script
REM Self-contained script with no external dependencies

setlocal EnableDelayedExpansion

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%migrate-dependabot-reviewers-windows.ps1"

REM Check if PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo Error: PowerShell script not found at "%PS_SCRIPT%"
    exit /b 1
)

REM Parse command line arguments
set "PS_ARGS="
set "SHOW_HELP=false"

:parse_args
if "%~1"=="" goto :execute
if /i "%~1"=="-h" set "SHOW_HELP=true"
if /i "%~1"=="--help" set "SHOW_HELP=true"
shift
goto :parse_args

:execute
if "%SHOW_HELP%"=="true" (
    echo Usage: %~nx0 [OPTIONS]
    echo.
    echo Migrate Dependabot reviewers from .github/dependabot.yml to CODEOWNERS file
    echo Self-contained script with no external dependencies
    echo.
    echo Options:
    echo   -h, --help             Show this help message
    echo.
    echo Requirements:
    echo   - PowerShell 5.0+ (pre-installed on Windows 10+^)
    echo.
    echo Features:
    echo   - No external dependencies - completely self-contained
    echo   - Native PowerShell YAML parsing implementation
    echo   - Built-in JSON processing capabilities
    echo   - Supports multiple package ecosystems
    echo   - Preserves existing CODEOWNERS content
    echo   - Sorts patterns for optimal matching
    echo.
    echo Examples:
    echo   %~nx0                        # Run the migration
    echo   %~nx0 --help                 # Show this help message
    echo.
    goto :end
)

REM Execute PowerShell script with bypass execution policy
echo Starting Dependabot reviewers migration to CODEOWNERS (Windows^)...
powershell.exe -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_ARGS%

REM Pass through the exit code from PowerShell
exit /b %ERRORLEVEL%

:end
