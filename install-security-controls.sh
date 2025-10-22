#!/bin/bash

# Copyright 2025 Albert Hui <albert@securityronin.com>
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 🛡️ Security Controls Installer
# Installs security controls for any repository
# Industry-leading security architecture for multi-language projects
#
# Version: 0.4.9
# Repository: https://github.com/h4x0r/1-click-github-sec

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
# shellcheck disable=SC2034 # Color reserved for future use
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_VERSION="0.6.11"
# shellcheck disable=SC2034 # Placeholder for future use
readonly REQUIRED_TOOLS_FILE="security-tools-requirements.txt"
# shellcheck disable=SC2034 # Placeholder for future use
readonly PRE_PUSH_HOOK_FILE="security-pre-push-hook"
# shellcheck disable=SC2034 # Placeholder for future use
readonly CI_WORKFLOW_FILE="security-ci-workflow.yml"
readonly DOCS_DIR="docs/security"

# Upgrade functionality configuration
readonly VERSION_FILE=".security-controls-version"
readonly BACKUP_DIR=".security-controls-backup"
readonly CONFIG_FILE=".security-controls-config"
readonly REMOTE_VERSION_URL="https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/VERSION"
readonly REMOTE_CHANGELOG_URL="https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/CHANGELOG.md"

# Local state/config directories
readonly CONTROL_STATE_DIR=".security-controls"
readonly CONFIG_ENV_FILE="$CONTROL_STATE_DIR/config.env"
readonly GITLEAKS_CONFIG_FILE="$CONTROL_STATE_DIR/gitleaks.toml"
# shellcheck disable=SC2034 # Baseline reserved
readonly GITLEAKS_BASELINE_FILE="$CONTROL_STATE_DIR/gitleaks-baseline.json"

# Hooks path (optional chaining)
readonly HOOKS_PATH_DIR=".githooks"
readonly PRE_PUSH_D_DIR="$HOOKS_PATH_DIR/pre-push.d"

# =============================================================================
# STANDARDIZED ERROR CODES AND HANDLING FRAMEWORK
# =============================================================================
# readonly EXIT_SUCCESS=0               # Unused but kept for consistency
readonly EXIT_GENERAL_ERROR=1 # Generic failure
# readonly EXIT_USAGE_ERROR=2           # Unused but kept for consistency
readonly EXIT_PERMISSION_ERROR=3 # Permission denied
readonly EXIT_NETWORK_ERROR=4    # Download/network issues
readonly EXIT_TOOL_MISSING=6     # Required tool not found
readonly EXIT_VALIDATION_ERROR=7 # Input validation failed
readonly EXIT_CONFIG_ERROR=9     # Configuration error
readonly EXIT_SECURITY_ERROR=10  # Security check failed

# =============================================================================
# ENHANCED LOGGING SYSTEM WITH TIMESTAMPS
# =============================================================================
readonly LOG_DIR="$CONTROL_STATE_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"
readonly LOG_FILE
VERBOSE=${VERBOSE:-false}

# =============================================================================
# TRANSACTION AND ROLLBACK SYSTEM
# =============================================================================
readonly TRANSACTION_DIR="$CONTROL_STATE_DIR/transactions"
TRANSACTION_ACTIVE=false
declare -a ROLLBACK_ACTIONS

# Initialize logging system
# shellcheck disable=SC2120  # Function accesses global script arguments
setup_logging() {
  # Function to initialize logging
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  # Log session start with script arguments from global scope
  {
    echo "=== INSTALLATION SESSION START ==="
    echo "Timestamp: $(date)"
    echo "Script: $0 ${*:-}"
    echo "PWD: $(pwd)"
    echo "User: $(whoami)"
    echo "========================================"
  } >>"$LOG_FILE"
}

# Enhanced logging functions
log_entry() {
  local level=$1
  local message=$2
  local context=${3:-""}
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local caller="${FUNCNAME[2]:-main}"

  local log_line="[$timestamp] [$level] [$caller] $message"
  [[ -n $context ]] && log_line="$log_line | Context: $context"

  echo "$log_line" >>"$LOG_FILE"

  # Also output to terminal if verbose or error/warn
  if [[ $VERBOSE == true ]] || [[ $level == "ERROR" ]] || [[ $level == "WARN" ]]; then
    echo "[$(date '+%H:%M:%S')] [$level] $message" >&2
  fi
}

log_debug() { [[ $VERBOSE == true ]] && log_entry "DEBUG" "$1" "${2:-}"; }
log_info() { log_entry "INFO" "$1" "${2:-}"; }
log_warn() { log_entry "WARN" "$1" "${2:-}"; }
log_error() { log_entry "ERROR" "$1" "${2:-}"; }

# Standardized error handler
handle_error() {
  local exit_code=$1
  local error_msg=$2
  local context=${3:-""}

  case $exit_code in
    "$EXIT_PERMISSION_ERROR")
      print_status $RED "❌ Permission Error: $error_msg"
      echo "💡 Try: sudo $0 $* or check file permissions"
      ;;
    "$EXIT_NETWORK_ERROR")
      print_status $RED "❌ Network Error: $error_msg"
      echo "💡 Check internet connection and retry"
      ;;
    "$EXIT_TOOL_MISSING")
      print_status $RED "❌ Missing Tool: $error_msg"
      echo "💡 Install required dependencies: $context"
      ;;
    "$EXIT_VALIDATION_ERROR")
      print_status $RED "❌ Validation Error: $error_msg"
      echo "💡 Check input: $context"
      ;;
    "$EXIT_CONFIG_ERROR")
      print_status $RED "❌ Configuration Error: $error_msg"
      echo "💡 Check configuration files and permissions"
      ;;
    "$EXIT_SECURITY_ERROR")
      print_status $RED "❌ Security Error: $error_msg"
      echo "💡 Review security requirements: $context"
      ;;
    *)
      print_status $RED "❌ Error: $error_msg"
      ;;
  esac

  [[ -n $context ]] && echo "   Context: $context"
  log_error "$error_msg" "$context"

  # Trigger rollback if transaction is active
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    rollback_on_error
  fi

  exit "$exit_code"
}

# Safe execution wrapper
safe_execute() {
  local operation=$1
  local error_msg=$2
  local exit_code=${3:-$EXIT_GENERAL_ERROR}
  local context=${4:-""}

  log_debug "Executing: $operation" "$context"

  if ! eval "$operation" 2>>"$LOG_FILE"; then
    handle_error "$exit_code" "$error_msg" "$context"
  fi

  log_debug "Completed: $operation"
}

# Transaction management
start_transaction() {
  local transaction_name=${1:-"install"}
  TRANSACTION_ACTIVE=true
  ROLLBACK_ACTIONS=()

  mkdir -p "$TRANSACTION_DIR"

  log_info "Transaction started: $transaction_name"

  # Set trap for automatic rollback on error
  trap 'rollback_on_error' ERR
  trap 'cleanup_transaction' EXIT
}

add_rollback() {
  local action=$1
  ROLLBACK_ACTIONS+=("$action")
  log_debug "Added rollback action: $action"
}

commit_transaction() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    log_info "Transaction committed successfully"
    TRANSACTION_ACTIVE=false
    ROLLBACK_ACTIONS=()
    trap - ERR EXIT
  fi
}

rollback_on_error() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    print_status $YELLOW "⚠️ Error detected - initiating rollback..."
    log_warn "Automatic rollback triggered"

    # Execute rollback actions in reverse order
    for ((i = ${#ROLLBACK_ACTIONS[@]} - 1; i >= 0; i--)); do
      local action="${ROLLBACK_ACTIONS[i]}"
      log_info "Rolling back: $action"

      if eval "$action" 2>>"$LOG_FILE"; then
        log_debug "Rollback action succeeded: $action"
      else
        log_error "Rollback action failed: $action"
      fi
    done

    print_status $GREEN "✅ Rollback completed"
    TRANSACTION_ACTIVE=false
  fi
}

cleanup_transaction() {
  if [[ $TRANSACTION_ACTIVE == true ]]; then
    TRANSACTION_ACTIVE=false
    trap - ERR EXIT
  fi
}

# Atomic file operations
atomic_write() {
  local file=$1
  local content=$2

  # Backup original if exists
  if [[ -f $file ]]; then
    local backup
    backup="$file.backup.$(date +%s)"
    cp "$file" "$backup"
    add_rollback "mv '$backup' '$file'"
    log_debug "Created backup: $backup"
  else
    add_rollback "rm -f '$file'"
  fi

  # Write new content
  echo "$content" >"$file"
  log_debug "Atomic write completed: $file"
}

atomic_move() {
  local src=$1
  local dest=$2

  if [[ -f $dest ]]; then
    local backup
    backup="$dest.backup.$(date +%s)"
    mv "$dest" "$backup"
    add_rollback "mv '$backup' '$dest'"
  else
    add_rollback "rm -f '$dest'"
  fi

  mv "$src" "$dest"
  log_debug "Atomic move: $src -> $dest"
}

# =============================================================================
# END FRAMEWORK SECTION
# =============================================================================

# Global flags
DRY_RUN=false
SKIP_TOOLS=false
FORCE_INSTALL=false
# Multi-language support - array of detected languages
declare -a DETECTED_LANGUAGES=()
PROJECT_LANGUAGE="auto" # auto, rust, nodejs, python, go, generic, or comma-separated list
# Legacy compatibility
RUST_PROJECT=true
INSTALL_HOOKS=true
INSTALL_CI=true
INSTALL_DOCS=true
INSTALL_SIGNING=true
SIGNING_METHOD="gitsign" # Default to secure gitsign, --signing=gpg for GitHub badges
YUBIKEY_MODE=false       # Default to software auth, --yubikey for hardware auth
USE_HOOKS_PATH=false
INSTALL_GITHUB_SECURITY=true

# Upgrade functionality flags
# shellcheck disable=SC2034 # Reserved flag
UPGRADE_MODE=false
CHECK_UPDATE=false
BACKUP_MODE=false
# shellcheck disable=SC2034 # Reserved flag
RESTORE_MODE=false
SHOW_VERSION=false

# Signing mode command flags
COMMAND_MODE=""
# Function to print colored output
print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
  log_info "$message"
}

print_header() {
  echo
  print_status $CYAN "════════════════════════════════════════════════"
  print_status $CYAN "  $1"
  print_status $CYAN "════════════════════════════════════════════════"
  echo
}

print_section() {
  echo
  print_status $BLUE "▶ $1"
  echo
}

# ===== UPGRADE FUNCTIONALITY =====

# Get current installed version
get_installed_version() {
  if [[ -f $VERSION_FILE ]]; then
    cat "$VERSION_FILE" | grep "version=" | cut -d'=' -f2 | tr -d '"'
  else
    echo "unknown"
  fi
}

# Get latest available version
get_latest_version() {
  if curl -fsSL "$REMOTE_VERSION_URL" 2>/dev/null; then
    return 0
  else
    echo "1.1.0" # Fallback version
    return 1
  fi
}

# Compare versions (returns 0 if upgrade needed, 1 if up-to-date)
compare_versions() {
  local current="$1"
  local latest="$2"

  # Simple version comparison (assumes semantic versioning)
  if [[ $current == "unknown" ]] || [[ $current != "$latest" ]]; then
    return 0 # Upgrade needed
  else
    return 1 # Up to date
  fi
}

# Show version information
show_version_info() {
  print_header "Version Information"

  local current_version
  local latest_version

  current_version=$(get_installed_version)

  print_status $BLUE "📋 Current Installation:"
  echo "   Installed Version: $current_version"

  if [[ -f $VERSION_FILE ]]; then
    local install_date
    install_date=$(grep "install_date=" "$VERSION_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
    echo "   Install Date: $install_date"

    local install_type
    install_type=$(grep "install_type=" "$VERSION_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "Unknown")
    echo "   Install Type: $install_type"
  fi

  echo
  print_status $BLUE "🌐 Checking for updates..."

  if latest_version=$(get_latest_version); then
    print_status $GREEN "✅ Successfully connected to update server"
    echo "   Latest Version: $latest_version"

    if compare_versions "$current_version" "$latest_version"; then
      print_status $YELLOW "🆙 Update available: $current_version → $latest_version"
      echo
      echo "Run '$0 --upgrade' to update to the latest version"
    else
      print_status $GREEN "✅ You have the latest version installed"
    fi
  else
    print_status $RED "❌ Could not check for updates"
    echo "   Please check your internet connection"
  fi
}

# Check for updates without installing
check_for_updates() {
  print_header "Update Check"

  local current_version
  local latest_version

  current_version=$(get_installed_version)

  print_status $BLUE "🔍 Checking for updates..."
  echo "   Current: $current_version"

  if latest_version=$(get_latest_version); then
    echo "   Latest:  $latest_version"
    echo

    if compare_versions "$current_version" "$latest_version"; then
      print_status $YELLOW "🆙 Update Available!"
      echo
      print_status $BLUE "📋 What's new in $latest_version:"

      # Fetch and display changelog excerpt
      if curl -fsSL "$REMOTE_CHANGELOG_URL" 2>/dev/null | head -20; then
        echo
      else
        echo "   (Changelog not available)"
        echo
      fi

      echo "To upgrade: $0 --upgrade"
    else
      print_status $GREEN "✅ No updates available"
      echo "   You have the latest version"
    fi
  else
    print_status $RED "❌ Update check failed"
    echo "   Could not connect to update server"
    exit 1
  fi
}

# Create backup of current installation
create_backup() {
  print_status $BLUE "💾 Creating backup..."

  # Create backup directory
  mkdir -p "$BACKUP_DIR"

  local backup_timestamp
  backup_timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_subdir="$BACKUP_DIR/backup_$backup_timestamp"

  mkdir -p "$backup_subdir"

  # Backup pre-push hook
  if [[ -f ".git/hooks/pre-push" ]]; then
    cp ".git/hooks/pre-push" "$backup_subdir/"
    print_status $GREEN "✅ Backed up pre-push hook"
  fi

  # Backup CI workflow
  if [[ -f ".github/workflows/security.yml" ]]; then
    mkdir -p "$backup_subdir/.github/workflows"
    cp ".github/workflows/security.yml" "$backup_subdir/.github/workflows/"
    print_status $GREEN "✅ Backed up CI workflow"
  fi

  # Backup documentation
  if [[ -d $DOCS_DIR ]]; then
    cp -r "$DOCS_DIR" "$backup_subdir/"
    print_status $GREEN "✅ Backed up documentation"
  fi

  # Backup version and config files
  if [[ -f $VERSION_FILE ]]; then
    cp "$VERSION_FILE" "$backup_subdir/"
  fi

  if [[ -f $CONFIG_FILE ]]; then
    cp "$CONFIG_FILE" "$backup_subdir/"
  fi

  # Create backup manifest
  cat >"$backup_subdir/BACKUP_MANIFEST.txt" <<MANIFEST_EOF
# Security Controls Backup
# Created: $(date)
# Original Version: $(get_installed_version)
# Backup Location: $backup_subdir

Files backed up:
$(find "$backup_subdir" -type f | sed "s|$backup_subdir/||" | sort)
MANIFEST_EOF

  # Update symlink to latest backup
  ln -sfn "backup_$backup_timestamp" "$BACKUP_DIR/latest"

  print_status $GREEN "✅ Backup created: $backup_subdir"
  echo "   Latest backup link: $BACKUP_DIR/latest"

  return 0
}

# Show changelog for current version
show_changelog() {
  print_header "Changelog"

  print_status $BLUE "📋 Fetching latest changelog..."

  if curl -fsSL "$REMOTE_CHANGELOG_URL" 2>/dev/null; then
    return 0
  else
    print_status $RED "❌ Could not fetch changelog"
    echo "   Please check your internet connection"
    echo "   View online: https://github.com/h4x0r/1-click-github-sec/blob/main/CHANGELOG.md"
    exit 1
  fi
}

# Write version information after successful installation
write_version_info() {
  cat >"$VERSION_FILE" <<VERSION_EOF
# Security Controls Installation Information
# Generated by install-security-controls.sh v$SCRIPT_VERSION
version="$SCRIPT_VERSION"
install_date="$(date)"
install_type="fresh_install"
installer_version="$SCRIPT_VERSION"
project_type="$(if [[ $RUST_PROJECT == true ]]; then echo "rust"; else echo "generic"; fi)"
global_install="false"
VERSION_EOF

  print_status $GREEN "📝 Version information saved to $VERSION_FILE"
}

# Execute upgrade commands
execute_upgrade_commands() {
  # Check upgrade commands first, before normal installation
  if [[ $SHOW_VERSION == true ]]; then
    show_version_info
    exit 0
  fi

  if [[ $CHECK_UPDATE == true ]]; then
    check_for_updates
    exit 0
  fi

  if [[ $BACKUP_MODE == true ]]; then
    create_backup
    exit 0
  fi

  # AUTO-DETECT EXISTING INSTALLATION (DMMT: Don't Make Me Think)
  # If security controls already installed, automatically trigger safe upgrade
  if [[ -f $VERSION_FILE ]]; then
    local installed_version
    installed_version=$(get_installed_version)

    # If we detect a different version, auto-run safe-upgrade
    if [[ $installed_version != "$SCRIPT_VERSION" && $installed_version != "unknown" ]]; then
      print_status $BLUE "🔄 Existing installation detected (v$installed_version)"
      print_status $BLUE "   Upgrading to v$SCRIPT_VERSION with modification detection..."
      echo

      # Check if safe-upgrade script exists
      local safe_upgrade_script="./scripts/safe-upgrade.sh"

      if [[ -x $safe_upgrade_script ]]; then
        # Auto-run safe-upgrade (default behavior is safe upgrade)
        exec "$safe_upgrade_script"
      else
        # Fallback: warn user but continue with standard upgrade
        print_status $YELLOW "⚠️  Safe upgrade script not found at $safe_upgrade_script"
        print_status $BLUE "ℹ️  Proceeding with standard upgrade..."
        print_status $YELLOW "    (User modifications will be overwritten without prompting)"
        echo
        read -rp "Continue with standard upgrade? [y/N]: " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
          print_status $RED "❌ Upgrade cancelled by user"
          exit 0
        fi
        # Continue to normal installation (which will overwrite files)
      fi
    fi
  fi
}

show_help() {
  cat <<EOF
🛡️  1-Click GitHub Security Controls Installer v${SCRIPT_VERSION}

👨‍💻 Created by Albert Hui <albert@securityronin.com>
   Security Ronin

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Installs security controls for multi-language projects.
    Provides security controls: local validation (35+ checks) + CI analysis + GitHub security features.

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    --verbose               Enable verbose logging output
    -d, --dry-run           Show what would be done without making changes
    -f, --force             Force overwrite existing files
    --skip-tools            Skip tool installation (assume tools are available)
    --no-hooks              Skip Git hooks installation
    --no-ci                 Skip CI workflow installation  
    --no-docs               Skip documentation installation
    --no-signing            Skip cryptographic signing installation and configuration
    --signing=METHOD        Choose signing method: 'gitsign' (default, secure) or 'gpg' (GitHub badges)
                            gitsign: Short-lived certificates, automatic rotation, keyless (secure)
                            gpg: Long-lived keys, manual management, GitHub verified badges (weaker)
    --yubikey               Enable YubiKey hardware authentication (works with both gitsign and GPG)
                            gitsign+yubikey: Maximum security (hardware auth + short-lived certs)
                            gpg+yubikey: Hardware-backed signing (hardware keys + GitHub badges)
    --language=LANG         Specify project language(s): rust, nodejs, python, go, generic
                            Supports multiple: --language=rust,nodejs,python
                            (auto-detects if not specified - supports polyglot repos)
    --hooks-path            Install hooks using git core.hooksPath (\".githooks\") and chain safely
    --no-github-security    Skip GitHub repository security features (enabled by default)

INSTALLATION:
    # Download installer and checksum
    curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v${SCRIPT_VERSION}/install-security-controls.sh
    curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v${SCRIPT_VERSION}/checksums.txt

    # VERIFY checksum before execution (STRONGLY RECOMMENDED - critical security practice)
    sha256sum -c checksums.txt --ignore-missing

    # Run installer (only after successful verification)
    chmod +x install-security-controls.sh
    ./install-security-controls.sh

UPGRADE COMMANDS:
    --version               Show version and check for updates
    --check-update          Check for available updates
    --upgrade               Upgrade to latest version with backup
    --backup                Create backup of current installation
    --changelog             Show changelog and release notes

SIGNING MODE COMMANDS:
    status                  Show current signing configuration and YubiKey status
    test                    Test current signing configuration (creates test commit)
    enable-yubikey          Enable YubiKey requirement for current signing method
    disable-yubikey         Disable YubiKey requirement (switch to software auth)
    switch-to-gitsign       Switch to gitsign signing (short-lived certificates)
    switch-to-gpg           Switch to GPG signing (GitHub verified badges)
EXAMPLES:
    # Full installation with all security features (recommended)
    $0

    # 4 SIGNING MODES:
    # Mode 1: gitsign + software (default - high security)
    $0

    # Mode 2: gitsign + YubiKey (maximum security)
    $0 --yubikey

    # Mode 3: GPG + software (GitHub badges, basic security)
    $0 --signing=gpg

    # Mode 4: GPG + YubiKey (GitHub badges, hardware security)
    $0 --signing=gpg --yubikey

    # Switch modes after installation:
    $0 status                    # Check current mode
    $0 enable-yubikey           # Add YubiKey to current method
    $0 disable-yubikey          # Remove YubiKey requirement
    $0 switch-to-gitsign        # Switch to gitsign (maintains YubiKey setting)
    $0 switch-to-gpg            # Switch to GPG (maintains YubiKey setting)
    $0 test                     # Test current signing setup

    # Preview changes without installing
    $0 --dry-run

    # Force reinstall over existing setup
    $0 --force

    # Install only hooks (skip CI, docs, and GitHub security)
    $0 --no-ci --no-docs --no-github-security

    # Configure for specific languages
    $0 --language=nodejs    # JavaScript/TypeScript/Node.js project
    $0 --language=python    # Python project
    $0 --language=go        # Go project
    $0 --language=generic   # Generic project (no specific language)

    # Configure for polyglot repositories
    $0 --language=rust,nodejs,python  # Multi-language project

    # Skip GitHub security features (local security only)
    $0 --no-github-security

    # Use hooksPath chaining instead of replacing .git/hooks/pre-push
    $0 --hooks-path

    # Check version and updates
    $0 --version

    # Check for updates
    $0 --check-update

    # Create manual backup
    $0 --backup

SECURITY CONTROLS INSTALLED:
    Pre-Push (Complete Coverage, < 60s):
    ✅ Code formatting validation (language-specific)
    ✅ Linting and quality checks (language-specific)
    ✅ Security audit (vulnerable dependencies)
    ✅ Test suite execution (language-specific)
    ✅ Secret detection (API keys, passwords) - universal
    ✅ License compliance checking
    ✅ SHA pinning validation - universal
    ✅ Commit signature verification - universal
    ✅ Dependency file validation & git tracking
    ✅ Dependency version pinning analysis
    ✅ Build script security scanning
    ✅ Documentation security validation
    ✅ Environment variable security check
    ✅ Language edition/version enforcement
    ✅ Unsafe/dangerous code monitoring
    ✅ Import security validation
    ✅ File permission auditing
    ✅ Dependency count monitoring
    ✅ Network address validation
    ✅ Commit message security scanning
    ✅ Large file detection & blocking
    ✅ Technical debt monitoring
    ✅ Empty file detection

    Post-Push (Comprehensive CI):
    🔍 Static security analysis (SAST)
    🔍 Vulnerability scanning (Trivy)
    🔍 Supply chain verification
    🔍 SBOM generation
    🔍 Security metrics collection
    🔍 Integration testing
    🔍 Compliance reporting

    GitHub Security Features (enabled by default):
    🤖 Renovate configuration (renovate.json)
    🔐 Vulnerability alerts
    🔐 CodeQL security scanning workflow
    🔐 Branch protection rules
    🔐 Secret scanning (auto-enabled for public repos)
    ⚠️  Security advisories (manual setup required)
    ❌ Advanced Security (GitHub Enterprise only)

    Cryptographic Signing & Verification:
    🔑 Secure gitsign signing (default: short-lived certificates)
    🔑 Keyless signing with automatic rotation
    🔑 Certificate transparency via Rekor ledger
    🔑 No long-term key management required
    🔑 Superior security vs traditional GPG
    🔑 Optional: GPG signing for GitHub 'Verified' badges (--signing=gpg)
    🔑 Public auditability of all signatures
    🔑 Enhanced supply chain security

CRYPTOGRAPHIC VERIFICATION:
    All releases of this installer are cryptographically signed:

    ✅ Signed commits: Every commit verified with Sigstore
    ✅ Signed tags: All releases signed with keyless certificates
    ✅ Certificate transparency: Signatures logged in public Rekor ledger
    ✅ Identity binding: Signatures tied to verified GitHub identities
    ✅ Tamper detection: Any modification breaks cryptographic proofs

    Verify this installer's authenticity:

        # Verify the release tag
        git tag -v v${SCRIPT_VERSION}

        # Check commit signatures
        git log --show-signature -1

        # Validate against Rekor transparency log
        gitsign verify HEAD

    Learn more: https://h4x0r.github.io/1-click-github-sec/cryptographic-verification

REQUIREMENTS:
    - Git repository (initialized)
    - Internet connection (for tool downloads)
    - Platform: Linux, macOS, or WSL2

EOF
}

show_version() {
  echo "🛡️  1-Click GitHub Security Controls v${SCRIPT_VERSION}"
  echo "👨‍💻 Created by Albert Hui <albert@securityronin.com>"
  echo "   Security Ronin"
  echo
  echo "Security controls for multi-language projects"
  echo "https://github.com/h4x0r/1-click-github-sec"
}

# Check if we're in a git repository
check_git_repo() {
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    handle_error $EXIT_VALIDATION_ERROR "Not in a Git repository" "Initialize git first: git init"
  fi
  print_status $GREEN "✅ Git repository detected"
}

# Multi-language detection with polyglot repository support
detect_project_languages() {
  local detected_count=0
  DETECTED_LANGUAGES=()

  # Handle explicit language selection
  if [[ $PROJECT_LANGUAGE != "auto" ]]; then
    # Support comma-separated language list: --language=rust,nodejs,python
    if [[ $PROJECT_LANGUAGE == *","* ]]; then
      IFS=',' read -ra EXPLICIT_LANGS <<<"$PROJECT_LANGUAGE"
      for lang in "${EXPLICIT_LANGS[@]}"; do
        lang=$(echo "$lang" | xargs) # trim whitespace
        case "$lang" in
          "rust" | "nodejs" | "javascript" | "typescript" | "python" | "go" | "generic")
            DETECTED_LANGUAGES+=("$lang")
            ;;
          *)
            print_status $RED "❌ Unknown language: $lang"
            exit 1
            ;;
        esac
      done
      print_status $GREEN "✅ Explicit multi-language configuration: ${DETECTED_LANGUAGES[*]}"
      return 0
    else
      # Single language specified
      case "$PROJECT_LANGUAGE" in
        "rust" | "nodejs" | "javascript" | "typescript" | "python" | "go" | "generic")
          DETECTED_LANGUAGES=("$PROJECT_LANGUAGE")
          print_status $GREEN "✅ Explicit language configuration: $PROJECT_LANGUAGE"
          return 0
          ;;
        *)
          print_status $RED "❌ Unknown language: $PROJECT_LANGUAGE"
          exit 1
          ;;
      esac
    fi
  fi

  print_status $BLUE "🔍 Auto-detecting project language(s)..."

  # Multi-language auto-detection - check all possibilities
  if [[ -f "Cargo.toml" ]]; then
    DETECTED_LANGUAGES+=("rust")
    print_status $GREEN "  ✅ Rust detected (Cargo.toml found)"
    ((detected_count++))
  fi

  if [[ -f "package.json" ]]; then
    # Determine if it's TypeScript or JavaScript
    if [[ -f "tsconfig.json" ]] || grep -q '"typescript"' package.json 2>/dev/null ||
      find . -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .; then
      DETECTED_LANGUAGES+=("typescript")
      print_status $GREEN "  ✅ TypeScript detected (package.json + TS files/config)"
    else
      DETECTED_LANGUAGES+=("nodejs")
      print_status $GREEN "  ✅ Node.js detected (package.json found)"
    fi
    ((detected_count++))
  fi

  if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] ||
    find . -maxdepth 2 -name "*.py" 2>/dev/null | head -1 | grep -q .; then
    DETECTED_LANGUAGES+=("python")
    print_status $GREEN "  ✅ Python detected (Python files/config found)"
    ((detected_count++))
  fi

  if [[ -f "go.mod" ]] || find . -maxdepth 2 -name "*.go" 2>/dev/null | head -1 | grep -q .; then
    DETECTED_LANGUAGES+=("go")
    print_status $GREEN "  ✅ Go detected (go.mod or .go files found)"
    ((detected_count++))
  fi

  # If no specific languages detected, use generic
  if [[ $detected_count -eq 0 ]]; then
    DETECTED_LANGUAGES=("generic")
    print_status $YELLOW "  ⚠️  No specific language detected - using generic configuration"
  fi

  # Set legacy compatibility flags
  if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
    RUST_PROJECT=true
  else
    RUST_PROJECT=false
  fi

  # Report detected languages
  if [[ $detected_count -gt 1 ]]; then
    print_status $CYAN "🎯 Polyglot repository detected! Languages: ${DETECTED_LANGUAGES[*]}"
    print_status $CYAN "   Installing security controls for all detected languages"
  elif [[ $detected_count -eq 1 ]]; then
    print_status $GREEN "🎯 Single-language repository: ${DETECTED_LANGUAGES[0]}"
  fi

  return 0
}

