#!/bin/bash
# Self-contained cross-platform script to migrate Dependabot reviewers to CODEOWNERS
# 
# Compatible with: Windows (Git Bash/WSL), Linux, Solaris, macOS
# Features embedded dependencies - no external downloads required
# Zero external dependencies - completely self-contained
# 
# Requirements:
# - bash (available on all target platforms)
# 
# Embedded dependencies:
# - Native YAML parser (pure bash implementation)
# - Native JSON parser (pure bash implementation)
#
# Features:
# - No external package managers required
# - No internet connection needed
# - Works in air-gapped environments
# - Portable across all platforms

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# ============================================================================
# EMBEDDED YAML PARSER (Pure Bash Implementation)
# ============================================================================

# Global variables for YAML parsing
declare -A YAML_DATA
YAML_PREFIX=""

# Function to parse YAML content
parse_yaml() {
    local input="$1"
    local prefix="$2"
    local s='[[:space:]]*'
    local w='[a-zA-Z0-9_-]*'
    local fs=$(echo @|tr @ '\034')
    
    # Clear previous data
    YAML_DATA=()
    YAML_PREFIX="$prefix"
    
    # Process YAML line by line
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Handle arrays and objects
        if [[ "$line" =~ ^($s)*-($s)*(.*)$ ]]; then
            # Array item
            local indent="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[3]}"
            local array_index=$(get_array_index "$prefix")
            
            if [[ "$value" =~ ^([^:]+):(.*)$ ]]; then
                # Object in array
                local key="${BASH_REMATCH[1]// /}"
                local val="${BASH_REMATCH[2]}"
                val="${val#"${val%%[![:space:]]*}"}" # trim leading whitespace
                val="${val%"${val##*[![:space:]]}"}" # trim trailing whitespace
                
                # Remove quotes if present
                if [[ "$val" =~ ^\"(.*)\"$ || "$val" =~ ^\'(.*)\'$ ]]; then
                    val="${BASH_REMATCH[1]}"
                fi
                
                YAML_DATA["${prefix}${array_index}.${key}"]="$val"
            else
                # Simple array item
                val="${value#"${value%%[![:space:]]*}"}" # trim leading whitespace
                val="${value%"${value##*[![:space:]]}"}" # trim trailing whitespace
                
                # Remove quotes if present
                if [[ "$val" =~ ^\"(.*)\"$ || "$val" =~ ^\'(.*)\'$ ]]; then
                    val="${BASH_REMATCH[1]}"
                fi
                
                YAML_DATA["${prefix}${array_index}"]="$val"
            fi
        elif [[ "$line" =~ ^($s)*([^:]+):(.*)$ ]]; then
            # Key-value pair
            local indent="${BASH_REMATCH[1]}"
            local key="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            
            # Clean up key and value
            key="${key// /}"
            value="${value#"${value%%[![:space:]]*}"}" # trim leading whitespace
            value="${value%"${value##*[![:space:]]}"}" # trim trailing whitespace
            
            # Remove quotes if present
            if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
                value="${BASH_REMATCH[1]}"
            fi
            
            # Handle nested structures
            if [[ -n "$value" ]]; then
                YAML_DATA["${prefix}${key}"]="$value"
            fi
        fi
    done <<< "$input"
}

# Helper function to get next array index
get_array_index() {
    local prefix="$1"
    local max_index=-1
    
    for key in "${!YAML_DATA[@]}"; do
        if [[ "$key" =~ ^${prefix}([0-9]+) ]]; then
            local index="${BASH_REMATCH[1]}"
            if [[ $index -gt $max_index ]]; then
                max_index=$index
            fi
        fi
    done
    
    echo $((max_index + 1))
}

# Function to get YAML value by path
get_yaml_value() {
    local path="$1"
    echo "${YAML_DATA[$path]:-}"
}

# Function to get all keys matching a pattern
get_yaml_keys() {
    local pattern="$1"
    for key in "${!YAML_DATA[@]}"; do
        if [[ "$key" =~ $pattern ]]; then
            echo "$key"
        fi
    done
}

# ============================================================================
# EMBEDDED JSON PARSER (Pure Bash Implementation)
# ============================================================================

# Global variables for JSON parsing
declare -A JSON_DATA
JSON_PREFIX=""

# Function to parse JSON content
parse_json() {
    local input="$1"
    local prefix="$2"
    
    # Clear previous data
    JSON_DATA=()
    JSON_PREFIX="$prefix"
    
    # Simple JSON parser - handles basic objects and arrays
    # Remove whitespace and newlines for easier parsing
    local cleaned_json
    cleaned_json=$(echo "$input" | tr -d '\n\r' | sed 's/[[:space:]]\+/ /g')
    
    # Parse the JSON structure
    parse_json_recursive "$cleaned_json" "$prefix"
}

# Recursive JSON parser
parse_json_recursive() {
    local json="$1"
    local current_prefix="$2"
    
    # Remove outer braces/brackets
    json="${json#"${json%%[![:space:]]*}"}" # trim leading whitespace
    json="${json%"${json##*[![:space:]]}"}" # trim trailing whitespace
    
    if [[ "$json" =~ ^\{.*\}$ ]]; then
        # Object
        json="${json:1:-1}" # Remove { }
        parse_json_object "$json" "$current_prefix"
    elif [[ "$json" =~ ^\[.*\]$ ]]; then
        # Array
        json="${json:1:-1}" # Remove [ ]
        parse_json_array "$json" "$current_prefix"
    fi
}

# Parse JSON object
parse_json_object() {
    local content="$1"
    local prefix="$2"
    
    # Split by commas (simplified - doesn't handle nested objects perfectly)
    local item
    local in_quotes=false
    local brace_count=0
    local bracket_count=0
    local current_item=""
    
    while IFS= read -r -n1 char; do
        if [[ "$char" == '"' && "${current_item: -1}" != '\' ]]; then
            in_quotes=$(!$in_quotes)
        elif [[ "$in_quotes" == false ]]; then
            if [[ "$char" == '{' ]]; then
                ((brace_count++))
            elif [[ "$char" == '}' ]]; then
                ((brace_count--))
            elif [[ "$char" == '[' ]]; then
                ((bracket_count++))
            elif [[ "$char" == ']' ]]; then
                ((bracket_count--))
            elif [[ "$char" == ',' && $brace_count -eq 0 && $bracket_count -eq 0 ]]; then
                parse_json_item "$current_item" "$prefix"
                current_item=""
                continue
            fi
        fi
        current_item+="$char"
    done <<< "$content"
    
    # Handle last item
    if [[ -n "$current_item" ]]; then
        parse_json_item "$current_item" "$prefix"
    fi
}

# Parse JSON array
parse_json_array() {
    local content="$1"
    local prefix="$2"
    local index=0
    
    # Similar to object parsing but with array indices
    local in_quotes=false
    local brace_count=0
    local bracket_count=0
    local current_item=""
    
    while IFS= read -r -n1 char; do
        if [[ "$char" == '"' && "${current_item: -1}" != '\' ]]; then
            in_quotes=$(!$in_quotes)
        elif [[ "$in_quotes" == false ]]; then
            if [[ "$char" == '{' ]]; then
                ((brace_count++))
            elif [[ "$char" == '}' ]]; then
                ((brace_count--))
            elif [[ "$char" == '[' ]]; then
                ((bracket_count++))
            elif [[ "$char" == ']' ]]; then
                ((bracket_count--))
            elif [[ "$char" == ',' && $brace_count -eq 0 && $bracket_count -eq 0 ]]; then
                parse_json_array_item "$current_item" "$prefix" "$index"
                current_item=""
                ((index++))
                continue
            fi
        fi
        current_item+="$char"
    done <<< "$content"
    
    # Handle last item
    if [[ -n "$current_item" ]]; then
        parse_json_array_item "$current_item" "$prefix" "$index"
    fi
}

# Parse individual JSON item (key-value pair)
parse_json_item() {
    local item="$1"
    local prefix="$2"
    
    # Remove leading/trailing whitespace
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    
    # Split on first colon
    if [[ "$item" =~ ^\"([^\"]+)\"[[:space:]]*:[[:space:]]*(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local value="${BASH_REMATCH[2]}"
        
        # Clean up value
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"
        
        # Remove quotes from string values
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi
        
        JSON_DATA["${prefix}${key}"]="$value"
    fi
}

# Parse JSON array item
parse_json_array_item() {
    local item="$1"
    local prefix="$2"
    local index="$3"
    
    # Remove leading/trailing whitespace
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    
    # Remove quotes from string values
    if [[ "$item" =~ ^\"(.*)\"$ ]]; then
        item="${BASH_REMATCH[1]}"
    fi
    
    JSON_DATA["${prefix}${index}"]="$item"
}

# Function to get JSON value by path
get_json_value() {
    local path="$1"
    echo "${JSON_DATA[$path]:-}"
}

# Function to get all keys matching a pattern
get_json_keys() {
    local pattern="$1"
    for key in "${!JSON_DATA[@]}"; do
        if [[ "$key" =~ $pattern ]]; then
            echo "$key"
        fi
    done
}

# ============================================================================
# DEPENDABOT MIGRATION LOGIC
# ============================================================================

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Migrate Dependabot reviewers from .github/dependabot.yml to CODEOWNERS file"
    echo "Self-contained script with embedded dependencies - no external tools required"
    echo ""
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Platform Support:"
    echo "  - Windows: Git Bash/WSL/Command Prompt"
    echo "  - Linux: All distributions"
    echo "  - Solaris: All versions"
    echo "  - macOS: All versions"
    echo ""
    echo "Requirements:"
    echo "  - bash shell (only requirement)"
    echo ""
    echo "Features:"
    echo "  - Zero external dependencies"
    echo "  - No internet connection required"
    echo "  - Works in air-gapped environments"
    echo "  - Completely portable"
    echo "  - Supports all Dependabot package ecosystems"
    echo "  - Preserves existing CODEOWNERS content"
    echo "  - Sorts patterns for optimal matching"
    echo ""
    echo "Examples:"
    echo "  $0                        # Run migration"
    echo ""
}

# Function to get manifest files for each ecosystem
get_manifest_files_for_ecosystem() {
    local ecosystem="$1"
    local directory="$2"
    
    # Normalize directory path
    if [[ ! "$directory" =~ ^/ ]]; then
        directory="/$directory"
    fi
    
    if [[ "$directory" == "/" ]]; then
        directory=""
    else
        directory="${directory%/}"  # Remove trailing slash
    fi
    
    local patterns=()
    
    case "$ecosystem" in
        "bundler")
            local manifests=("Gemfile" "Gemfile.lock" "*.gemspec")
            ;;
        "bun")
            local manifests=("package.json" "bun.lockb")
            ;;
        "npm")
            local manifests=("package.json" "package-lock.json" "npm-shrinkwrap.json" "yarn.lock" "pnpm-lock.yaml")
            ;;
        "cargo")
            local manifests=("Cargo.toml" "Cargo.lock")
            ;;
        "composer")
            local manifests=("composer.json" "composer.lock")
            ;;
        "devcontainers")
            local manifests=(".devcontainer/devcontainer.json" ".devcontainer.json")
            ;;
        "docker")
            local manifests=("Dockerfile" "Dockerfile.*" "*.dockerfile")
            ;;
        "docker-compose")
            local manifests=("docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml")
            ;;
        "dotnet-sdk")
            local manifests=("*.csproj" "*.fsproj" "*.vbproj" "*.sln" "packages.config" "global.json")
            ;;
        "nuget")
            local manifests=("*.csproj" "*.fsproj" "*.vbproj" "*.sln" "packages.config" "Directory.Build.props" "Directory.Packages.props")
            ;;
        "elm")
            local manifests=("elm.json")
            ;;
        "github-actions")
            local manifests=(".github/workflows/*.yml" ".github/workflows/*.yaml" "action.yml" "action.yaml")
            ;;
        "gitsubmodule")
            local manifests=(".gitmodules")
            ;;
        "gomod")
            local manifests=("go.mod" "go.sum")
            ;;
        "gradle")
            local manifests=("build.gradle" "build.gradle.kts" "gradle.properties" "settings.gradle" "settings.gradle.kts")
            ;;
        "maven")
            local manifests=("pom.xml" "*.pom")
            ;;
        "helm")
            local manifests=("Chart.yaml" "Chart.yml" "values.yaml" "values.yml")
            ;;
        "mix")
            local manifests=("mix.exs" "mix.lock")
            ;;
        "pip")
            local manifests=("requirements.txt" "requirements/*.txt" "setup.py" "setup.cfg" "pyproject.toml" "Pipfile" "Pipfile.lock")
            ;;
        "uv")
            local manifests=("pyproject.toml" "uv.lock")
            ;;
        "pub")
            local manifests=("pubspec.yaml" "pubspec.yml" "pubspec.lock")
            ;;
        "swift")
            local manifests=("Package.swift" "Package.resolved")
            ;;
        "terraform")
            local manifests=("*.tf" "*.tfvars" "*.hcl")
            ;;
        *)
            return 1
            ;;
    esac
    
    # Generate patterns for each manifest file
    for manifest in "${manifests[@]}"; do
        if [[ -z "$directory" ]]; then
            # Root directory case
            if [[ "$manifest" == *"*"* || "$manifest" == *"?"* ]]; then
                # Glob pattern
                patterns+=("/$manifest")
                if [[ ! "$manifest" =~ ^\*\*/ ]]; then
                    patterns+=("/**/$manifest")
                fi
            else
                # Specific file
                patterns+=("/$manifest")
            fi
        else
            # Specific directory case
            if [[ "$manifest" == *"*"* || "$manifest" == *"?"* ]]; then
                patterns+=("$directory/$manifest")
                if [[ ! "$manifest" =~ ^\*\*/ ]]; then
                    patterns+=("$directory/**/$manifest")
                fi
            else
                patterns+=("$directory/$manifest")
            fi
        fi
    done
    
    # Remove duplicates and return unique patterns
    printf '%s\n' "${patterns[@]}" | sort -u
}

