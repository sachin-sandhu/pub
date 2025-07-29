# Windows PowerShell script to migrate Dependabot reviewers to CODEOWNERS
# 
# Optimized for Windows with native PowerShell - no external dependencies required
# Features built-in YAML parsing and JSON processing using PowerShell
# Self-contained script with no package manager requirements
# 
# Requirements:
# - PowerShell 5.0+ (pre-installed on Windows 10+)
# 
# Dependencies:
# - None! Uses built-in PowerShell capabilities for YAML/JSON processing
#
# Features:
# - No external dependencies - completely self-contained
# - Native PowerShell YAML parsing implementation
# - Built-in JSON processing with ConvertFrom-Json

param(
    [switch]$Help
)

# No global variables needed for package management

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

# Function to parse YAML content natively in PowerShell
function ConvertFrom-Yaml {
    param(
        [string]$YamlContent
    )
    
    try {
        # Simple YAML parser for dependabot.yml structure
        $result = @{}
        $updates = @()
        
        $lines = $YamlContent -split "`n"
        $inUpdates = $false
        $currentUpdate = $null
        $inReviewers = $false
        $reviewersList = @()
        $indentLevel = 0
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmedLine = $line.Trim()
            
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($trimmedLine) -or $trimmedLine.StartsWith('#')) {
                continue
            }
            
            # Check for updates section
            if ($trimmedLine -eq 'updates:') {
                $inUpdates = $true
                continue
            }
            
            if ($inUpdates) {
                # Get current line indentation
                $currentIndent = $line.Length - $line.TrimStart().Length
                
                # New update entry (starts with -)
                if ($trimmedLine.StartsWith('- ')) {
                    # Save previous update if it had reviewers
                    if ($currentUpdate -and $currentUpdate.ContainsKey('reviewers') -and $currentUpdate.reviewers.Count -gt 0) {
                        $updates += $currentUpdate
                    }
                    
                    $currentUpdate = @{}
                    $inReviewers = $false
                    $reviewersList = @()
                    $indentLevel = $currentIndent
                    
                    # Parse package-ecosystem on same line
                    $packageEcosystem = $trimmedLine -replace '^-\s*package-ecosystem:\s*', ''
                    if ($packageEcosystem -ne $trimmedLine) {
                        $currentUpdate['package-ecosystem'] = $packageEcosystem.Trim('"').Trim("'")
                    }
                    continue
                }
                
                # Parse key-value pairs within an update
                if ($currentIndent -gt $indentLevel -and $trimmedLine.Contains(':')) {
                    $parts = $trimmedLine -split ':', 2
                    $key = $parts[0].Trim()
                    $value = if ($parts.Count -gt 1) { $parts[1].Trim() } else { '' }
                    
                    switch ($key) {
                        'package-ecosystem' {
                            $currentUpdate['package-ecosystem'] = $value.Trim('"').Trim("'")
                        }
                        'directory' {
                            $currentUpdate['directory'] = $value.Trim('"').Trim("'")
                        }
                        'reviewers' {
                            $inReviewers = $true
                            $reviewersList = @()
                            # Check if reviewers are on the same line
                            if (![string]::IsNullOrWhiteSpace($value)) {
                                # Handle inline array format
                                $inlineReviewers = $value.Trim('[').Trim(']').Split(',')
                                foreach ($reviewer in $inlineReviewers) {
                                    $cleanReviewer = $reviewer.Trim().Trim('"').Trim("'")
                                    if (![string]::IsNullOrWhiteSpace($cleanReviewer)) {
                                        $reviewersList += $cleanReviewer
                                    }
                                }
                                $currentUpdate['reviewers'] = $reviewersList
                                $inReviewers = $false
                            }
                        }
                    }
                    continue
                }
                
                # Parse reviewers list items
                if ($inReviewers -and $trimmedLine.StartsWith('-')) {
                    $reviewer = $trimmedLine -replace '^-\s*', ''
                    $reviewer = $reviewer.Trim('"').Trim("'")
                    if (![string]::IsNullOrWhiteSpace($reviewer)) {
                        $reviewersList += $reviewer
                        $currentUpdate['reviewers'] = $reviewersList
                    }
                    continue
                }
            }
        }
        
        # Add the last update if it has reviewers
        if ($currentUpdate -and $currentUpdate.ContainsKey('reviewers') -and $currentUpdate.reviewers.Count -gt 0) {
            $updates += $currentUpdate
        }
        
        $result['updates'] = $updates
        return $result
    }
    catch {
        Write-Error "Failed to parse YAML content: $_"
        return $null
    }
}

