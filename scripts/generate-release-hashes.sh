#!/usr/bin/env bash

# Copyright 2025 Albert Hui <albert@securityronin.com>
# Licensed under the Apache License, Version 2.0

# generate-release-hashes.sh - Generate version-specific file hash registry
# Used during release process to create known-good hash manifest
#
# Usage: ./scripts/generate-release-hashes.sh VERSION
#
# Example: ./scripts/generate-release-hashes.sh 0.6.11

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT

# Colors
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

show_usage() {
  cat <<EOF
🔐 Release Hash Registry Generator

USAGE:
    $0 VERSION [OPTIONS]

ARGUMENTS:
    VERSION             Version number (e.g., 0.6.11, 1.0.0)

OPTIONS:
    --output FILE       Output file (default: release-hashes-VERSION.txt)
    --format FORMAT     Output format: bash|json|yaml (default: bash)
    --help              Show this help

DESCRIPTION:
    Generates version-specific file hash registry for safe upgrade system.
    Calculates SHA256 hashes for all managed files and outputs in format
    suitable for inclusion in safe-upgrade.sh or distribution via releases.

WORKFLOW:
    1. Validate version number format
    2. Calculate SHA256 for all managed files
    3. Generate hash manifest in requested format
    4. Sign manifest (if GPG available)
    5. Output integration instructions

EXAMPLES:
    $0 0.6.11                      # Generate bash format
    $0 1.0.0 --format json         # Generate JSON format
    $0 1.0.0 --output hashes.txt   # Custom output file

OUTPUT FORMATS:
    bash:   Ready for copy/paste into safe-upgrade.sh
    json:   Machine-readable for API consumption
    yaml:   Human-readable for documentation

EOF
}

# Validate version format (semantic versioning)
validate_version() {
  local version="$1"

  if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format: $version"
    log_info "Expected format: MAJOR.MINOR.PATCH (e.g., 0.6.11)"
    return 1
  fi

  log_success "Valid version format: $version"
}

# List of managed files to hash
get_managed_files() {
  cat <<EOF
.security-controls/bin/pinactlite
.security-controls/bin/gitleakslite
install-security-controls.sh
uninstall-security-controls.sh
yubikey-gitsign-toggle.sh
EOF
}

# Calculate hash for a file
calculate_hash() {
  local file="$1"

  if [[ ! -f $file ]]; then
    echo "FILE_MISSING"
    return 1
  fi

  sha256sum "$file" | cut -d' ' -f1
}

# Generate bash format output
generate_bash_format() {
  local version="$1"
  local output_file="$2"

  cat >"$output_file" <<EOF
# Version $version File Hashes
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Repository: https://github.com/h4x0r/1-click-github-sec
#
# Add these lines to scripts/safe-upgrade.sh init_hash_registry() function:

EOF

  log_info "Calculating file hashes..."
  local file_count=0

  while IFS= read -r file; do
    local hash
    hash=$(calculate_hash "$file")

    if [[ $hash == "FILE_MISSING" ]]; then
      log_warning "Skipping missing file: $file"
      continue
    fi

    echo "VERSION_HASHES[\"$version|$file\"]=\"$hash\"" >>"$output_file"
    log_success "✅ $file"
    ((file_count++))
  done < <(get_managed_files)

  echo "" >>"$output_file"
  echo "# Total files: $file_count" >>"$output_file"

  log_success "Generated bash format with $file_count files"
}