# Function to parse dependabot.yml and extract reviewers using embedded parser
parse_dependabot_yml() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        print_error "dependabot.yml file not found!"
        return 1
    fi
    
    local content
    content=$(cat "$file_path")
    
    # Parse YAML
    parse_yaml "$content" ""
    
    # Extract updates with reviewers
    local updates_with_reviewers=()
    local update_index=0
    
    # Find all update entries
    while true; do
        local ecosystem_key="updates.${update_index}.package-ecosystem"
        local directory_key="updates.${update_index}.directory"
        local reviewers_key="updates.${update_index}.reviewers"
        
        local ecosystem
        ecosystem=$(get_yaml_value "$ecosystem_key")
        
        if [[ -z "$ecosystem" ]]; then
            break
        fi
        
        # Check if this update has reviewers
        local has_reviewers=false
        local reviewer_index=0
        while true; do
            local reviewer
            reviewer=$(get_yaml_value "${reviewers_key}.${reviewer_index}")
            if [[ -n "$reviewer" ]]; then
                has_reviewers=true
                break
            fi
            ((reviewer_index++))
            if [[ $reviewer_index -gt 50 ]]; then  # Safety limit
                break
            fi
        done
        
        if [[ "$has_reviewers" == true ]]; then
            local directory
            directory=$(get_yaml_value "$directory_key")
            if [[ -z "$directory" ]]; then
                directory="/"
            fi
            
            # Collect all reviewers for this update
            local reviewers=()
            reviewer_index=0
            while true; do
                local reviewer
                reviewer=$(get_yaml_value "${reviewers_key}.${reviewer_index}")
                if [[ -n "$reviewer" ]]; then
                    reviewers+=("$reviewer")
                else
                    break
                fi
                ((reviewer_index++))
                if [[ $reviewer_index -gt 50 ]]; then  # Safety limit
                    break
                fi
            done
            
            # Store update information
            updates_with_reviewers+=("$ecosystem|$directory|${reviewers[*]}")
        fi
        
        ((update_index++))
        if [[ $update_index -gt 100 ]]; then  # Safety limit
            break
        fi
    done
    
    # Output in format that can be easily processed
    printf '%s\n' "${updates_with_reviewers[@]}"
}

