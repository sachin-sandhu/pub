# Windows PowerShell script to migrate Dependabot reviewers to CODEOWNERS
# 
# Optimized for Windows with native PowerShell and package managers
# Features auto-installation of dependencies via multiple package managers
# Uses temporary installation by default for CI/CD environments
# 
# Requirements:
# - PowerShell 5.0+ (pre-installed on Windows 10+)
# - Package manager (Chocolatey, Scoop, or Winget)
# 
# Dependencies (auto-installed if missing):
# - yq (YAML processor)
# - jq (JSON processor)
#
# Usage modes:
# - Temporary install (DEFAULT): dependencies are removed after script completion
# - Permanent install: dependencies remain after script completion

param(
    [switch]$Help,
    [switch]$NoAutoInstall,
    [switch]$PermanentInstall
)

# Global variables
$script:TempInstalledTools = @()
$script:CleanupOnTrap = $false
$script:PackageManager = ""

# Function to display colored output
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# Function to detect available package managers
function Get-AvailablePackageManager {
    # Check for Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        return "chocolatey"
    }
    
    # Check for Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return "scoop"
    }
    
    # Check for Winget (Windows 10 1709+)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return "winget"
    }
    
    return $null
}

# Function to install package using detected package manager
function Install-Package {
    param(
        [string]$PackageName,
        [string]$PackageManager
    )
    
    try {
        switch ($PackageManager) {
            "chocolatey" {
                $result = & choco install $PackageName -y 2>&1
                return $LASTEXITCODE -eq 0
            }
            "scoop" {
                $result = & scoop install $PackageName 2>&1
                return $LASTEXITCODE -eq 0
            }
            "winget" {
                $result = & winget install $PackageName --accept-source-agreements --accept-package-agreements 2>&1
                return $LASTEXITCODE -eq 0
            }
            default {
                return $false
            }
        }
    }
    catch {
        return $false
    }
}

# Function to uninstall package using detected package manager
function Uninstall-Package {
    param(
        [string]$PackageName,
        [string]$PackageManager
    )
    
    try {
        switch ($PackageManager) {
            "chocolatey" {
                $result = & choco uninstall $PackageName -y 2>&1
                return $LASTEXITCODE -eq 0
            }
            "scoop" {
                $result = & scoop uninstall $PackageName 2>&1
                return $LASTEXITCODE -eq 0
            }
            "winget" {
                $result = & winget uninstall $PackageName 2>&1
                return $LASTEXITCODE -eq 0
            }
            default {
                return $false
            }
        }
    }
    catch {
        return $false
    }
}

# Function to check dependencies and auto-install if missing
function Test-Dependencies {
    param(
        [bool]$AutoInstall = $true,
        [bool]$TempInstall = $true
    )
    
    $missingTools = @()
    
    if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
        $missingTools += "yq"
    }
    
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        $missingTools += "jq"
    }
    
    if ($missingTools.Count -gt 0) {
        Write-Warning "Missing required tools: $($missingTools -join ', ')"
        
        if (-not $AutoInstall) {
            Write-Info "Auto-installation is disabled. Please install missing tools manually:"
            foreach ($tool in $missingTools) {
                Write-Info "  Package manager install commands:"
                Write-Info "    Chocolatey: choco install $tool"
                Write-Info "    Scoop: scoop install $tool"
                Write-Info "    Winget: winget install $tool"
            }
            return $false
        }
        
        # Detect package manager
        $script:PackageManager = Get-AvailablePackageManager
        if (-not $script:PackageManager) {
            Write-Error "No supported package manager found (Chocolatey, Scoop, or Winget)"
            Write-Info "Please install one of the following:"
            Write-Info "  Chocolatey: https://chocolatey.org/install"
            Write-Info "  Scoop: https://scoop.sh/"
            Write-Info "  Winget: Built into Windows 10 1709+ and Windows 11"
            return $false
        }
        
        # Install missing tools
        if ($TempInstall) {
            Write-Info "Temporarily installing missing tools using $script:PackageManager..."
        } else {
            Write-Info "Installing missing tools using $script:PackageManager..."
        }
        
        foreach ($tool in $missingTools) {
            Write-Info "Installing $tool..."
            if (Install-Package -PackageName $tool -PackageManager $script:PackageManager) {
                Write-Success "Successfully installed $tool"
                if ($TempInstall) {
                    $script:TempInstalledTools += $tool
                }
            } else {
                Write-Error "Failed to install $tool. Please install manually."
                return $false
            }
        }
        
        Write-Success "All dependencies installed successfully!"
        
        # Verify installations by refreshing PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Check if tools are now available
        $stillMissing = @()
        foreach ($tool in $missingTools) {
            if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
                $stillMissing += $tool
            }
        }
        
        if ($stillMissing.Count -gt 0) {
            Write-Error "Some tools are still missing after installation: $($stillMissing -join ', ')"
            Write-Info "You may need to restart your PowerShell session or update your PATH"
            return $false
        }
        
        # Enable cleanup for temp install
        if ($TempInstall -and $script:TempInstalledTools.Count -gt 0) {
            $script:CleanupOnTrap = $true
        }
    }
    
    return $true
}