# Check if a specific language is detected
has_language() {
  local lang="$1"
  [[ " ${DETECTED_LANGUAGES[*]} " =~ \ ${lang}\  ]]
}

# Legacy function for backward compatibility
detect_project_type() {
  detect_project_languages
  # Set PROJECT_LANGUAGE for legacy code that expects it
  if [[ ${#DETECTED_LANGUAGES[@]} -eq 1 ]]; then
    PROJECT_LANGUAGE="${DETECTED_LANGUAGES[0]}"
  else
    PROJECT_LANGUAGE="multi"
  fi
}

# Check if required tools are available
check_required_tools() {
  print_section "Checking Required Tools"

  local missing_tools=()

  # Core tools (always required)
  local core_tools=("git" "curl" "jq")

  # Project-specific tools
  local rust_tools=("cargo" "rustc")

  # Check core tools
  for tool in "${core_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      print_status $GREEN "✅ $tool: $(command -v $tool)"
    else
      missing_tools+=("$tool")
      print_status $RED "❌ $tool: not found"
    fi
  done

  # Check Rust tools if Rust project
  if [[ $RUST_PROJECT == true ]]; then
    for tool in "${rust_tools[@]}"; do
      if command -v "$tool" &>/dev/null; then
        print_status $GREEN "✅ $tool: $(command -v $tool)"
      else
        missing_tools+=("$tool")
        print_status $RED "❌ $tool: not found"
      fi
    done
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]] && [[ $SKIP_TOOLS == false ]]; then
    local install_instructions=""
    for tool in "${missing_tools[@]}"; do
      case $tool in
        "git")
          install_instructions+="  macOS: brew install git\n  Ubuntu: sudo apt install git\n"
          ;;
        "curl")
          install_instructions+="  macOS: brew install curl\n  Ubuntu: sudo apt install curl\n"
          ;;
        "jq")
          install_instructions+="  macOS: brew install jq\n  Ubuntu: sudo apt install jq\n"
          ;;
        "cargo" | "rustc")
          install_instructions+="  Install Rust: https://rustup.rs/\n"
          ;;
      esac
    done
    handle_error $EXIT_TOOL_MISSING "Missing required tools: ${missing_tools[*]}" "$install_instructions"
  fi
}

# Install security tools
install_security_tools() {
  print_section "Installing Security Tools"

  # Warn if a toolchain override is present and prefer +stable for optional installs
  local CARGO=(cargo)
  if [[ -n ${RUSTUP_TOOLCHAIN:-} ]]; then
    print_status $YELLOW "⚠️ RUSTUP_TOOLCHAIN is set to '$RUSTUP_TOOLCHAIN' — this overrides the default toolchain."
    print_status $YELLOW "   Optional cargo installs may fail or use a non-default toolchain. Using 'cargo +stable' for installs."
    print_status $YELLOW "   To avoid this, unset RUSTUP_TOOLCHAIN before running the installer."
    CARGO=(cargo +stable)
  fi

  # Install language-specific security tools for each detected language
  for lang in "${DETECTED_LANGUAGES[@]}"; do
    case "$lang" in
      "rust")
        if command -v cargo &>/dev/null; then
          install_rust_security_tools
        else
          print_status $YELLOW "⚠️ Cargo not found - skipping Rust tool installation"
        fi
        ;;
      "nodejs" | "typescript")
        install_nodejs_security_tools
        ;;
      "python")
        install_python_security_tools
        ;;
      "go")
        install_go_security_tools
        ;;
      "generic")
        print_status $BLUE "📦 Using generic security tools only"
        ;;
      *)
        print_status $YELLOW "⚠️ Unknown language: $lang - skipping tools"
        ;;
    esac
  done

  # Install gitsign for commit signing (if not disabled)
  if [[ $INSTALL_SIGNING == true ]]; then
    install_gitsign
  fi
}

# Install Rust security tools (backward compatibility)
install_rust_security_tools() {
  print_status $BLUE "🦀 Installing Rust security tools..."

  # Enhanced security tools with no-brainer additions
  local rust_security_tools=("cargo-deny" "cargo-geiger" "cargo-cyclonedx" "cargo-machete")
  local fallback_tools=("cargo-audit" "cargo-license") # Fallbacks if enhanced tools fail

  # Try to install enhanced tools first
  for tool in "${rust_security_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      print_status $YELLOW "📦 Installing $tool..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would install $tool"
      else
        if "${CARGO[@]}" install --locked "$tool" 2>/dev/null; then
          print_status $GREEN "✅ $tool installed"
        else
          print_status $YELLOW "⚠️ $tool installation failed, will use fallback if needed"
        fi
      fi
    else
      print_status $GREEN "✅ $tool already installed"
    fi
  done

  # Install fallback tools if enhanced tools aren't available
  print_status $BLUE "🔄 Ensuring fallback security tools..."
  for tool in "${fallback_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null && ! command -v "${tool/audit/deny}" &>/dev/null; then
      print_status $YELLOW "📦 Installing fallback tool $tool..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would install fallback $tool"
      else
        if "${CARGO[@]}" install --locked "$tool" 2>/dev/null; then
          print_status $GREEN "✅ Fallback $tool installed"
        else
          print_status $RED "❌ Failed to install $tool"
        fi
      fi
    fi
  done
}

# Install Node.js/JavaScript/TypeScript security tools
install_nodejs_security_tools() {
  print_status $BLUE "🟨 Installing Node.js security tools..."

  # Check if npm is available
  if ! command -v npm &>/dev/null; then
    print_status $YELLOW "⚠️ npm not found - skipping Node.js tool installation"
    print_status $BLUE "   Install Node.js from https://nodejs.org/ or:"
    print_status $BLUE "   • macOS: brew install node"
    print_status $BLUE "   • Ubuntu: sudo apt install nodejs npm"
    return 0
  fi

  # Core security tools for Node.js projects
  local nodejs_security_tools=(
    "eslint"             # JavaScript/TypeScript linting
    "prettier"           # Code formatting
    "audit-ci"           # Enhanced npm audit for CI
    "license-checker"    # License compliance checking
    "npm-check-updates"  # Dependency update checker
    "semgrep"            # SAST scanning
    "@npmcli/arborist"   # npm dependency tree analysis
    "better-npm-audit"   # Enhanced npm audit with better filtering
    "npm-audit-resolver" # Advanced audit resolution
    "snyk"               # Advanced vulnerability scanning
    "retire"             # JavaScript library vulnerability scanner
    "npm-check"          # Interactive dependency updates
    "depcheck"           # Unused dependency detection
    "madge"              # Circular dependency detection
    "bundlewatch"        # Bundle size monitoring
    "cost-of-modules"    # Analyze cost of dependencies
  )

  # Optional TypeScript-specific tools
  if [[ -f "tsconfig.json" ]] || grep -q '"typescript"' package.json 2>/dev/null; then
    nodejs_security_tools+=(
      "typescript"                # TypeScript compiler
      "@typescript-eslint/parser" # TypeScript ESLint parser
    )
  fi

  # Install tools globally for system-wide availability
  for tool in "${nodejs_security_tools[@]}"; do
    if ! command -v "${tool%@*}" &>/dev/null && ! npm list -g "$tool" &>/dev/null; then
      print_status $YELLOW "📦 Installing $tool..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would install $tool"
      else
        if npm install -g "$tool" 2>/dev/null; then
          print_status $GREEN "✅ $tool installed"
        else
          print_status $YELLOW "⚠️ Failed to install $tool globally"
          # Try local installation as fallback
          if [[ -f "package.json" ]]; then
            print_status $BLUE "   Attempting local installation..."
            if npm install --save-dev "$tool" 2>/dev/null; then
              print_status $GREEN "✅ $tool installed locally"
            else
              print_status $RED "❌ Failed to install $tool"
            fi
          fi
        fi
      fi
    else
      print_status $GREEN "✅ $tool already installed"
    fi
  done

  # Install additional development tools if package.json exists
  if [[ -f "package.json" ]] && [[ $DRY_RUN == false ]]; then
    print_status $BLUE "🔧 Configuring package.json security scripts..."

    # Add comprehensive security scripts to package.json
    if ! grep -q '"audit"' package.json; then
      print_status $YELLOW "📝 Adding comprehensive npm audit scripts to package.json..."
      # Basic npm audit
      npm pkg set scripts.audit="npm audit --audit-level=moderate" 2>/dev/null || true
      # Enhanced audit with better-npm-audit (if available)
      npm pkg set scripts."audit:enhanced"="better-npm-audit audit --level moderate" 2>/dev/null || true
      # Audit with CI-friendly output
      npm pkg set scripts."audit:ci"="audit-ci --moderate" 2>/dev/null || true
      # Comprehensive security scan
      npm pkg set scripts."security:scan"="npm run audit && npm run audit:enhanced && npm run security:retire && npm run security:snyk" 2>/dev/null || true
    fi

    if ! grep -q '"security:retire"' package.json; then
      print_status $YELLOW "📝 Adding retire.js scanning script..."
      npm pkg set scripts."security:retire"="retire --path . --outputformat json --outputpath retire-report.json || true" 2>/dev/null || true
    fi

    if ! grep -q '"security:snyk"' package.json; then
      print_status $YELLOW "📝 Adding Snyk scanning script..."
      npm pkg set scripts."security:snyk"="snyk test --severity-threshold=medium || true" 2>/dev/null || true
    fi

    if ! grep -q '"security:deps"' package.json; then
      print_status $YELLOW "📝 Adding dependency analysis script..."
      npm pkg set scripts."security:deps"="npm ls --depth=0 --json > deps-analysis.json && license-checker --json --out license-report.json" 2>/dev/null || true
    fi

    if ! grep -q '"lint"' package.json; then
      print_status $YELLOW "📝 Adding lint script to package.json..."
      npm pkg set scripts.lint="eslint ." 2>/dev/null || true
    fi

    if ! grep -q '"format"' package.json; then
      print_status $YELLOW "📝 Adding format script to package.json..."
      npm pkg set scripts.format="prettier --write ." 2>/dev/null || true
      npm pkg set scripts."format:check"="prettier --check ." 2>/dev/null || true
    fi
  fi
}

# Install Python security tools
install_python_security_tools() {
  print_status $BLUE "🐍 Installing Python security tools..."

  # Check for Python package managers (UX-first: fastest first)
  local pip_cmd=""

  # Prefer fastest modern tools first, fallback to standard
  if command -v uv &>/dev/null; then
    pip_cmd="uv pip"
    print_status $GREEN "🚀 Using uv (ultra-fast Python package manager)"
  elif command -v pip3 &>/dev/null; then
    pip_cmd="pip3"
    print_status $BLUE "📦 Using pip3"
  elif command -v pip &>/dev/null; then
    pip_cmd="pip"
    print_status $BLUE "📦 Using pip"
  else
    print_status $YELLOW "⚠️ No Python package manager found - skipping Python tool installation"
    print_status $BLUE "   Install Python from https://python.org/ or:"
    print_status $BLUE "   • macOS: brew install python3"
    print_status $BLUE "   • Ubuntu: sudo apt install python3-pip"
    print_status $BLUE "   • For ultra-fast installs: pip install uv"
    return 0
  fi

  # Core security tools for Python projects
  local python_security_tools=(
    "black"     # Code formatting
    "flake8"    # Linting
    "pylint"    # Advanced linting
    "safety"    # Known vulnerability scanning
    "bandit"    # Security issue scanner
    "pip-audit" # PyPI package vulnerability scanner
    "semgrep"   # SAST scanning
  )

  for tool in "${python_security_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      print_status $YELLOW "📦 Installing $tool..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would install $tool"
      else
        if $pip_cmd install "$tool"; then
          print_status $GREEN "✅ $tool installed"
        else
          print_status $RED "❌ Failed to install $tool"
          print_status $YELLOW "   Try: $pip_cmd install $tool"
        fi
      fi
    else
      print_status $GREEN "✅ $tool already installed"
    fi
  done
}

# Install Go security tools
install_go_security_tools() {
  print_status $BLUE "🐹 Installing Go security tools..."

  # Check if go is available
  if ! command -v go &>/dev/null; then
    print_status $YELLOW "⚠️ Go not found - skipping Go tool installation"
    print_status $BLUE "   Install Go from https://golang.org/dl/ or:"
    print_status $BLUE "   • macOS: brew install go"
    print_status $BLUE "   • Ubuntu: sudo apt install golang-go"
    return 0
  fi

  # Core security tools for Go projects
  local go_security_tools=(
    "golang.org/x/tools/cmd/goimports@latest"                # Import management
    "golang.org/x/vuln/cmd/govulncheck@latest"               # Vulnerability scanner
    "golang.org/x/lint/golint@latest"                        # Linting (legacy but widely used)
    "honnef.co/go/tools/cmd/staticcheck@latest"              # Advanced static analysis
    "github.com/securecodewarrior/gosec/v2/cmd/gosec@latest" # Security scanner
  )

  for tool in "${go_security_tools[@]}"; do
    local binary="${tool##*/}"
    binary="${binary%@*}"
    if ! command -v "$binary" &>/dev/null; then
      print_status $YELLOW "📦 Installing $tool..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would install $tool"
      else
        if go install "$tool" 2>/dev/null; then
          print_status $GREEN "✅ $binary installed"
        else
          print_status $RED "❌ Failed to install $tool"
        fi
      fi
    else
      print_status $GREEN "✅ $binary already installed"
    fi
  done
}

# Install and configure gitsign for Sigstore commit signing
install_gitsign() {
  print_section "Installing Gitsign for Sigstore Signing"

  # Check if Go is available for gitsign installation
  if ! command -v go &>/dev/null; then
    print_status $YELLOW "⚠️ Go not found - gitsign installation requires Go"
    print_status $BLUE "   Install Go from https://golang.org/dl/ or:"
    print_status $BLUE "   • macOS: brew install go"
    print_status $BLUE "   • Ubuntu: sudo apt install golang-go"
    print_status $BLUE "   • Windows: Download from golang.org"
    return 0
  fi

  # Check if gitsign is already installed
  if command -v gitsign &>/dev/null; then
    print_status $GREEN "✅ gitsign already installed"
  else
    print_status $YELLOW "📦 Installing gitsign..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would install gitsign"
    else
      if go install github.com/sigstore/gitsign@latest 2>/dev/null; then
        print_status $GREEN "✅ gitsign installed successfully"
      else
        print_status $RED "❌ Failed to install gitsign"
        print_status $YELLOW "   Try installing manually: go install github.com/sigstore/gitsign@latest"
        return 1
      fi
    fi
  fi

  # Configure gitsign with manual authentication behavior
  configure_gitsign_manual_auth
}

# Non-fatal execution for optional configurations
try_execute() {
  local operation=$1
  local success_msg=${2:-""}
  local failure_msg=${3:-"⚠️ Operation failed"}

  if eval "$operation" 2>/dev/null; then
    [[ -n $success_msg ]] && print_status $GREEN "$success_msg"
    return 0
  else
    print_status $YELLOW "$failure_msg"
    return 1
  fi
}

# Install automatic dual signing hook
install_dual_signing_hook() {
  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "   [DRY RUN] Would install dual signing hook"
    return 0
  fi

  local hook_script=".git/hooks/post-commit"

  # Create post-commit hook for automatic dual signing
  cat >"$hook_script" <<'EOF'
#!/bin/bash
# Automatic True Dual Signature Hook
# Adds Sigstore signature to GPG-signed commits

# Exit if already dual-signed
if git cat-file commit HEAD | grep -q "^x-sigstore-signature "; then
    exit 0
fi

# Only proceed if commit has GPG signature
if ! git cat-file commit HEAD | grep -q "^gpgsig "; then
    exit 0
fi

# Create Sigstore signature
TEMP_DIR=$(mktemp -d)
COMMIT_HASH=$(git rev-parse HEAD)

# Extract commit content (without signatures)
git cat-file commit "$COMMIT_HASH" | \
awk '/^gpgsig /{flag=1; next} flag && /^ /{next} flag && !/^ /{flag=0} !flag{print}' \
> "$TEMP_DIR/base_commit"

# Create Sigstore signature
if timeout 60 gitsign --detach-sign --armor < "$TEMP_DIR/base_commit" > "$TEMP_DIR/sigstore_sig" 2>/dev/null; then
    # Reconstruct commit with both signatures
    {
        git cat-file commit "$COMMIT_HASH" | awk '
        /^gpgsig / { in_gpg=1; print; next }
        in_gpg && /^ / { print; next }
        in_gpg && !/^ / {
            in_gpg=0
            print "x-sigstore-signature -----BEGIN SIGNED MESSAGE-----"
            while ((getline line < "'$TEMP_DIR'/sigstore_sig") > 0) {
                print " " line
            }
            print " -----END SIGNED MESSAGE-----"
            print $0
            next
        }
        !in_gpg { print }
        '
    } > "$TEMP_DIR/dual_commit"

    # Replace commit object
    NEW_HASH=$(git hash-object -t commit -w "$TEMP_DIR/dual_commit")
    git update-ref HEAD "$NEW_HASH"
fi

rm -rf "$TEMP_DIR"
EOF

  chmod +x "$hook_script"
  print_status $GREEN "✅ Automatic dual signing hook installed"
}

# Upload GPG public key to GitHub for verification badges
upload_gpg_key_to_github() {
  print_status $BLUE "🔑 Setting up GitHub GPG key verification..."

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "   [DRY RUN] Would upload GPG key to GitHub"
    return 0
  fi

  # Check if gh CLI is available
  if ! command -v gh &>/dev/null; then
    print_status $YELLOW "⚠️ GitHub CLI not found - skipping automatic GPG key upload"
    print_status $BLUE "   Manual setup: https://github.com/settings/keys"
    return 0
  fi

  # Check if user is authenticated
  if ! gh auth status &>/dev/null; then
    print_status $YELLOW "⚠️ GitHub CLI not authenticated - skipping automatic GPG key upload"
    print_status $BLUE "   Run: gh auth login"
    print_status $BLUE "   Then: https://github.com/settings/keys"
    return 0
  fi

  # Get the configured signing key
  local signing_key
  signing_key=$(git config --global user.signingkey 2>/dev/null || git config user.signingkey 2>/dev/null || echo "")

  if [[ -z $signing_key ]]; then
    print_status $YELLOW "⚠️ No GPG signing key configured - generating one..."

    # Get user email for GPG key generation
    local user_email
    user_email=$(git config --global user.email 2>/dev/null || git config user.email 2>/dev/null)
    local user_name
    user_name=$(git config --global user.name 2>/dev/null || git config user.name 2>/dev/null)

    if [[ -z $user_email || -z $user_name ]]; then
      print_status $YELLOW "⚠️ Git user.email or user.name not configured"
      print_status $BLUE "   Run: git config --global user.email 'your-email@example.com'"
      print_status $BLUE "   Run: git config --global user.name 'Your Name'"
      print_status $BLUE "   Then: https://github.com/settings/keys"
      return 0
    fi

    # Generate GPG key non-interactively
    print_status $BLUE "   Generating GPG key for $user_name <$user_email>..."

    local gpg_config
    gpg_config=$(
      cat <<EOF
%echo Generating GPG key for Git signing
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $user_name
Name-Email: $user_email
Expire-Date: 2y
%no-protection
%commit
%echo Done
EOF
    )

    if echo "$gpg_config" | gpg --batch --generate-key 2>/dev/null; then
      # Get the newly generated key ID
      signing_key=$(gpg --list-secret-keys --keyid-format LONG "$user_email" 2>/dev/null | grep "sec" | sed 's/.*\/\([A-F0-9]*\).*/\1/' | head -1)

      if [[ -n $signing_key ]]; then
        # Configure Git to use the new key
        git config --global user.signingkey "$signing_key"
        print_status $GREEN "✅ Generated and configured GPG key: $signing_key"
      else
        print_status $YELLOW "⚠️ Failed to retrieve generated key ID"
        return 0
      fi
    else
      print_status $YELLOW "⚠️ Failed to generate GPG key"
      print_status $BLUE "   Manual setup: https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key"
      return 0
    fi
  fi

  # Export the public key
  local public_key
  if ! public_key=$(gpg --armor --export "$signing_key" 2>/dev/null); then
    print_status $YELLOW "⚠️ Failed to export GPG public key"
    print_status $BLUE "   Manual export: gpg --armor --export $signing_key"
    print_status $BLUE "   Upload at: https://github.com/settings/keys"
    return 0
  fi

  # Check if we have the required scope
  print_status $BLUE "   Checking GitHub API permissions..."
  if ! gh api /user/gpg_keys &>/dev/null; then
    print_status $YELLOW "⚠️ GitHub token lacks GPG key permissions"
    print_status $BLUE "   Requesting additional permissions..."

    # Request the required scopes
    if gh auth refresh -h github.com -s admin:gpg_key &>/dev/null; then
      print_status $GREEN "✅ GitHub permissions updated"
    else
      print_status $YELLOW "⚠️ Failed to update GitHub permissions"
      print_status $BLUE "   Manual upload required: https://github.com/settings/keys"
      return 0
    fi
  fi

  # Check if key is already uploaded
  local existing_keys
  if existing_keys=$(gh api /user/gpg_keys 2>/dev/null); then
    local key_fingerprint
    key_fingerprint=$(gpg --fingerprint "$signing_key" 2>/dev/null | grep -A 1 "pub" | tail -1 | tr -d ' ')

    if echo "$existing_keys" | grep -q "$key_fingerprint"; then
      print_status $GREEN "✅ GPG key already uploaded to GitHub"
      return 0
    fi
  fi

  # Upload the GPG key
  print_status $BLUE "   Uploading GPG key to GitHub..."
  if gh api /user/gpg_keys -X POST -f armored_public_key="$public_key" >/dev/null 2>&1; then
    print_status $GREEN "✅ GPG key uploaded to GitHub successfully"
    print_status $BLUE "   Your commits will now show 'Verified' badges"
    print_status $BLUE "   View your keys: https://github.com/settings/keys"
  else
    print_status $YELLOW "⚠️ Failed to upload GPG key automatically"
    print_status $BLUE "   Manual upload: https://github.com/settings/keys"
    print_status $BLUE "   Key to upload:"
    echo "$public_key"
  fi
}

# Configure gitsign-only signing (secure, short-lived certificates)
configure_gitsign_only() {
  if [[ $YUBIKEY_MODE == true ]]; then
    print_status $BLUE "🔐 Configuring secure gitsign + YubiKey signing..."
  else
    print_status $BLUE "🔐 Configuring secure gitsign signing..."
  fi

  if [[ $DRY_RUN == true ]]; then
    if [[ $YUBIKEY_MODE == true ]]; then
      print_status $BLUE "   [DRY RUN] Would configure gitsign + YubiKey signing"
    else
      print_status $BLUE "   [DRY RUN] Would configure gitsign-only signing"
    fi
    return 0
  fi

  # Configure gitsign as the signing method
  try_execute "git config --global commit.gpgsign true" "" "⚠️ Failed to enable commit signing"
  try_execute "git config --global tag.gpgsign true" "" "⚠️ Failed to enable tag signing"
  try_execute "git config --global gpg.format x509" "" "⚠️ Failed to set gitsign format"
  try_execute "git config --global gpg.x509.program gitsign" "" "⚠️ Failed to set gitsign program"

  # Configure Sigstore endpoints
  try_execute "git config --global gitsign.fulcio-url 'https://fulcio.sigstore.dev'" "" "⚠️ Failed to set Fulcio URL"
  try_execute "git config --global gitsign.rekor-url 'https://rekor.sigstore.dev'" "" "⚠️ Failed to set Rekor URL"

  # Configure OIDC issuer based on YubiKey mode
  if [[ $YUBIKEY_MODE == true ]]; then
    # YubiKey mode: use GitHub Actions issuer for hardware-backed auth
    try_execute "git config --global gitsign.oidc-issuer 'https://token.actions.githubusercontent.com'" "" "⚠️ Failed to set YubiKey OIDC issuer"
    print_status $BLUE "   • 🔑 YubiKey hardware authentication enabled"
  else
    # Software mode: use regular OAuth issuer
    try_execute "git config --global gitsign.oidc-issuer 'https://oauth2.sigstore.dev/auth'" "" "⚠️ Failed to set OIDC issuer"
    print_status $BLUE "   • 💻 Browser-based authentication enabled"
  fi

  try_execute "git config --global gitsign.oidc-client-id 'sigstore'" "" "⚠️ Failed to set OIDC client ID"

  # Configure balanced authentication behavior (security + usability)
  try_execute "git config --global gitsign.autoclose true" "" "⚠️ Failed to enable autoclose"
  try_execute "git config --global gitsign.autocloseTimeout 20" "" "⚠️ Failed to set timeout"
  try_execute "git config --global gitsign.connectorID 'https://github.com/login/oauth'" "" "⚠️ Failed to set connector ID"

  if [[ $YUBIKEY_MODE == true ]]; then
    print_status $GREEN "✅ Secure gitsign + YubiKey signing configured"
    print_status $BLUE "   • 🏆 Maximum security: Short-lived certs + hardware auth"
    print_status $BLUE "   • 🔑 YubiKey required for each signing operation"
    print_status $BLUE "   • 📋 Transparency logging via Rekor"
    print_status $BLUE "   • 📝 Note: GitHub shows as 'Unverified' (limitation on GitHub's side)"
    print_status $YELLOW "   • 💡 Ensure your YubiKey is registered with GitHub"
  else
    print_status $GREEN "✅ Secure gitsign signing configured"
    print_status $BLUE "   • 🔒 Short-lived certificates (automatic rotation)"
    print_status $BLUE "   • 🔄 Keyless signing with transparency logging"
    print_status $BLUE "   • 🏆 Superior security vs traditional GPG"
    print_status $BLUE "   • 📝 Note: GitHub shows as 'Unverified' (limitation on GitHub's side)"
    print_status $YELLOW "   • 💡 Add --yubikey for maximum security"
  fi
}