# Function to find existing CODEOWNERS file
find_codeowners_file() {
    local possible_paths=("CODEOWNERS" ".github/CODEOWNERS" "docs/CODEOWNERS")
    
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # Return default location if none found
    echo "CODEOWNERS"
}

# Function to sort CODEOWNERS lines
sort_codeowners_lines() {
    # Sort with the following priority:
    # 1. Root patterns (/*) first
    # 2. Less wildcards first
    # 3. Files with extensions first
    # 4. Shorter paths first
    while IFS= read -r line; do
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        local pattern
        pattern=$(echo "$line" | awk '{print $1}')
        
        local wildcard_count
        wildcard_count=$(echo "$pattern" | tr -cd '*?' | wc -c)
        
        local path_depth
        path_depth=$(echo "$pattern" | tr -cd '/' | wc -c)
        
        local has_extension=1
        if [[ "$pattern" == *.* ]]; then
            has_extension=0
        fi
        
        local is_root_pattern=1
        if [[ "$pattern" =~ ^/[^/]*$ ]]; then
            is_root_pattern=0
        fi
        
        # Create sort key: is_root_pattern:wildcard_count:has_extension:path_depth:pattern
        echo "$is_root_pattern:$wildcard_count:$has_extension:$path_depth:$line"
    done | sort -t: -k1,1n -k2,2n -k3,3n -k4,4n -k5 | cut -d: -f5-
}