# Function to parse dependabot.yml and extract reviewers
function Get-DependabotReviewers {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "dependabot.yml file not found!"
        return $null
    }
    
    try {
        # Read the YAML file content
        $yamlContent = Get-Content $FilePath -Raw
        
        # Parse YAML using our native parser
        $parsed = ConvertFrom-Yaml -YamlContent $yamlContent
        
        if (-not $parsed -or -not $parsed.updates) {
            Write-Warning "No updates found in dependabot.yml"
            return @()
        }
        
        # Filter updates that have reviewers and convert to expected format
        $reviewerUpdates = @()
        foreach ($update in $parsed.updates) {
            if ($update.ContainsKey('reviewers') -and $update.reviewers.Count -gt 0) {
                $reviewerUpdate = @{
                    'package-ecosystem' = $update['package-ecosystem']
                    'directory' = if ($update.ContainsKey('directory')) { $update['directory'] } else { '/' }
                    'reviewers' = $update['reviewers']
                }
                $reviewerUpdates += $reviewerUpdate
            }
        }
        
        return $reviewerUpdates
    }
    catch {
        Write-Error "Failed to parse dependabot.yml: $_"
        return $null
    }
}

# Function to display usage information
function Show-Usage {
    Write-Host @"
Usage: .\migrate-dependabot-reviewers-windows.ps1 [OPTIONS]

Migrate Dependabot reviewers from .github/dependabot.yml to CODEOWNERS file
Self-contained PowerShell script with no external dependencies

Options:
  -Help                  Show this help message

Requirements:
  - PowerShell 5.0+ (pre-installed on Windows 10+)

Features:
  - No external dependencies - completely self-contained
  - Native PowerShell YAML parsing implementation
  - Built-in JSON processing capabilities
  - Supports multiple package ecosystems
  - Preserves existing CODEOWNERS content
  - Sorts patterns for optimal matching

Examples:
  .\migrate-dependabot-reviewers-windows.ps1       # Run the migration
  .\migrate-dependabot-reviewers-windows.ps1 -Help # Show this help

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
        # Read the YAML file content
        $yamlContent = Get-Content $FilePath -Raw
        
        # Parse YAML using our native parser
        $parsed = ConvertFrom-Yaml -YamlContent $yamlContent
        
        if (-not $parsed -or -not $parsed.updates) {
            Write-Warning "No updates found in dependabot.yml"
            return @()
        }
        
        # Filter updates that have reviewers and convert to expected format
        $reviewerUpdates = @()
        foreach ($update in $parsed.updates) {
            if ($update.ContainsKey('reviewers') -and $update.reviewers.Count -gt 0) {
                $reviewerUpdate = @{
                    'package-ecosystem' = $update['package-ecosystem']
                    'directory' = if ($update.ContainsKey('directory')) { $update['directory'] } else { '/' }
                    'reviewers' = $update['reviewers']
                }
                $reviewerUpdates += $reviewerUpdate
            }
        }
        
        return $reviewerUpdates
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
    Write-Info "Starting Dependabot reviewers migration to CODEOWNERS (Windows)..."
    
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
    
    return $true
}
}

# Main execution
try {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    # Run the migration
    $success = Start-Migration
    
    if ($success) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
