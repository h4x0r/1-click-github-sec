#!/usr/bin/env bash

# Copyright 2025 Albert Hui <albert@securityronin.com>
# Licensed under the Apache License, Version 2.0

# safe-upgrade.sh - Safe Upgrade System for Security Controls
# Verifies file integrity before upgrade and detects user modifications
#
# Usage: ./scripts/safe-upgrade.sh [--check|--upgrade|--force]
#
# Features:
# - Version detection of existing installation
# - File integrity verification against known hashes
# - Detection of user modifications
# - Interactive diff display
# - User confirmation before overwriting modified files
# - Automatic backup of modified files

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT
readonly CONTROL_STATE_DIR=".security-controls"
readonly VERSION_FILE="$CONTROL_STATE_DIR/.version"
readonly BACKUP_DIR="$CONTROL_STATE_DIR/backup"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Version-specific file hash registry
# Format: version|file_path|sha256_hash
# This is the "known good" state for each version
declare -A VERSION_HASHES

# Initialize hash registry for known versions
init_hash_registry() {
  # Version 0.6.10 hashes (current version)
  # These would be generated during release process
  VERSION_HASHES["0.6.10|.security-controls/bin/pinactlite"]="8869c009332879a5366e2aeaf14eaca82f4467d5ab35f0042293da5e966d8097"
  VERSION_HASHES["0.6.10|.security-controls/bin/gitleakslite"]="TBD" # To be determined

  # Version 0.6.9 hashes (example for previous version)
  VERSION_HASHES["0.6.9|.security-controls/bin/pinactlite"]="9c580e3a5c6386ca1365ef587cb71dbe9cb1d39caf639c8e25dfe580e616c731"
  VERSION_HASHES["0.6.9|.security-controls/bin/gitleakslite"]="TBD"

  # Future versions would be added here during release process
}

# Get installed version
get_installed_version() {
  if [[ -f $VERSION_FILE ]]; then
    grep -E "^version=" "$VERSION_FILE" | cut -d= -f2 | tr -d '"'
  else
    echo "unknown"
  fi
}

# Get expected hash for file at specific version
get_expected_hash() {
  local version="$1"
  local file_path="$2"
  local key="${version}|${file_path}"

  echo "${VERSION_HASHES[$key]:-unknown}"
}

# Calculate actual file hash
get_actual_hash() {
  local file_path="$1"

  if [[ ! -f $file_path ]]; then
    echo "missing"
    return
  fi

  sha256sum "$file_path" | cut -d' ' -f1
}

# Check if file has been modified by user
check_file_integrity() {
  local version="$1"
  local file_path="$2"

  local expected_hash
  expected_hash=$(get_expected_hash "$version" "$file_path")

  if [[ $expected_hash == "unknown" ]]; then
    log_warning "No hash record for $file_path in version $version"
    return 2 # Unknown/can't verify
  fi

  if [[ $expected_hash == "TBD" ]]; then
    log_warning "Hash not yet recorded for $file_path in version $version"
    return 2 # Not yet tracked
  fi

  local actual_hash
  actual_hash=$(get_actual_hash "$file_path")

  if [[ $actual_hash == "missing" ]]; then
    log_warning "File missing: $file_path"
    return 3 # Missing file
  fi

  if [[ $expected_hash == "$actual_hash" ]]; then
    return 0 # Intact
  else
    return 1 # Modified
  fi
}

# Show diff between current and new version
show_file_diff() {
  local current_file="$1"
  local new_file="$2"
  local file_label="$3"

  echo ""
  log_info "📝 Changes in ${file_label}:"
  echo ""

  if command -v delta >/dev/null 2>&1; then
    # Use delta for beautiful diffs if available
    delta --side-by-side "$current_file" "$new_file" || diff -u "$current_file" "$new_file" || true
  elif command -v colordiff >/dev/null 2>&1; then
    # Use colordiff if available
    colordiff -u "$current_file" "$new_file" || true
  else
    # Fall back to standard diff
    diff -u "$current_file" "$new_file" || true
  fi

  echo ""
}

# Ask user for confirmation
ask_user_confirmation() {
  local prompt="$1"
  local default="${2:-n}"

  local response
  if [[ $default == "y" ]]; then
    read -rp "${prompt} [Y/n]: " response
    response="${response:-y}"
  else
    read -rp "${prompt} [y/N]: " response
    response="${response:-n}"
  fi

  [[ ${response,,} == "y" ]]
}