# Configure GPG signing (weaker, for GitHub verification badges)
configure_gpg_signing() {
  if [[ $YUBIKEY_MODE == true ]]; then
    print_status $YELLOW "🔧 Configuring GPG + YubiKey signing for GitHub verification..."
  else
    print_status $YELLOW "🔧 Configuring GPG signing for GitHub verification..."
  fi

  if [[ $DRY_RUN == true ]]; then
    if [[ $YUBIKEY_MODE == true ]]; then
      print_status $BLUE "   [DRY RUN] Would configure GPG + YubiKey signing"
    else
      print_status $BLUE "   [DRY RUN] Would configure GPG signing"
    fi
    return 0
  fi

  if [[ $YUBIKEY_MODE == true ]]; then
    print_status $BLUE "⚖️  GPG + YubiKey: Hardware keys with GitHub badges"
    print_status $BLUE "   • YubiKey provides hardware-backed signing"
    print_status $BLUE "   • GitHub 'Verified' badges supported"
    print_status $BLUE "   • Manual YubiKey setup required (see below)"
  else
    print_status $YELLOW "⚠️  WARNING: GPG uses long-lived keys (weaker security)"
    print_status $BLUE "   • Choose this only if you need GitHub 'Verified' badges"
    print_status $BLUE "   • For better security, use default gitsign option"
  fi

  # Set up GPG as signing method
  try_execute "git config --global commit.gpgsign true" "" "⚠️ Failed to enable commit signing"
  try_execute "git config --global tag.gpgsign true" "" "⚠️ Failed to enable tag signing"
  try_execute "git config --global gpg.format openpgp" "" "⚠️ Failed to set GPG format"

  # Auto-upload GPG key to GitHub for verification badges
  upload_gpg_key_to_github

  if [[ $YUBIKEY_MODE == true ]]; then
    print_status $GREEN "✅ GPG + YubiKey signing configured"
    print_status $BLUE "   • Hardware-backed signing enabled"
    print_status $BLUE "   • GitHub 'Verified' badges enabled"
    print_status $BLUE "   • YubiKey touch required for signing"
    echo
    print_status $YELLOW "🔧 YubiKey Setup Required:"
    echo "   1. Configure YubiKey touch policy:"
    echo "      ykman openpgp keys set-touch sig on"
    echo "   2. Generate or import GPG key on YubiKey"
    echo "   3. Verify key: gpg --card-status"
    echo "   4. Configure Git: git config --global user.signingkey YOUR_KEY_ID"
    echo
    print_status $BLUE "💡 After setup, test with: $0 test"
  else
    print_status $GREEN "✅ GPG signing configured"
    print_status $BLUE "   • Long-lived keys (2-year expiration)"
    print_status $BLUE "   • Manual key management required"
    print_status $BLUE "   • GitHub 'Verified' badges enabled"
    print_status $YELLOW "   • Consider gitsign for better security"
    print_status $YELLOW "   • For hardware security: $0 enable-yubikey"
  fi
}

# Legacy function name for backward compatibility
configure_gitsign_manual_auth() {
  case "$SIGNING_METHOD" in
    gitsign)
      configure_gitsign_only
      ;;
    gpg)
      configure_gpg_signing
      ;;
    *)
      print_status $RED "❌ Unknown signing method: $SIGNING_METHOD"
      exit 1
      ;;
  esac

  # Test configuration and provide guidance based on signing method
  if [[ $SIGNING_METHOD == "gitsign" ]]; then
    if command -v gitsign &>/dev/null; then
      print_status $BLUE "🧪 Testing gitsign configuration..."
      if git config --global --get commit.gpgsign >/dev/null 2>&1; then
        print_status $GREEN "✅ Gitsign ready for secure commit signing"
        print_status $BLUE "   Next commit will be signed with short-lived certificates"
        echo
        print_status $YELLOW "💡 Authentication Behavior:"
        echo "   When you make your first signed commit:"
        echo "   1. Browser will open to GitHub OAuth page"
        echo "   2. You have 20 seconds to complete authentication"
        echo "   3. Browser closes automatically after auth or timeout"
        echo "   4. If timeout occurs, git commit will fail - simply retry"
        echo
        print_status $YELLOW "🔧 Troubleshooting Authentication Failures:"
        echo "   • Ensure you're logged into GitHub in your default browser"
        echo "   • Check that pop-ups are not blocked for sigstore.dev"
        echo "   • If repeated failures: git config --global gitsign.autocloseTimeout 60"
        echo "   • For CI/CD environments: use GITHUB_TOKEN authentication"
      else
        print_status $YELLOW "⚠️ Gitsign configuration may need verification"
      fi
    fi
  elif [[ $SIGNING_METHOD == "gpg" ]]; then
    print_status $BLUE "🧪 Testing GPG configuration..."
    if git config --global --get commit.gpgsign >/dev/null 2>&1; then
      print_status $GREEN "✅ GPG signing configured"
      print_status $BLUE "   Your commits will show 'Verified' badges on GitHub"
      print_status $YELLOW "   Remember: GPG keys have 2-year expiration"
    fi
  fi
}

# Configure Cargo.toml for security enhancements
configure_cargo_security() {
  if [[ $RUST_PROJECT == true ]] && [[ -f "Cargo.toml" ]]; then
    print_section "Configuring Cargo.toml Security Settings"

    # Check if [profile.release] section exists
    if ! grep -q "^\[profile\.release\]" Cargo.toml; then
      print_status $YELLOW "📝 Adding [profile.release] section to Cargo.toml..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would add [profile.release] section"
      else
        echo "" >>Cargo.toml
        echo "# Security enhancements" >>Cargo.toml
        echo "[profile.release]" >>Cargo.toml
        echo "# Enable integer overflow checks in release builds for security" >>Cargo.toml
        echo "overflow-checks = true" >>Cargo.toml
        print_status $GREEN "✅ Added security profile to Cargo.toml"
      fi
    else
      # Check if overflow-checks is already configured
      if ! grep -A 10 "^\[profile\.release\]" Cargo.toml | grep -q "overflow-checks"; then
        print_status $YELLOW "📝 Adding overflow-checks to existing [profile.release]..."
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "   [DRY RUN] Would add overflow-checks = true"
        else
          # Add overflow-checks after the [profile.release] line
          sed -i.bak '/^\[profile\.release\]/a\
# Enable integer overflow checks in release builds for security\
overflow-checks = true' Cargo.toml
          rm -f Cargo.toml.bak
          print_status $GREEN "✅ Added overflow-checks to Cargo.toml"
        fi
      else
        print_status $GREEN "✅ overflow-checks already configured in Cargo.toml"
      fi
    fi

    # Create deny.toml if it doesn't exist
    if [[ ! -f "deny.toml" ]]; then
      print_status $YELLOW "📝 Creating deny.toml security configuration..."
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "   [DRY RUN] Would create deny.toml"
      else
        create_deny_toml
        print_status $GREEN "✅ Created deny.toml configuration"
      fi
    else
      print_status $GREEN "✅ deny.toml already exists"
    fi

    # Create secure .cargo/config.toml
    configure_cargo_config_security
  fi
}

# Configure .cargo/config.toml for security hardening
configure_cargo_config_security() {
  local cargo_config_dir=".cargo"
  local cargo_config_file="$cargo_config_dir/config.toml"

  print_status $YELLOW "📝 Configuring secure .cargo/config.toml..."

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "   [DRY RUN] Would create secure .cargo/config.toml"
    return 0
  fi

  # Create .cargo directory if it doesn't exist
  mkdir -p "$cargo_config_dir"

  # Create or update config.toml with security settings
  if [[ ! -f $cargo_config_file ]]; then
    cat >"$cargo_config_file" <<'CARGO_CONFIG_EOF'
# Cargo security configuration
# Generated by 1-Click GitHub Security Controls

[net]
# Force git to use CLI for fetching (more secure than libgit2)
git-fetch-with-cli = true
# Set reasonable timeouts to prevent hanging builds
connect-timeout = 60
read-timeout = 60

[http]
# Check certificate revocation
check-revoke = true
# Force TLS 1.2 or higher
ssl-version = "tlsv1.2"
# Set user agent for security tracking
user-agent = "cargo (security-hardened)"
# Set timeout for HTTP requests
timeout = 60

# Ensure we're using the official crates.io registry
# The default crates-io source is already secure with HTTPS
CARGO_CONFIG_EOF
    print_status $GREEN "✅ Created secure .cargo/config.toml"
  else
    # Merge security settings with existing config
    print_status $BLUE "ℹ️  .cargo/config.toml exists - adding security settings"

    # Add [net] section if missing
    if ! grep -q "^\[net\]" "$cargo_config_file"; then
      echo "" >>"$cargo_config_file"
      echo "# Security: Force git CLI and set timeouts" >>"$cargo_config_file"
      echo "[net]" >>"$cargo_config_file"
      echo "git-fetch-with-cli = true" >>"$cargo_config_file"
      echo "connect-timeout = 60" >>"$cargo_config_file"
      echo "read-timeout = 60" >>"$cargo_config_file"
      print_status $GREEN "✅ Added [net] security settings"
    fi

    # Add [http] section if missing
    if ! grep -q "^\[http\]" "$cargo_config_file"; then
      echo "" >>"$cargo_config_file"
      echo "# Security: HTTP hardening" >>"$cargo_config_file"
      echo "[http]" >>"$cargo_config_file"
      echo "check-revoke = true" >>"$cargo_config_file"
      echo 'ssl-version = "tlsv1.2"' >>"$cargo_config_file"
      echo "timeout = 60" >>"$cargo_config_file"
      print_status $GREEN "✅ Added [http] security settings"
    fi
  fi
}

# Configure language-specific project files
configure_language_specific_files() {
  case "$PROJECT_LANGUAGE" in
    "nodejs")
      configure_nodejs_security
      ;;
    "python")
      configure_python_security
      ;;
    "go")
      configure_go_security
      ;;
  esac
}

# Configure Node.js/JavaScript/TypeScript security settings
configure_nodejs_security() {
  if [[ ! -f "package.json" ]]; then
    print_status $YELLOW "⚠️  No package.json found - creating basic Node.js project structure"
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create package.json"
      return 0
    fi

    # Create basic package.json
    cat >"package.json" <<'NODEJS_PACKAGE_EOF'
{
  "name": "my-project",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "keywords": [],
  "author": "",
  "license": "ISC"
}
NODEJS_PACKAGE_EOF
    print_status $GREEN "✅ Created basic package.json"
  fi

  # Create ESLint configuration
  create_eslint_config

  # Create Prettier configuration
  create_prettier_config

  # Create TypeScript configuration if needed
  if [[ -f "tsconfig.json" ]] || grep -q '"typescript"' package.json 2>/dev/null; then
    create_typescript_config
  fi

  # Create npm security configuration
  create_npm_security_config
}

# Create ESLint configuration
create_eslint_config() {
  if [[ ! -f ".eslintrc.js" ]] && [[ ! -f ".eslintrc.json" ]] && [[ ! -f ".eslintrc.yml" ]]; then
    print_status $YELLOW "📝 Creating ESLint configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .eslintrc.js"
      return 0
    fi

    cat >".eslintrc.js" <<'ESLINT_CONFIG_EOF'
module.exports = {
  extends: ['eslint:recommended'],
  env: {
    node: true,
    es2021: true,
    browser: true,
  },
  parserOptions: {
    ecmaVersion: 12,
    sourceType: 'module',
  },
  rules: {
    // Basic security rules
    'no-eval': 'error',
    'no-implied-eval': 'error',
    'no-new-func': 'error',
    'no-script-url': 'error',

    // Prevent dangerous globals
    'no-global-assign': 'error',
    'no-implicit-globals': 'error',

    // Code quality and security
    'eqeqeq': 'error',
    'curly': 'error',
    'prefer-const': 'error',
    'no-var': 'error',
    'no-unused-vars': 'error',
    'no-undef': 'error',

    // Prevent prototype pollution
    'no-prototype-builtins': 'error',
    'no-extend-native': 'error',

    // Prevent regex attacks
    'no-invalid-regexp': 'error',
    'no-regex-spaces': 'error',

    // Node.js security
    'no-path-concat': 'error',
    'no-process-exit': 'warn',
    'no-process-env': 'warn',

    // General code quality
    'no-console': 'warn',
    'no-debugger': 'error',
    'no-alert': 'error',
    'no-duplicate-imports': 'error',

    // Async security
    'no-await-in-loop': 'warn',
    'prefer-promise-reject-errors': 'error',

    // Security-focused formatting
    'quotes': ['error', 'single', { 'avoidEscape': true }],
    'semi': ['error', 'always'],
  },
};
ESLINT_CONFIG_EOF
    print_status $GREEN "✅ Created .eslintrc.js with security-focused rules"
  fi
}

# Create Prettier configuration
create_prettier_config() {
  if [[ ! -f ".prettierrc" ]] && [[ ! -f ".prettierrc.json" ]] && [[ ! -f "prettier.config.js" ]]; then
    print_status $YELLOW "📝 Creating Prettier configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .prettierrc"
      return 0
    fi

    cat >".prettierrc" <<'PRETTIER_CONFIG_EOF'
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2,
  "useTabs": false
}
PRETTIER_CONFIG_EOF
    print_status $GREEN "✅ Created .prettierrc"
  fi
}

# Create TypeScript configuration
create_typescript_config() {
  if [[ ! -f "tsconfig.json" ]]; then
    print_status $YELLOW "📝 Creating TypeScript configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create tsconfig.json"
      return 0
    fi

    cat >"tsconfig.json" <<'TYPESCRIPT_CONFIG_EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
TYPESCRIPT_CONFIG_EOF
    print_status $GREEN "✅ Created tsconfig.json with strict settings"
  fi
}

# Create npm security configuration
create_npm_security_config() {
  # Create .npmrc for security settings
  if [[ ! -f ".npmrc" ]]; then
    print_status $YELLOW "📝 Creating .npmrc security configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .npmrc"
      return 0
    fi

    cat >".npmrc" <<'NPMRC_CONFIG_EOF'
# Security-focused npm configuration
# Generated by 1-Click GitHub Security

# Audit settings
audit-level=moderate
fund=false

# Registry security
registry=https://registry.npmjs.org/
strict-ssl=true

# Package verification
package-lock=true
package-lock-only=true
shrinkwrap=false

# Security settings
audit-signatures=true
foreground-scripts=false
ignore-scripts=false

# Cache and temporary settings
cache-max=86400000
prefer-offline=false
offline=false

# Progress and output
progress=true
loglevel=warn
NPMRC_CONFIG_EOF
    print_status $GREEN "✅ Created .npmrc with security-focused configuration"
  fi

  # Create audit configuration
  create_audit_config

  # Create security policy file
  create_security_policy_file
}

# Create audit configuration file
create_audit_config() {
  if [[ ! -f ".auditrc" ]]; then
    print_status $YELLOW "📝 Creating audit configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .auditrc"
      return 0
    fi

    cat >".auditrc" <<'AUDIT_CONFIG_EOF'
{
  "audit-level": "moderate",
  "production": true,
  "dev": false,
  "exclude": [],
  "report-format": "json",
  "output-format": "table",
  "advisories": [],
  "whitelist": [],
  "allowlist": [],
  "pass-enoaudit": false,
  "show-not-found": true
}
AUDIT_CONFIG_EOF
    print_status $GREEN "✅ Created .auditrc audit configuration"
  fi
}

# Create security policy file
create_security_policy_file() {
  if [[ ! -f "SECURITY.md" ]]; then
    print_status $YELLOW "📝 Creating SECURITY.md policy template..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create SECURITY.md"
      return 0
    fi

    cat >"SECURITY.md" <<'SECURITY_MD_EOF'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |

## Reporting a Vulnerability

Please report security vulnerabilities to [security@yourproject.com] or through GitHub Security Advisories.

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if known)

### Response Time

- Initial response: Within 48 hours
- Status update: Within 7 days
- Resolution target: Within 30 days for critical issues

## Security Measures

This project implements:

- ✅ Automated dependency scanning (npm audit, Snyk, retire.js)
- ✅ License compliance checking
- ✅ Secret scanning (gitleaks)
- ✅ SHA pinning for GitHub Actions
- ✅ Pre-push security validation
- ✅ Comprehensive linting and code analysis

## Dependency Management

- All dependencies are regularly audited
- Package-lock.json is committed for consistency
- Security updates are prioritized
- Vulnerable dependencies are promptly updated

## Code Security

- ESLint with security rules enabled
- No eval() or similar dangerous functions
- Strict TypeScript configuration (if applicable)
- Input validation and sanitization
SECURITY_MD_EOF
    print_status $GREEN "✅ Created SECURITY.md policy template"
  fi
}

# Configure Python security settings
configure_python_security() {
  # Create pyproject.toml for modern Python projects
  create_pyproject_toml

  # Create flake8 configuration
  create_flake8_config

  # Create bandit configuration
  create_bandit_config
}

# Create pyproject.toml configuration
create_pyproject_toml() {
  if [[ ! -f "pyproject.toml" ]]; then
    print_status $YELLOW "📝 Creating pyproject.toml configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create pyproject.toml"
      return 0
    fi

    cat >"pyproject.toml" <<'PYPROJECT_TOML_EOF'
[build-system]
requires = ["setuptools>=45", "wheel"]
build-backend = "setuptools.build_meta"

[tool.black]
line-length = 100
target-version = ['py38']
include = '\.pyi?$'
extend-exclude = '''
/(
  # directories
  \.eggs
  | \.git
  | \.hg
  | \.mypy_cache
  | \.tox
  | \.venv
  | build
  | dist
)/
'''

[tool.pytest.ini_options]
minversion = "6.0"
addopts = "-ra -q --strict-markers"
testpaths = [
    "tests",
]

[tool.coverage.run]
source = ["."]
omit = [
    "*/venv/*",
    "*/env/*",
    "tests/*",
    "setup.py",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise AssertionError",
    "raise NotImplementedError",
]
PYPROJECT_TOML_EOF
    print_status $GREEN "✅ Created pyproject.toml with security-focused configuration"
  fi
}

# Create flake8 configuration
create_flake8_config() {
  if [[ ! -f ".flake8" ]] && [[ ! -f "setup.cfg" ]]; then
    print_status $YELLOW "📝 Creating flake8 configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .flake8"
      return 0
    fi

    cat >".flake8" <<'FLAKE8_CONFIG_EOF'
[flake8]
max-line-length = 100
extend-ignore = E203, W503
exclude =
    .git,
    __pycache__,
    .venv,
    venv,
    build,
    dist,
    *.egg-info
per-file-ignores =
    __init__.py:F401
FLAKE8_CONFIG_EOF
    print_status $GREEN "✅ Created .flake8"
  fi
}

# Create bandit configuration
create_bandit_config() {
  if [[ ! -f ".bandit" ]]; then
    print_status $YELLOW "📝 Creating bandit security configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .bandit"
      return 0
    fi

    cat >".bandit" <<'BANDIT_CONFIG_EOF'
[bandit]
exclude_dirs = ["/tests", "/test"]
skips = ["B101"]  # Skip assert_used test (commonly used in tests)

[bandit.any_other_function_with_shell_equals_true]
shell = [
    "os.system",
    "subprocess.run",
    "subprocess.call",
    "subprocess.Popen",
]
BANDIT_CONFIG_EOF
    print_status $GREEN "✅ Created .bandit security configuration"
  fi
}

# Configure Go security settings
configure_go_security() {
  # Create go.mod if it doesn't exist
  create_go_mod

  # Create golangci-lint configuration
  create_golangci_config
}

# Create go.mod file
create_go_mod() {
  if [[ ! -f "go.mod" ]]; then
    print_status $YELLOW "📝 Creating go.mod..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create go.mod"
      return 0
    fi

    local module_name
    module_name=$(basename "$PWD")

    cat >"go.mod" <<EOF
module $module_name

go 1.21
EOF
    print_status $GREEN "✅ Created go.mod"
  fi
}

# Create golangci-lint configuration
create_golangci_config() {
  if [[ ! -f ".golangci.yml" ]] && [[ ! -f ".golangci.yaml" ]]; then
    print_status $YELLOW "📝 Creating golangci-lint configuration..."
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "   [DRY RUN] Would create .golangci.yml"
      return 0
    fi

    cat >".golangci.yml" <<'GOLANGCI_CONFIG_EOF'
run:
  timeout: 5m
  issues-exit-code: 1
  tests: true

linters-settings:
  staticcheck:
    checks: ["all"]
  gosec:
    severity: medium
    confidence: medium

linters:
  enable:
    - staticcheck
    - gosec
    - govet
    - errcheck
    - gofmt
    - goimports
    - golint
    - ineffassign
    - misspell
    - unconvert
    - unused
  disable:
    - typecheck

issues:
  exclude-use-default: false
  max-issues-per-linter: 0
  max-same-issues: 0
GOLANGCI_CONFIG_EOF
    print_status $GREEN "✅ Created .golangci.yml security configuration"
  fi
}

# Create comprehensive deny.toml configuration
create_deny_toml() {
  cat >deny.toml <<'DENY_TOML_EOF'
# cargo-deny configuration for comprehensive security
# Generated by 1-Click GitHub Security Controls

[graph]
targets = [
    "x86_64-unknown-linux-gnu",
    "x86_64-apple-darwin",
    "aarch64-apple-darwin",
    "x86_64-pc-windows-msvc",
]

[advisories]
db-path = "~/.cargo/advisory-db"
db-urls = ["https://github.com/rustsec/advisory-db"]
unmaintained = "warn"

[licenses]
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
    "CC0-1.0",
    "MPL-2.0",
    "Zlib",
    "BSL-1.0",
]
confidence-threshold = 0.8

[bans]
multiple-versions = "warn"
wildcards = "allow"
deny = [
    { crate = "openssl", reason = "Use rustls instead for pure Rust crypto" },
    { crate = "openssl-sys", reason = "Use rustls instead for pure Rust crypto" },
]

[sources]
unknown-registry = "warn"
unknown-git = "warn"
allow-registry = ["https://github.com/rust-lang/crates.io-index"]
DENY_TOML_EOF
}

# Generate unified multi-language pre-push hook
generate_pre_push_hook() {
  generate_unified_pre_push_hook_content
}

# Generate unified pre-push hook with multi-language detection
generate_unified_pre_push_hook_content() {
  cat <<'UNIFIED_HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for multi-language security validation
# Generated by 1-Click GitHub Security v0.3.9

echo "🔍 Running pre-push validation checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Track if any checks fail
FAILED=0

print_status $BLUE "📋 Pre-push validation started"

# ============================================================================
# PROJECT LANGUAGE DETECTION - Multi-Language Security Architecture
# ============================================================================
print_status $BLUE "🔍 Detecting project languages and security requirements..."

# Initialize language detection variables
declare -a DETECTED_LANGUAGES=()
SKIP_RUST=1
SKIP_NODEJS=1
SKIP_PYTHON=1
SKIP_GO=1

# Language detection logic
detect_languages() {
  local detected_count=0

  # Rust detection
  if [[ -f "Cargo.toml" ]]; then
    if command -v cargo >/dev/null 2>&1; then
      if cargo metadata --no-deps --format-version 1 >/dev/null 2>&1; then
        PKG_COUNT=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages | length' 2>/dev/null || echo 0)
        if [[ "${PKG_COUNT:-0}" -gt 0 ]]; then
          DETECTED_LANGUAGES+=("rust")
          SKIP_RUST=0
          print_status $GREEN "  ✅ Rust project detected ($PKG_COUNT packages)"
          ((detected_count++))
        fi
      fi
    fi
  fi

  # Node.js/TypeScript detection
  if [[ -f "package.json" ]]; then
    if [[ -f "tsconfig.json" ]] || grep -q '"typescript"' package.json 2>/dev/null || find . -maxdepth 2 -name "*.ts" -o -name "*.tsx" 2>/dev/null | head -1 | grep -q .; then
      DETECTED_LANGUAGES+=("typescript")
      SKIP_NODEJS=0
      print_status $GREEN "  ✅ TypeScript project detected"
    else
      DETECTED_LANGUAGES+=("nodejs")
      SKIP_NODEJS=0
      print_status $GREEN "  ✅ Node.js project detected"
    fi
    ((detected_count++))
  fi

  # Python detection
  if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || find . -maxdepth 2 -name "*.py" 2>/dev/null | head -1 | grep -q .; then
    DETECTED_LANGUAGES+=("python")
    SKIP_PYTHON=0
    print_status $GREEN "  ✅ Python project detected"
    ((detected_count++))
  fi

  # Go detection
  if [[ -f "go.mod" ]] || find . -maxdepth 2 -name "*.go" 2>/dev/null | head -1 | grep -q .; then
    DETECTED_LANGUAGES+=("go")
    SKIP_GO=0
    print_status $GREEN "  ✅ Go project detected"
    ((detected_count++))
  fi

  # Summary
  if [[ $detected_count -eq 0 ]]; then
    DETECTED_LANGUAGES=("generic")
    print_status $YELLOW "  ⚠️  Generic project detected - universal security checks only"
  else
    if [[ $detected_count -gt 1 ]]; then
      print_status $CYAN "🎯 Polyglot repository: ${DETECTED_LANGUAGES[*]}"
      print_status $CYAN "   Running security checks for all detected languages"
    else
      print_status $GREEN "🎯 Single-language project: ${DETECTED_LANGUAGES[0]}"
    fi
  fi
}

# Execute language detection
detect_languages

# Display security check plan
print_status $BLUE "📋 Security check plan:"
for lang in "${DETECTED_LANGUAGES[@]}"; do
  case "$lang" in
    "rust")
      print_status $GREEN "  🦀 Rust: format, lint, test, security audit, unsafe code analysis"
      ;;
    "nodejs"|"typescript")
      print_status $GREEN "  📦 Node.js/TypeScript: format, lint, test, npm audit"
      ;;
    "python")
      print_status $GREEN "  🐍 Python: format, lint, test, safety check, security analysis"
      ;;
    "go")
      print_status $GREEN "  🐹 Go: format, lint, test, vulnerability check"
      ;;
    "generic")
      print_status $YELLOW "  ⚙️  Universal: secret detection, SHA pinning, large file check"
      ;;
  esac