# Function to cleanup temporarily installed dependencies
function Remove-TempDependencies {
    if ($script:TempInstalledTools.Count -gt 0) {
        Write-Info "Cleaning up temporarily installed dependencies..."
        Write-Info "Tools to remove: $($script:TempInstalledTools -join ', ')"
        
        foreach ($tool in $script:TempInstalledTools) {
            Write-Info "Uninstalling $tool..."
            if (Uninstall-Package -PackageName $tool -PackageManager $script:PackageManager) {
                Write-Success "Successfully uninstalled $tool"
            } else {
                Write-Warning "Failed to uninstall $tool (it may be required by other packages)"
            }
        }
        
        $script:TempInstalledTools = @()
        Write-Success "Cleanup completed!"
    } else {
        Write-Info "No temporary dependencies to clean up"
    }
}

# Function to display usage information
function Show-Usage {
    Write-Host @"
Usage: .\migrate-dependabot-reviewers-windows.ps1 [OPTIONS]

Migrate Dependabot reviewers from .github/dependabot.yml to CODEOWNERS file
Optimized for Windows with auto-dependency installation

Options:
  -Help                  Show this help message
  -NoAutoInstall         Disable automatic dependency installation
  -PermanentInstall      Install dependencies permanently (instead of temp)

Requirements:
  - PowerShell 5.0+ (pre-installed on Windows 10+)
  - Package manager (Chocolatey, Scoop, or Winget)
  - yq and jq (will be auto-installed if missing)

Features:
  - Automatically installs missing dependencies via package managers
  - Temporary installation by default (perfect for CI/CD)
  - Supports multiple package ecosystems
  - Preserves existing CODEOWNERS content
  - Sorts patterns for optimal matching

Examples:
  .\migrate-dependabot-reviewers-windows.ps1                     # Run with temporary installation (default)
  .\migrate-dependabot-reviewers-windows.ps1 -PermanentInstall   # Run with permanent installation
  .\migrate-dependabot-reviewers-windows.ps1 -NoAutoInstall     # Run without auto-installation

"@
}

