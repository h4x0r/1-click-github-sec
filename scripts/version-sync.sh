#!/usr/bin/env bash

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

# version-sync.sh - Synchronize version numbers across all documentation
# Part of 1-Click GitHub Security Documentation Synchronization Framework
#
# Usage: ./scripts/version-sync.sh [VERSION]
# Example: ./scripts/version-sync.sh 0.3.8
#
# Maintains Single Source of Truth: VERSION file → All documentation

set -euo pipefail

# Configuration
readonly VERSION_FILE="VERSION"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_ROOT

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

show_usage() {
  cat <<EOF
🔄 Version Synchronization Tool

USAGE:
    $0 [VERSION]
    $0 --check
    $0 --help

DESCRIPTION:
    Synchronizes version numbers across all documentation files using VERSION file as
    Single Source of Truth (SSOT). Maintains consistency across:

    - VERSION file (authoritative source)
    - README.md badges and examples
    - install-security-controls.sh script version
    - CHANGELOG.md version headers
    - mkdocs.yml site info
    - Git tag verification examples
    - Download URL examples

OPTIONS:
    VERSION         Set new version (updates VERSION file and propagates)
    --check         Check version consistency across all files
    --help          Show this help message

EXAMPLES:
    $0 0.3.8              # Set new version and sync all files
    $0 --check            # Verify all versions are consistent

SINGLE-SCRIPT ARCHITECTURE COMPLIANCE:
    This tool is OPTIONAL - the installer works perfectly without it.
    This script helps maintainers keep documentation synchronized.

EOF
}

# Get current version from VERSION file
get_current_version() {
  if [[ -f $VERSION_FILE ]]; then
    cat "$VERSION_FILE" | tr -d '\n\r\s'
  else
    log_error "VERSION file not found!"
    exit 1
  fi
}

# Update version in VERSION file
set_version() {
  local new_version="$1"
  echo "$new_version" >"$VERSION_FILE"
  log_success "Updated VERSION file: $new_version"
}

# Update README.md version badge and examples
update_readme_version() {
  local version="$1"
  local readme="README.md"

  if [[ ! -f $readme ]]; then
    log_warning "README.md not found, skipping"
    return
  fi

  # Update version badge
  sed -i.bak "s/Version-v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/Version-v${version}/g" "$readme"

  # Update git tag verification example
  sed -i.bak2 "s/git tag -v v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/git tag -v v${version}/g" "$readme"

  # Update download examples in Quick Start section
  sed -i.bak3 "s|download/v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/|download/v${version}/|g" "$readme"

  rm -f "${readme}.bak" "${readme}.bak2" "${readme}.bak3"
  log_success "Updated README.md version badge and examples: v$version"
}

# Update installer script version
update_installer_version() {
  local version="$1"
  local installer="install-security-controls.sh"

  if [[ ! -f $installer ]]; then
    log_warning "install-security-controls.sh not found, skipping"
    return
  fi

  # Update INSTALLER_VERSION variable
  sed -i.bak "s/readonly INSTALLER_VERSION=\"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"/readonly INSTALLER_VERSION=\"${version}\"/g" "$installer"
  rm -f "${installer}.bak"
  log_success "Updated installer script version: $version"
}

# Update mkdocs.yml version
update_mkdocs_version() {
  local version="$1"
  local mkdocs="mkdocs.yml"

  if [[ ! -f $mkdocs ]]; then
    log_warning "mkdocs.yml not found, skipping"
    return
  fi

  # Update site version
  sed -i.bak "s/site_name: .* v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/site_name: 1-Click GitHub Security v${version}/g" "$mkdocs"
  rm -f "${mkdocs}.bak"
  log_success "Updated mkdocs.yml version: v$version"
}