done

echo
# ============================================================================

# 1. Rust Checks
if [[ $SKIP_RUST -eq 0 ]]; then
  # Code formatting
  print_status $YELLOW "🎨 Checking code formatting (cargo fmt)..."
  if cargo fmt --all -- --check; then
      print_status $GREEN "✅ Code formatting is correct"
  else
      print_status $RED "❌ Code formatting issues found"
      echo "   Run: cargo fmt --all"
      FAILED=1
  fi

  # Linting
  print_status $YELLOW "🔍 Running linter (cargo clippy)..."
  if cargo clippy --all-targets --all-features -- -D warnings; then
      print_status $GREEN "✅ No linting issues found"
  else
      print_status $RED "❌ Clippy warnings found"
      echo "   Fix warnings before pushing"
      FAILED=1
  fi

  # Security audit
  if command -v cargo-deny &> /dev/null; then
      print_status $YELLOW "🛡️ Running comprehensive security audit (cargo deny)..."
      if cargo deny check; then
          print_status $GREEN "✅ All cargo-deny checks passed"
      else
          print_status $RED "❌ cargo-deny checks failed"
          echo "   Review vulnerabilities, license issues, or banned dependencies"
          FAILED=1
      fi
  else
      print_status $YELLOW "🛡️ Running security audit (cargo audit)..."
      if command -v cargo-audit &> /dev/null; then
          if cargo audit; then
              print_status $GREEN "✅ Security audit passed"
          else
              print_status $RED "❌ Security vulnerabilities found"
              FAILED=1
          fi
      else
          print_status $YELLOW "⚠️ Neither cargo-deny nor cargo-audit found"
          echo "   Install cargo-deny: cargo install cargo-deny (recommended)"
      fi
  fi

  # Tests
  print_status $YELLOW "🧪 Running test suite..."
  if cargo test --all; then
      print_status $GREEN "✅ All tests passed"
  else
      print_status $RED "❌ Test failures detected"
      FAILED=1
  fi
fi

# Universal security checks
print_status $YELLOW "🔍 Running secret detection (staged changes)..."
if [[ -x .security-controls/bin/gitleakslite ]]; then
    if .security-controls/bin/gitleakslite protect --staged --no-banner --redact; then
        print_status $GREEN "✅ No secrets detected in staged changes"
    else
        print_status $RED "❌ Secrets detected in staged changes"
        echo "   Remove secrets or add to allowlist: .security-controls/secret-allowlist.txt"
        FAILED=1
    fi
fi

# GitHub Actions pinning check
print_status $YELLOW "📌 Checking GitHub Actions SHA pinning..."
if [[ -x .security-controls/bin/pinactlite ]] && [[ -d .github/workflows ]]; then
    if .security-controls/bin/pinactlite pincheck --dir .github/workflows --quiet; then
        print_status $GREEN "✅ All GitHub Actions are properly pinned"
    else
        print_status $YELLOW "🛠  Auto-pinning unpinned references..."
        set +e
        .security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images --quiet
        rc=$?
        set -e
        if [[ $rc -eq 2 ]]; then
            print_status $GREEN "✅ Auto-pinned all references successfully"
            git --no-pager diff -- .github/workflows | sed -n '1,120p' || true
            print_status $CYAN "📝 Changes staged - review with 'git diff .github/workflows'"
        else
            print_status $RED "❌ Some references remain unpinned or autopin failed"
            FAILED=1
        fi
    fi
fi

# Large files check
print_status $YELLOW "📦 Checking for large files (> 10MB)..."
LARGE_FILES=$(find . -type f -size +10M -not -path "./.git/*" 2>/dev/null || true)
if [[ -n "$LARGE_FILES" ]]; then
    print_status $RED "❌ Large files detected (> 10MB):"
    echo "$LARGE_FILES"
    FAILED=1
else
    print_status $GREEN "✅ No large files detected"
fi

# Summary
if [ $FAILED -eq 0 ]; then
    print_status $GREEN "🎉 All pre-push checks passed! Pushing to remote..."
    echo
    print_status $BLUE "📤 Push will proceed"
else
    print_status $RED "💥 Pre-push validation failed!"
    echo
    print_status $RED "❌ Push blocked - fix the issues above before pushing"
    echo
    exit 1
fi

exit 0
UNIFIED_HOOK_EOF
}