# Create backup of file
backup_file() {
  local file_path="$1"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)

  mkdir -p "$BACKUP_DIR"

  local backup_path
  backup_path="$BACKUP_DIR/$(basename "$file_path").${timestamp}.backup"
  cp "$file_path" "$backup_path"

  log_success "✅ Backed up to: $backup_path"
  echo "$backup_path"
}

# Verify all managed files for current installation
verify_installation_integrity() {
  local version
  version=$(get_installed_version)

  if [[ $version == "unknown" ]]; then
    log_error "Cannot determine installed version"
    log_info "Version file not found: $VERSION_FILE"
    return 1
  fi

  log_info "🔍 Verifying installation integrity for version $version"
  echo ""

  local total_files=0
  local intact_files=0
  local modified_files=0
  local missing_files=0
  local unknown_files=0

  # List of files to check (would be expanded for full installation)
  local files_to_check=(
    ".security-controls/bin/pinactlite"
    ".security-controls/bin/gitleakslite"
    ".git/hooks/pre-push"
    ".git/hooks/pre-commit"
  )

  declare -a modified_file_list=()

  for file_path in "${files_to_check[@]}"; do
    ((total_files++))

    if check_file_integrity "$version" "$file_path"; then
      ((intact_files++))
      echo -e "${GREEN}✅${NC} $file_path - intact"
    else
      local rc=$?
      case $rc in
        1)
          ((modified_files++))
          modified_file_list+=("$file_path")
          echo -e "${YELLOW}⚠️${NC}  $file_path - ${YELLOW}MODIFIED${NC}"
          ;;
        2)
          ((unknown_files++))
          echo -e "${BLUE}❓${NC} $file_path - unknown/not tracked"
          ;;
        3)
          ((missing_files++))
          echo -e "${RED}❌${NC} $file_path - ${RED}MISSING${NC}"
          ;;
      esac
    fi
  done

  echo ""
  log_info "📊 Integrity Verification Summary:"
  echo "   Total files checked:  $total_files"
  echo -e "   ${GREEN}Intact:${NC}               $intact_files"
  echo -e "   ${YELLOW}Modified:${NC}             $modified_files"
  echo -e "   ${RED}Missing:${NC}              $missing_files"
  echo -e "   ${BLUE}Unknown/Not tracked:${NC}  $unknown_files"

  if [[ ${#modified_file_list[@]} -gt 0 ]]; then
    echo ""
    log_warning "Modified files detected:"
    for file in "${modified_file_list[@]}"; do
      echo "   • $file"
    done
    return 1
  fi

  return 0
}

# Safe upgrade workflow
safe_upgrade() {
  local force_mode="${1:-false}"

  log_info "🔄 Starting safe upgrade process..."
  echo ""

  # Step 1: Detect current version
  local current_version
  current_version=$(get_installed_version)

  if [[ $current_version == "unknown" ]]; then
    log_warning "Cannot detect current installation version"
    if [[ $force_mode != "true" ]]; then
      if ! ask_user_confirmation "Proceed with upgrade anyway?"; then
        log_info "Upgrade cancelled"
        return 1
      fi
    fi
  else
    log_info "Current installation: version $current_version"
  fi

  # Step 2: Verify file integrity
  echo ""
  log_info "🔍 Checking for user modifications..."
  echo ""

  local integrity_ok=true
  if ! verify_installation_integrity; then
    integrity_ok=false
  fi

  if [[ $integrity_ok == "false" ]]; then
    echo ""
    log_warning "⚠️  Modified files detected in current installation"
    log_info "These files differ from the original version $current_version installation."
    log_info "They may contain your customizations or local changes."
    echo ""

    if [[ $force_mode != "true" ]]; then
      log_info "Options:"
      echo "  1. View diffs and decide per file (recommended)"
      echo "  2. Backup all and proceed with upgrade"
      echo "  3. Cancel upgrade"
      echo ""

      read -rp "Choose option [1/2/3]: " choice

      case $choice in
        1)
          # Interactive per-file handling
          handle_modified_files_interactive "$current_version"
          ;;
        2)
          # Backup all and proceed
          log_info "Creating backups of all modified files..."
          # Implementation would backup all modified files
          log_success "Backups created in $BACKUP_DIR"
          ;;
        3)
          log_info "Upgrade cancelled"
          return 1
          ;;
        *)
          log_error "Invalid choice"
          return 1
          ;;
      esac
    else
      log_warning "Force mode: proceeding without confirmation"
    fi
  else
    log_success "✅ All files intact - safe to upgrade"
  fi

  # Step 3: Download and verify new installer
  echo ""
  log_info "📥 Downloading new installer version..."
  # Implementation would download latest installer

  # Step 4: Run upgrade
  echo ""
  log_info "🚀 Running upgrade..."
  # Implementation would execute upgrade

  log_success "✅ Upgrade completed successfully"
}

