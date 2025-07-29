# Windows Migration Script for Dependabot Reviewers

This directory contains Windows-optimized scripts to migrate Dependabot reviewers from `.github/dependabot.yml` to the `CODEOWNERS` file.

## Files

- **`migrate-dependabot-reviewers-windows.ps1`** - Main PowerShell script with full functionality
- **`migrate-dependabot-reviewers-windows.bat`** - Batch wrapper for easier command prompt execution

## Requirements

### System Requirements
- **Windows 10** (version 1709+) or **Windows 11**
- **PowerShell 5.0+** (pre-installed on supported Windows versions)

### Package Manager (One of the following)
- **Chocolatey** - https://chocolatey.org/install
- **Scoop** - https://scoop.sh/
- **Winget** - Built into Windows 10 1709+ and Windows 11

### Dependencies (Auto-installed)
- **yq** - YAML processor
- **jq** - JSON processor

## Usage

### PowerShell Execution (Recommended)

```powershell
# Run with temporary installation (default - perfect for CI/CD)
.\migrate-dependabot-reviewers-windows.ps1

# Run with permanent installation
.\migrate-dependabot-reviewers-windows.ps1 -PermanentInstall

# Run without auto-installation (manual dependency management)
.\migrate-dependabot-reviewers-windows.ps1 -NoAutoInstall

# Show help
.\migrate-dependabot-reviewers-windows.ps1 -Help
```

### Command Prompt Execution

```cmd
REM Run with temporary installation (default)
migrate-dependabot-reviewers-windows.bat

REM Run with permanent installation
migrate-dependabot-reviewers-windows.bat --permanent-install

REM Run without auto-installation
migrate-dependabot-reviewers-windows.bat --no-auto-install

REM Show help
migrate-dependabot-reviewers-windows.bat --help
```

## Features

### 🚀 Auto-Installation
- Automatically detects and uses available package managers (Chocolatey, Scoop, Winget)
- Installs missing dependencies (`yq`, `jq`) without user intervention
- Smart fallback between package managers

### 🔄 Temporary Installation (Default)
- Dependencies are automatically removed after script completion
- Perfect for CI/CD environments and automated workflows
- Keeps your system clean and minimal

### 🛠️ Permanent Installation
- Use `--permanent-install` flag to keep dependencies installed
- Useful for development environments where tools are used regularly

### 📦 Multi-Ecosystem Support
Supports all major package ecosystems:
- **Bundler** (Ruby Gems)
- **Bun** (JavaScript/TypeScript)
- **npm/yarn** (Node.js)
- **Cargo** (Rust)
- **Composer** (PHP)
- **Docker/Docker Compose**
- **.NET/NuGet**
- **Elm**
- **GitHub Actions**
- **Git Submodules**
- **Go Modules**
- **Gradle** (Java/Kotlin)
- **Maven** (Java)
- **Helm** (Kubernetes)
- **Mix** (Elixir)
- **pip/uv** (Python)
- **Pub** (Dart/Flutter)
- **Swift Package Manager**
- **Terraform**

### 📋 CODEOWNERS Management
- Preserves existing CODEOWNERS content
- Updates or creates Dependabot reviewers section
- Sorts patterns for optimal Git matching performance
- Supports multiple CODEOWNERS file locations

## Installation Options

### Option 1: Chocolatey
```cmd
# Install Chocolatey (if not already installed)
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# The script will auto-install yq and jq via Chocolatey
```

### Option 2: Scoop
```powershell
# Install Scoop (if not already installed)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# The script will auto-install yq and jq via Scoop
```

### Option 3: Winget
```cmd
# Winget is pre-installed on Windows 10 1709+ and Windows 11
# The script will auto-install yq and jq via Winget
```

## Troubleshooting

### PowerShell Execution Policy
If you encounter execution policy errors:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run with bypass (one-time)
PowerShell.exe -ExecutionPolicy Bypass -File ".\migrate-dependabot-reviewers-windows.ps1"
```

### Package Manager Issues
1. **Chocolatey not found**: Install from https://chocolatey.org/install
2. **Scoop not found**: Install from https://scoop.sh/
3. **Winget not found**: Update Windows to latest version

### Dependency Installation Failures
- Ensure you have internet connectivity
- Run PowerShell/Command Prompt as Administrator if needed
- Check if your corporate firewall blocks package manager repositories

### PATH Issues
If tools are installed but not found:
1. Restart your PowerShell/Command Prompt session
2. Check PATH environment variable
3. Log out and log back in to Windows

## CI/CD Integration

### GitHub Actions
```yaml
- name: Migrate Dependabot reviewers (Windows)
  run: |
    .\migrate-dependabot-reviewers-windows.ps1
  shell: powershell
```

### Azure DevOps
```yaml
- task: PowerShell@2
  displayName: 'Migrate Dependabot reviewers'
  inputs:
    targetType: 'filePath'
    filePath: 'migrate-dependabot-reviewers-windows.ps1'
```

## Examples

### Basic Usage
```powershell
# Navigate to repository root
cd C:\path\to\your\repo

# Run migration with defaults (temporary installation)
.\migrate-dependabot-reviewers-windows.ps1
```

### CI/CD Pipeline
```powershell
# Perfect for automated environments - installs dependencies temporarily
.\migrate-dependabot-reviewers-windows.ps1

# Dependencies are automatically cleaned up after completion
```

### Development Environment
```powershell
# Keep tools installed for repeated use
.\migrate-dependabot-reviewers-windows.ps1 -PermanentInstall
```

## Output

The script provides colored, informative output:
- 🔵 **Info**: General information and progress
- 🟢 **Success**: Successful operations
- 🟡 **Warning**: Non-critical issues
- 🔴 **Error**: Critical errors requiring attention

Example output:
```
ℹ️  Starting Dependabot reviewers migration to CODEOWNERS (Windows)...
⚠️  Missing required tools: yq, jq
ℹ️  Temporarily installing missing tools using chocolatey...
ℹ️  Installing yq...
✅ Successfully installed yq
ℹ️  Installing jq...
✅ Successfully installed jq
✅ All dependencies installed successfully!
ℹ️  Processing ecosystem: npm, directory: /
ℹ️  Found existing CODEOWNERS file at: CODEOWNERS
ℹ️  Updating existing Dependabot reviewers section...
✅ CODEOWNERS file updated at: CODEOWNERS
✅ Migration completed successfully!
ℹ️  Cleaning up temporarily installed dependencies...
✅ Cleanup completed!
```