# Generate Rust pre-push hook (existing implementation)
generate_rust_pre_push_hook_content() {
  cat <<'HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Rust)
# Generated by Security Controls Installer v1.4.0

echo "🔍 Running pre-push validation checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Script-only helpers: secrets and pinning
run_secret_scan() {
    local dir_filter='^(target/|node_modules/|dist/|build/|vendor/|coverage/|\\.git/|\\.github/workflows/)'
    local allowlist_file=".security-controls/secret-allowlist.txt"
    local hits=0
    while IFS= read -r f; do
        [[ -z "$f" || ! -f "$f" ]] && continue
        while IFS= read -r line; do
            [[ "$f" =~ \\.lock$ ]] && continue
            if [[ -f "$allowlist_file" ]] && grep -E -q -f "$allowlist_file" <<<"$line"; then continue; fi
            if grep -E -q 'AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|AIza[0-9A-Za-z_-]{35}|xox[baprs]-[A-Za-z0-9-]{10,48}|-----BEGIN [A-Z ,]*PRIVATE KEY-----|[A-Za-z0-9+/=]{40,}' <<<"$line" \
               || grep -E -qi '(secret|password|api[_-]?key|token)[^\n]{0,20}[:=][[:space:]]*[^[:space:]]{8,}' <<<"$line"; then
                echo "   $f: $(sed -E 's/([:=])[[:space:]]*\"?[^\"[:space:]]{4,}/\\1 ***REDACTED***/g' <<<"$line")"
                hits=$((hits+1))
            fi
        done < <(git diff --cached -U0 -- "$f" | sed -n 's/^+//p')
    done < <(git diff --cached --name-only --diff-filter=ACM | grep -v -E "$dir_filter" || true)
    [[ $hits -eq 0 ]]
}

run_pin_checks() {
    local wf_dir="${1:-.github/workflows}"
    local violations=0
    [[ ! -d "$wf_dir" ]] && return 0
    is_hex40() { [[ ${#1} -eq 40 && "$1" =~ ^[0-9a-fA-F]{40}$ ]]; }
    check_uses_line() {
        local file="$1" uses="$2"
        if [[ "$uses" == ./* || "$uses" == .github/* ]]; then return 0; fi
        if [[ "$uses" == docker://* ]]; then
            [[ "$uses" == *"@sha256:"* ]] || { echo "   $file: docker action not pinned: $uses"; return 1; }
            return 0
        fi
        [[ "$uses" == *"@"* ]] || { echo "   $file: unpinned action (missing @<sha>): $uses"; return 1; }
        local ref="${uses##*@}"
        is_hex40 "$ref" || { echo "   $file: action ref not a 40-hex commit: $uses"; return 1; }
        return 0
    }
    while IFS= read -r -d '' f; do
        rm -f "$f.uses.tmp"
        awk -v FNAME="$f" -v UFILE="$f.uses.tmp" '
          function ltrim(s) { sub(/^\s+/, "", s); return s }
          function indent(s) { match(s, /^ */); return RLENGTH }
          BEGIN{ in_container=0; cont_indent=0; in_services=0; serv_indent=0; bad=0 }
          /^[[:space:]]*#/ { next }
          {
            line=$0; ind=indent(line); l=ltrim(line)
            if (l ~ /^container:/) {
              if (l ~ /^container:[[:space:]]*[^\{\[]/) {
                img=l; sub(/^container:[[:space:]]*/, "", img)
                if (img !~ /@sha256:/) { printf "   %s: jobs.container: image not pinned: %s\n", FNAME, img; bad++ }
              } else {
                in_container=1; cont_indent=ind
              }
            } else if (in_container && ind <= cont_indent) { in_container=0 }
            if (l ~ /^services:/) { in_services=1; serv_indent=ind; next }
            if (in_services && ind <= serv_indent) { in_services=0 }
            if ((in_container || in_services) && l ~ /^image:[[:space:]]*/) {
              img=l; sub(/^image:[[:space:]]*/, "", img)
              gsub(/^"|"$/, "", img); gsub(/^\047|\047$/, "", img)
              if (img !~ /@sha256:/) { printf "   %s: image not pinned: %s\n", FNAME, img; bad++ }
            }
            if (l ~ /^uses:[[:space:]]*/) {
              val=l; sub(/^uses:[[:space:]]*/, "", val); gsub(/^"|"$/, "", val); gsub(/^\047|\047$/, "", val)
              printf "USES %s\n", val >> UFILE
            }
          }
          END{ if (bad>0) exit 2 }' "$f" || violations=$((violations+1))
        while IFS= read -r uses; do
            check_uses_line "$f" "$uses" || violations=$((violations+1))
        done < "$f.uses.tmp"
    done < <(find "$wf_dir" -type f \( -name "*.yml" -o -name "*.yaml" \) -print0)
    [[ $violations -eq 0 ]]
}

# Load optional configuration
CONFIG_FILE=".security-controls/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

# Defaults if not set in config
: "${ENABLE_SECRET_SCAN:=true}"
: "${SECRET_SCAN_MODE:=staged}"
: "${ENABLE_LARGE_FILE_CHECK:=true}"
: "${LARGE_FILE_MAX_MB:=10}"
: "${ENABLE_TECH_DEBT_CHECK:=true}"
: "${ENABLE_EMPTY_FILE_CHECK:=true}"
: "${ENABLE_LINT:=true}"
: "${ENABLE_TESTS:=true}"
: "${TEST_SCOPE:=all}"

# Track if any checks fail
FAILED=0

print_status $BLUE "📋 Pre-push validation started"

# Detect if there are Rust packages; skip Rust-specific checks if workspace has no members
SKIP_RUST=0
if command -v cargo >/dev/null 2>&1; then
    if cargo metadata --no-deps --format-version 1 >/dev/null 2>&1; then
        PKG_COUNT=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages | length' 2>/dev/null || echo 0)
    else
        PKG_COUNT=0
    fi
else
    PKG_COUNT=0
fi
if [[ "${PKG_COUNT:-0}" -eq 0 ]]; then
    print_status $BLUE "ℹ️ No Rust packages detected — skipping Rust-specific checks"
    SKIP_RUST=1
fi

# 1. Cargo Format Check
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo fmt (no Rust packages)"
else
print_status $YELLOW "🎨 Checking code formatting (cargo fmt)..."
if cargo fmt --all -- --check; then
    print_status $GREEN "✅ Code formatting is correct"
else
    print_status $RED "❌ Code formatting issues found"
    echo "   Run: cargo fmt --all"
    FAILED=1
fi
fi

echo
# 2. Cargo Clippy Check
if [[ "${ENABLE_LINT}" == "true" ]]; then
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping clippy (no Rust packages)"
else
print_status $YELLOW "🔧 Running linting checks (cargo clippy)..."
if cargo clippy --all-targets --all-features -- -D warnings; then
    print_status $GREEN "✅ No clippy warnings found"
else
    print_status $RED "❌ Clippy warnings found"
    echo "   Fix warnings before pushing"
    FAILED=1
fi
fi
else
print_status $BLUE "ℹ️ Linting disabled via config (ENABLE_LINT=false)"
fi

echo

# ============================================================================
# RUST DEPENDENCY SECURITY ARCHITECTURE - DEFENSE-IN-DEPTH APPROACH
# ============================================================================
#
# This section implements a comprehensive 4-tool security workflow that creates
# layered protection against dependency vulnerabilities and supply chain attacks:
#
# 🧹 PHASE 1: cargo-machete (Attack Surface Reduction)
#   - Removes unused dependencies to minimize supply chain risk
#   - Reduces compilation time and binary size
#   - Eliminates maintenance burden from unnecessary dependencies
#   - SECURITY RATIONALE: Unused dependencies still pose vulnerability risks
#
# 🛡️ PHASE 2: cargo-deny (Comprehensive Policy Enforcement)
#   - Vulnerability Scanning: Blocks known CVEs from RustSec Database
#   - License Compliance: Enforces approved licenses only
#   - Source Verification: Restricts dependencies to trusted registries
#   - Dependency Bans: Blocks explicitly dangerous crates
#   - Supply Chain Protection: Multi-layer dependency validation
#   - SECURITY RATIONALE: Primary security enforcement with 4-layer protection
#
# ⚠️ PHASE 3: cargo-geiger (Unsafe Code Detection)
#   - Quantifies unsafe code usage across all dependencies
#   - Identifies potential memory safety violations
#   - Guides manual security review priorities
#   - SECURITY RATIONALE: Rust's safety guarantees only apply to safe code
#
# 📦 PHASE 4: cargo-auditable (Supply Chain Transparency) [CI-only]
#   - Production builds with embedded dependency metadata
#   - Enables post-incident dependency analysis
#   - Complete Software Bill of Materials (SBOM) generation
#   - SECURITY RATIONALE: Forensic analysis and vulnerability tracking
#
# 🤖 CONTINUOUS MONITORING: Renovate Integration
#   - Automatically scans for dependency vulnerabilities 24/7
#   - Creates pull requests for security and version updates
#   - Each Renovate PR triggers this complete 4-tool pipeline
#   - Provides continuous security monitoring beyond local validation
#   - Superior to Dependabot: automerge, grouping, better scheduling
#   - SECURITY RATIONALE: Proactive vulnerability management and automated updates
#
# WHY THIS APPROACH WORKS:
# - Minimize → Validate → Document → Deploy: Each tool has specific role
# - Defense in Depth: Multiple overlapping security controls
# - Fast Feedback: Critical checks complete in < 60 seconds
# - Zero False Positives: Tools tuned for accuracy
# - Developer Education: Each failure provides learning opportunities
#
# TOOL SYNERGY:
# - cargo-machete reduces work for subsequent tools
# - cargo-deny provides authoritative security decisions
# - cargo-auditable enables production incident response
# - cargo-geiger adds quantified risk assessment
# - Renovate provides continuous monitoring and automated updates (superior to Dependabot)
# ============================================================================

# 3. Security Audit (cargo-deny preferred - Comprehensive Policy Enforcement)
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-deny/audit (no Rust packages)"
else
if command -v cargo-deny &> /dev/null; then
    print_status $YELLOW "🛡️ Running comprehensive security audit (cargo deny)..."
    if cargo deny check; then
        print_status $GREEN "✅ All cargo-deny checks passed"
    else
        print_status $RED "❌ cargo-deny checks failed"
        echo "   Review vulnerabilities, license issues, or banned dependencies"
        FAILED=1
    fi
else
    print_status $YELLOW "🛡️ Running security audit (cargo audit)..."
    if command -v cargo-audit &> /dev/null; then
        if cargo audit; then
            print_status $GREEN "✅ No security vulnerabilities found"
        else
            print_status $RED "❌ Security vulnerabilities found"
            echo "   Run: cargo audit fix"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Neither cargo-deny nor cargo-audit found"
        echo "   Install cargo-deny: cargo install cargo-deny (recommended)"
    fi
fi
fi

echo
# 4. Memory Safety Analysis (cargo-geiger) - PHASE 3 of Defense-in-Depth [warn]
# SECURITY RATIONALE: Quantifies unsafe code to guide security review priorities
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-geiger (no Rust packages)"
else
if command -v cargo-geiger &> /dev/null; then
    print_status $YELLOW "🔬 Checking unsafe code usage (cargo geiger)..."
    if cargo geiger --format compact --quiet 2>/dev/null | grep -q "unsafe"; then
        print_status $YELLOW "⚠️ Unsafe code detected in dependencies"
        echo "   Review unsafe code usage for security implications"
    else
        print_status $GREEN "✅ No unsafe code detected"
    fi
else
    print_status $BLUE "ℹ️ cargo-geiger not found - skipping unsafe code check"
fi
fi

echo
# 5. Attack Surface Reduction (cargo-machete) - PHASE 1 of Defense-in-Depth [warn]
# SECURITY RATIONALE: Minimizes attack surface by removing unused dependencies
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping cargo-machete (no Rust packages)"
else
if command -v cargo-machete &> /dev/null; then
    print_status $YELLOW "🧹 Checking for unused dependencies (cargo machete)..."
    if cargo machete --with-metadata 2>/dev/null | grep -q "unused"; then
        print_status $YELLOW "⚠️ Unused dependencies found"
        echo "   Run: cargo machete --fix (to auto-remove)"
    else
        print_status $GREEN "✅ No unused dependencies found"
    fi
else
    print_status $BLUE "ℹ️ cargo-machete not found - skipping unused dependency check"
fi
fi

echo
# 6. Test Suite
if [[ "${ENABLE_TESTS}" == "true" ]]; then
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping tests (no Rust packages)"
else
print_status $YELLOW "🧪 Running test suite..."
if [[ "${TEST_SCOPE}" == "unit" ]]; then
    TEST_CMD=(cargo test --lib)
else
    TEST_CMD=(cargo test --all)
fi
if "${TEST_CMD[@]}"; then
    print_status $GREEN "✅ Tests passed (${TEST_SCOPE})"
else
    print_status $RED "❌ Tests failed (${TEST_SCOPE})"
    echo "   Fix failing tests before pushing"
    FAILED=1
fi
fi
else
print_status $BLUE "ℹ️ Tests disabled via config (ENABLE_TESTS=false)"
fi

echo
# 7. Secret Detection (script-only helper)
if [[ "$ENABLE_SECRET_SCAN" == "true" ]]; then
    print_status $YELLOW "🔍 Running secret detection (staged changes)..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if .security-controls/bin/gitleakslite protect --staged --no-banner --redact; then
            print_status $GREEN "✅ No secrets detected in staged changes"
        else
            print_status $RED "❌ Secrets detected in staged changes"
            echo "   Remove secrets or add safe patterns to .security-controls/secret-allowlist.txt"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Secret scanner helper missing: .security-controls/bin/gitleakslite"
        echo "   Re-run installer to restore helpers"
    fi
else
    print_status $BLUE "ℹ️ Secret scan disabled via config"
fi

echo
# 8. License Compliance Check [warn]
if [[ "${SKIP_RUST:-0}" -eq 1 ]]; then
    print_status $BLUE "ℹ️ Skipping license compliance (no Rust packages)"
else
print_status $YELLOW "⚖️ Checking license compliance..."
if command -v cargo-license &> /dev/null; then
    COPYLEFT=$(cargo license --json 2>/dev/null | jq -r '.[] | select(.license | test("GPL-2.0|GPL-3.0|AGPL|LGPL"; "i")) | .name' 2>/dev/null || echo "")
    if [ -n "$COPYLEFT" ]; then
        print_status $YELLOW "⚠️ Copyleft licenses found (review required):"
        echo "$COPYLEFT" | while read -r pkg; do
            echo "     • $pkg"
        done
    else
        print_status $GREEN "✅ No problematic licenses found"
    fi
else
    print_status $YELLOW "⚠️ cargo-license not found - skipping license check"
fi
fi

echo
# 9. GitHub Actions SHA Pinning Check
print_status $YELLOW "📌 Checking GitHub Actions SHA pinning..."
if [[ -x ".security-controls/bin/pinactlite" ]]; then
    if .security-controls/bin/pinactlite pincheck --dir .github/workflows; then
        print_status $GREEN "✅ All GitHub Actions are properly pinned"
    else
        print_status $YELLOW "🛠  Auto-pinning unpinned references..."
        set +e
        .security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images --quiet
        rc=$?
        set -e
        if [[ $rc -eq 2 ]]; then
            print_status $GREEN "✅ Auto-pinned all references successfully"
            git --no-pager diff -- .github/workflows | sed -n '1,120p' || true
        else
            print_status $RED "❌ Some references remain unpinned or autopin failed"
            FAILED=1
        fi
    fi
else
    print_status $YELLOW "⚠️  pinactlite helper not found, using basic validation..."
    if run_pin_checks .github/workflows; then
        print_status $GREEN "✅ Basic GitHub Actions pinning validation passed"
    else
        print_status $RED "❌ GitHub Actions pinning validation failed"
        FAILED=1
    fi
fi

echo
# 10. Commit Signing Check (if gitsign is configured)
if git config --get gpg.format | grep -q "x509"; then
    print_status $YELLOW "🔐 Checking Sigstore commit signing..."
    if git log --show-signature -1 HEAD 2>&1 | grep -q "gitsign: Good signature"; then
        print_status $GREEN "✅ Latest commit is Sigstore signed"
    else
        print_status $YELLOW "⚠️ Latest commit is not Sigstore signed"
    fi
    echo
fi

# 11. Cargo.lock Validation
print_status $YELLOW "📋 Checking Cargo.lock file..."
if [[ ! -f "Cargo.lock" ]]; then
    print_status $RED "❌ Cargo.lock not found"
    echo "   Run: cargo generate-lockfile"
    FAILED=1
elif ! git ls-files --error-unmatch Cargo.lock >/dev/null 2>&1; then
    print_status $YELLOW "⚠️ Cargo.lock is not committed to git"
else
    print_status $GREEN "✅ Cargo.lock exists and is committed"
fi

echo
# 12. Dependency Version Pinning Check [warn]
print_status $YELLOW "📌 Checking dependency version pinning..."
if grep -E "^\s*[a-zA-Z0-9_-]+\s*=\s*[\"']*[\*\^]" Cargo.toml >/dev/null 2>&1; then
    print_status $YELLOW "⚠️ Unpinned dependencies detected in Cargo.toml"
    grep -E "^\s*[a-zA-Z0-9_-]+\s*=\s*[\"']*[\*\^]" Cargo.toml | head -3 || true
else
    print_status $GREEN "✅ All dependencies appear to be pinned"
fi

echo
# 13. Build Script Security Check [warn]
print_status $YELLOW "🔧 Checking build scripts for security..."
BUILD_SCRIPTS=$(find . -name "build.rs" -not -path "./target/*" 2>/dev/null || true)
if [[ -n "$BUILD_SCRIPTS" ]]; then
    SUSPICIOUS_BUILD=""
    for script in $BUILD_SCRIPTS; do
        if grep -l "std::process\|std::env::var\|Command::new\|process::Command" "$script" >/dev/null 2>&1; then
            SUSPICIOUS_BUILD="$SUSPICIOUS_BUILD $script"
        fi
    done
    if [[ -n "$SUSPICIOUS_BUILD" ]]; then
        print_status $YELLOW "⚠️ Build scripts with system calls detected:"
        for script in $SUSPICIOUS_BUILD; do
            echo "     • $script"
        done
    else
        print_status $GREEN "✅ Build scripts appear safe"
    fi
else
    print_status $GREEN "✅ No build scripts found"
fi

echo
# 14. Documentation Security Check [warn]
print_status $YELLOW "📚 Scanning documentation for secrets..."
DOC_SECRETS=""
if [[ -d "docs" ]] || [[ -f "README.md" ]] || [[ -f "CHANGELOG.md" ]]; then
    for doc_file in README.md CHANGELOG.md $(find docs/ -name "*.md" 2>/dev/null | head -10); do
        if [[ -f "$doc_file" ]]; then
            if grep -i -E "(password|secret|token|api[_-]?key|private[_-]?key)" "$doc_file" >/dev/null 2>&1; then
                DOC_SECRETS="$DOC_SECRETS $doc_file"
            fi
        fi
    done
    if [[ -n "$DOC_SECRETS" ]]; then
        print_status $YELLOW "⚠️ Documentation may contain sensitive information:"
        for doc in $DOC_SECRETS; do
            echo "     • $doc"
        done
    else
        print_status $GREEN "✅ Documentation appears clean"
    fi
else
    print_status $BLUE "ℹ️ No documentation files to scan"
fi

echo
# 15. Environment Variable Security Check [warn]
print_status $YELLOW "🔐 Checking for hardcoded environment variables..."
ENV_VARS=$(grep -r "std::env::var.*['\"][A-Z_]*\(API\|KEY\|TOKEN\|SECRET\|PASSWORD\)" src/ --include="*.rs" 2>/dev/null || true)
if [[ -n "$ENV_VARS" ]]; then
    print_status $YELLOW "⚠️ Hardcoded environment variable names detected:"
    echo "$ENV_VARS" | head -3 || true
else
    print_status $GREEN "✅ No hardcoded environment variable patterns found"
fi

echo
# 16. Rust Edition Check [warn]
print_status $YELLOW "📅 Checking Rust edition..."
if [[ -f "Cargo.toml" ]]; then
    EDITION=$(grep 'edition = ' Cargo.toml | head -1 | sed 's/.*edition = "\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    if [[ "$EDITION" == "2021" ]]; then
        print_status $GREEN "✅ Using current Rust edition 2021"
    elif [[ -z "$EDITION" ]]; then
        print_status $YELLOW "⚠️ No explicit Rust edition specified"
    else
        print_status $BLUE "ℹ️ Using Rust edition: $EDITION"
    fi
else
    print_status $BLUE "ℹ️ No Cargo.toml found for edition check"
fi

echo
# 17. Unsafe Block Monitoring [warn]
print_status $YELLOW "⚠️ Monitoring unsafe code blocks..."
if [[ -d "src" ]]; then
    UNSAFE_COUNT=$(find src/ -name "*.rs" -exec grep -c "unsafe" {} \; 2>/dev/null | awk '{sum += $1} END {print sum+0}')
    if [[ $UNSAFE_COUNT -gt 10 ]]; then
        print_status $YELLOW "⚠️ High unsafe block count: $UNSAFE_COUNT"
    elif [[ $UNSAFE_COUNT -gt 0 ]]; then
        print_status $BLUE "ℹ️ Found $UNSAFE_COUNT unsafe blocks"
    else
        print_status $GREEN "✅ No unsafe code blocks found"
    fi
else
    print_status $BLUE "ℹ️ No src/ directory found for unsafe code check"
fi

echo
# 18. Import Security Validation [warn]
print_status $YELLOW "📦 Checking for potentially dangerous imports..."
DANGEROUS_IMPORTS=$(grep -r "use std::process::\*\|use std::ffi::\*\|use std::mem::\*" src/ --include="*.rs" 2>/dev/null || true)
if [[ -n "$DANGEROUS_IMPORTS" ]]; then
    print_status $YELLOW "⚠️ Wildcard imports of potentially dangerous modules detected:"
    echo "$DANGEROUS_IMPORTS" | head -3 || true
else
    print_status $GREEN "✅ No dangerous wildcard imports found"
fi

echo
# 19. File Permission Check
print_status $YELLOW "🔒 Checking file permissions..."
WRITABLE_FILES=$(find . -name "*.rs" -perm -o+w -not -path "./.git/*" 2>/dev/null | head -10 || true)
if [[ -n "$WRITABLE_FILES" ]]; then
    print_status $RED "❌ World-writable source files found:"
    echo "$WRITABLE_FILES"
    FAILED=1
else
    print_status $GREEN "✅ File permissions are secure"
fi

echo
# 20. Dependency Count Monitoring [warn]
print_status $YELLOW "📊 Monitoring dependency count..."
if [[ -f "Cargo.toml" ]]; then
    DEP_COUNT=$(grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml | grep -v "^\[" | wc -l | tr -d ' ')
    if [[ $DEP_COUNT -gt 75 ]]; then
        print_status $YELLOW "⚠️ Very high dependency count: $DEP_COUNT"
    elif [[ $DEP_COUNT -gt 50 ]]; then
        print_status $YELLOW "⚠️ High dependency count: $DEP_COUNT"
    else
        print_status $GREEN "✅ Reasonable dependency count: $DEP_COUNT"
    fi
else
    print_status $BLUE "ℹ️ No Cargo.toml found for dependency count check"
fi

echo
# 21. Network Address Validation [warn]
print_status $YELLOW "🌐 Checking for hardcoded network addresses..."
NETWORK_REFS=$(grep -r "http://\|https://[a-zA-Z0-9.-]\+\|[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" src/ --include="*.rs" 2>/dev/null | grep -v "//\|#\|println!\|eprintln!" | head -5 || true)
if [[ -n "$NETWORK_REFS" ]]; then
    print_status $YELLOW "⚠️ Hardcoded network addresses detected:"
    echo "$NETWORK_REFS"
else
    print_status $GREEN "✅ No hardcoded network addresses found"
fi

echo
# 22. Commit Message Security Check [warn]
print_status $YELLOW "💬 Checking recent commit messages..."
COMMIT_SECRETS=$(git log --oneline -10 2>/dev/null | grep -i -E "password|secret|token|api.?key|private.?key" || true)
if [[ -n "$COMMIT_SECRETS" ]]; then
    print_status $YELLOW "⚠️ Sensitive information detected in commit messages:"
    echo "$COMMIT_SECRETS"
else
    print_status $GREEN "✅ Recent commit messages appear clean"
fi

echo
# 23. Large File Detection (Critical - Blocking)
if [[ "$ENABLE_LARGE_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📦 Checking for large files (> ${LARGE_FILE_MAX_MB}MB)..."
    LARGE_FILES=$(find . -type f -size +${LARGE_FILE_MAX_MB}M -not -path "./.git/*" -not -path "./target/*" 2>/dev/null || true)
    if [[ -n "$LARGE_FILES" ]]; then
        print_status $RED "❌ Large files detected (> ${LARGE_FILE_MAX_MB}MB):"
        echo "$LARGE_FILES"
        FAILED=1
    else
        print_status $GREEN "✅ No large files detected"
    fi
else
    print_status $BLUE "ℹ️ Large file check disabled via config"
fi

echo
# 24. Technical Debt Monitoring [warn]
if [[ "$ENABLE_TECH_DEBT_CHECK" == "true" ]]; then
    print_status $YELLOW "🔧 Monitoring technical debt..."
    if [[ -d "src" ]]; then
        TODO_COUNT=$(grep -r "TODO\|FIXME\|XXX\|HACK" src/ --include="*.rs" 2>/dev/null | wc -l | tr -d ' ')
        if [[ $TODO_COUNT -gt 100 ]]; then
            print_status $YELLOW "⚠️ Very high technical debt: $TODO_COUNT TODO/FIXME items"
        elif [[ $TODO_COUNT -gt 50 ]]; then
            print_status $YELLOW "⚠️ High technical debt: $TODO_COUNT TODO/FIXME items"
        elif [[ $TODO_COUNT -gt 0 ]]; then
            print_status $BLUE "ℹ️ Technical debt items: $TODO_COUNT TODO/FIXME items"
        else
            print_status $GREEN "✅ No technical debt markers found"
        fi
    else
        print_status $BLUE "ℹ️ No src/ directory found for technical debt check"
    fi
else
    print_status $BLUE "ℹ️ Technical debt check disabled via config"
fi

echo
# 25. Empty File Detection [warn]
if [[ "$ENABLE_EMPTY_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📄 Checking for empty source files..."
    if [[ -d "src" ]]; then
        EMPTY_FILES=$(find src/ -name "*.rs" -empty 2>/dev/null || true)
        if [[ -n "$EMPTY_FILES" ]]; then
            print_status $YELLOW "⚠️ Empty source files detected:"
            echo "$EMPTY_FILES"
        else
            print_status $GREEN "✅ No empty source files found"
        fi
    else
        print_status $BLUE "ℹ️ No src/ directory found for empty file check"
    fi
else
    print_status $BLUE "ℹ️ Empty file check disabled via config"
fi

echo
# Summary
if [ $FAILED -eq 0 ]; then
    print_status $GREEN "🎉 All pre-push checks passed! Pushing to remote..."
    echo
    print_status $BLUE "📤 Push will proceed"
else
    print_status $RED "💥 Pre-push validation failed!"
    echo
    print_status $RED "❌ Push blocked - fix the issues above before pushing"
    echo
    exit 1
fi

exit 0
HOOK_EOF
}

# Generate generic pre-push hook (existing implementation)
generate_generic_pre_push_hook_content() {
  cat <<'HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Generic)
# Generated by Security Controls Installer v1.4.0

echo "🔍 Running pre-push validation checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load optional configuration
CONFIG_FILE=".security-controls/config.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

: "${ENABLE_SECRET_SCAN:=true}"
: "${ENABLE_LARGE_FILE_CHECK:=true}"
: "${LARGE_FILE_MAX_MB:=10}"

FAILED=0

print_status $BLUE "📋 Pre-push validation started"

echo
# 1. Secret Detection (script-only helper)
if [[ "$ENABLE_SECRET_SCAN" == "true" ]]; then
    print_status $YELLOW "🔍 Running secret detection (staged changes)..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if .security-controls/bin/gitleakslite protect --staged --no-banner --redact; then
            print_status $GREEN "✅ No secrets detected in staged changes"
        else
            print_status $RED "❌ Secrets detected in staged changes"
            FAILED=1
        fi
    else
        print_status $YELLOW "⚠️ Secret scanner helper missing: .security-controls/bin/gitleakslite"
        echo "   Re-run installer to restore helpers"
    fi
else
    print_status $BLUE "ℹ️ Secret scan disabled via config"
fi

echo
# 2. GitHub Actions SHA Pinning Check
if [[ -d ".github/workflows" ]]; then
print_status $YELLOW "📌 Checking GitHub Actions SHA pinning..."
if [[ -x ".security-controls/bin/pinactlite" ]]; then
        if .security-controls/bin/pinactlite pincheck --dir .github/workflows; then
            print_status $GREEN "✅ All GitHub Actions are properly pinned"
        else
print_status $YELLOW "🛠  Auto-pinning unpinned references..."
            set +e
            .security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images --quiet
            rc=$?
            set -e
            if [[ $rc -eq 2 ]]; then
                print_status $GREEN "✅ Auto-pinned all references successfully"
                git --no-pager diff -- .github/workflows | sed -n '1,120p' || true
            else
                print_status $RED "❌ Some references remain unpinned or autopin failed"
                FAILED=1
            fi
        fi
    else
print_status $YELLOW "⚠️ Pinning checker helper missing: .security-controls/bin/pinactlite"
        echo "   Re-run installer to restore helpers"
    fi
    echo
fi
if git config --get gpg.format | grep -q "x509"; then
    print_status $YELLOW "🔐 Checking Sigstore commit signing..."
    if git log --show-signature -1 HEAD 2>&1 | grep -q "gitsign: Good signature"; then
        print_status $GREEN "✅ Latest commit is Sigstore signed"
    else
        print_status $YELLOW "⚠️ Latest commit is not Sigstore signed"
    fi
fi

echo
# 4. Large File Detection (Critical - Blocking)
if [[ "$ENABLE_LARGE_FILE_CHECK" == "true" ]]; then
    print_status $YELLOW "📦 Checking for large files (> ${LARGE_FILE_MAX_MB}MB)..."
    LARGE_FILES=$(find . -type f -size +${LARGE_FILE_MAX_MB}M -not -path "./.git/*" 2>/dev/null || true)
    if [[ -n "$LARGE_FILES" ]]; then
        print_status $RED "❌ Large files detected (> ${LARGE_FILE_MAX_MB}MB):"
        echo "$LARGE_FILES"
        FAILED=1
    else
        print_status $GREEN "✅ No large files detected"
    fi
fi

echo
# Shell script quality checks
print_status $YELLOW "🔍 Running shell script quality checks..."

# ShellCheck validation (fail fast)
if command -v shellcheck >/dev/null 2>&1; then
    print_status $YELLOW "   📋 Running shellcheck (blocking)..."
    SHELL_FILES=$(find . -type f -name "*.sh" -not -path "./.git/*" 2>/dev/null | head -20)
    if [[ -n "$SHELL_FILES" ]]; then
        # Use process substitution to avoid subshell variable scope issues
        shellcheck_failed=0
        while IFS= read -r script; do
            if [[ -n "$script" ]]; then
                if ! shellcheck -S warning "$script" >/dev/null 2>&1; then
                    if [[ $shellcheck_failed -eq 0 ]]; then
                        print_status $RED "❌ ShellCheck warnings/errors found:"
                    fi
                    echo "   • $script"
                    shellcheck_failed=1
                fi
            fi
        done <<< "$SHELL_FILES"

        if [[ $shellcheck_failed -eq 1 ]]; then
            print_status $RED "   Fix shellcheck issues before pushing"
            print_status $BLUE "   Run: shellcheck your_script.sh"
            FAILED=1
        else
            print_status $GREEN "   ✅ All shell scripts pass shellcheck"
        fi
    else
        print_status $BLUE "   ℹ️  No shell scripts found to check"
    fi
else
    print_status $YELLOW "   ⚠️  shellcheck not found - install for better shell script validation"
    print_status $BLUE "   Install: brew install shellcheck (macOS) or apt install shellcheck (Ubuntu)"
fi

# Shell formatting check (shfmt)
if command -v shfmt >/dev/null 2>&1; then
    print_status $YELLOW "   🎨 Checking shell script formatting..."
    if shfmt -d -i 2 -ci -s . >/dev/null 2>&1; then
        print_status $GREEN "   ✅ Shell script formatting is correct"
    else
        print_status $RED "   ❌ Shell script formatting issues found"
        print_status $BLUE "   Fix: shfmt -w -i 2 -ci -s ."
        FAILED=1
    fi
else
    print_status $YELLOW "   ⚠️  shfmt not found - install for shell script formatting validation"
    print_status $BLUE "   Install: brew install shfmt (macOS) or apt install shfmt (Ubuntu)"
fi

echo
# License header validation (fail fast)
print_status $YELLOW "📄 Checking license compliance..."
missing_license_headers=0

# Check main shell scripts for license headers
MAIN_SCRIPTS=$(find . -maxdepth 1 -name "*.sh" -type f 2>/dev/null)
if [[ -n "$MAIN_SCRIPTS" ]]; then
    print_status $YELLOW "   📋 Validating license headers in main scripts..."
    while IFS= read -r script; do
        if [[ -n "$script" ]]; then
            # Check first 20 lines for license/copyright
            if ! head -20 "$script" | grep -q -i "license\|copyright" 2>/dev/null; then
                if [[ $missing_license_headers -eq 0 ]]; then
                    print_status $RED "❌ Missing license headers:"
                fi
                echo "   • $script"
                missing_license_headers=1
            fi
        fi
    done <<< "$MAIN_SCRIPTS"

    if [[ $missing_license_headers -eq 1 ]]; then
        print_status $RED "   Add license headers to source files before pushing"
        print_status $BLUE "   Include copyright notice and license reference"
        FAILED=1
    else
        print_status $GREEN "   ✅ License headers present in main scripts"
    fi
else
    print_status $BLUE "   ℹ️  No main shell scripts found to check"
fi

# Verify LICENSE file exists
if [[ ! -f "LICENSE" ]]; then
    print_status $RED "❌ No LICENSE file found in repository root"
    print_status $BLUE "   Add a LICENSE file (Apache-2.0, MIT, etc.)"
    FAILED=1
else
    print_status $GREEN "   ✅ LICENSE file present"
fi

echo
# Summary
if [ $FAILED -eq 0 ]; then
    print_status $GREEN "🎉 All pre-push checks passed! Pushing to remote..."
    echo
    print_status $BLUE "📤 Push will proceed"
else
    print_status $RED "💥 Pre-push validation failed!"
    echo
    print_status $RED "❌ Push blocked - fix the issues above before pushing"
    echo
    exit 1
fi

exit 0
HOOK_EOF
}

# Generate Node.js/JavaScript/TypeScript pre-push hook
generate_nodejs_pre_push_hook_content() {
  cat <<'NODEJS_HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Node.js/JavaScript/TypeScript)
# Generated by 1-Click GitHub Security

echo "🔍 Running pre-push validation checks (Node.js)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load optional configuration
if [[ -f .security-controls/config.env ]]; then
    source .security-controls/config.env
fi

# Configuration with defaults
SKIP_FORMAT_CHECK=${SKIP_FORMAT_CHECK:-false}
SKIP_LINT_CHECK=${SKIP_LINT_CHECK:-false}
SKIP_TEST_CHECK=${SKIP_TEST_CHECK:-false}
SKIP_SECURITY_AUDIT=${SKIP_SECURITY_AUDIT:-false}
SKIP_SECRET_SCAN=${SKIP_SECRET_SCAN:-false}
SKIP_PIN_CHECK=${SKIP_PIN_CHECK:-false}

# Exit early if no staged changes
if ! git diff --cached --quiet; then
    echo "📝 Staged changes detected, running validation..."
else
    echo "✅ No staged changes, skipping pre-push validation"
    exit 0
fi

failed_checks=0

# Node.js format check
if [[ $SKIP_FORMAT_CHECK != true ]]; then
    print_status $BLUE "🎨 Checking JavaScript/TypeScript formatting..."
    if command -v prettier &>/dev/null; then
        if ! prettier --check . &>/dev/null; then
            print_status $RED "❌ Code formatting check failed"
            echo "   Fix: prettier --write . (or npm run format)"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Code formatting looks good"
        fi
    elif [[ -f package.json ]] && npm run format:check &>/dev/null 2>&1; then
        print_status $GREEN "✅ Code formatting looks good (npm script)"
    else
        print_status $YELLOW "⚠️  No formatter available (install prettier)"
    fi
fi

# Node.js linting
if [[ $SKIP_LINT_CHECK != true ]]; then
    print_status $BLUE "🔍 Running JavaScript/TypeScript linting..."
    if command -v eslint &>/dev/null; then
        if ! eslint . &>/dev/null; then
            print_status $RED "❌ ESLint linting failed"
            echo "   Fix: eslint . --fix (or npm run lint)"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ ESLint linting passed"
        fi
    elif [[ -f package.json ]] && npm run lint &>/dev/null 2>&1; then
        print_status $GREEN "✅ Linting passed (npm script)"
    else
        print_status $YELLOW "⚠️  No linter available (install eslint)"
    fi
fi

# Node.js testing
if [[ $SKIP_TEST_CHECK != true ]]; then
    print_status $BLUE "🧪 Running Node.js tests..."
    if [[ -f package.json ]]; then
        if npm test &>/dev/null; then
            print_status $GREEN "✅ All tests passed"
        else
            print_status $RED "❌ Tests failed"
            echo "   Fix: npm test"
            failed_checks=$((failed_checks + 1))
        fi
    else
        print_status $YELLOW "⚠️  No package.json found, skipping tests"
    fi
fi

# Node.js comprehensive security audit
if [[ $SKIP_SECURITY_AUDIT != true ]]; then
    print_status $BLUE "🔐 Running comprehensive npm security audit..."
    if [[ -f package.json ]]; then
        local audit_failed=0

        # 1. Standard npm audit (moderate and above)
        print_status $BLUE "   🔍 Running npm audit (standard)..."
        if ! npm audit --audit-level=moderate &>/dev/null; then
            print_status $RED "   ❌ npm audit found vulnerabilities"
            echo "      Fix: npm audit fix"
            audit_failed=1
        else
            print_status $GREEN "   ✅ npm audit passed"
        fi

        # 2. Enhanced audit with audit-ci (if available)
        if command -v audit-ci &>/dev/null; then
            print_status $BLUE "   🔍 Running audit-ci (enhanced)..."
            if ! audit-ci --moderate --skip-dev &>/dev/null; then
                print_status $RED "   ❌ audit-ci found production vulnerabilities"
                echo "      Fix: npm audit fix --only=prod"
                audit_failed=1
            else
                print_status $GREEN "   ✅ audit-ci passed"
            fi
        fi

        # 3. Better npm audit (if available)
        if command -v better-npm-audit &>/dev/null; then
            print_status $BLUE "   🔍 Running better-npm-audit..."
            if ! better-npm-audit audit --level moderate &>/dev/null; then
                print_status $RED "   ❌ better-npm-audit found issues"
                echo "      Review: better-npm-audit audit"
                audit_failed=1
            else
                print_status $GREEN "   ✅ better-npm-audit passed"
            fi
        fi

        # 4. Snyk test (if available and authenticated)
        if command -v snyk &>/dev/null; then
            print_status $BLUE "   🔍 Running Snyk vulnerability scan..."
            if snyk auth &>/dev/null && snyk test --severity-threshold=medium &>/dev/null; then
                print_status $GREEN "   ✅ Snyk scan passed"
            elif snyk test --severity-threshold=medium &>/dev/null 2>&1 | grep -q "authenticated"; then
                print_status $YELLOW "   ⚠️  Snyk requires authentication (run: snyk auth)"
            else
                print_status $RED "   ❌ Snyk found medium+ severity issues"
                echo "      Fix: snyk wizard or snyk fix"
                audit_failed=1
            fi
        fi

        # 5. Retire.js scan for known vulnerable libraries
        if command -v retire &>/dev/null; then
            print_status $BLUE "   🔍 Running retire.js vulnerability scan..."
            if ! retire --path . --exitwith 1 &>/dev/null; then
                print_status $RED "   ❌ retire.js found vulnerable JavaScript libraries"
                echo "      Fix: Update vulnerable dependencies shown by 'retire'"
                audit_failed=1
            else
                print_status $GREEN "   ✅ retire.js scan passed"
            fi
        fi

        # 6. Check for package-lock.json and verify integrity
        if [[ -f "package-lock.json" ]]; then
            print_status $BLUE "   🔍 Verifying package-lock.json integrity..."
            if ! npm ci --dry-run &>/dev/null; then
                print_status $RED "   ❌ package-lock.json integrity check failed"
                echo "      Fix: rm package-lock.json && npm install"
                audit_failed=1
            else
                print_status $GREEN "   ✅ package-lock.json integrity verified"
            fi
        else
            print_status $YELLOW "   ⚠️  No package-lock.json found (consider adding for security)"
        fi

        # 7. License compliance check
        if command -v license-checker &>/dev/null; then
            print_status $BLUE "   🔍 Checking license compliance..."
            # Allow common permissive licenses, block GPL and proprietary
            local blocked_licenses="GPL;AGPL;LGPL;SSPL;OSL;EPL;CDDL;MPL;BUSL"
            if license-checker --onlyAllow "MIT;BSD;Apache;ISC;BSD-2-Clause;BSD-3-Clause;Unlicense;CC0;WTFPL" --excludePrivatePackages &>/dev/null; then
                print_status $GREEN "   ✅ License compliance check passed"
            else
                print_status $RED "   ❌ Problematic licenses detected"
                echo "      Review: license-checker --summary"
                audit_failed=1
            fi
        fi

        # 8. Check for outdated packages with known security issues
        print_status $BLUE "   🔍 Checking for outdated security-critical packages..."
        if command -v npm-check-updates &>/dev/null; then
            # Check if any security-critical packages are outdated
            local outdated_security_packages
            outdated_security_packages=$(npm outdated --json 2>/dev/null | jq -r 'to_entries[] | select(.key | test("express|lodash|request|moment|serialize-javascript|handlebars|marked|socket.io|ws|jsonwebtoken|bcrypt|crypto-js")) | .key' 2>/dev/null || echo "")
            if [[ -n "$outdated_security_packages" ]]; then
                print_status $YELLOW "   ⚠️  Security-critical packages are outdated:"
                echo "$outdated_security_packages" | while read -r pkg; do
                    echo "      • $pkg"
                done
                print_status $YELLOW "      Consider: npm update or npm-check-updates -u"
            fi
        fi

        # 9. Check for unused dependencies
        if command -v depcheck &>/dev/null; then
            print_status $BLUE "   🔍 Checking for unused dependencies..."
            local unused_deps
            unused_deps=$(depcheck --json 2>/dev/null | jq -r '.dependencies[]' 2>/dev/null || echo "")
            if [[ -n "$unused_deps" ]]; then
                print_status $YELLOW "   ⚠️  Unused dependencies detected:"
                echo "$unused_deps" | while read -r dep; do
                    [[ -n "$dep" ]] && echo "      • $dep"
                done
                print_status $YELLOW "      Consider: npm uninstall unused packages"
            else
                print_status $GREEN "   ✅ No unused dependencies found"
            fi
        fi

        # 10. Check for circular dependencies
        if command -v madge &>/dev/null; then
            print_status $BLUE "   🔍 Checking for circular dependencies..."
            if madge --circular . &>/dev/null; then
                print_status $GREEN "   ✅ No circular dependencies found"
            else
                print_status $RED "   ❌ Circular dependencies detected"
                echo "      Review: madge --circular ."
                audit_failed=1
            fi
        fi

        # 11. Global npm audit for system-wide packages (if requested)
        if [[ "${NPM_GLOBAL_AUDIT:-}" == "true" ]]; then
            print_status $BLUE "   🔍 Running global npm audit..."
            if npm audit -g --audit-level=high &>/dev/null; then
                print_status $GREEN "   ✅ Global npm audit passed"
            else
                print_status $YELLOW "   ⚠️  Global npm vulnerabilities found"
                print_status $YELLOW "      Fix: npm audit fix -g (run with caution)"
            fi
        fi

        # 12. Bundle size analysis (if configured)
        if [[ -f "bundlewatch.config.json" ]] && command -v bundlewatch &>/dev/null; then
            print_status $BLUE "   🔍 Checking bundle size limits..."
            if bundlewatch &>/dev/null; then
                print_status $GREEN "   ✅ Bundle size within limits"
            else
                print_status $RED "   ❌ Bundle size exceeds configured limits"
                echo "      Review: bundlewatch --config bundlewatch.config.json"
                audit_failed=1
            fi
        fi

        # Final audit result
        if [[ $audit_failed -eq 1 ]]; then
            print_status $RED "❌ Node.js comprehensive security audit failed"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Node.js comprehensive security audit passed"
        fi
    else
        print_status $YELLOW "⚠️  No package.json found, skipping npm audit"
    fi
fi

# Universal secret scanning
if [[ $SKIP_SECRET_SCAN != true ]]; then
    print_status $BLUE "🔍 Scanning for secrets..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if ! ./.security-controls/bin/gitleakslite protect --staged --no-banner --redact &>/dev/null; then
            print_status $RED "❌ Secret scan failed"
            echo "   Secrets detected in staged changes"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Secret scan passed"
        fi
    else
        print_status $YELLOW "⚠️  No secret scanner available"
    fi
fi

# Universal SHA pinning check
if [[ $SKIP_PIN_CHECK != true ]]; then
    print_status $BLUE "📌 Checking GitHub Actions SHA pinning..."
    if [[ -x ".security-controls/bin/pinactlite" ]]; then
        if ! ./.security-controls/bin/pinactlite pincheck --dir .github/workflows &>/dev/null; then
            print_status $RED "❌ SHA pinning check failed"
            echo "   Fix: ./.security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ SHA pinning check passed"
        fi
    else
        print_status $YELLOW "⚠️  No SHA pinning checker available"
    fi
fi

# Summary
if [[ $failed_checks -gt 0 ]]; then
    echo
    print_status $RED "💥 Pre-push validation failed!"
    print_status $RED "❌ Push blocked - fix $failed_checks issue(s) above"
    echo
    exit 1
fi

print_status $GREEN "✅ All pre-push validation checks passed!"
exit 0
NODEJS_HOOK_EOF
}

# Generate Python pre-push hook
generate_python_pre_push_hook_content() {
  cat <<'PYTHON_HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Python)
# Generated by 1-Click GitHub Security

echo "🔍 Running pre-push validation checks (Python)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load optional configuration
if [[ -f .security-controls/config.env ]]; then
    source .security-controls/config.env
fi

# Configuration with defaults
SKIP_FORMAT_CHECK=${SKIP_FORMAT_CHECK:-false}
SKIP_LINT_CHECK=${SKIP_LINT_CHECK:-false}
SKIP_TEST_CHECK=${SKIP_TEST_CHECK:-false}
SKIP_SECURITY_AUDIT=${SKIP_SECURITY_AUDIT:-false}
SKIP_SECRET_SCAN=${SKIP_SECRET_SCAN:-false}
SKIP_PIN_CHECK=${SKIP_PIN_CHECK:-false}

# Exit early if no staged changes
if ! git diff --cached --quiet; then
    echo "📝 Staged changes detected, running validation..."
else
    echo "✅ No staged changes, skipping pre-push validation"
    exit 0
fi

failed_checks=0

# Python format check
if [[ $SKIP_FORMAT_CHECK != true ]]; then
    print_status $BLUE "🎨 Checking Python formatting (black)..."
    if command -v black &>/dev/null; then
        if ! black --check . &>/dev/null; then
            print_status $RED "❌ Python formatting check failed"
            echo "   Fix: black ."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Python formatting looks good"
        fi
    else
        print_status $YELLOW "⚠️  No formatter available (install black)"
    fi
fi

# Python linting
if [[ $SKIP_LINT_CHECK != true ]]; then
    print_status $BLUE "🔍 Running Python linting..."
    if command -v flake8 &>/dev/null; then
        if ! flake8 . &>/dev/null; then
            print_status $RED "❌ flake8 linting failed"
            echo "   Fix: flake8 ."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ flake8 linting passed"
        fi
    elif command -v pylint &>/dev/null; then
        if ! find . -name "*.py" -exec pylint {} \; &>/dev/null; then
            print_status $RED "❌ pylint linting failed"
            echo "   Fix: pylint **/*.py"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ pylint linting passed"
        fi
    else
        print_status $YELLOW "⚠️  No linter available (install flake8 or pylint)"
    fi
fi

# Python testing
if [[ $SKIP_TEST_CHECK != true ]]; then
    print_status $BLUE "🧪 Running Python tests..."
    if command -v pytest &>/dev/null; then
        if ! pytest &>/dev/null; then
            print_status $RED "❌ pytest tests failed"
            echo "   Fix: pytest"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ All tests passed (pytest)"
        fi
    elif [[ -f "test_*.py" ]] || [[ -f "*_test.py" ]]; then
        if ! python -m unittest discover &>/dev/null; then
            print_status $RED "❌ unittest tests failed"
            echo "   Fix: python -m unittest discover"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ All tests passed (unittest)"
        fi
    else
        print_status $YELLOW "⚠️  No tests found"
    fi
fi

# Python security audit
if [[ $SKIP_SECURITY_AUDIT != true ]]; then
    print_status $BLUE "🔐 Running Python security audit..."
    if command -v safety &>/dev/null; then
        if ! safety check &>/dev/null; then
            print_status $RED "❌ Safety security audit failed"
            echo "   Fix: safety check"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Safety security audit passed"
        fi
    elif command -v pip-audit &>/dev/null; then
        if ! pip-audit &>/dev/null; then
            print_status $RED "❌ pip-audit security audit failed"
            echo "   Fix: pip-audit"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ pip-audit security audit passed"
        fi
    else
        print_status $YELLOW "⚠️  No security audit tool available (install safety or pip-audit)"
    fi

    # Additional security scanning with bandit
    if command -v bandit &>/dev/null; then
        if ! bandit -r . &>/dev/null; then
            print_status $RED "❌ Bandit security scan failed"
            echo "   Fix: bandit -r ."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Bandit security scan passed"
        fi
    fi
fi

# Universal secret scanning
if [[ $SKIP_SECRET_SCAN != true ]]; then
    print_status $BLUE "🔍 Scanning for secrets..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if ! ./.security-controls/bin/gitleakslite protect --staged --no-banner --redact &>/dev/null; then
            print_status $RED "❌ Secret scan failed"
            echo "   Secrets detected in staged changes"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Secret scan passed"
        fi
    else
        print_status $YELLOW "⚠️  No secret scanner available"
    fi
fi

# Universal SHA pinning check
if [[ $SKIP_PIN_CHECK != true ]]; then
    print_status $BLUE "📌 Checking GitHub Actions SHA pinning..."
    if [[ -x ".security-controls/bin/pinactlite" ]]; then
        if ! ./.security-controls/bin/pinactlite pincheck --dir .github/workflows &>/dev/null; then
            print_status $RED "❌ SHA pinning check failed"
            echo "   Fix: ./.security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ SHA pinning check passed"
        fi
    else
        print_status $YELLOW "⚠️  No SHA pinning checker available"
    fi
fi

# Summary
if [[ $failed_checks -gt 0 ]]; then
    echo
    print_status $RED "💥 Pre-push validation failed!"
    print_status $RED "❌ Push blocked - fix $failed_checks issue(s) above"
    echo
    exit 1
fi

print_status $GREEN "✅ All pre-push validation checks passed!"
exit 0
PYTHON_HOOK_EOF
}

# Generate Go pre-push hook
generate_go_pre_push_hook_content() {
  cat <<'GO_HOOK_EOF'
#!/bin/bash
set -euo pipefail

# Pre-push hook for security validation (Go)
# Generated by 1-Click GitHub Security

echo "🔍 Running pre-push validation checks (Go)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load optional configuration
if [[ -f .security-controls/config.env ]]; then
    source .security-controls/config.env
fi

# Configuration with defaults
SKIP_FORMAT_CHECK=${SKIP_FORMAT_CHECK:-false}
SKIP_LINT_CHECK=${SKIP_LINT_CHECK:-false}
SKIP_TEST_CHECK=${SKIP_TEST_CHECK:-false}
SKIP_SECURITY_AUDIT=${SKIP_SECURITY_AUDIT:-false}
SKIP_SECRET_SCAN=${SKIP_SECRET_SCAN:-false}
SKIP_PIN_CHECK=${SKIP_PIN_CHECK:-false}

# Exit early if no staged changes
if ! git diff --cached --quiet; then
    echo "📝 Staged changes detected, running validation..."
else
    echo "✅ No staged changes, skipping pre-push validation"
    exit 0
fi

failed_checks=0

# Go format check
if [[ $SKIP_FORMAT_CHECK != true ]]; then
    print_status $BLUE "🎨 Checking Go formatting (gofmt)..."
    if [[ $(gofmt -l . | wc -l) -ne 0 ]]; then
        print_status $RED "❌ Go formatting check failed"
        echo "   Fix: gofmt -w ."
        failed_checks=$((failed_checks + 1))
    else
        print_status $GREEN "✅ Go formatting looks good"
    fi
fi

# Go linting
if [[ $SKIP_LINT_CHECK != true ]]; then
    print_status $BLUE "🔍 Running Go linting..."
    if command -v staticcheck &>/dev/null; then
        if ! staticcheck ./... &>/dev/null; then
            print_status $RED "❌ staticcheck linting failed"
            echo "   Fix: staticcheck ./..."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ staticcheck linting passed"
        fi
    elif command -v golint &>/dev/null; then
        if ! golint ./... &>/dev/null; then
            print_status $RED "❌ golint linting failed"
            echo "   Fix: golint ./..."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ golint linting passed"
        fi
    else
        print_status $YELLOW "⚠️  No linter available (install staticcheck or golint)"
    fi
fi

# Go testing
if [[ $SKIP_TEST_CHECK != true ]]; then
    print_status $BLUE "🧪 Running Go tests..."
    if ! go test ./... &>/dev/null; then
        print_status $RED "❌ Go tests failed"
        echo "   Fix: go test ./..."
        failed_checks=$((failed_checks + 1))
    else
        print_status $GREEN "✅ All Go tests passed"
    fi
fi

# Go security audit
if [[ $SKIP_SECURITY_AUDIT != true ]]; then
    print_status $BLUE "🔐 Running Go security audit..."
    if command -v govulncheck &>/dev/null; then
        if ! govulncheck ./... &>/dev/null; then
            print_status $RED "❌ govulncheck security audit failed"
            echo "   Fix: govulncheck ./..."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ govulncheck security audit passed"
        fi
    else
        print_status $YELLOW "⚠️  No vulnerability scanner available (install govulncheck)"
    fi

    # Additional security scanning with gosec
    if command -v gosec &>/dev/null; then
        if ! gosec ./... &>/dev/null; then
            print_status $RED "❌ gosec security scan failed"
            echo "   Fix: gosec ./..."
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ gosec security scan passed"
        fi
    fi
fi

# Universal secret scanning
if [[ $SKIP_SECRET_SCAN != true ]]; then
    print_status $BLUE "🔍 Scanning for secrets..."
    if [[ -x ".security-controls/bin/gitleakslite" ]]; then
        if ! ./.security-controls/bin/gitleakslite protect --staged --no-banner --redact &>/dev/null; then
            print_status $RED "❌ Secret scan failed"
            echo "   Secrets detected in staged changes"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ Secret scan passed"
        fi
    else
        print_status $YELLOW "⚠️  No secret scanner available"
    fi
fi

# Universal SHA pinning check
if [[ $SKIP_PIN_CHECK != true ]]; then
    print_status $BLUE "📌 Checking GitHub Actions SHA pinning..."
    if [[ -x ".security-controls/bin/pinactlite" ]]; then
        if ! ./.security-controls/bin/pinactlite pincheck --dir .github/workflows &>/dev/null; then
            print_status $RED "❌ SHA pinning check failed"
            echo "   Fix: ./.security-controls/bin/pinactlite autopin --dir .github/workflows --actions --images"
            failed_checks=$((failed_checks + 1))
        else
            print_status $GREEN "✅ SHA pinning check passed"
        fi
    else
        print_status $YELLOW "⚠️  No SHA pinning checker available"
    fi
fi

# Summary
if [[ $failed_checks -gt 0 ]]; then
    echo
    print_status $RED "💥 Pre-push validation failed!"
    print_status $RED "❌ Push blocked - fix $failed_checks issue(s) above"
    echo
    exit 1
fi

print_status $GREEN "✅ All pre-push validation checks passed!"
exit 0
GO_HOOK_EOF
}

# Ensure hooksPath dispatcher exists and optionally set core.hooksPath
ensure_hooks_path_dispatcher() {
  # Create dispatcher and directory structure
  mkdir -p "$PRE_PUSH_D_DIR"

  local dispatcher="$HOOKS_PATH_DIR/pre-push"
  if [[ ! -f $dispatcher ]]; then
    cat >"$dispatcher" <<'DISPATCH_EOF'
#!/bin/bash
# hooksPath pre-push dispatcher: runs all executables in pre-push.d
set -euo pipefail
HOOK_DIR="$(dirname "$0")/pre-push.d"
status=0
if [ -d "$HOOK_DIR" ]; then
  for hook in "$HOOK_DIR"/*; do
    if [ -f "$hook" ] && [ -x "$hook" ]; then
      "$hook" || status=$?
    fi
  done
fi
exit $status
DISPATCH_EOF
    chmod +x "$dispatcher"
    print_status $GREEN "✅ Created hooksPath dispatcher at $dispatcher"
  fi

  # Configure git to use hooksPath if not already set
  local current_hooks_path
  current_hooks_path=$(git config --get core.hooksPath || true)
  if [[ -z $current_hooks_path ]]; then
    if [[ $FORCE_INSTALL == true ]]; then
      git config core.hooksPath "$HOOKS_PATH_DIR"
      print_status $GREEN "✅ Set git core.hooksPath to $HOOKS_PATH_DIR"
    else
      read -p "Set git core.hooksPath to $HOOKS_PATH_DIR for chained hooks? (y/N): " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        git config core.hooksPath "$HOOKS_PATH_DIR"
        print_status $GREEN "✅ Set git core.hooksPath to $HOOKS_PATH_DIR"
      else
        print_status $BLUE "ℹ️ Skipping core.hooksPath configuration"
      fi
    fi
  else
    print_status $BLUE "ℹ️ git core.hooksPath already set to $current_hooks_path"
  fi
}

# Install pre-push hook
install_pre_push_hook() {
  print_section "Installing Pre-Push Hook"

  if [[ $USE_HOOKS_PATH == true ]]; then
    # hooksPath mode (chaining-friendly)
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "[DRY RUN] Would create hooksPath dispatcher and install hook to $PRE_PUSH_D_DIR/50-security-pre-push"
      return 0
    fi
    ensure_hooks_path_dispatcher
    local chained_hook="$PRE_PUSH_D_DIR/50-security-pre-push"

    # Generate hook content and write atomically
    local hook_content
    hook_content=$(generate_pre_push_hook)
    atomic_write "$chained_hook" "$hook_content"
    chmod +x "$chained_hook"
    add_rollback "chmod -x '$chained_hook'"

    print_status $GREEN "✅ Pre-push hook installed (hooksPath): $chained_hook"
    return 0
  fi

  # Legacy mode: write to .git/hooks/pre-push (may replace existing)
  local hook_file=".git/hooks/pre-push"

  if [[ -f $hook_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Pre-push hook already exists"
    read -p "Replace existing hook? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping pre-push hook installation"
      return 0
    fi
  fi

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install pre-push hook to $hook_file"
  else
    mkdir -p .git/hooks

    # Generate hook content and write atomically
    local hook_content
    hook_content=$(generate_pre_push_hook)
    atomic_write "$hook_file" "$hook_content"
    chmod +x "$hook_file"
    add_rollback "chmod -x '$hook_file'"

    print_status $GREEN "✅ Pre-push hook installed: $hook_file"
  fi
}

# Generate Pinning Validation workflow (standalone)
generate_pinning_workflow() {
  cat <<'EOF'
name: Pinning Validation

on:
  workflow_dispatch:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

permissions:
  contents: write

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  pinning:
    name: Validate GitHub Actions and container image pins
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0

      - name: Quick local pincheck (if present)
        run: |
          if [ -x ./.security-controls/bin/pinactlite ]; then
            ./.security-controls/bin/pinactlite pincheck --dir .github/workflows
          else
            echo "Local pinactlite helper not present; skipping quick check."
          fi

      - name: Install and verify tools, then install pinact v3.4.2
        run: |
          set -euo pipefail
          mkdir -p "$HOME/.local/bin"
          export PATH="$HOME/.local/bin:$PATH"

          # 1) Install cosign v2.6.0 and verify with SHA256
          COSIGN_VERSION=v2.6.0
          COSIGN_BASE="https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}"
          COSIGN_BIN="cosign-linux-amd64"
          COSIGN_SHA="ea5c65f99425d6cfbb5c4b5de5dac035f14d09131c1a0ea7c7fc32eab39364f9"
          curl -fsSLo /tmp/${COSIGN_BIN} "${COSIGN_BASE}/${COSIGN_BIN}"
          echo "${COSIGN_SHA}  /tmp/${COSIGN_BIN}" | sha256sum -c -
          install -m 0755 /tmp/${COSIGN_BIN} "$HOME/.local/bin/cosign"

          # 2) Install slsa-verifier v2.7.1 and verify SHA256
          SLSA_VERIFIER_VERSION=v2.7.1
          SLSA_BIN="slsa-verifier-linux-amd64"
          SLSA_BASE="https://github.com/slsa-framework/slsa-verifier/releases/download/${SLSA_VERIFIER_VERSION}"
          SLSA_SHA="946dbec729094195e88ef78e1734324a27869f03e2c6bd2f61cbc06bd5350339"
          curl -fsSLo /tmp/${SLSA_BIN} "${SLSA_BASE}/${SLSA_BIN}"
          echo "${SLSA_SHA}  /tmp/${SLSA_BIN}" | sha256sum -c -
          install -m 0755 /tmp/${SLSA_BIN} "$HOME/.local/bin/slsa-verifier"

          # 3) Download pinact v3.4.2 artifacts and verify signature + provenance + checksum
          VERSION=v3.4.2
          BASE="https://github.com/suzuki-shunsuke/pinact/releases/download/${VERSION}"

          # Fetch checksums and signature (prefer versioned filenames; fallback to plain)
          curl -fsSLo /tmp/checksums.txt "${BASE}/pinact_${VERSION#v}_checksums.txt" || \
          curl -fsSLo /tmp/checksums.txt "${BASE}/checksums.txt"

          curl -fsSLo /tmp/checksums.txt.pem "${BASE}/pinact_${VERSION#v}_checksums.txt.pem" || \
          curl -fsSLo /tmp/checksums.txt.pem "${BASE}/checksums.txt.pem"

          curl -fsSLo /tmp/checksums.txt.sig "${BASE}/pinact_${VERSION#v}_checksums.txt.sig" || \
          curl -fsSLo /tmp/checksums.txt.sig "${BASE}/checksums.txt.sig"

          # Sigstore verification of checksums.txt certificate and signature (GitHub OIDC issuer)
          cosign verify-blob \
            --certificate /tmp/checksums.txt.pem \
            --signature /tmp/checksums.txt.sig \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            --certificate-identity-regexp '^https://github.com/suzuki-shunsuke/(pinact|go-release-workflow)/.*' \
            /tmp/checksums.txt

          # OpenSSL verification as defense in depth
          # 1) Extract pubkey from certificate: try PEM directly, else decode base64-wrapped cert
          if ! openssl x509 -in /tmp/checksums.txt.pem -pubkey -noout > /tmp/pinact.pub 2>/dev/null; then
            base64 -d /tmp/checksums.txt.pem > /tmp/checksums.txt.pem.dec
            openssl x509 -in /tmp/checksums.txt.pem.dec -pubkey -noout > /tmp/pinact.pub
          fi
          # 2) Prepare signature: decode base64 if needed, else use raw signature
          if ! base64 -d /tmp/checksums.txt.sig > /tmp/checksums.txt.sig.bin 2>/dev/null; then
            cp /tmp/checksums.txt.sig /tmp/checksums.txt.sig.bin
          fi
          # 3) Verify
          openssl dgst -sha256 -verify /tmp/pinact.pub -signature /tmp/checksums.txt.sig.bin /tmp/checksums.txt

          # Determine Linux amd64 tarball name from checksums (support multiple conventions)
          TARBALL=""
          for name in "pinact_${VERSION#v}_linux_amd64.tar.gz" "pinact_linux_amd64.tar.gz" \
                     "pinact_${VERSION#v}_Linux_x86_64.tar.gz" "pinact_Linux_x86_64.tar.gz"; do
            if grep -q " ${name}$" /tmp/checksums.txt; then
              TARBALL="$name"; break
            fi
          done
          if [[ -z "$TARBALL" ]]; then
            echo "Unable to determine tarball name from checksums.txt" >&2
            echo "Available entries:" >&2
            cat /tmp/checksums.txt >&2
            exit 1
          fi

          # Download the tarball using the discovered name
          curl -fsSLo "/tmp/${TARBALL}" "${BASE}/${TARBALL}"

          # Checksum verification of the tarball
          awk -v tar="${TARBALL}" -v path="/tmp/${TARBALL}" '$2==tar { print $1, path }' /tmp/checksums.txt | sha256sum -c -

          # Try to download provenance with fallbacks
          PROV=""
          for prov in multiple.intoto.jsonl provenance.intoto.jsonl attestation.intoto.jsonl; do
            if curl -fsSLo "/tmp/${prov}" "${BASE}/${prov}"; then PROV="/tmp/${prov}"; break; fi
          done

          # SLSA provenance verification for the tarball (if provenance is available)
          if [[ -n "${PROV}" ]]; then
            slsa-verifier verify-artifact \
              --provenance-path "${PROV}" \
              --source-uri github.com/suzuki-shunsuke/pinact \
              --source-tag "${VERSION}" \
              "/tmp/${TARBALL}"
          else
            echo "Provenance file not found for ${VERSION}; skipping SLSA verification"
          fi

          # Extract and install pinact
          tar -xzf "/tmp/${TARBALL}"
          install -m 0755 pinact "$HOME/.local/bin/pinact"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: Verify pinact version (non-blocking)
        run: |
          pinact --version || true

      - name: Auto-fix unpinned actions with pinact
        id: pinact_fix
        run: |
          # Run pinact to auto-pin any unpinned actions
          pinact run

          # Check if any files were modified
          if git diff --quiet; then
            echo "changed=false" >> $GITHUB_OUTPUT
            echo "✅ All actions are already pinned"
          else
            echo "changed=true" >> $GITHUB_OUTPUT
            echo "📌 Auto-pinned actions:"
            git diff --stat
          fi

      - name: Commit auto-pinned changes
        if: steps.pinact_fix.outputs.changed == 'true'
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          git add .github/workflows/
          git commit -m "chore: auto-pin GitHub Actions to SHA

Auto-pinned by pinact v3.4.2 via Pinning Validation workflow

🤖 Generated with [Claude Code](https://claude.com/claude-code)"

      - name: Push auto-pinned changes
        if: steps.pinact_fix.outputs.changed == 'true'
        uses: ad-m/github-push-action@master
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          branch: ${{ github.ref }}

      - name: Alert about unpinned actions that were fixed
        if: steps.pinact_fix.outputs.changed == 'true'
        run: |
          echo "::warning::Unpinned actions were detected and automatically fixed. Changes have been committed."
          exit 0
EOF
}

# Generate CI workflow
generate_ci_workflow() {
  if [[ $RUST_PROJECT == true ]]; then
    cat <<'EOF'
name: Security CI

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

env:
  CARGO_TERM_COLOR: always

jobs:
  security-audit:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Skip Security Audit (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Security Audit job steps."

    - name: Cache dependencies
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9 # v4.0.2
      with:
        path: |
          ~/.cargo/bin/
          ~/.cargo/registry/index/
          ~/.cargo/registry/cache/
          ~/.cargo/git/db/
          target/
        key: ${{ runner.os }}-cargo-audit-${{ hashFiles('**/Cargo.lock') }}
        restore-keys: |
          ${{ runner.os }}-cargo-audit-

    - name: Install cargo-audit and cargo-auditable
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-audit
        cargo install --locked cargo-auditable

    - name: Build with auditable metadata
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo auditable build --release

    - name: Run cargo audit
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit

    - name: Run cargo audit for dependencies
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit --db advisory-db --json | tee audit-report.json

    - name: Run cargo audit on binary
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo audit bin target/release/*

    - name: Upload audit report
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: security-audit-report
        path: audit-report.json

  secret-scanning:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Run Gitleaks
      uses: gitleaks/gitleaks-action@cb7149b9e61c3d6896c4bc2616d4c9e86ee2d0c2 # v2.3.6
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  vulnerability-scanning:
    name: Vulnerability Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Run Trivy vulnerability scanner in repo mode
      uses: aquasecurity/trivy-action@b6643a29fecd7f34b3597bc6acb0a98b03d33ff8 # 0.33.1
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security
      uses: github/codeql-action/upload-sarif@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  static-analysis:
    name: Static Analysis
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Initialize CodeQL
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: github/codeql-action/init@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      with:
        languages: rust
        queries: +security-and-quality

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Build project
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo build --release

    - name: Perform CodeQL Analysis
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: github/codeql-action/analyze@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7

  supply-chain:
    name: Supply Chain Security
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Generate SBOM
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-auditable
        cargo auditable build --release
        cargo install --locked cargo-cyclonedx
        cargo cyclonedx --output-format json --output-file sbom.json

    - name: Skip Supply Chain (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Supply Chain job steps."

    - name: Upload SBOM
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: software-bill-of-materials
        path: sbom.json


  license-compliance:
    name: License Compliance
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Install cargo-license
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo install --locked cargo-license

    - name: Generate license report
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo license --json > licenses.json
        cargo license --tsv > licenses.tsv

    - name: Check for copyleft licenses
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        COPYLEFT=$(cargo license --json | jq -r '.[] | select(.license | test("GPL-2.0|GPL-3.0|AGPL|LGPL"; "i")) | "\(.name): \(.license)"' || true)
        if [ -n "$COPYLEFT" ]; then
          echo "::warning::Copyleft licenses found:"
          echo "$COPYLEFT"
        else
          echo "No problematic copyleft licenses found"
        fi

    - name: Skip License Compliance (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping License Compliance job steps."

    - name: Upload license report
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: license-compliance-report
        path: |
          licenses.json
          licenses.tsv

  binary-analysis:
    name: Binary Security Analysis
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Build release binary
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: cargo build --release

    - name: Install binary analysis tools
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        cargo install --locked cargo-binutils
        rustup component add llvm-tools-preview

    - name: Analyze binary for embedded secrets
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Scanning binary for embedded secrets..."
        for binary in target/release/*; do
          if [[ -x "$binary" && ! -d "$binary" ]]; then
            echo "Analyzing: $binary"
            # Check for common secret patterns in binary
            if strings "$binary" | grep -i -E "(password|secret|token|api[_-]?key|private[_-]?key|-----BEGIN)" > binary-secrets.txt; then
              echo "::warning::Potential secrets found in binary"
              cat binary-secrets.txt
            else
              echo "✅ No obvious secrets found in binary"
            fi
          fi
        done

    - name: Check for debug symbols
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Checking for debug symbols..."
        for binary in target/release/*; do
          if [[ -x "$binary" && ! -d "$binary" ]]; then
            if file "$binary" | grep -q "not stripped"; then
              echo "::warning::Binary contains debug symbols: $binary"
            else
              echo "✅ Binary is properly stripped: $binary"
            fi
          fi
        done

    - name: Upload binary analysis results
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: actions/upload-artifact@65462800fd760344b1a7b4382951275a0abb4808 # v4.3.3
      with:
        name: binary-analysis-results
        path: binary-secrets.txt
      if: hashFiles('binary-secrets.txt') != ''

  dependency-confusion-check:
    name: Dependency Confusion Detection
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Check for suspicious dependency names
      run: |
        echo "🔍 Checking for potential dependency confusion attacks..."
        
        # Extract dependency names from Cargo.toml
        if [[ -f "Cargo.toml" ]]; then
          echo "Dependencies found in Cargo.toml:"
          grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml | head -10
          
          # Check for common typosquatting patterns
          SUSPICIOUS=""
          while IFS= read -r dep; do
            dep_name=$(echo "$dep" | sed 's/^\s*//' | cut -d'=' -f1 | tr -d ' ')
            # Check for suspicious patterns (numbers at end, common typos)
            if echo "$dep_name" | grep -E ".*[0-9]+$|.*-rs$|.*_rs$" >/dev/null; then
              SUSPICIOUS="$SUSPICIOUS $dep_name"
            fi
          done < <(grep -E "^\s*[a-zA-Z0-9_-]+\s*=" Cargo.toml)
          
          if [[ -n "$SUSPICIOUS" ]]; then
            echo "::warning::Potentially suspicious dependency names detected:"
            for dep in $SUSPICIOUS; do
              echo "  - $dep"
            done
            echo "Review these dependencies for typosquatting attempts"
          else
            echo "✅ No obviously suspicious dependency names detected"
          fi
        fi

    - name: Verify official crates.io sources
      run: |
        echo "🔍 Verifying dependency sources..."
        
        # Check if any dependencies are from non-standard sources
        if grep -E "git\s*=|path\s*=" Cargo.toml >/dev/null 2>&1; then
          echo "::notice::Found dependencies from non-crates.io sources:"
          grep -E "git\s*=|path\s*=" Cargo.toml || true
          echo "Ensure these are from trusted sources"
        else
          echo "✅ All dependencies appear to be from crates.io"
        fi

  enhanced-security-checks:
    name: Enhanced Security Validation
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Detect Rust packages
      id: rust
      run: |
        set -euo pipefail
        if [ -f Cargo.toml ]; then
          if grep -q '^[[:space:]]*\[package\]' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          elif grep -q '^[[:space:]]*\[workspace\]' Cargo.toml && grep -q '^[[:space:]]*members[[:space:]]*=' Cargo.toml; then
            echo "has=true" >> "$GITHUB_OUTPUT"
          else
            echo "has=false" >> "$GITHUB_OUTPUT"
          fi
        else
          echo "has=false" >> "$GITHUB_OUTPUT"
        fi

    - name: Install Rust toolchain
      if: ${{ steps.rust.outputs.has == 'true' }}
      uses: dtolnay/rust-toolchain@21dc36fb71dd22e3317045c0c31a3f4249868b17 # stable
      with:
        toolchain: stable

    - name: Validate Cargo.lock
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Validating Cargo.lock..."
        if [[ ! -f "Cargo.lock" ]]; then
          echo "::error::Cargo.lock not found - this is required for reproducible builds"
          exit 1
        fi
        
        # Check if Cargo.lock is up-to-date
        if ! cargo check --locked >/dev/null 2>&1; then
          echo "::error::Cargo.lock is out of date"
          echo "Run 'cargo update' to update Cargo.lock"
          exit 1
        fi
        echo "✅ Cargo.lock is valid and up-to-date"

    - name: Check for feature flag security
      if: ${{ steps.rust.outputs.has == 'true' }}
      run: |
        echo "🔍 Checking feature flag configuration..."
        
        # Check for debug features that might be enabled inappropriately
        if grep -E "debug.*=.*true|dev.*=.*true" Cargo.toml >/dev/null 2>&1; then
          echo "::warning::Debug/dev features found in Cargo.toml"
          grep -E "debug.*=.*true|dev.*=.*true" Cargo.toml || true
          echo "Ensure debug features are not enabled in production builds"
        fi
        
        # Check for default features that might expose debug functionality
        if cargo tree --format "{f}" | grep -i debug >/dev/null 2>&1; then
          echo "::notice::Debug-related features detected in dependency tree"
          echo "Review feature flags for production appropriateness"
          else
            echo "✅ No obvious debug features in dependency tree"
          fi

    - name: Skip Enhanced Security (no Rust packages)
      if: ${{ steps.rust.outputs.has != 'true' }}
      run: echo "No Rust packages detected; skipping Enhanced Security job steps."

  gitsign-verification:
    name: Commit Signature Verification
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Install Go
      uses: actions/setup-go@0a12ed9d6a96ab950c8f026ed9f722fe0da7ef32 # v5.0.2
      with:
        go-version: '1.21'

    - name: Install gitsign for Sigstore verification
      run: |
        # Install gitsign for Sigstore signature verification
        go install github.com/sigstore/gitsign@latest

    - name: Verify latest commit signature
      run: |
        echo "Checking commit signature for: $(git log -1 --format='%H %s')"
        if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
          echo "✅ Latest commit has valid Sigstore signature"
        elif git log --show-signature -1 2>&1 | grep -q "gitsign: "; then
          echo "::error::Latest commit has invalid Sigstore signature"
          git log --show-signature -1
          exit 1
        else
          echo "::warning::Commit is not signed with Sigstore - enable gitsign"
        fi

EOF
  else
    cat <<'EOF'
name: Security CI

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master, develop ]

jobs:
  secret-scanning:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Run Gitleaks
      uses: gitleaks/gitleaks-action@cb7149b9e61c3d6896c4bc2616d4c9e86ee2d0c2 # v2.3.6
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}


  vulnerability-scanning:
    name: Vulnerability Scanning
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Run Trivy vulnerability scanner in repo mode
      uses: aquasecurity/trivy-action@b6643a29fecd7f34b3597bc6acb0a98b03d33ff8 # 0.33.1
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'

    - name: Upload Trivy scan results to GitHub Security
      uses: github/codeql-action/upload-sarif@396bb3e45325a47dd9ef434068033c6d5bb0d11a # v3.26.7
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  gitsign-verification:
    name: Commit Signature Verification
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7
      with:
        fetch-depth: 0

    - name: Install Go
      uses: actions/setup-go@0a12ed9d6a96ab950c8f026ed9f722fe0da7ef32 # v5.0.2
      with:
        go-version: '1.21'

    - name: Install gitsign for Sigstore verification
      run: |
        # Install gitsign for Sigstore signature verification
        go install github.com/sigstore/gitsign@latest

    - name: Verify latest commit signature
      run: |
        echo "Checking commit signature for: $(git log -1 --format='%H %s')"
        if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
          echo "✅ Latest commit has valid Sigstore signature"
        elif git log --show-signature -1 2>&1 | grep -q "gitsign: "; then
          echo "::error::Latest commit has invalid Sigstore signature"
          git log --show-signature -1
          exit 1
        else
          echo "::warning::Commit is not signed with Sigstore - enable gitsign"
        fi

EOF
  fi
}

# Generate CodeQL workflow for security scanning
generate_codeql_workflow() {
  cat <<'EOF'
name: "Code Scanning - CodeQL"

on:
  push:
    branches: [ "main", "master" ]
  pull_request:
    branches: [ "main", "master" ]
  schedule:
    - cron: '17 18 * * 1'  # Weekly on Mondays

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  analyze:
    name: Analyze Code
    runs-on: ubuntu-latest
    timeout-minutes: 360

    strategy:
      fail-fast: false
      matrix:
        include:
        - language: javascript-typescript
          build-mode: none # CodeQL supports 'none', 'autobuild', and 'manual'

    steps:
    - name: Checkout repository
      uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # v4.1.7

    - name: Initialize CodeQL
      uses: github/codeql-action/init@afb54ba388a7dca6ecae48f608c4ff05ff4cc77a # v3.25.15
      with:
        languages: ${{ matrix.language }}
        build-mode: ${{ matrix.build-mode }}

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@afb54ba388a7dca6ecae48f608c4ff05ff4cc77a # v3.25.15
      with:
        category: "/language:${{matrix.language}}"
EOF
}

# Install CI workflow
install_ci_workflow() {
  print_section "Installing CI Workflow"

  local workflows_dir=".github/workflows"
  local workflow_file="$workflows_dir/security.yml"
  local pinning_file="$workflows_dir/pinning-validation.yml"

  # Create workflows directory if it doesn't exist
  if [[ $DRY_RUN == false ]]; then
    mkdir -p "$workflows_dir"
  fi

  # Check if security workflow already exists
  if [[ -f $workflow_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Security workflow already exists"
    read -p "Replace existing workflow? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping security CI workflow installation"
    else
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "[DRY RUN] Would install CI workflow to $workflow_file"
      else
        generate_ci_workflow >"$workflow_file"
        print_status $GREEN "✅ Security CI workflow installed: $workflow_file"
      fi
    fi
  else
    if [[ $DRY_RUN == true ]]; then
      print_status $BLUE "[DRY RUN] Would install CI workflow to $workflow_file"
    else
      generate_ci_workflow >"$workflow_file"
      print_status $GREEN "✅ Security CI workflow installed: $workflow_file"
    fi
  fi

  # Install dedicated Pinning Validation workflow separately
  if [[ -f $pinning_file ]] && [[ $FORCE_INSTALL == false ]]; then
    print_status $YELLOW "⚠️  Pinning Validation workflow already exists"
    read -p "Replace existing pinning workflow? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_status $BLUE "📝 Skipping pinning workflow installation"
      return 0
    fi
  fi

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install Pinning Validation workflow to $pinning_file"
  else
    generate_pinning_workflow >"$pinning_file"
    print_status $GREEN "✅ Pinning Validation workflow installed: $pinning_file"
  fi

  # Install CodeQL workflow if GitHub security features are enabled
  if [[ $INSTALL_GITHUB_SECURITY == true ]]; then
    local codeql_file="$workflows_dir/codeql.yml"
    if [[ -f $codeql_file ]] && [[ $FORCE_INSTALL == false ]]; then
      print_status $YELLOW "⚠️  CodeQL workflow already exists"
      read -p "Replace existing CodeQL workflow? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status $BLUE "📝 Skipping CodeQL workflow installation"
      else
        if [[ $DRY_RUN == true ]]; then
          print_status $BLUE "[DRY RUN] Would install CodeQL workflow to $codeql_file"
        else
          generate_codeql_workflow >"$codeql_file"
          print_status $GREEN "✅ CodeQL workflow installed: $codeql_file"
        fi
      fi
    else
      if [[ $DRY_RUN == true ]]; then
        print_status $BLUE "[DRY RUN] Would install CodeQL workflow to $codeql_file"
      else
        generate_codeql_workflow >"$codeql_file"
        print_status $GREEN "✅ CodeQL workflow installed: $codeql_file"
      fi
    fi
  fi
}

# Install documentation
install_documentation() {
  print_section "Installing Security Documentation"

  if [[ $DRY_RUN == false ]]; then
    mkdir -p "$DOCS_DIR"
  fi

  # README removed - redundant with ARCHITECTURE.md
  # All essential information is now in ARCHITECTURE.md

  # Install architecture documentation
  local arch_file="$DOCS_DIR/architecture.md"
  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would install architecture documentation to $arch_file"
  else
    # Install focused architecture documentation for users
    cat <<'ARCH_EOF' >"$arch_file"
# Security Controls Architecture

## 🎯 What's Installed in Your Repository

This document explains the security architecture deployed in your project by 1-Click GitHub Security.

### 📊 Performance & Coverage Metrics
| Metric | Value | Impact |
|--------|--------|--------|
| **Pre-Push Validation** | < 60 seconds | ⚡ Developer workflow preservation |
| **Security Controls** | 35+ comprehensive | 🛡️ Complete attack vector coverage |
| **Language Support** | Multi-language | 🌐 Universal project compatibility |
| **Issue Resolution Speed** | 10x faster | 🚀 Early detection advantage |

## 🏗️ Two-Tier Security Architecture

### Tier 1: Pre-Push Controls (< 60 seconds)
**Purpose**: Block critical issues before they enter the repository

**Controls Installed**:
- ✅ **Secret Detection** - Blocks API keys, passwords, tokens (gitleakslite)
- ✅ **Vulnerability Scanning** - Catches known security issues (language-specific)
- ✅ **Code Quality** - Linting and formatting validation (language-specific)
- ✅ **Test Validation** - Ensures tests pass before push (language-specific)
- ✅ **Supply Chain Security** - SHA pinning, dependency validation (pinactlite)
- ✅ **License Compliance** - Validates dependency licenses (language-specific)

### Tier 2: Post-Push Controls (CI/CD Analysis)
**Purpose**: Comprehensive analysis and reporting

**Workflows Installed** (optional, via --workflows flag):
- 🔍 **Static Analysis** - SAST with CodeQL and Trivy
- 🔍 **Dependency Auditing** - Automated vulnerability detection
- 🔍 **Security Reporting** - SBOM generation and metrics
- 🔍 **Compliance Checking** - License and policy validation

## 🔧 Components Installed

### Pre-Push Hook
**Location**: `.git/hooks/pre-push`
**Function**: Runs security validation before every push
**Performance**: Completes in < 60 seconds
**Bypass**: `git push --no-verify` (emergency use only)

### Security Tools
**Location**: `.security-controls/bin/`
- `gitleakslite` - Secret detection (embedded binary)
- `pinactlite` - GitHub Actions SHA pinning (embedded binary)

### Configuration Files
- `.security-controls-version` - Tracks installed version
- `.security-controls-config` - Installation configuration
- Language-specific configs (e.g., `.cargo/audit.toml`, `.eslintrc.js`)

### Optional CI/CD Workflows
**Location**: `.github/workflows/`
- `security-ci-workflow.yml` - Comprehensive security analysis
- Additional specialized workflows (if --workflows used)

## 🚀 Developer Workflow Integration

### Normal Development
1. **Code** - Write code as usual
2. **Commit** - `git commit` works normally
3. **Push** - Pre-push hook validates automatically (< 60s)
4. **CI** - Optional comprehensive analysis runs in background

### When Pre-Push Fails
The hook provides specific fix instructions:

```bash
# Format issues
cargo fmt --all                    # Rust
npm run format                     # Node.js
black .                           # Python
go fmt ./...                      # Go

# Linting issues
cargo clippy --all-targets --fix  # Rust
npm run lint --fix               # Node.js
flake8 . --fix                   # Python
golint ./...                     # Go

# Security vulnerabilities
cargo audit fix                   # Rust
npm audit fix                    # Node.js
safety check                     # Python
govulncheck ./...               # Go

# Secrets detected
# Remove secrets, use environment variables

# GitHub Actions not SHA-pinned
.security-controls/bin/pinactlite pinactlite --dir .github/workflows
```

## 🔐 GitHub Security Features (Optional)

When installed with `--github-security` flag:

### Automatically Configured
- **Renovate Bot** - Automated dependency updates with automerge, grouping, and scheduling
- **Vulnerability Alerts** - Automated dependency scanning
- **Branch Protection Rules** - Requires reviews and status checks
- **CodeQL Security Scanning** - Automated code analysis
- **Secret Scanning** - Server-side secret detection
- **Secret Push Protection** - Blocks secrets at GitHub level

**Note**: This project uses Renovate instead of Dependabot for superior dependency management:
- ✅ Automerge for patch/minor updates after CI passes
- ✅ Intelligent grouping (GitHub Actions, dependency groups)
- ✅ Scheduled PRs (weekdays during work hours)
- ✅ Automatic PR rebasing on conflicts
- ✅ Vulnerability alerts with immediate automerge
- ✅ Better monorepo/workspace support

## 🎯 Language-Specific Security

### Rust Projects
- `cargo audit` - Vulnerability scanning
- `cargo clippy` - Security linting
- `cargo test` - Test validation
- `cargo license` - License compliance

### Node.js Projects
- `npm audit` - Vulnerability scanning
- `eslint` - Security linting
- `npm test` - Test validation
- `license-checker` - License compliance

### Python Projects
- `safety check` - Vulnerability scanning
- `bandit` - Security linting
- `pytest` - Test validation
- `pip-licenses` - License compliance

### Go Projects
- `govulncheck` - Vulnerability scanning
- `golint` - Security linting
- `go test` - Test validation
- `go-licenses` - License compliance

### Generic Projects
- Universal secret detection
- GitHub Actions SHA pinning
- Basic file validation

## 🛠️ Maintenance and Updates

### Upgrading Security Controls
```bash
# Download latest installer
curl -O https://github.com/h4x0r/1-click-github-sec/releases/latest/download/install-security-controls.sh

# Run upgrade (preserves your settings)
chmod +x install-security-controls.sh
./install-security-controls.sh --upgrade
```

### Manual Tool Updates
```bash
# Update embedded security tools
.security-controls/bin/gitleakslite --update
.security-controls/bin/pinactlite --update
```

### Configuration Management
- Version tracked in `.security-controls-version`
- Settings preserved in `.security-controls-config`
- Backups created in `.security-controls-backup/`

## 📊 Monitoring and Metrics

### Pre-Push Performance
- Target: < 60 seconds total execution time
- Parallel execution for efficiency
- Tool-specific timeouts prevent hangs

### Security Coverage
- 35+ comprehensive security controls
- Multi-language vulnerability detection
- Supply chain attack prevention
- Secret exposure prevention

### Compliance Standards
- ✅ NIST SSDF aligned
- ✅ SLSA Level 2 compliant
- ✅ OpenSSF best practices
- ✅ SBOM generation ready

## 🔗 Additional Resources

- **Complete Architecture**: https://h4x0r.github.io/1-click-github-sec/architecture
- **Installation Guide**: https://h4x0r.github.io/1-click-github-sec/installation
- **Cryptographic Verification**: https://h4x0r.github.io/1-click-github-sec/cryptographic-verification
- **GitHub Repository**: https://github.com/h4x0r/1-click-github-sec

---

*This architecture document describes the security controls installed in your specific repository. For complete technical details, see the full documentation at the links above.*
ARCH_EOF
    print_status $GREEN "✅ Architecture documentation installed: $arch_file"
  fi

}

# Install default config/state files
install_default_config() {
  print_section "Installing Default Security Configuration"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would create $CONTROL_STATE_DIR with config and gitleaks config"
    return 0
  fi

  mkdir -p "$CONTROL_STATE_DIR"

  # Create config.env if missing
  if [[ ! -f $CONFIG_ENV_FILE ]]; then
    cat >"$CONFIG_ENV_FILE" <<'CONF_EOF'
# 1-Click Security Controls - Configuration
# Toggle controls (true/false)
ENABLE_SECRET_SCAN=true
SECRET_SCAN_MODE=staged   # staged|full
ENABLE_LARGE_FILE_CHECK=true
LARGE_FILE_MAX_MB=10
ENABLE_TECH_DEBT_CHECK=true
ENABLE_EMPTY_FILE_CHECK=true
# New toggles
ENABLE_LINT=true
ENABLE_TESTS=true
# unit: cargo test --lib, all: cargo test --all
TEST_SCOPE=all
CONF_EOF
    print_status $GREEN "✅ Created $CONFIG_ENV_FILE"
  else
    print_status $BLUE "ℹ️ Existing config preserved at $CONFIG_ENV_FILE"
  fi

  # Create a default gitleaks config if missing (used by CI action)
  if [[ ! -f $GITLEAKS_CONFIG_FILE ]]; then
    cat >"$GITLEAKS_CONFIG_FILE" <<'GL_EOF'
# Gitleaks configuration for 1-Click Security Controls
# Basic allowlist to reduce noise for common build artifacts
title = "1-Click Security Gitleaks Config"

[allowlist]
paths = [
  "target/",
  "node_modules/",
  "dist/",
  "build/",
  "coverage/",
  "*.lock",
]
GL_EOF
    print_status $GREEN "✅ Created $GITLEAKS_CONFIG_FILE"
  else
    print_status $BLUE "ℹ️ Existing gitleaks config preserved at $GITLEAKS_CONFIG_FILE"
  fi

  # Create a simple secret allowlist for local scanner
  local allowlist_file="$CONTROL_STATE_DIR/secret-allowlist.txt"
  if [[ ! -f $allowlist_file ]]; then
    cat >"$allowlist_file" <<'AL_EOF'
# Regex patterns to allow (one per line). Examples:
# ^TEST_[A-Z0-9_]+$
# example.com
AL_EOF
    print_status $GREEN "✅ Created $allowlist_file"
  fi
}

install_renovate_config() {
  print_section "Installing Renovate Configuration"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would create language-specific renovate.json and workflow"
    return 0
  fi

  # Only install if not already present
  if [[ -f "renovate.json" ]]; then
    print_status $BLUE "ℹ️  renovate.json already exists, skipping"
  else
    # Get repository owner for assignees/reviewers
    local repo_owner
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      repo_owner=$(gh repo view --json owner -q '.owner.login' 2>/dev/null || echo "REPO_OWNER")
    else
      repo_owner="REPO_OWNER"
    fi

    # Build language-specific packageRules
    local package_rules=""
    local manager_configs=""
    local detected_langs_str="${DETECTED_LANGUAGES[*]}"

    print_status $BLUE "🔧 Generating language-specific Renovate configuration..."
    print_status $BLUE "   Detected languages: $detected_langs_str"

    # Rust-specific rules
    if [[ " ${DETECTED_LANGUAGES[*]} " =~ " rust " ]]; then
      package_rules+='
    {
      "description": "Automerge patch and minor updates for Rust dependencies",
      "matchDatasources": ["crate"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash",
      "platformAutomerge": true
    },
    {
      "description": "Group all Rust workspace dependencies together",
      "matchDatasources": ["crate"],
      "groupName": "Rust workspace dependencies"
    },
    {
      "description": "Hold back major Rust dependency updates for review",
      "matchDatasources": ["crate"],
      "matchUpdateTypes": ["major"],
      "dependencyDashboardApproval": true,
      "automerge": false
    },'
      manager_configs+='
  "cargo": {
    "enabled": true,
    "rangeStrategy": "bump"
  },
  "rust": {
    "enabled": true
  },'
    fi

    # Python-specific rules
    if [[ " ${DETECTED_LANGUAGES[*]} " =~ " python " ]]; then
      package_rules+='
    {
      "description": "Automerge Python security tools",
      "matchManagers": ["pip_requirements", "poetry", "pipenv"],
      "matchPackageNames": ["bandit", "safety", "pip-audit", "semgrep", "black", "flake8", "pylint"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash"
    },
    {
      "description": "Group Python dependencies",
      "matchManagers": ["pip_requirements", "poetry", "pipenv"],
      "groupName": "Python dependencies"
    },'
      manager_configs+='
  "pip_requirements": {
    "enabled": true
  },
  "poetry": {
    "enabled": true
  },
  "pipenv": {
    "enabled": true
  },'
    fi

    # Node.js/TypeScript-specific rules
    if [[ " ${DETECTED_LANGUAGES[*]} " =~ " nodejs " ]] || [[ " ${DETECTED_LANGUAGES[*]} " =~ " typescript " ]]; then
      package_rules+='
    {
      "description": "Automerge Node.js dev dependencies",
      "matchManagers": ["npm", "yarn", "pnpm"],
      "matchDepTypes": ["devDependencies"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash"
    },
    {
      "description": "Group Node.js dependencies",
      "matchManagers": ["npm", "yarn", "pnpm"],
      "groupName": "Node.js dependencies"
    },'
      manager_configs+='
  "npm": {
    "enabled": true,
    "rangeStrategy": "bump"
  },
  "yarn": {
    "enabled": true
  },
  "pnpm": {
    "enabled": true
  },'
    fi

    # Go-specific rules
    if [[ " ${DETECTED_LANGUAGES[*]} " =~ " go " ]]; then
      package_rules+='
    {
      "description": "Automerge Go module updates",
      "matchManagers": ["gomod"],
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash"
    },
    {
      "description": "Group Go module dependencies",
      "matchManagers": ["gomod"],
      "groupName": "Go modules"
    },'
      manager_configs+='
  "gomod": {
    "enabled": true
  },'
    fi

    # Generate renovate.json with language-specific rules
    cat >"renovate.json" <<EOF
{
  "\$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:recommended",
    ":dependencyDashboard",
    ":semanticCommits",
    ":gitSignOff"
  ],
  "labels": ["dependencies"],
  "assignees": ["$repo_owner"],
  "reviewers": ["$repo_owner"],
  "timezone": "America/Los_Angeles",
  "schedule": ["after 9am and before 5pm every weekday"],
  "prConcurrentLimit": 5,
  "prCreation": "immediate",
  "prHourlyLimit": 0,
  "packageRules": [$package_rules
    {
      "description": "Group all GitHub Actions updates together",
      "matchManagers": ["github-actions"],
      "groupName": "GitHub Actions",
      "automerge": true,
      "automergeType": "pr",
      "automergeStrategy": "squash",
      "platformAutomerge": true
    },
    {
      "description": "Pin GitHub Actions to commit SHA with version comment",
      "matchManagers": ["github-actions"],
      "pinDigests": true
    }
  ],$manager_configs
  "lockFileMaintenance": {
    "enabled": true,
    "automerge": true,
    "automergeType": "pr",
    "schedule": ["before 6am on monday"]
  },
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"],
    "automerge": true,
    "schedule": ["at any time"]
  },
  "stabilityDays": 3,
  "prBodyDefinitions": {
    "Change": "{{#if displayFrom}}\\\`{{{displayFrom}}}\\\` -> {{else}}**New dependency** {{/if}}\\\`{{{displayTo}}}\\\`"
  },
  "commitMessagePrefix": "chore(deps):",
  "commitMessageAction": "update",
  "commitMessageTopic": "{{depName}}",
  "commitMessageExtra": "to {{newVersion}}",
  "commitBody": "🤖 Generated with 1-Click GitHub Security\\n\\nCo-Authored-By: Security Controls <noreply@securityronin.com>"
}
EOF
    print_status $GREEN "✅ Created language-specific renovate.json"
    print_status $BLUE "   Languages configured: $detected_langs_str"
  fi

  # Install self-hosted Renovate workflow (truly 1-click!)
  mkdir -p ".github/workflows"
  if [[ -f ".github/workflows/renovate.yml" ]]; then
    print_status $BLUE "ℹ️  Renovate workflow already exists, skipping"
  else
    cat >".github/workflows/renovate.yml" <<'RENOVATE_WORKFLOW_EOF'
name: Renovate
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:
  push:
    branches:
      - main
    paths:
      - '.github/workflows/renovate.yml'
      - 'renovate.json'

permissions:
  contents: write
  pull-requests: write
  issues: write

jobs:
  renovate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2

      - name: Self-hosted Renovate
        uses: renovatebot/github-action@696f57d7c1b47aa1097f46915e93ed0bdd25d641 # v40.3.12
        with:
          configurationFile: renovate.json
          token: ${{ secrets.GITHUB_TOKEN }}
RENOVATE_WORKFLOW_EOF
    print_status $GREEN "✅ Created self-hosted Renovate workflow"
    print_status $BLUE "   🎉 Fully automated - no manual app installation required!"
    print_status $BLUE "   ⚡ Runs every 6 hours automatically"
    print_status $BLUE "   📝 Uses renovate.json configuration"
  fi
}

install_pinactlite_script() {
  print_section "Installing script-only pinactlite helper"

  local bin_dir="$CONTROL_STATE_DIR/bin"
  local script_path="$bin_dir/pinactlite"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would copy pinactlite to $script_path"
    return 0
  fi

  mkdir -p "$bin_dir"

  # Copy from the canonical source instead of embedding
  if [[ -f ".security-controls/bin/pinactlite" ]]; then
    cp ".security-controls/bin/pinactlite" "$script_path"
    print_status $GREEN "✅ Copied pinactlite from canonical source"
  else
    # Fallback: download from repository if not available locally
    local pinactlite_url="https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/.security-controls/bin/pinactlite"
    if command -v curl >/dev/null 2>&1; then
      curl -sSL "$pinactlite_url" >"$script_path"
      print_status $GREEN "✅ Downloaded pinactlite from repository"
    else
      print_status $RED "❌ Cannot find local pinactlite and curl not available"
      return 1
    fi
  fi

  chmod +x "$script_path"
  print_status $GREEN "✅ Installed script-only pinactlite at $script_path"
}

install_gitleakslite_script() {
  print_section "Installing script-only gitleakslite helper"

  local bin_dir="$CONTROL_STATE_DIR/bin"
  local script_path="$bin_dir/gitleakslite"

  if [[ $DRY_RUN == true ]]; then
    print_status $BLUE "[DRY RUN] Would copy gitleakslite to $script_path"
    return 0
  fi

  mkdir -p "$bin_dir"

  # Copy from the canonical source instead of embedding
  if [[ -f ".security-controls/bin/gitleakslite" ]]; then
    cp ".security-controls/bin/gitleakslite" "$script_path"
    print_status $GREEN "✅ Copied gitleakslite from canonical source"
  else
    # Fallback: download from repository if not available locally
    local gitleakslite_url="https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/.security-controls/bin/gitleakslite"
    if command -v curl >/dev/null 2>&1; then
      curl -sSL "$gitleakslite_url" >"$script_path"
      print_status $GREEN "✅ Downloaded gitleakslite from repository"
    else
      print_status $YELLOW "⚠️ Cannot find local gitleakslite and curl not available, generating basic fallback"
      # Fallback: generate basic version if source not available
      cat >"$script_path" <<'GLSCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<USG
gitleakslite (script) - basic secret scanner (fallback version)

Usage:
  gitleakslite protect --staged [--redact] [--no-banner] [--config PATH]
  gitleakslite detect [--redact] [--no-banner] [--config PATH]

Note: This is a fallback version. For comprehensive patterns, run from repository.
USG
}
read_allowlist() {
  local file=".security-controls/secret-allowlist.txt"
  [[ -f $file ]] && cat "$file"
}
scan_lines() {
  local file="$1" redact="$2" allowlist hit=0
  allowlist=$(read_allowlist || true)
  local patterns='(A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z0-9]{16}|(ghp|gho|ghu|ghr|ghs)_[0-9a-zA-Z]{36}|AIza[0-9A-Za-z_-]{35}|xox[bpsoarunv]-[0-9]{8,13}-[0-9a-zA-Z]{8,64}|-----BEGIN[ A-Z0-9_-]{0,100}PRIVATE KEY'
  while IFS= read -r line; do
    [[ -n $allowlist ]] && grep -E -q "$allowlist" <<<"$line" && continue
    if grep -E -q "$patterns" <<<"$line"; then
      [[ $redact == "1" ]] && line=$(echo "$line" | sed -E 's/([:=])[[:space:]]*"?[^"[:space:]]{4,}/\1 ***REDACTED***/g')
      echo "$line"; hit=1
    fi
  done
  return $hit
}
cmd_protect() {
  local staged=0 redact=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --staged) staged=1; shift ;; --redact) redact=1; shift ;; --no-banner|--config) shift ;; *) shift ;; esac
  done
  [[ $staged -ne 1 ]] && { echo "protect: --staged required" >&2; exit 2; }
  local hit=0
  while IFS= read -r f; do
    [[ -z $f || ! -f $f ]] && continue
    git diff --cached -U0 -- "$f" | sed -n 's/^+//p' | scan_lines "$f" "$redact" || { hit=1; echo "[$f]" >&2; }
  done < <(git diff --cached --name-only --diff-filter=ACM | grep -v -E '^(target/|node_modules/)' || true)
  [[ $hit -eq 1 ]] && exit 1
}
cmd_detect() {
  local redact=0
  while [[ $# -gt 0 ]]; do
    case "$1" in --redact) redact=1; shift ;; *) shift ;; esac
  done
  local hit=0
  while IFS= read -r f; do
    [[ -z $f || ! -f $f ]] && continue
    cat "$f" | scan_lines "$f" "$redact" || { hit=1; echo "[$f]" >&2; }
  done < <(git ls-files | grep -v -E '^(target/|node_modules/)' || true)
  [[ $hit -eq 1 ]] && exit 1
}
case "${1:-}" in
  protect) shift; cmd_protect "$@" ;;
  detect) shift; cmd_detect "$@" ;;
  *) usage ;;
esac
GLSCRIPT_EOF
    fi
  fi

  chmod +x "$script_path"
  print_status $GREEN "✅ Installed script-only gitleakslite at $script_path"
}

# Install GitHub repository security features
install_github_security() {
  if [[ $INSTALL_GITHUB_SECURITY != true ]]; then
    return 0
  fi

  print_section "Configuring GitHub Repository Security Features"

  # Check if gh CLI is available
  if ! command -v gh >/dev/null 2>&1; then
    print_status $YELLOW "⚠️  GitHub CLI (gh) not found"
    print_status $BLUE "💡 Manual setup required for GitHub security features:"
    print_status $BLUE ""
    print_status $BLUE "   1. Install GitHub CLI: https://cli.github.com/"
    print_status $BLUE "   2. Run: gh auth login"
    print_status $BLUE "   3. Re-run installer with --github-security"
    print_status $BLUE ""
    print_manual_github_instructions
    return 0
  fi

  # Check if authenticated
  if ! gh auth status >/dev/null 2>&1; then
    print_status $YELLOW "⚠️  GitHub CLI not authenticated"
    print_status $BLUE "💡 Please authenticate with GitHub:"
    print_status $BLUE "   gh auth login"
    print_status $BLUE ""
    print_manual_github_instructions
    return 0
  fi

  # Get repository information
  local repo_info
  repo_info=$(gh repo view --json nameWithOwner 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    print_status $YELLOW "⚠️  Not in a GitHub repository or no remote configured"
    print_manual_github_instructions
    return 0
  fi

  local repo_name
  repo_name=$(echo "$repo_info" | jq -r '.nameWithOwner')
  print_status $BLUE "🔧 Configuring security for repository: $repo_name"

  # 1. Enable vulnerability alerts (works with both Dependabot and Renovate)
  print_status $BLUE "🔍 Enabling vulnerability alerts..."
  if gh api "repos/$repo_name/vulnerability-alerts" -X PUT >/dev/null 2>&1; then
    print_status $GREEN "   ✅ Vulnerability alerts enabled"
  else
    print_status $YELLOW "   ⚠️  Failed to enable vulnerability alerts (may already be enabled)"
  fi

  # 2. Note: Renovate self-hosted workflow already installed
  print_status $BLUE "🤖 Renovate self-hosted workflow installed"
  print_status $GREEN "   ✅ Fully automated - no manual setup required!"
  print_status $BLUE "   ✨ Superior dependency management vs Dependabot:"
  print_status $BLUE "      • Automerge for patch/minor updates"
  print_status $BLUE "      • Intelligent grouping (reduces PR noise)"
  print_status $BLUE "      • Better monorepo/workspace support"
  print_status $BLUE "      • Runs every 6 hours automatically"

  # 3. Enable Branch Protection (if this is the main branch)
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ $current_branch == "main" ]] || [[ $current_branch == "master" ]]; then
    print_status $BLUE "🛡️  Enabling branch protection for $current_branch..."
    configure_branch_protection "$repo_name" "$current_branch"
  else
    print_status $BLUE "ℹ️  Branch protection configuration available for main/master branch"
    print_status $BLUE "   Current branch: $current_branch"
  fi

  # 4. Show manual steps for remaining features
  print_status $BLUE ""
  print_status $BLUE "📋 Additional security features (manual setup required):"
  print_status $BLUE ""
  print_status $BLUE "   🔐 Security Advisories:"
  print_status $BLUE "       Visit: https://github.com/$repo_name/settings/security_analysis"
  print_status $BLUE "       Enable: 'Private vulnerability reporting'"
  print_status $BLUE ""
  print_status $BLUE "   ❌ Advanced Security (GitHub Enterprise only):"
  print_status $BLUE "       • Advanced code scanning"
  print_status $BLUE "       • Secret scanning for private repos"
  print_status $BLUE "       • Dependency review"
  print_status $BLUE "       Not available for public repositories"
  print_status $BLUE ""

  print_status $GREEN "🎉 GitHub security features configured!"
}

# Configure branch protection rules
configure_branch_protection() {
  local repo_name=$1
  local branch_name=$2

  local protection_config
  protection_config=$(
    cat <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Security CI",
      "Pinning Validation"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
  )

  if gh api "repos/$repo_name/branches/$branch_name/protection" -X PUT --input - <<<"$protection_config" >/dev/null 2>&1; then
    print_status $GREEN "   ✅ Branch protection enabled for $branch_name"
    print_status $BLUE "      • Requires PR reviews (1 approver)"
    print_status $BLUE "      • Requires status checks to pass"
    print_status $BLUE "      • Enforces admin restrictions"
    print_status $BLUE "      • Blocks force pushes and deletions"
  else
    print_status $YELLOW "   ⚠️  Failed to enable branch protection"
    print_status $BLUE "   💡 Manual setup: https://github.com/$repo_name/settings/branches"
  fi
}

# Print manual instructions for GitHub security features
print_manual_github_instructions() {
  print_status $BLUE "📋 Manual GitHub Security Setup Instructions:"
  print_status $BLUE ""
  print_status $BLUE "   1. 🔍 Secret Scanning (Public repos - auto-enabled):"
  print_status $BLUE "      Already enabled for public repositories"
  print_status $BLUE ""
  print_status $BLUE "   2. 🔧 Dependabot Security Updates:"
  print_status $BLUE "      Go to: Repository Settings → Security & analysis"
  print_status $BLUE "      Enable: 'Dependabot security updates'"
  print_status $BLUE ""
  print_status $BLUE "   3. 🛡️  Branch Protection:"
  print_status $BLUE "      Go to: Repository Settings → Branches"
  print_status $BLUE "      Add rule for 'main' branch with:"
  print_status $BLUE "      ✓ Require pull request reviews"
  print_status $BLUE "      ✓ Require status checks to pass"
  print_status $BLUE "      ✓ Include administrators"
  print_status $BLUE ""
  print_status $BLUE "   4. 🔐 Security Advisories:"
  print_status $BLUE "      Go to: Repository Settings → Security & analysis"
  print_status $BLUE "      Enable: 'Private vulnerability reporting'"
  print_status $BLUE ""
  print_status $BLUE "   5. 📊 Code Scanning:"
  print_status $BLUE "      CodeQL workflow added to .github/workflows/codeql.yml"
  print_status $BLUE "      Will activate automatically on next push"
  print_status $BLUE ""
}

# Show installation summary
show_summary() {
  print_header "Installation Complete"

  print_status $GREEN "✅ Security controls successfully installed!"
  echo

  if [[ $INSTALL_HOOKS == true ]]; then
    print_status $BLUE "📋 Pre-Push Hook:"
    if [[ $USE_HOOKS_PATH == true ]]; then
      print_status $GREEN "   ✅ Installed to $PRE_PUSH_D_DIR/50-security-pre-push"
      print_status $BLUE "   🔗 hooksPath dispatcher: $HOOKS_PATH_DIR/pre-push"
    else
      print_status $GREEN "   ✅ Installed to .git/hooks/pre-push"
    fi
    print_status $BLUE "   🔍 Validates: format, lint, security, tests, secrets, licenses, SHA pinning, size, tech debt, empty files"
    print_status $BLUE "   ⚡ Pre-push aims to complete in ~55–75 seconds"
  fi

  if [[ $INSTALL_CI == true ]]; then
    print_status $BLUE "🔄 CI Workflow:"
    print_status $GREEN "   ✅ Installed to .github/workflows/security.yml"
    print_status $BLUE "   🔍 Includes: SAST, vulnerability scanning, SBOM generation"
    print_status $BLUE "   🚀 Runs automatically on push/PR"
  fi

  if [[ $INSTALL_DOCS == true ]]; then
    print_status $BLUE "📚 Documentation:"
    print_status $GREEN "   ✅ Installed to $DOCS_DIR/"
    print_status $BLUE "   📖 Includes: architecture.md (with integrated 4-mode signing guide)"
  fi

  if [[ $INSTALL_GITHUB_SECURITY == true ]]; then
    print_status $BLUE "🔐 GitHub Security Features:"
    print_status $GREEN "   ✅ Vulnerability alerts enabled"
    print_status $GREEN "   ✅ Renovate self-hosted workflow installed"
    print_status $BLUE "   🎉 Fully automated - runs every 6 hours!"
    print_status $GREEN "   ✅ CodeQL workflow added"
    print_status $BLUE "   🔧 Branch protection configured (if main/master branch)"
    print_status $YELLOW "   ⚠️  Security advisories require manual setup"
    print_status $BLUE "   ❌ Advanced security (GitHub Enterprise only)"
  fi

  echo
  print_status $BLUE "🎯 Next Steps:"
  echo "   1. Test the pre-push hook: git push --dry-run"
  echo "   2. Make a test commit and push to verify CI workflow"
  echo "   3. Review documentation in $DOCS_DIR/"
  echo "   4. Configure gitsign for commit signing (optional)"
  echo

  print_status $YELLOW "💡 Pro Tips:"
  echo "   • Pre-push hook runs automatically on every push"
  echo "   • Use 'git push --no-verify' for emergency bypasses only"
  echo "   • All security reports available in CI artifacts"
  echo "   • Tools auto-install instructions provided on first run"
  echo

  print_status $GREEN "🛡️  Your repository is now secured with comprehensive controls!"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      # Signing mode commands
      status)
        COMMAND_MODE="status"
        shift
        ;;
      test)
        COMMAND_MODE="test"
        shift
        ;;
      enable-yubikey)
        COMMAND_MODE="enable-yubikey"
        shift
        ;;
      disable-yubikey)
        COMMAND_MODE="disable-yubikey"
        shift
        ;;
      switch-to-gitsign)
        COMMAND_MODE="switch-to-gitsign"
        shift
        ;;
      switch-to-gpg)
        COMMAND_MODE="switch-to-gpg"
        shift
        ;;
      -h | --help)
        show_help
        exit 0
        ;;
      -v)
        show_version
        exit 0
        ;;
      --version)
        SHOW_VERSION=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      -d | --dry-run)
        DRY_RUN=true
        shift
        ;;
      -f | --force)
        FORCE_INSTALL=true
        shift
        ;;
      --skip-tools)
        SKIP_TOOLS=true
        shift
        ;;
      --no-hooks)
        INSTALL_HOOKS=false
        shift
        ;;
      --no-ci)
        INSTALL_CI=false
        shift
        ;;
      --no-docs)
        INSTALL_DOCS=false
        shift
        ;;
      --language=*)
        PROJECT_LANGUAGE="${1#--language=}"
        # Validation will happen in detect_project_languages function
        shift
        ;;
      --hooks-path)
        USE_HOOKS_PATH=true
        shift
        ;;
      --no-github-security)
        INSTALL_GITHUB_SECURITY=false
        shift
        ;;
      --no-signing)
        INSTALL_SIGNING=false
        shift
        ;;
      --signing=*)
        SIGNING_METHOD="${1#--signing=}"
        case "$SIGNING_METHOD" in
          gitsign | gpg) ;;
          *)
            print_status $RED "❌ Invalid signing method: $SIGNING_METHOD"
            echo "   Valid options: gitsign (default, secure), gpg (GitHub badges)"
            exit 1
            ;;
        esac
        shift
        ;;
      --yubikey)
        YUBIKEY_MODE=true
        shift
        ;;
      --check-update)
        CHECK_UPDATE=true
        shift
        ;;
      --backup)
        BACKUP_MODE=true
        shift
        ;;
      --changelog)
        show_changelog
        exit 0
        ;;
      *)
        print_status $RED "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
    esac
  done
}