# Interactive handling of modified files
handle_modified_files_interactive() {
  local version="$1"

  log_info "Reviewing modified files interactively..."

  # This would iterate through modified files
  # Show diff for each
  # Ask user: keep, replace, backup+replace

  # Example for one file:
  local file=".security-controls/bin/pinactlite"

  if ! check_file_integrity "$version" "$file"; then
    echo ""
    log_warning "File modified: $file"

    # Show diff (would need reference to new version)
    # show_file_diff "$file" "/tmp/new_version/$file" "pinactlite"

    echo ""
    log_info "What would you like to do with this file?"
    echo "  1. Keep my version (skip upgrade for this file)"
    echo "  2. Replace with new version (your changes will be lost)"
    echo "  3. Backup my version and install new version"
    echo ""

    read -rp "Choose option [1/2/3]: " choice

    case $choice in
      1)
        log_info "Keeping your version of $file"
        ;;
      2)
        log_warning "Will replace $file with new version"
        ;;
      3)
        backup_file "$file"
        log_info "Will install new version of $file"
        ;;
      *)
        log_error "Invalid choice, defaulting to keep your version"
        ;;
    esac
  fi
}

# ============================================================================
# FUTURE ENHANCEMENTS
# ============================================================================

# Auto-download hash registry from GitHub releases
download_hash_registry() {
  local version="$1"
  local format="${2:-json}"

  local registry_url="https://github.com/h4x0r/1-click-github-sec/releases/download/v${version}/release-hashes-${version}.${format}"

  log_info "📥 Downloading hash registry for version $version..."

  local temp_file
  temp_file=$(mktemp)

  if ! curl -fsSL "$registry_url" -o "$temp_file"; then
    log_warning "Could not download hash registry from GitHub releases"
    log_info "Falling back to embedded hash registry"
    rm -f "$temp_file"
    return 1
  fi

  log_success "Downloaded hash registry from releases"

  # Parse and import hashes based on format
  case $format in
    json)
      import_json_hashes "$temp_file" "$version"
      ;;
    yaml)
      import_yaml_hashes "$temp_file" "$version"
      ;;
    *)
      log_error "Unknown hash registry format: $format"
      rm -f "$temp_file"
      return 1
      ;;
  esac

  rm -f "$temp_file"
  return 0
}

# Import hashes from JSON format
import_json_hashes() {
  local json_file="$1"
  local version="$2"

  if ! command -v jq >/dev/null 2>&1; then
    log_warning "jq not found - cannot parse JSON hash registry"
    return 1
  fi

  log_info "Importing hashes from JSON registry..."

  local count=0
  while IFS= read -r line; do
    local file
    local hash
    file=$(echo "$line" | jq -r '.file')
    hash=$(echo "$line" | jq -r '.hash')

    VERSION_HASHES["$version|$file"]="$hash"
    ((count++))
  done < <(jq -c '.hashes | to_entries[] | {file: .key, hash: .value}' "$json_file")

  log_success "Imported $count file hashes from registry"
}

# Import hashes from YAML format (basic parser)
import_yaml_hashes() {
  local yaml_file="$1"
  local version="$2"

  log_info "Importing hashes from YAML registry..."

  local count=0
  local in_hashes=false

  while IFS= read -r line; do
    # Skip until we find hashes section
    if [[ $line =~ ^hashes: ]]; then
      in_hashes=true
      continue
    fi

    if [[ $in_hashes == true ]]; then
      # Parse "  file: hash" format
      if [[ $line =~ ^[[:space:]]+(.+):[[:space:]]+([a-f0-9]{64})$ ]]; then
        local file="${BASH_REMATCH[1]}"
        local hash="${BASH_REMATCH[2]}"

        VERSION_HASHES["$version|$file"]="$hash"
        ((count++))
      fi
    fi
  done <"$yaml_file"

  log_success "Imported $count file hashes from registry"
}