# Check if CHANGELOG.md has entry for version
check_changelog_version() {
  local version="$1"
  local changelog="CHANGELOG.md"

  if [[ ! -f $changelog ]]; then
    log_warning "CHANGELOG.md not found, skipping check"
    return 0
  fi

  if grep -q "## \[${version}\]" "$changelog"; then
    log_success "CHANGELOG.md has entry for version $version"
    return 0
  else
    log_warning "CHANGELOG.md missing entry for version $version"
    log_info "Please add changelog entry manually"
    return 1
  fi
}

# Verify all versions are consistent
check_version_consistency() {
  local current_version
  current_version=$(get_current_version)
  local issues=0

  log_info "Checking version consistency (SSOT: $current_version)"
  echo

  # Check README.md
  if [[ -f "README.md" ]]; then
    local readme_issues=0

    # Check version badge
    if grep -q "Version-v${current_version}" README.md; then
      log_success "✅ README.md version badge: v$current_version"
    else
      log_error "❌ README.md version badge mismatch"
      ((readme_issues++))
    fi

    # Check git tag example
    if grep -q "git tag -v v${current_version}" README.md; then
      log_success "✅ README.md git tag example: v$current_version"
    else
      log_error "❌ README.md git tag example mismatch"
      ((readme_issues++))
    fi

    # Check download URLs
    if grep -q "download/v${current_version}/" README.md; then
      log_success "✅ README.md download URLs: v$current_version"
    else
      log_error "❌ README.md download URLs mismatch"
      ((readme_issues++))
    fi

    ((issues += readme_issues))
  fi

  # Check installer script
  if [[ -f "install-security-controls.sh" ]]; then
    if grep -q "readonly INSTALLER_VERSION=\"${current_version}\"" install-security-controls.sh; then
      log_success "✅ Installer script version: $current_version"
    else
      log_error "❌ Installer script version mismatch"
      ((issues++))
    fi
  fi

  # Check mkdocs.yml
  if [[ -f "mkdocs.yml" ]]; then
    if grep -q "v${current_version}" mkdocs.yml; then
      log_success "✅ MkDocs site version: v$current_version"
    else
      log_error "❌ MkDocs site version mismatch"
      ((issues++))
    fi
  fi

  # Check CHANGELOG.md
  check_changelog_version "$current_version" || ((issues++))

  echo
  if [[ $issues -eq 0 ]]; then
    log_success "🎯 All versions are consistent: $current_version"
    return 0
  else
    log_error "🚨 Found $issues version inconsistencies"
    log_info "Run: $0 $current_version (to fix inconsistencies)"
    return 1
  fi
}

# Sync all version references
sync_all_versions() {
  local version="$1"

  log_info "Synchronizing version $version across all files..."
  echo

  # Update all files
  set_version "$version"
  update_readme_version "$version"
  update_installer_version "$version"
  update_mkdocs_version "$version"

  # Check changelog
  if ! check_changelog_version "$version"; then
    log_info "Don't forget to update CHANGELOG.md with version $version entry"
  fi

  echo
  log_success "🎯 Version synchronization complete: $version"
  log_info "Next steps:"
  echo "  1. Review changes: git diff"
  echo "  2. Update CHANGELOG.md if needed"
  echo "  3. Commit changes: git add . && git commit -m 'version: bump to $version'"
  echo "  4. Create SIGNED release: git tag -s v$version -m 'Release message' && git push --tags"
  echo "     (Use -s flag for Sigstore/gitsign signing - stronger security than unsigned tags)"
}

# Main execution
main() {
  cd "$PROJECT_ROOT"

  case "${1:-}" in
    --help | -h)
      show_usage
      exit 0
      ;;
    --check)
      check_version_consistency
      exit $?
      ;;
    "")
      log_error "Missing version argument"
      show_usage
      exit 1
      ;;
    *)
      if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        sync_all_versions "$1"
      else
        log_error "Invalid version format: $1"
        log_info "Use semantic versioning format: X.Y.Z (e.g., 0.3.8)"
        exit 1
      fi
      ;;
  esac
}

# Execute main function
main "$@"
