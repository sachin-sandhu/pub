# Windows Migration Script for Dependabot Reviewers

This directory contains Windows-optimized scripts to migrate Dependabot reviewers from `.github/dependabot.yml` to the `CODEOWNERS` file.

**NEW: Self-contained version with NO external dependencies!**

## Files

- **`migrate-dependabot-reviewers-windows.ps1`** - Main PowerShell script with native YAML parsing
- **`migrate-dependabot-reviewers-windows.bat`** - Batch wrapper for easier command prompt execution

## Requirements

### System Requirements
- **Windows 10** (version 1709+) or **Windows 11**
- **PowerShell 5.0+** (pre-installed on supported Windows versions)

### Dependencies
- **None!** - Completely self-contained script with native PowerShell YAML parsing

## Usage

### PowerShell Execution (Recommended)

```powershell
# Run the migration
.\migrate-dependabot-reviewers-windows.ps1

# Show help
.\migrate-dependabot-reviewers-windows.ps1 -Help
```

### Command Prompt Execution

```cmd
REM Run the migration
migrate-dependabot-reviewers-windows.bat

REM Show help
migrate-dependabot-reviewers-windows.bat --help
```

## Features

### 🚀 Self-Contained Operation
- **No external dependencies** required - completely self-contained
- **Native PowerShell YAML parsing** implementation
- **Built-in JSON processing** with PowerShell cmdlets
- Perfect for air-gapped environments and secure networks

### � Zero Installation Required
- Works out-of-the-box on any Windows system with PowerShell 5.0+
- No package managers needed (Chocolatey, Scoop, Winget)
- No additional tools to install or manage

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

## Installation & Setup

### No Installation Required!
The script is completely self-contained and requires no setup. Simply download and run:

1. Download the PowerShell script and batch file
2. Place them in your repository root or any convenient location
3. Run the script - that's it!

### Verification
To verify the script works correctly:
```powershell
# Test the script help
.\migrate-dependabot-reviewers-windows.ps1 -Help
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

### YAML Parsing Issues
If the script has trouble parsing your `dependabot.yml`:
1. Ensure the file uses standard YAML formatting
2. Check for proper indentation (spaces, not tabs)
3. Verify the `updates` section structure matches Dependabot specification

### Common File Issues
- Ensure `.github/dependabot.yml` exists in your repository
- Check that the file has the correct structure with `updates` and `reviewers` sections
- Verify reviewers are properly formatted as a YAML array

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

# Run migration (no setup required!)
.\migrate-dependabot-reviewers-windows.ps1
```

### CI/CD Pipeline
```powershell
# Perfect for automated environments - no dependencies to manage
.\migrate-dependabot-reviewers-windows.ps1

# Works in any CI/CD system that supports PowerShell
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
ℹ️  Processing ecosystem: npm, directory: /
ℹ️  Found existing CODEOWNERS file at: CODEOWNERS
ℹ️  Updating existing Dependabot reviewers section...
✅ CODEOWNERS file updated at: CODEOWNERS
✅ Migration completed successfully!
```