# Function to get manifest files for each ecosystem
function Get-ManifestFilesForEcosystem {
    param(
        [string]$Ecosystem,
        [string]$Directory
    )
    
    # Normalize directory path
    if (-not $Directory.StartsWith("/")) {
        $Directory = "/$Directory"
    }
    
    if ($Directory -eq "/") {
        $Directory = ""
    } else {
        $Directory = $Directory.TrimEnd("/")
    }
    
    $patterns = @()
    
    switch ($Ecosystem) {
        "bundler" {
            $manifests = @("Gemfile", "Gemfile.lock", "*.gemspec")
        }
        "bun" {
            $manifests = @("package.json", "bun.lockb")
        }
        "npm" {
            $manifests = @("package.json", "package-lock.json", "npm-shrinkwrap.json", "yarn.lock", "pnpm-lock.yaml")
        }
        "cargo" {
            $manifests = @("Cargo.toml", "Cargo.lock")
        }
        "composer" {
            $manifests = @("composer.json", "composer.lock")
        }
        "devcontainers" {
            $manifests = @(".devcontainer/devcontainer.json", ".devcontainer.json")
        }
        "docker" {
            $manifests = @("Dockerfile", "Dockerfile.*", "*.dockerfile")
        }
        "docker-compose" {
            $manifests = @("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")
        }
        "dotnet-sdk" {
            $manifests = @("*.csproj", "*.fsproj", "*.vbproj", "*.sln", "packages.config", "global.json")
        }
        "nuget" {
            $manifests = @("*.csproj", "*.fsproj", "*.vbproj", "*.sln", "packages.config", "Directory.Build.props", "Directory.Packages.props")
        }
        "elm" {
            $manifests = @("elm.json")
        }
        "github-actions" {
            $manifests = @(".github/workflows/*.yml", ".github/workflows/*.yaml", "action.yml", "action.yaml")
        }
        "gitsubmodule" {
            $manifests = @(".gitmodules")
        }
        "gomod" {
            $manifests = @("go.mod", "go.sum")
        }
        "gradle" {
            $manifests = @("build.gradle", "build.gradle.kts", "gradle.properties", "settings.gradle", "settings.gradle.kts")
        }
        "maven" {
            $manifests = @("pom.xml", "*.pom")
        }
        "helm" {
            $manifests = @("Chart.yaml", "Chart.yml", "values.yaml", "values.yml")
        }
        "mix" {
            $manifests = @("mix.exs", "mix.lock")
        }
        "pip" {
            $manifests = @("requirements.txt", "requirements/*.txt", "setup.py", "setup.cfg", "pyproject.toml", "Pipfile", "Pipfile.lock")
        }
        "uv" {
            $manifests = @("pyproject.toml", "uv.lock")
        }
        "pub" {
            $manifests = @("pubspec.yaml", "pubspec.yml", "pubspec.lock")
        }
        "swift" {
            $manifests = @("Package.swift", "Package.resolved")
        }
        "terraform" {
            $manifests = @("*.tf", "*.tfvars", "*.hcl")
        }
        default {
            return @()
        }
    }
    
    # Generate patterns for each manifest file
    foreach ($manifest in $manifests) {
        if ([string]::IsNullOrEmpty($Directory)) {
            # Root directory case
            if ($manifest.Contains("*") -or $manifest.Contains("?")) {
                # Glob pattern
                $patterns += "/$manifest"
                if (-not $manifest.StartsWith("**/")) {
                    $patterns += "/**/$manifest"
                }
            } else {
                # Specific file
                $patterns += "/$manifest"
            }
        } else {
            # Specific directory case
            if ($manifest.Contains("*") -or $manifest.Contains("?")) {
                $patterns += "$Directory/$manifest"
                if (-not $manifest.StartsWith("**/")) {
                    $patterns += "$Directory/**/$manifest"
                }
            } else {
                $patterns += "$Directory/$manifest"
            }
        }
    }
    
    # Remove duplicates and return unique patterns
    return $patterns | Sort-Object -Unique
}

# Function to parse YAML and extract reviewers
function Get-DependabotReviewers {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "dependabot.yml file not found!"
        return $null
    }
    
    try {
        # Extract updates that have reviewers and wrap in array
        $yamlContent = & yq eval '.updates[] | select(has("reviewers")) | {"package-ecosystem": ."package-ecosystem", "directory": .directory // "/", "reviewers": .reviewers}' $FilePath -o json
        $jsonArray = $yamlContent | & jq -s '.'
        return $jsonArray | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to parse dependabot.yml: $_"
        return $null
    }
}

# Function to find existing CODEOWNERS file
function Find-CodeownersFile {
    $possiblePaths = @("CODEOWNERS", ".github\CODEOWNERS", "docs\CODEOWNERS")
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    # Return default location if none found
    return "CODEOWNERS"
}