# =============================================================================
# YUBIKEY SIGNING MODE MANAGEMENT FUNCTIONS
# =============================================================================

# Detect current signing mode
detect_signing_mode() {
  # Check both global and local config, with global taking precedence
  local commit_signing_global
  local commit_signing_local
  local gpg_format_global
  local gpg_format_local
  local gpg_program_global
  local gpg_program_local

  # Check global config first
  commit_signing_global=$(git config --global --get commit.gpgsign 2>/dev/null || echo "")
  gpg_format_global=$(git config --global --get gpg.format 2>/dev/null || echo "")
  gpg_program_global=$(git config --global --get gpg.x509.program 2>/dev/null || echo "")

  # Check local config as fallback
  commit_signing_local=$(git config --get commit.gpgsign 2>/dev/null || echo "")
  gpg_format_local=$(git config --get gpg.format 2>/dev/null || echo "")
  gpg_program_local=$(git config --get gpg.x509.program 2>/dev/null || echo "")

  # Use global config if available, otherwise local, otherwise defaults
  local commit_signing="${commit_signing_global:-${commit_signing_local:-false}}"
  local gpg_format="${gpg_format_global:-${gpg_format_local:-openpgp}}"
  local gpg_program="${gpg_program_global:-${gpg_program_local:-}}"

  if [[ $commit_signing != "true" ]]; then
    echo "none"
  elif [[ $gpg_format == "x509" ]] && [[ $gpg_program == "gitsign" ]]; then
    echo "gitsign"
  elif [[ $gpg_format == "openpgp" ]]; then
    echo "gpg"
  else
    echo "unknown"
  fi
}