# Generate JSON format output
generate_json_format() {
  local version="$1"
  local output_file="$2"

  cat >"$output_file" <<EOF
{
  "version": "$version",
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "repository": "https://github.com/h4x0r/1-click-github-sec",
  "hashes": {
EOF

  log_info "Calculating file hashes..."
  local file_count=0
  local files_array=()

  while IFS= read -r file; do
    local hash
    hash=$(calculate_hash "$file")

    if [[ $hash == "FILE_MISSING" ]]; then
      log_warning "Skipping missing file: $file"
      continue
    fi

    files_array+=("$file:$hash")
    log_success "✅ $file"
    ((file_count++))
  done < <(get_managed_files)

  # Output JSON entries
  local i=0
  for entry in "${files_array[@]}"; do
    local file="${entry%:*}"
    local hash="${entry#*:}"

    echo -n "    \"$file\": \"$hash\"" >>"$output_file"

    if [[ $i -lt $((${#files_array[@]} - 1)) ]]; then
      echo "," >>"$output_file"
    else
      echo "" >>"$output_file"
    fi

    ((i++))
  done

  cat >>"$output_file" <<EOF
  }
}
EOF

  log_success "Generated JSON format with $file_count files"
}

# Generate YAML format output
generate_yaml_format() {
  local version="$1"
  local output_file="$2"

  cat >"$output_file" <<EOF
version: $version
generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
repository: https://github.com/h4x0r/1-click-github-sec
hashes:
EOF

  log_info "Calculating file hashes..."
  local file_count=0

  while IFS= read -r file; do
    local hash
    hash=$(calculate_hash "$file")

    if [[ $hash == "FILE_MISSING" ]]; then
      log_warning "Skipping missing file: $file"
      continue
    fi

    echo "  $file: $hash" >>"$output_file"
    log_success "✅ $file"
    ((file_count++))
  done < <(get_managed_files)

  log_success "Generated YAML format with $file_count files"
}

# Sign manifest with GPG (if available)
sign_manifest() {
  local file="$1"

  if ! command -v gpg >/dev/null 2>&1; then
    log_warning "GPG not found - skipping signature"
    return 0
  fi

  log_info "Signing manifest with GPG..."

  if gpg --detach-sign --armor "$file"; then
    log_success "Created signature: ${file}.asc"
  else
    log_warning "GPG signing failed (continuing without signature)"
  fi
}

# Main function
main() {
  cd "$PROJECT_ROOT"

  local version=""
  local output_file=""
  local format="bash"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help | -h)
        show_usage
        exit 0
        ;;
      --output)
        output_file="$2"
        shift 2
        ;;
      --format)
        format="$2"
        shift 2
        ;;
      -*)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
      *)
        if [[ -z $version ]]; then
          version="$1"
        else
          log_error "Unexpected argument: $1"
          show_usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate version
  if [[ -z $version ]]; then
    log_error "Version argument required"
    show_usage
    exit 1
  fi

  validate_version "$version" || exit 1

  # Set default output file
  if [[ -z $output_file ]]; then
    case $format in
      bash) output_file="release-hashes-${version}.txt" ;;
      json) output_file="release-hashes-${version}.json" ;;
      yaml) output_file="release-hashes-${version}.yaml" ;;
      *)
        log_error "Unknown format: $format"
        exit 1
        ;;
    esac
  fi

  log_info "🔐 Generating release hash registry for version $version"
  log_info "Format: $format"
  log_info "Output: $output_file"
  echo ""

  # Generate manifest
  case $format in
    bash)
      generate_bash_format "$version" "$output_file"
      ;;
    json)
      generate_json_format "$version" "$output_file"
      ;;
    yaml)
      generate_yaml_format "$version" "$output_file"
      ;;
  esac

  # Sign manifest
  sign_manifest "$output_file"

  echo ""
  log_success "✅ Hash registry generated: $output_file"
  echo ""

  # Show integration instructions
  case $format in
    bash)
      log_info "📋 Integration Instructions:"
      echo "   1. Review the generated hashes:"
      echo "      $ cat $output_file"
      echo ""
      echo "   2. Add to scripts/safe-upgrade.sh init_hash_registry() function"
      echo "      $ cat $output_file >> scripts/safe-upgrade.sh  # (manual editing required)"
      echo ""
      echo "   3. Include in GitHub release:"
      echo "      $ gh release upload v${version} $output_file"
      ;;
    json | yaml)
      log_info "📋 Integration Instructions:"
      echo "   1. Include in GitHub release:"
      echo "      $ gh release upload v${version} $output_file"
      echo ""
      echo "   2. Safe upgrade will auto-download from:"
      echo "      https://github.com/h4x0r/1-click-github-sec/releases/download/v${version}/$output_file"
      ;;
  esac

  echo ""
  log_info "💡 Next Steps:"
  echo "   • Commit hash registry to repository"
  echo "   • Tag release: git tag -s v${version} -m 'Release v${version}'"
  echo "   • Push release: git push origin v${version}"
  echo "   • Create GitHub release with hash registry attached"
}

main "$@"