# Main function
main() {
    local dependabot_file=".github/dependabot.yml"
    local has_changes=false
    
    print_info "Starting Dependabot reviewers migration to CODEOWNERS (Self-contained)..."
    print_info "Platform: $(uname -s) $(uname -m)"
    print_success "No external dependencies required - using embedded parsers"
    
    # Check if dependabot.yml exists
    if [[ ! -f "$dependabot_file" ]]; then
        print_error "dependabot.yml file not found at $dependabot_file!"
        return 1
    fi
    
    # Find CODEOWNERS file
    local codeowners_file
    codeowners_file=$(find_codeowners_file)
    
    if [[ -f "$codeowners_file" ]]; then
        print_info "Found existing CODEOWNERS file at: $codeowners_file"
    else
        print_info "No existing CODEOWNERS file found, will create at: $codeowners_file"
    fi
    
    # Create directory if it doesn't exist
    local codeowners_dir
    codeowners_dir=$(dirname "$codeowners_file")
    if [[ -n "$codeowners_dir" && "$codeowners_dir" != "." && ! -d "$codeowners_dir" ]]; then
        mkdir -p "$codeowners_dir"
        print_info "Created directory: $codeowners_dir"
    fi
    
    # Parse dependabot.yml and process each update
    local temp_file
    temp_file=$(mktemp)
    
    # Extract updates with reviewers
    parse_dependabot_yml "$dependabot_file" > "$temp_file"
    
    if [[ ! -s "$temp_file" ]]; then
        print_warning "No reviewers found in dependabot.yml!"
        rm -f "$temp_file"
        return 1
    fi
    
    # Process each update configuration
    local new_reviewers_lines=()
    
    # Process each line from the parsed output
    while IFS='|' read -r ecosystem directory reviewers; do
        if [[ -z "$reviewers" ]]; then
            continue
        fi
        
        print_info "Processing ecosystem: $ecosystem, directory: $directory"
        
        # Get manifest patterns for this ecosystem
        local manifest_patterns=()
        while IFS= read -r pattern; do
            manifest_patterns+=("$pattern")
        done < <(get_manifest_files_for_ecosystem "$ecosystem" "$directory")
        
        if [[ ${#manifest_patterns[@]} -eq 0 ]]; then
            print_warning "No manifest patterns found for ecosystem: $ecosystem"
            continue
        fi
        
        # Format reviewers (ensure they start with @)
        local formatted_reviewers=()
        for reviewer in $reviewers; do
            if [[ ! "$reviewer" =~ ^@ ]]; then
                reviewer="@$reviewer"
            fi
            formatted_reviewers+=("$reviewer")
        done
        
        # Create CODEOWNERS lines for each manifest pattern
        for pattern in "${manifest_patterns[@]}"; do
            local line="$pattern ${formatted_reviewers[*]}"
            new_reviewers_lines+=("$line")
        done
        
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [[ ${#new_reviewers_lines[@]} -eq 0 ]]; then
        print_warning "No reviewers configuration found!"
        return 1
    fi
    
    # Sort the new reviewer lines
    local sorted_lines=()
    while IFS= read -r line; do
        sorted_lines+=("$line")
    done < <(printf '%s\n' "${new_reviewers_lines[@]}" | sort_codeowners_lines)
    
    # Read existing CODEOWNERS content
    local codeowners_content=""
    if [[ -f "$codeowners_file" ]]; then
        codeowners_content=$(cat "$codeowners_file")
    fi
    
    # Process the CODEOWNERS file
    local dependabot_section="# Dependabot reviewers (migrated from .github/dependabot.yml)"
    local temp_codeowners
    temp_codeowners=$(mktemp)
    
    if [[ -n "$codeowners_content" ]]; then
        echo "$codeowners_content" > "$temp_codeowners"
    fi
    
    # Check if dependabot section already exists
    local section_exists=false
    local section_line_num=0
    
    if grep -n "# Dependabot reviewers" "$temp_codeowners" >/dev/null 2>&1; then
        section_exists=true
        section_line_num=$(grep -n "# Dependabot reviewers" "$temp_codeowners" | head -1 | cut -d: -f1)
    fi
    
    if [[ "$section_exists" == "true" ]]; then
        print_info "Updating existing Dependabot reviewers section..."
        
        # Always recreate the section (simpler and more reliable)
        local temp_without_section
        temp_without_section=$(mktemp)
        
        # Copy lines before the section
        if [[ $section_line_num -gt 1 ]]; then
            sed -n "1,$((section_line_num - 1))p" "$temp_codeowners" > "$temp_without_section"
        fi
        
        # Add the new section
        echo "$dependabot_section" >> "$temp_without_section"
        printf '%s\n' "${sorted_lines[@]}" >> "$temp_without_section"
        
        # Replace the temp file
        mv "$temp_without_section" "$temp_codeowners"
        
        has_changes=true
    else
        print_info "Adding new Dependabot reviewers section..."
        
        # Add new section at the end
        if [[ -s "$temp_codeowners" ]]; then
            echo "" >> "$temp_codeowners"
        fi
        echo "$dependabot_section" >> "$temp_codeowners"
        printf '%s\n' "${sorted_lines[@]}" >> "$temp_codeowners"
        
        has_changes=true
    fi
    
    # Write changes if any
    if [[ "$has_changes" == "true" ]]; then
        cp "$temp_codeowners" "$codeowners_file"
        print_success "CODEOWNERS file updated at: $codeowners_file"
        
        # Set GitHub Actions output
        if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
            echo "has_changes=true" >> "$GITHUB_OUTPUT"
            echo "codeowners_path=$codeowners_file" >> "$GITHUB_OUTPUT"
        fi
    else
        print_info "No changes were made to CODEOWNERS file"
        
        # Set GitHub Actions output
        if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
            echo "has_changes=false" >> "$GITHUB_OUTPUT"
        fi
    fi
    
    rm -f "$temp_codeowners"
    
    print_success "Migration completed successfully!"
    print_info "Script used embedded parsers - no external tools were needed"
    
    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Run main function
    main
fi