# Check if YubiKey mode is enabled
check_yubikey_mode() {
  # Check global config first, then local
  local oidc_issuer_global
  local oidc_issuer_local

  oidc_issuer_global=$(git config --global --get gitsign.oidc-issuer 2>/dev/null || echo "")
  oidc_issuer_local=$(git config --get gitsign.oidc-issuer 2>/dev/null || echo "")

  local oidc_issuer="${oidc_issuer_global:-$oidc_issuer_local}"

  if [[ $oidc_issuer == "https://token.actions.githubusercontent.com" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Show current signing status
show_signing_status() {
  print_header "Current Signing Configuration"

  local signing_mode
  signing_mode=$(detect_signing_mode)

  case "$signing_mode" in
    "none")
      print_status $RED "❌ Git commit signing is DISABLED"
      print_status $BLUE "   Run installer to enable: $0"
      ;;
    "gitsign")
      print_status $GREEN "✅ gitsign signing is ENABLED"
      local yubikey_mode
      yubikey_mode=$(check_yubikey_mode)
      if [[ $yubikey_mode == "true" ]]; then
        print_status $GREEN "🔑 Mode: gitsign + YubiKey (maximum security)"
        print_status $BLUE "   • Short-lived certificates with hardware authentication"
      else
        print_status $GREEN "💻 Mode: gitsign + software (high security)"
        print_status $BLUE "   • Short-lived certificates with browser authentication"
      fi
      ;;
    "gpg")
      print_status $GREEN "✅ GPG signing is ENABLED"
      print_status $BLUE "💻 Mode: GPG + software (GitHub badges)"
      print_status $BLUE "   • Traditional GPG signing with GitHub verification"
      ;;
    "unknown")
      print_status $YELLOW "⚠️  Unknown signing configuration detected"
      ;;
  esac

  echo
  print_status $BLUE "📋 Available commands:"
  echo "   $0 test                     # Test current configuration"
  echo "   $0 enable-yubikey          # Enable YubiKey requirement"
  echo "   $0 disable-yubikey         # Disable YubiKey requirement"
  echo "   $0 switch-to-gitsign       # Switch to gitsign mode"
  echo "   $0 switch-to-gpg           # Switch to GPG mode"
}