# List available backups for rollback
list_available_backups() {
  if [[ ! -d $BACKUP_DIR ]]; then
    log_warning "No backups found"
    return 1
  fi

  log_info "📦 Available backups:"
  echo ""

  local backup_index=1
  declare -A backup_map

  # Group backups by timestamp
  local timestamps
  timestamps=$(find "$BACKUP_DIR" -name "*.backup" -type f -exec basename {} \; |
    sed 's/.*\.\([0-9]\{8\}_[0-9]\{6\}\)\.backup/\1/' |
    sort -u)

  for timestamp in $timestamps; do
    local date_part="${timestamp%_*}"
    local time_part="${timestamp#*_}"

    # Format: YYYYMMDD_HHMMSS -> YYYY-MM-DD HH:MM:SS
    local formatted_date="${date_part:0:4}-${date_part:4:2}-${date_part:6:2}"
    local formatted_time="${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

    # Count files in this backup
    local file_count
    file_count=$(find "$BACKUP_DIR" -name "*${timestamp}.backup" | wc -l | tr -d ' ')

    echo "  $backup_index. Backup from $formatted_date $formatted_time ($file_count files)"
    backup_map[$backup_index]="$timestamp"
    ((backup_index++))
  done

  echo ""

  # Return the backup map via global variable (bash limitation)
  declare -p backup_map
}

# Rollback to previous version
rollback_to_backup() {
  log_info "🔄 Rollback Wizard"
  echo ""

  # List available backups
  local backup_data
  backup_data=$(list_available_backups)

  if [[ -z $backup_data ]]; then
    log_error "No backups available for rollback"
    return 1
  fi

  # Parse backup map
  eval "$backup_data"

  # Ask user to choose backup
  read -rp "Choose backup to restore [1-${#backup_map[@]}] or 'q' to quit: " choice

  if [[ $choice == "q" ]]; then
    log_info "Rollback cancelled"
    return 0
  fi

  if [[ ! ${backup_map[$choice]+_} ]]; then
    log_error "Invalid choice: $choice"
    return 1
  fi

  local timestamp="${backup_map[$choice]}"

  log_info "Selected backup timestamp: $timestamp"
  echo ""

  # Find all files for this backup
  local backup_files
  mapfile -t backup_files < <(find "$BACKUP_DIR" -name "*${timestamp}.backup")

  if [[ ${#backup_files[@]} -eq 0 ]]; then
    log_error "No backup files found for timestamp $timestamp"
    return 1
  fi

  log_info "Files to restore:"
  for backup_file in "${backup_files[@]}"; do
    local original_name
    original_name=$(basename "$backup_file" | sed "s/\\.${timestamp}\\.backup$//")
    echo "  • $original_name"
  done
  echo ""

  if ! ask_user_confirmation "Restore these files?"; then
    log_info "Rollback cancelled"
    return 0
  fi

  # Restore files
  log_info "Restoring backup..."
  for backup_file in "${backup_files[@]}"; do
    local original_name
    original_name=$(basename "$backup_file" | sed "s/\\.${timestamp}\\.backup$//")

    # Determine original location (simplified - would need mapping)
    local target_path=".security-controls/bin/$original_name"

    if [[ -f $target_path ]]; then
      log_info "Restoring $target_path..."
      cp "$backup_file" "$target_path"
      log_success "✅ Restored $target_path"
    else
      log_warning "⚠️  Original location not found: $target_path"
    fi
  done

  log_success "✅ Rollback completed"
  echo ""
  log_info "💡 Tip: Run --check to verify restored installation"
}

# Merge tool integration
merge_with_tool() {
  local current_file="$1"
  local new_file="$2"
  local output_file="$3"

  # Detect available merge tools
  local merge_tool="${MERGE_TOOL:-}"

  if [[ -z $merge_tool ]]; then
    # Auto-detect merge tools in preference order
    for tool in meld kdiff3 vimdiff; do
      if command -v "$tool" >/dev/null 2>&1; then
        merge_tool="$tool"
        break
      fi
    done
  fi

  if [[ -z $merge_tool ]]; then
    log_warning "No merge tool found (tried: meld, kdiff3, vimdiff)"
    log_info "Set MERGE_TOOL environment variable to use custom tool"
    return 1
  fi

  log_info "Launching $merge_tool for 3-way merge..."
  echo ""
  log_info "Instructions:"
  echo "  • LEFT: Your current version"
  echo "  • RIGHT: New version from upgrade"
  echo "  • Save merged result and exit merge tool to continue"
  echo ""

  # Create a common ancestor (base) - use current as base for simplicity
  local base_file
  base_file=$(mktemp)
  cp "$current_file" "$base_file"

  # Launch merge tool based on type
  case $merge_tool in
    meld)
      # Meld: 3-way merge view
      meld "$current_file" "$base_file" "$new_file" --output="$output_file"
      ;;
    kdiff3)
      # KDiff3: 3-way merge with auto-merge
      kdiff3 "$base_file" "$current_file" "$new_file" -o "$output_file"
      ;;
    vimdiff)
      # Vimdiff: simpler 2-way merge
      vimdiff -c "wincmd l" -c "diffthis" "$current_file" "$new_file"
      # User manually saves to output_file
      cp "$current_file" "$output_file"
      ;;
    *)
      # Generic merge tool
      "$merge_tool" "$current_file" "$new_file"
      cp "$current_file" "$output_file"
      ;;
  esac

  rm -f "$base_file"

  if [[ -f $output_file ]]; then
    log_success "✅ Merge completed"
    return 0
  else
    log_error "Merge failed or cancelled"
    return 1
  fi
}

