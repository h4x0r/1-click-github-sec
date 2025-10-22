# Safe Upgrade System

## Overview

The Safe Upgrade System provides **integrity verification and user modification detection** during security controls upgrades. It prevents accidental loss of user customizations by detecting changes and providing interactive upgrade decisions.

## Problem Statement

**Current Risk**: When upgrading security controls, user customizations can be silently overwritten without warning.

**Examples of User Customizations**:
- Modified pre-push hooks with project-specific checks
- Customized gitleaks rules for false positive reduction
- Adjusted pinactlite allowlists for trusted actions
- Modified workflow templates for CI/CD requirements

**Without Safe Upgrade** (old behavior):
```bash
# User customizes pre-push hook
$ edit .git/hooks/pre-push  # Add project-specific checks

# Runs manual upgrade script
$ ./install-security-controls.sh --force  # bypasses safe upgrade

# ❌ Customizations lost - no warning!
```

**With Safe Upgrade** (automatic):
```bash
# User just runs installer again
$ ./install-security-controls.sh

🔍 Checking for user modifications...
⚠️  File modified: .git/hooks/pre-push

📝 Changes detected:
  + # Project-specific security check
  + check_internal_compliance()

What would you like to do with this file?
  1. Keep my version (skip upgrade for this file)
  2. Replace with new version (your changes will be lost)
  3. Backup my version and install new version

Choose option [1/2/3]: 3
✅ Backed up to: .security-controls/backup/pre-push.20251021_211500.backup
✅ Installed new version
```

## Design Principles

### 1. **Don't Make Me Think (DMMT)**
- **Auto-detect modifications**: System automatically identifies changed files
- **Show, don't tell**: Display actual diffs, not vague warnings
- **Guide decisions**: Clear options with consequences explained
- **Safe defaults**: Always backup before replacement

### 2. **Trust Through Transparency**
- **Version-specific hashes**: Known good state for each release
- **Diff display**: See exact changes before deciding
- **Audit trail**: All backups timestamped and preserved
- **Verification**: Confirm integrity before and after upgrade