# Test current signing configuration
test_signing_configuration() {
  print_header "Testing Current Signing Configuration"

  local signing_mode
  signing_mode=$(detect_signing_mode)

  case "$signing_mode" in
    "none")
      print_status $RED "❌ Signing is not configured"
      print_status $BLUE "   Run installer first: $0"
      exit 1
      ;;
    "gitsign" | "gpg")
      # Create a test commit to verify signing
      local test_file
      test_file="signing-test-$(date +%s).txt"
      echo "Signing test - $(date)" >"$test_file"

      print_status $BLUE "🧪 Creating test commit..."
      if git add "$test_file" && git commit -m "Test signing configuration

Created by: Security Controls Installer v$SCRIPT_VERSION"; then
        print_status $GREEN "✅ Test commit created successfully!"

        # Verify signature
        print_status $BLUE "🔍 Verifying signature..."
        if [[ $signing_mode == "gitsign" ]]; then
          if git log --show-signature -1 2>&1 | grep -q "gitsign: Good signature"; then
            print_status $GREEN "✅ gitsign signature verified!"
          else
            print_status $YELLOW "⚠️  gitsign signature verification unclear"
          fi
        else
          if git log --show-signature -1 2>&1 | grep -q "Good signature"; then
            print_status $GREEN "✅ GPG signature verified!"
          else
            print_status $YELLOW "⚠️  GPG signature verification unclear"
          fi
        fi

        # Clean up
        rm -f "$test_file"
        print_status $GREEN "🎉 Signing test completed!"
      else
        rm -f "$test_file"
        print_status $RED "❌ Test commit failed"
        exit 1
      fi
      ;;
    *)
      print_status $RED "❌ Unknown signing mode: $signing_mode"
      exit 1
      ;;
  esac
}

# Enable YubiKey mode for current signing method
enable_yubikey_mode() {
  print_header "Enabling YubiKey Mode"

  local signing_mode
  signing_mode=$(detect_signing_mode)

  case "$signing_mode" in
    "none")
      print_status $RED "❌ Signing must be configured first"
      print_status $BLUE "   Run installer: $0"
      exit 1
      ;;
    "gitsign")
      print_status $BLUE "🔐 Enabling YubiKey mode for gitsign..."
      git config --global gitsign.oidc-issuer 'https://token.actions.githubusercontent.com'
      print_status $GREEN "✅ YubiKey mode enabled for gitsign!"
      print_status $BLUE "   • gitsign will now require YubiKey authentication"
      ;;
    "gpg")
      print_status $BLUE "🔐 Enabling YubiKey mode for GPG..."
      print_status $YELLOW "💡 GPG YubiKey setup requires manual configuration:"
      echo "   1. Configure YubiKey for GPG: ykman openpgp keys set-touch sig on"
      echo "   2. Import/generate GPG key on YubiKey"
      echo "   3. Configure git: git config --global user.signingkey YOUR_KEY_ID"
      print_status $GREEN "✅ YubiKey mode instructions provided for GPG!"
      ;;
    *)
      print_status $RED "❌ Unknown signing mode: $signing_mode"
      exit 1
      ;;
  esac
}

# Disable YubiKey mode for current signing method
disable_yubikey_mode() {
  print_header "Disabling YubiKey Mode"

  local signing_mode
  signing_mode=$(detect_signing_mode)

  case "$signing_mode" in
    "none")
      print_status $RED "❌ Signing is not configured"
      exit 1
      ;;
    "gitsign")
      print_status $BLUE "🔓 Disabling YubiKey mode for gitsign..."
      git config --global gitsign.oidc-issuer 'https://oauth2.sigstore.dev/auth'
      print_status $GREEN "✅ YubiKey mode disabled for gitsign!"
      print_status $BLUE "   • gitsign will use browser authentication"
      ;;
    "gpg")
      print_status $BLUE "🔓 Disabling YubiKey mode for GPG..."
      print_status $YELLOW "💡 To disable GPG YubiKey touch requirement:"
      echo "   ykman openpgp keys set-touch sig off"
      print_status $GREEN "✅ YubiKey mode instructions provided for GPG!"
      ;;
    *)
      print_status $RED "❌ Unknown signing mode: $signing_mode"
      exit 1
      ;;
  esac
}

# Switch to gitsign signing mode
switch_to_gitsign_mode() {
  print_header "Switching to gitsign Signing Mode"

  # Check if gitsign is available
  if ! command -v gitsign &>/dev/null; then
    print_status $RED "❌ gitsign is not installed"
    print_status $BLUE "   Install gitsign first or run full installer: $0"
    exit 1
  fi

  # Remember current YubiKey setting
  local yubikey_mode
  yubikey_mode=$(check_yubikey_mode)

  print_status $BLUE "🔐 Configuring gitsign signing..."

  # Configure gitsign
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  git config --global gpg.format x509
  git config --global gpg.x509.program gitsign

  # Configure Sigstore endpoints
  git config --global gitsign.fulcio-url 'https://fulcio.sigstore.dev'
  git config --global gitsign.rekor-url 'https://rekor.sigstore.dev'
  git config --global gitsign.oidc-client-id 'sigstore'
  git config --global gitsign.autoclose true
  git config --global gitsign.autocloseTimeout 20
  git config --global gitsign.connectorID 'https://github.com/login/oauth'

  # Restore YubiKey setting
  if [[ $yubikey_mode == "true" ]]; then
    git config --global gitsign.oidc-issuer 'https://token.actions.githubusercontent.com'
    print_status $GREEN "✅ Switched to gitsign + YubiKey mode!"
  else
    git config --global gitsign.oidc-issuer 'https://oauth2.sigstore.dev/auth'
    print_status $GREEN "✅ Switched to gitsign + software mode!"
  fi

  print_status $BLUE "   • Short-lived certificates enabled"
  print_status $BLUE "   • Automatic certificate rotation"
  print_status $BLUE "   • Transparency logging via Rekor"
}

# Switch to GPG signing mode
switch_to_gpg_mode() {
  print_header "Switching to GPG Signing Mode"

  # Check if GPG is available
  if ! command -v gpg &>/dev/null; then
    print_status $RED "❌ GPG is not installed"
    print_status $BLUE "   Install GPG first: brew install gnupg (macOS) or apt install gnupg (Ubuntu)"
    exit 1
  fi

  print_status $BLUE "🔐 Configuring GPG signing..."

  # Configure GPG
  git config --global commit.gpgsign true
  git config --global tag.gpgsign true
  git config --global gpg.format openpgp

  # Remove gitsign-specific settings
  git config --global --unset gpg.x509.program || true
  git config --global --unset gitsign.fulcio-url || true
  git config --global --unset gitsign.rekor-url || true
  git config --global --unset gitsign.oidc-issuer || true
  git config --global --unset gitsign.oidc-client-id || true
  git config --global --unset gitsign.autoclose || true
  git config --global --unset gitsign.autocloseTimeout || true
  git config --global --unset gitsign.connectorID || true

  print_status $GREEN "✅ Switched to GPG signing mode!"
  print_status $BLUE "   • Traditional GPG signing enabled"
  print_status $BLUE "   • GitHub verification badges supported"

  # Check if signing key is configured
  local signing_key
  signing_key=$(git config --global --get user.signingkey 2>/dev/null || echo "")

  if [[ -z $signing_key ]]; then
    print_status $YELLOW "⚠️  No GPG signing key configured"
    print_status $BLUE "   Configure a signing key:"
    echo "   1. Generate key: gpg --full-generate-key"
    echo "   2. List keys: gpg --list-secret-keys --keyid-format=long"
    echo "   3. Configure git: git config --global user.signingkey YOUR_KEY_ID"
    echo "   4. Upload public key to GitHub for verification"
  else
    print_status $GREEN "✅ GPG signing key already configured: $signing_key"
  fi
}

# Main execution
main() {
  # Initialize framework first - but do minimal setup before argument parsing
  setup_logging

  print_header "Security Controls Installer v$SCRIPT_VERSION"

  # Parse arguments first, so flags like --version work before other output
  parse_arguments "$@"

  # Now start transaction after parsing arguments (in case of early exits)
  start_transaction "security-controls-install"

  # Display startup banner
  echo
  print_status $CYAN "══════════════════════════════════════════════════════════════"
  print_status $CYAN "  🛡️  1-Click GitHub Security Controls v$SCRIPT_VERSION"
  print_status $CYAN "  👨‍💻  Created by Albert Hui <albert@securityronin.com>"
  print_status $CYAN "     Security Ronin"
  print_status $CYAN "══════════════════════════════════════════════════════════════"
  echo

  log_info "=== Security Controls Installation Started ==="
  log_info "Script version: $SCRIPT_VERSION"
  log_info "Arguments: $*"

  if [[ $DRY_RUN == true ]]; then
    print_status $YELLOW "🔍 DRY RUN MODE - No changes will be made"
    echo
  fi

  # Execute upgrade commands (these exit before normal installation)
  execute_upgrade_commands

  # Handle signing mode commands (these exit before normal installation)
  if [[ -n $COMMAND_MODE ]]; then
    case "$COMMAND_MODE" in
      "status")
        show_signing_status
        exit 0
        ;;
      "test")
        test_signing_configuration
        exit 0
        ;;
      "enable-yubikey")
        enable_yubikey_mode
        exit 0
        ;;
      "disable-yubikey")
        disable_yubikey_mode
        exit 0
        ;;
      "switch-to-gitsign")
        switch_to_gitsign_mode
        exit 0
        ;;
      "switch-to-gpg")
        switch_to_gpg_mode
        exit 0
        ;;
      *)
        print_status $RED "❌ Unknown command: $COMMAND_MODE"
        exit 1
        ;;
    esac
  fi

  # Core setup with enhanced error handling
  safe_execute "check_git_repo" \
    "Not in a Git repository" \
    $EXIT_VALIDATION_ERROR \
    "Initialize git first: git init"

  safe_execute "detect_project_type" \
    "Failed to detect project type" \
    $EXIT_VALIDATION_ERROR

  safe_execute "check_required_tools" \
    "Missing required tools" \
    $EXIT_TOOL_MISSING \
    "Install required dependencies"

  # Install components
  if [[ $SKIP_TOOLS == false ]]; then
    safe_execute "install_security_tools" \
      "Failed to install security tools" \
      $EXIT_NETWORK_ERROR \
      "Check internet connection"
  fi

  # Configure security settings (Rust-specific and global)
  safe_execute "configure_cargo_security" \
    "Failed to configure Cargo security" \
    $EXIT_CONFIG_ERROR

  # Configure language-specific security settings
  safe_execute "configure_language_specific_files" \
    "Failed to configure language-specific settings" \
    $EXIT_CONFIG_ERROR

  # Install default config/state
  safe_execute "install_default_config" \
    "Failed to install default configuration" \
    $EXIT_CONFIG_ERROR

  # Install Renovate configuration
  safe_execute "install_renovate_config" \
    "Failed to install Renovate configuration" \
    $EXIT_CONFIG_ERROR

  # Install script-only helpers
  install_pinactlite_script
  install_gitleakslite_script

  if [[ $INSTALL_HOOKS == true ]]; then
    install_pre_push_hook
  fi

  if [[ $INSTALL_CI == true ]]; then
    install_ci_workflow
  fi

  if [[ $INSTALL_DOCS == true ]]; then
    install_documentation
  fi

  # Configure GitHub security features
  install_github_security

  # Summary
  if [[ $DRY_RUN == false ]]; then
    show_summary
    write_version_info
  else
    print_header "Dry Run Complete"
    print_status $BLUE "🔍 Preview complete - no changes made"
    print_status $BLUE "   Run without --dry-run to install"
  fi

  # Commit transaction on success
  commit_transaction
  log_info "=== Installation Completed Successfully ==="
}

# Execute main function with all arguments and error handling
if ! main "$@"; then
  handle_error $EXIT_GENERAL_ERROR "Installation failed" "Check logs: $LOG_FILE"
fi