# Function to sort CODEOWNERS lines
function Sort-CodeownersLines {
    param([string[]]$Lines)
    
    $sortedLines = @()
    
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) {
            continue
        }
        
        $pattern = ($line -split '\s+')[0]
        
        $wildcardCount = ($pattern.ToCharArray() | Where-Object { $_ -eq '*' -or $_ -eq '?' }).Count
        $pathDepth = ($pattern.ToCharArray() | Where-Object { $_ -eq '/' }).Count
        
        $hasExtension = if ($pattern.Contains('.')) { 0 } else { 1 }
        $isRootPattern = if ($pattern -match '^/[^/]*$') { 0 } else { 1 }
        
        # Create sort key object
        $sortedLines += [PSCustomObject]@{
            SortKey = "$isRootPattern`:$wildcardCount`:$hasExtension`:$pathDepth"
            Line = $line
        }
    }
    
    return ($sortedLines | Sort-Object SortKey).Line
}

# Main function
function Start-Migration {
    param(
        [bool]$AutoInstall = $true,
        [bool]$TempInstall = $true
    )
    
    Write-Info "Starting Dependabot reviewers migration to CODEOWNERS (Windows)..."
    
    # Check dependencies first
    if (-not (Test-Dependencies -AutoInstall $AutoInstall -TempInstall $TempInstall)) {
        return $false
    }
    
    $dependabotFile = ".github\dependabot.yml"
    
    # Check if dependabot.yml exists
    if (-not (Test-Path $dependabotFile)) {
        Write-Error "dependabot.yml file not found at $dependabotFile!"
        return $false
    }
    
    # Find CODEOWNERS file
    $codeownersFile = Find-CodeownersFile
    
    if (Test-Path $codeownersFile) {
        Write-Info "Found existing CODEOWNERS file at: $codeownersFile"
    } else {
        Write-Info "No existing CODEOWNERS file found, will create at: $codeownersFile"
    }
    
    # Create directory if it doesn't exist
    $codeownersDir = Split-Path $codeownersFile
    if ($codeownersDir -and -not (Test-Path $codeownersDir)) {
        New-Item -ItemType Directory -Path $codeownersDir -Force | Out-Null
        Write-Info "Created directory: $codeownersDir"
    }
    
    # Parse dependabot.yml and process each update
    $updates = Get-DependabotReviewers -FilePath $dependabotFile
    
    if (-not $updates -or $updates.Count -eq 0) {
        Write-Warning "No reviewers found in dependabot.yml!"
        return $false
    }
    
    # Process each update configuration
    $newReviewerLines = @()
    
    foreach ($update in $updates) {
        $ecosystem = $update.'package-ecosystem'
        $directory = if ($update.directory) { $update.directory } else { "/" }
        $reviewers = $update.reviewers
        
        if (-not $reviewers -or $reviewers.Count -eq 0) {
            continue
        }
        
        Write-Info "Processing ecosystem: $ecosystem, directory: $directory"
        
        # Get manifest patterns for this ecosystem
        $manifestPatterns = Get-ManifestFilesForEcosystem -Ecosystem $ecosystem -Directory $directory
        
        if ($manifestPatterns.Count -eq 0) {
            Write-Warning "No manifest patterns found for ecosystem: $ecosystem"
            continue
        }
        
        # Format reviewers (ensure they start with @)
        $formattedReviewers = @()
        foreach ($reviewer in $reviewers) {
            if (-not $reviewer.StartsWith("@")) {
                $reviewer = "@$reviewer"
            }
            $formattedReviewers += $reviewer
        }
        
        # Create CODEOWNERS lines for each manifest pattern
        foreach ($pattern in $manifestPatterns) {
            $line = "$pattern $($formattedReviewers -join ' ')"
            $newReviewerLines += $line
        }
    }
    
    if ($newReviewerLines.Count -eq 0) {
        Write-Warning "No reviewers configuration found!"
        return $false
    }
    
    # Sort the new reviewer lines
    $sortedLines = Sort-CodeownersLines -Lines $newReviewerLines
    
    # Read existing CODEOWNERS content
    $codeownersContent = ""
    if (Test-Path $codeownersFile) {
        $codeownersContent = Get-Content $codeownersFile -Raw
    }
    
    # Process the CODEOWNERS file
    $dependabotSection = "# Dependabot reviewers (migrated from .github/dependabot.yml)"
    $tempFile = [System.IO.Path]::GetTempFileName()
    
    if ($codeownersContent) {
        Set-Content -Path $tempFile -Value $codeownersContent -NoNewline
    }
    
    # Check if dependabot section already exists
    $sectionExists = $false
    $sectionLineNum = 0
    
    if ($codeownersContent -and $codeownersContent.Contains("# Dependabot reviewers")) {
        $lines = Get-Content $tempFile
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Contains("# Dependabot reviewers")) {
                $sectionExists = $true
                $sectionLineNum = $i + 1  # PowerShell arrays are 0-based, but line numbers are 1-based
                break
            }
        }
    }
    
    $hasChanges = $false
    
    if ($sectionExists) {
        Write-Info "Updating existing Dependabot reviewers section..."
        
        # Read all lines and recreate file
        $allLines = if (Test-Path $tempFile) { Get-Content $tempFile } else { @() }
        $newContent = @()
        
        # Copy lines before the section
        if ($sectionLineNum -gt 1) {
            $newContent += $allLines[0..($sectionLineNum - 2)]
        }
        
        # Add the new section
        $newContent += $dependabotSection
        $newContent += $sortedLines
        
        # Write new content
        Set-Content -Path $tempFile -Value $newContent
        $hasChanges = $true
    } else {
        Write-Info "Adding new Dependabot reviewers section..."
        
        # Add new section at the end
        if (Test-Path $tempFile -and (Get-Item $tempFile).Length -gt 0) {
            Add-Content -Path $tempFile -Value ""
        }
        Add-Content -Path $tempFile -Value $dependabotSection
        Add-Content -Path $tempFile -Value $sortedLines
        
        $hasChanges = $true
    }
    
    # Write changes if any
    if ($hasChanges) {
        Copy-Item $tempFile $codeownersFile -Force
        Write-Success "CODEOWNERS file updated at: $codeownersFile"
        
        # Set GitHub Actions output if running in CI
        if ($env:GITHUB_OUTPUT) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "has_changes=true"
            Add-Content -Path $env:GITHUB_OUTPUT -Value "codeowners_path=$codeownersFile"
        }
    } else {
        Write-Info "No changes were made to CODEOWNERS file"
        
        # Set GitHub Actions output if running in CI
        if ($env:GITHUB_OUTPUT) {
            Add-Content -Path $env:GITHUB_OUTPUT -Value "has_changes=false"
        }
    }
    
    # Cleanup temp file
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    
    Write-Success "Migration completed successfully!"
    
    # Cleanup temporary dependencies if needed
    if ($TempInstall) {
        $script:CleanupOnTrap = $false
        Remove-TempDependencies
    }
    
    return $true
}

# Cleanup on script termination
$script:OnExit = {
    if ($script:CleanupOnTrap -and $script:TempInstalledTools.Count -gt 0) {
        Write-Host ""
        Write-Warning "Script interrupted, cleaning up temporary dependencies..."
        Remove-TempDependencies
    }
}

# Register cleanup event
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $script:OnExit

# Main execution
try {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Set defaults
    $autoInstall = -not $NoAutoInstall
    $tempInstall = -not $PermanentInstall  # Default to temp install unless permanent is specified
    
    # Run the migration
    $success = Start-Migration -AutoInstall $autoInstall -TempInstall $tempInstall
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Error "An error occurred: $_"
    
    # Cleanup on error if needed
    if ($script:CleanupOnTrap -and $script:TempInstalledTools.Count -gt 0) {
        Write-Warning "Cleaning up temporary dependencies due to error..."
        Remove-TempDependencies
    }
    
    exit 1
}
finally {
    # Unregister cleanup event
    Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue
}
