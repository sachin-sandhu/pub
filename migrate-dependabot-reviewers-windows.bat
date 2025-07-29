@echo off
REM Windows Batch wrapper for PowerShell migration script
REM This allows execution from Command Prompt without PowerShell execution policy issues

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
if /i "%~1"=="--no-auto-install" set "PS_ARGS=!PS_ARGS! -NoAutoInstall"
if /i "%~1"=="--permanent-install" set "PS_ARGS=!PS_ARGS! -PermanentInstall"
shift
goto :parse_args

:execute
if "%SHOW_HELP%"=="true" (
    echo Usage: %~nx0 [OPTIONS]
    echo.
    echo Migrate Dependabot reviewers from .github/dependabot.yml to CODEOWNERS file
    echo Optimized for Windows with auto-dependency installation
    echo.
    echo Options:
    echo   -h, --help             Show this help message
    echo   --no-auto-install      Disable automatic dependency installation
    echo   --permanent-install    Install dependencies permanently (instead of temp^)
    echo.
    echo Requirements:
    echo   - PowerShell 5.0+ (pre-installed on Windows 10+^)
    echo   - Package manager (Chocolatey, Scoop, or Winget^)
    echo   - yq and jq (will be auto-installed if missing^)
    echo.
    echo Features:
    echo   - Automatically installs missing dependencies via package managers
    echo   - Temporary installation by default (perfect for CI/CD^)
    echo   - Supports multiple package ecosystems
    echo   - Preserves existing CODEOWNERS content
    echo   - Sorts patterns for optimal matching
    echo.
    echo Examples:
    echo   %~nx0                        # Run with temporary installation (default^)
    echo   %~nx0 --permanent-install    # Run with permanent installation
    echo   %~nx0 --no-auto-install      # Run without auto-installation
    echo.
    goto :end
)

REM Execute PowerShell script with bypass execution policy
echo Starting Dependabot reviewers migration to CODEOWNERS (Windows^)...
powershell.exe -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %PS_ARGS%

REM Pass through the exit code from PowerShell
exit /b %ERRORLEVEL%

:end