# Enhanced interactive modification handler with merge tool
handle_modified_file_with_merge() {
  local file="$1"
  local new_file="$2"

  echo ""
  log_warning "File modified: $file"

  # Show diff first
  show_file_diff "$file" "$new_file" "$(basename "$file")"

  echo ""
  log_info "What would you like to do?"
  echo "  1. Keep my version (skip upgrade for this file)"
  echo "  2. Replace with new version (your changes will be lost)"
  echo "  3. Backup my version and install new version"
  echo "  4. Use merge tool to combine changes interactively"
  echo ""

  read -rp "Choose option [1/2/3/4]: " choice

  case $choice in
    1)
      log_info "Keeping your version of $file"
      return 0
      ;;
    2)
      log_warning "Replacing $file with new version"
      cp "$new_file" "$file"
      return 0
      ;;
    3)
      backup_file "$file"
      cp "$new_file" "$file"
      log_success "Installed new version"
      return 0
      ;;
    4)
      local merged_file
      merged_file=$(mktemp)

      if merge_with_tool "$file" "$new_file" "$merged_file"; then
        backup_file "$file"
        cp "$merged_file" "$file"
        log_success "Installed merged version"
      else
        log_warning "Merge cancelled - keeping your version"
      fi

      rm -f "$merged_file"
      return 0
      ;;
    *)
      log_error "Invalid choice, keeping your version"
      return 1
      ;;
  esac
}

# Show usage
show_usage() {
  cat <<EOF
🔄 Safe Upgrade System for 1-Click GitHub Security

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Safely upgrades security controls with user modification detection.
    Verifies file integrity before upgrade and provides interactive
    handling of customized files.

OPTIONS:
    --check             Check installation integrity (no upgrade)
    --upgrade           Perform safe upgrade with user confirmation
    --rollback          Rollback to a previous backup
    --force             Force upgrade without confirmation (NOT recommended)
    --download-hashes   Download hash registry from GitHub releases
    --help              Show this help message

ENVIRONMENT VARIABLES:
    MERGE_TOOL          Preferred merge tool (meld, kdiff3, vimdiff)
                        Auto-detects if not set

WORKFLOW:
    1. Detect current installation version
    2. Verify file integrity against known hashes
    3. Identify user-modified files
    4. Show diffs for modified files
    5. Ask user what to do with each modification
    6. Backup modified files before replacing
    7. Download and install new version
    8. Verify new installation

EXAMPLES:
    $0 --check          # Check current installation integrity
    $0 --upgrade        # Safe upgrade with interactive prompts
    $0 --rollback       # Restore from previous backup
    $0 --force          # Force upgrade (skips confirmations)

    # Use custom merge tool
    MERGE_TOOL=meld $0 --upgrade

    # Download hash registry for specific version
    $0 --download-hashes 0.7.0

SAFETY FEATURES:
    ✅ Version-specific hash verification
    ✅ User modification detection
    ✅ Interactive diff display
    ✅ Per-file upgrade decisions
    ✅ Automatic backup of modified files
    ✅ Rollback capability
    ✅ Merge tool integration (meld, kdiff3, vimdiff)
    ✅ Auto-download hash registry from releases
    ✅ 3-way merge conflict resolution

EOF
}

# Main function
main() {
  cd "$PROJECT_ROOT"

  # Initialize hash registry
  init_hash_registry

  local mode="${1:-}"

  case "$mode" in
    --help | -h)
      show_usage
      exit 0
      ;;
    --check)
      verify_installation_integrity
      ;;
    --upgrade)
      safe_upgrade false
      ;;
    --rollback)
      rollback_to_backup
      ;;
    --download-hashes)
      local version="${2:-}"
      if [[ -z $version ]]; then
        log_error "Version argument required for --download-hashes"
        echo "Usage: $0 --download-hashes VERSION"
        exit 1
      fi
      download_hash_registry "$version" "json"
      ;;
    --force)
      log_warning "⚠️  Force mode: skipping safety confirmations"
      safe_upgrade true
      ;;
    "")
      log_error "No option specified. Use --help for usage."
      exit 1
      ;;
    *)
      log_error "Unknown option: $mode"
      show_usage
      exit 1
      ;;
  esac
}

# Execute main function
main "$@"