### 3. **Fail Secure**
- **Block unknown**: If hash unknown, ask user (don't assume)
- **Preserve on doubt**: When uncertain, keep user version
- **Reversible operations**: All replacements backed up
- **Verification gates**: Verify new installation after upgrade

## Architecture

### Version-Specific Hash Registry

Each release includes SHA256 hashes for all managed files:

```bash
# Hash registry structure
declare -A VERSION_HASHES

# Version 0.6.10 known good hashes
VERSION_HASHES["0.6.10|.security-controls/bin/pinactlite"]="8869c009..."
VERSION_HASHES["0.6.10|.security-controls/bin/gitleakslite"]="a1b2c3d4..."
VERSION_HASHES["0.6.10|.git/hooks/pre-push"]="e5f6g7h8..."

# Version 0.6.9 known good hashes
VERSION_HASHES["0.6.9|.security-controls/bin/pinactlite"]="9c580e3a..."
```

**How It Works**:
1. Detect installed version from `.security-controls/.version`
2. Look up expected hash for each file at that version
3. Calculate actual hash of installed file
4. Compare: `expected_hash == actual_hash`
   - Match → File intact (safe to replace)
   - Mismatch → File modified (ask user)
   - Unknown → No hash for this version (ask user)

### File Integrity States

```
┌─────────────────────────────────────────────────────────────┐
│                     File Integrity Check                     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ├─► [Intact] ✅
                            │   Expected hash matches actual
                            │   → Safe to replace
                            │
                            ├─► [Modified] ⚠️
                            │   Hash mismatch detected
                            │   → Show diff, ask user
                            │
                            ├─► [Missing] ❌
                            │   File expected but not found
                            │   → Install new version
                            │
                            └─► [Unknown] ❓
                                No hash record for this version
                                → Ask user, proceed with caution
```

### Interactive Upgrade Workflow

```
1. Version Detection
   ├─ Read .security-controls/.version
   └─ Extract current version number

2. Integrity Verification
   ├─ For each managed file:
   │  ├─ Get expected hash for current version
   │  ├─ Calculate actual file hash
   │  └─ Compare and classify state
   └─ Generate integrity report

3. Modification Handling
   ├─ If modifications detected:
   │  ├─ Display summary of modified files
   │  ├─ Offer options:
   │  │  ├─ [1] Review each file (show diffs)
   │  │  ├─ [2] Backup all and proceed
   │  │  └─ [3] Cancel upgrade
   │  └─ Execute user choice
   └─ If all intact: proceed to upgrade

4. Per-File Interactive Review
   ├─ For each modified file:
   │  ├─ Show diff (current vs new)
   │  ├─ Ask: Keep / Replace / Backup+Replace
   │  └─ Record decision
   └─ Apply all decisions atomically

5. Upgrade Execution
   ├─ Backup modified files (if selected)
   ├─ Download new installer
   ├─ Run installation with recorded decisions
   └─ Verify new installation integrity

6. Post-Upgrade Verification
   ├─ Check all files match new version hashes
   ├─ Generate upgrade report
   └─ Notify user of backup locations
```

## Usage

### Automatic Upgrade Detection (DMMT)

**Don't Make Me Think**: The installer automatically detects existing installations and triggers safe upgrade.

```bash
# User just runs installer - system detects it's an upgrade
$ ./install-security-controls.sh

🔄 Existing installation detected (v0.6.9)
   Upgrading to v0.6.10 with modification detection...

🔍 Checking for user modifications...
⚠️  File modified: .git/hooks/pre-push

# Interactive workflow begins automatically...
```

**How It Works**:
1. Installer checks for `.security-controls-version` file
2. If version ≠ installer version → auto-run safe-upgrade
3. Safe upgrade handles integrity checks and user decisions
4. No manual script execution needed

### Manual Safe Upgrade

You can also run safe-upgrade directly (default behavior):

```bash
# Safe upgrade with user confirmation (DEFAULT)
$ ./scripts/safe-upgrade.sh

# Same as above - safe upgrade is default when no args
```

### Check Installation Integrity

Verify current installation without upgrading:

```bash
$ ./scripts/safe-upgrade.sh --check

🔍 Verifying installation integrity for version 0.6.10

✅ .security-controls/bin/pinactlite - intact
✅ .security-controls/bin/gitleakslite - intact
⚠️  .git/hooks/pre-push - MODIFIED
✅ .git/hooks/pre-commit - intact

📊 Integrity Verification Summary:
   Total files checked:  4
   Intact:               3
   Modified:             1
   Missing:              0
   Unknown/Not tracked:  0

⚠️ Modified files detected:
   • .git/hooks/pre-push
```

### Interactive Upgrade Workflow

When safe-upgrade runs (automatically or manually), it provides interactive decisions:

```bash
$ ./scripts/safe-upgrade.sh  # or just run installer

🔄 Starting safe upgrade process...

Current installation: version 0.6.10

🔍 Checking for user modifications...

✅ .security-controls/bin/pinactlite - intact
⚠️  .git/hooks/pre-push - MODIFIED

⚠️  Modified files detected in current installation
These files differ from the original version 0.6.10 installation.
They may contain your customizations or local changes.

Options:
  1. View diffs and decide per file (recommended)
  2. Backup all and proceed with upgrade
  3. Cancel upgrade

Choose option [1/2/3]: 1

───────────────────────────────────────────────────────────
File modified: .git/hooks/pre-push

📝 Changes detected:
  @@ -150,6 +150,12 @@
   # Run security checks
   run_security_checks

  +# Project-specific compliance check
  +if [[ -f ".compliance/check.sh" ]]; then
  +  .compliance/check.sh || exit 1
  +fi
  +
   # Push if all checks pass
   exit 0
───────────────────────────────────────────────────────────

What would you like to do with this file?
  1. Keep my version (skip upgrade for this file)
  2. Replace with new version (your changes will be lost)
  3. Backup my version and install new version

Choose option [1/2/3]: 3

✅ Backed up to: .security-controls/backup/pre-push.20251021_211500.backup
Will install new version of .git/hooks/pre-push

📥 Downloading new installer version...
🚀 Running upgrade...
✅ Upgrade completed successfully

📋 Upgrade Summary:
   Files replaced:  1
   Files kept:      0
   Backups created: 1

💡 To restore your customizations:
   $ diff .git/hooks/pre-push .security-controls/backup/pre-push.20251021_211500.backup
   $ # Cherry-pick desired changes
```

### Force Upgrade (NOT Recommended)

Skip all confirmations (dangerous):

```bash
$ ./scripts/safe-upgrade.sh --force

⚠️  Force mode: skipping safety confirmations
🔄 Starting safe upgrade process...
⚠️  Force mode: proceeding without confirmation
📥 Downloading new installer version...
🚀 Running upgrade...
✅ Upgrade completed successfully
```

## Implementation in Installer

### Automatic Upgrade Detection

The installer **automatically detects** existing installations and triggers safe upgrade:

```bash
# In install-security-controls.sh - execute_upgrade_commands()

# AUTO-DETECT EXISTING INSTALLATION (DMMT: Don't Make Me Think)
if [[ -f $VERSION_FILE ]]; then
  installed_version=$(get_installed_version)

  # If we detect a different version, auto-run safe-upgrade
  if [[ $installed_version != "$SCRIPT_VERSION" && $installed_version != "unknown" ]]; then
    print_status $BLUE "🔄 Existing installation detected (v$installed_version)"
    print_status $BLUE "   Upgrading to v$SCRIPT_VERSION with modification detection..."

    # Auto-run safe-upgrade (default behavior is safe upgrade)
    if [[ -x ./scripts/safe-upgrade.sh ]]; then
      exec ./scripts/safe-upgrade.sh
    else
      # Fallback: warn user about risks
      print_status $YELLOW "⚠️  Safe upgrade script not found"
      read -rp "Continue with standard upgrade? [y/N]: " confirm
      [[ ! $confirm =~ ^[Yy]$ ]] && exit 0
    fi
  fi
fi
```

**Key Features**:
- ✅ **Zero user action**: Just run installer again
- ✅ **Version comparison**: Automatically detects upgrades
- ✅ **Safe fallback**: Warns if safe-upgrade unavailable
- ✅ **User confirmation**: Asks before risky operations

### Version Tracking

During installation, version info is recorded:

```bash
# Write version file during installation
write_version_info() {
  cat >"$VERSION_FILE" <<EOF
# Security Controls Installation Information
version="$SCRIPT_VERSION"
install_date="$(date)"
installer_version="$SCRIPT_VERSION"
project_type="$(detect_project_type)"
EOF
}
```

## Hash Registry Generation

### Automated Release Process

Hash registries are **automatically generated** during releases via GitHub Actions:

```yaml
# .github/workflows/release.yml

- name: Generate hash registry for safe-upgrade
  run: |
    # Extract version from tag (remove 'v' prefix)
    VERSION="${{ github.ref_name }}"
    VERSION="${VERSION#v}"

    echo "🔐 Generating hash registry for version $VERSION"

    # Generate hash registry in all formats
    ./scripts/generate-release-hashes.sh "$VERSION" --format bash
    ./scripts/generate-release-hashes.sh "$VERSION" --format json
    ./scripts/generate-release-hashes.sh "$VERSION" --format yaml

- name: Create Release
  uses: softprops/action-gh-release@v2
  with:
    files: |
      install-security-controls.sh
      checksums.txt
      release-hashes-*.txt   # Bash format (for embedding)
      release-hashes-*.json  # JSON format (auto-download)
      release-hashes-*.yaml  # YAML format (documentation)
```

**Workflow**:
1. Developer creates git tag (e.g., `v0.6.11`)
2. GitHub Actions workflow triggered automatically
3. Hash registry generated in 3 formats
4. All formats uploaded to GitHub release
5. Safe-upgrade auto-downloads JSON registry

**Zero Manual Steps** (DMMT compliance):
- ✅ No manual hash generation
- ✅ No manual file uploads
- ✅ No manual registry updates
- ✅ Consistent hashes for every release

### Manual Hash Generation (Debugging)

For local testing or debugging:

```bash
# Generate hash registry for version 0.6.11
$ ./scripts/generate-release-hashes.sh 0.6.11

🔐 Generating release hash registry for version 0.6.11
Format: bash
Output: release-hashes-0.6.11.txt

Calculating file hashes...
✅ .security-controls/bin/pinactlite
✅ .security-controls/bin/gitleakslite
✅ install-security-controls.sh

✅ Hash registry generated: release-hashes-0.6.11.txt
```

## Security Considerations

### Hash Verification Security

**Threat Model**:
- **Attacker modifies files**: Detected by hash mismatch
- **Attacker modifies hash registry**: Requires repository access + signed commit
- **Attacker intercepts upgrade**: Checksums verified during download
- **Attacker downgrades**: Version number increases monotonically

**Defense in Depth**:
1. **Signed Commits**: All releases signed with Sigstore/gitsign
2. **Checksum Verification**: Installer checksums verified before execution
3. **Version Monotonicity**: Downgrade detection prevents rollback attacks
4. **Backup Integrity**: Backups also hashed and verified

### Privacy Considerations

**No Telemetry**: Safe upgrade system operates entirely locally. No data sent to external services.

**Backup Contents**: Backups may contain sensitive customizations. Stored in `.security-controls/backup/` (gitignored).

## Implemented Enhancements

### ✅ Automatic Hash Registry Downloads

**Status**: Implemented in v0.7.0

Download version-specific hash registries from GitHub releases:

```bash
$ ./scripts/safe-upgrade.sh --download-hashes 0.7.0

📥 Downloading hash registry for version 0.7.0...
✅ Downloaded hash registry from releases
✅ Importing hashes from JSON registry...
✅ Imported 5 file hashes from registry

# Auto-fallback to embedded hashes if download fails
⚠️ Could not download hash registry from GitHub releases
ℹ️ Falling back to embedded hash registry
```

**Implementation**: `download_hash_registry()` function
- Fetches from: `https://github.com/h4x0r/1-click-github-sec/releases/download/v{VERSION}/release-hashes-{VERSION}.json`
- Supports JSON and YAML formats
- Automatic fallback to embedded hashes
- Uses `jq` for JSON parsing (optional dependency)

### ✅ Rollback Capability

**Status**: Implemented in v0.7.0

Restore from previous backups interactively:

```bash
$ ./scripts/safe-upgrade.sh --rollback

🔄 Rollback Wizard

📦 Available backups:

  1. Backup from 2025-10-21 21:15:00 (3 files)
  2. Backup from 2025-10-15 14:30:00 (3 files)

Choose backup to restore [1-2] or 'q' to quit: 1

Selected backup timestamp: 20251021_211500

Files to restore:
  • pinactlite
  • gitleakslite
  • pre-push

Restore these files? [y/N]: y

Restoring backup...
✅ Restored .security-controls/bin/pinactlite
✅ Restored .security-controls/bin/gitleakslite
✅ Restored .git/hooks/pre-push

✅ Rollback completed

💡 Tip: Run --check to verify restored installation
```

**Implementation**: `rollback_to_backup()` function
- Lists timestamped backups from `.security-controls/backup/`
- Groups files by backup timestamp
- Interactive selection with confirmation
- Restores all files from selected backup
- Verification suggested after rollback

### ✅ Merge Tool Integration

**Status**: Implemented in v0.7.0

Use visual merge tools to resolve conflicts:

```bash
$ MERGE_TOOL=meld ./scripts/safe-upgrade.sh --upgrade

⚠️  File modified: .git/hooks/pre-push

📝 Changes detected:
  [diff display]

What would you like to do?
  1. Keep my version (skip upgrade for this file)
  2. Replace with new version (your changes will be lost)
  3. Backup my version and install new version
  4. Use merge tool to combine changes interactively

Choose option [1/2/3/4]: 4

Launching meld for 3-way merge...

Instructions:
  • LEFT: Your current version
  • RIGHT: New version from upgrade
  • Save merged result and exit merge tool to continue

[meld opens with 3-pane view]

✅ Merge completed
✅ Backed up to: .security-controls/backup/pre-push.20251021_211500.backup
✅ Installed merged version
```

**Implementation**: `merge_with_tool()` and `handle_modified_file_with_merge()` functions
- Auto-detects: meld, kdiff3, vimdiff (in preference order)
- Environment variable: `MERGE_TOOL` for manual selection
- 3-way merge support (base, current, new)
- Automatic backup before applying merge
- Merge result validation

**Supported Merge Tools**:
| Tool | Type | Auto-Merge | Visual | Installation |
|------|------|-----------|--------|--------------|
| **meld** | GUI | Partial | ✅ | `brew install meld` |
| **kdiff3** | GUI | Yes | ✅ | `brew install kdiff3` |
| **vimdiff** | TUI | No | 🟡 | Built-in with vim |

### ✅ Automated Hash Registry Generation

**Status**: Implemented in v0.7.0

Generate version-specific hash registries for releases:

```bash
$ ./scripts/generate-release-hashes.sh 0.7.0 --format json

✅ Valid version format: 0.7.0
🔐 Generating release hash registry for version 0.7.0
Format: json
Output: release-hashes-0.7.0.json

Calculating file hashes...
✅ .security-controls/bin/pinactlite
✅ .security-controls/bin/gitleakslite
✅ install-security-controls.sh
✅ uninstall-security-controls.sh
✅ yubikey-gitsign-toggle.sh

✅ Generated JSON format with 5 files

Signing manifest with GPG...
✅ Created signature: release-hashes-0.7.0.json.asc

✅ Hash registry generated: release-hashes-0.7.0.json

📋 Integration Instructions:
   1. Include in GitHub release:
      $ gh release upload v0.7.0 release-hashes-0.7.0.json

   2. Safe upgrade will auto-download from:
      https://github.com/h4x0r/1-click-github-sec/releases/download/v0.7.0/release-hashes-0.7.0.json

💡 Next Steps:
   • Commit hash registry to repository
   • Tag release: git tag -s v0.7.0 -m 'Release v0.7.0'
   • Push release: git push origin v0.7.0
   • Create GitHub release with hash registry attached
```

**Implementation**: `scripts/generate-release-hashes.sh`
- Multiple formats: bash (for embedding), json (API), yaml (docs)
- Semantic version validation
- GPG signature generation (optional)
- SHA256 hash calculation for all managed files
- Integration instructions
- Release workflow guidance

**Output Formats**:
```json
// JSON format (release-hashes-0.7.0.json)
{
  "version": "0.7.0",
  "generated": "2025-10-22T03:15:00Z",
  "repository": "https://github.com/h4x0r/1-click-github-sec",
  "hashes": {
    ".security-controls/bin/pinactlite": "1fa109bc...",
    ".security-controls/bin/gitleakslite": "a1b2c3d4...",
    ...
  }
}
```

```yaml
# YAML format (release-hashes-0.7.0.yaml)
version: 0.7.0
generated: 2025-10-22T03:15:00Z
repository: https://github.com/h4x0r/1-click-github-sec
hashes:
  .security-controls/bin/pinactlite: 1fa109bc...
  .security-controls/bin/gitleakslite: a1b2c3d4...
```

```bash
# Bash format (release-hashes-0.7.0.txt)
# Ready for copy/paste into safe-upgrade.sh
VERSION_HASHES["0.7.0|.security-controls/bin/pinactlite"]="1fa109bc..."
VERSION_HASHES["0.7.0|.security-controls/bin/gitleakslite"]="a1b2c3d4..."
```

## Future Enhancements (Proposed)

### Differential Hash Updates

Only download hash diff between versions instead of full registry:

```bash
# Proposed: Fetch only new/changed hashes
download_hash_diff() {
  local from_version="$1"
  local to_version="$2"

  # Download differential update
  curl -sSL "https://.../v${to_version}/hash-diff-${from_version}-to-${to_version}.json"
}
```

### Smart Conflict Resolution

Use AI/ML to suggest conflict resolutions:

```bash
# Proposed: AI-assisted merge suggestions
analyze_conflict() {
  # Analyze both versions
  # Suggest safe merge strategy
  # Highlight potential issues
}
```

## Related Documentation

- [Installation Guide](installation.md) - Initial installation process
- [CLAUDE.md § 2 (DMMT)](../CLAUDE.md#2-dont-make-me-think-dmmt---universal-design-principle) - Design principle behind safe upgrades
- [Version Sync](../scripts/version-sync.sh) - Version number management across repository

## License

Same as main project: Apache License 2.0

---

**Last Updated**: 2025-10-22
**Version**: 1.0.0
**Author**: Albert Hui <albert@securityronin.com>
