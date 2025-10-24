# Upgrading Security Controls

This guide explains how to upgrade your security controls installation to the latest version.

## Table of Contents

- [Overview](#overview)
- [Automatic Upgrades](#automatic-upgrades)
- [Manual Upgrades](#manual-upgrades)
- [Understanding the Manifest System](#understanding-the-manifest-system)
- [Handling Customizations](#handling-customizations)
- [Troubleshooting](#troubleshooting)

## Overview

Starting with v0.9.0, the installer uses a **config-driven workflow generation system** for maximum simplicity and transparency.

### What's New in v0.9.0

**Major Simplification - Breaking Changes:**

- **Config-driven generation**: Workflows are now pure generated artifacts from `.security-controls/config.yml`
- **Merged workflows**: `security.yml` + `pinning-validation.yml` → `1cgs-security.yml` (single comprehensive workflow)
- **Prominent warnings**: All generated workflows have clear "DO NOT EDIT" headers
- **Simplified manifest**: Removed hash-based customization detection (YAGNI for 2 controlled users)
- **Auto-cleanup**: Old workflows automatically removed during upgrade
- **No backward compatibility**: v0.8.0 → v0.9.0 is not backward compatible (by design)

**How to customize workflows in v0.9.0:**
1. Edit `.security-controls/config.yml`
2. Re-run installer
3. Commit both `config.yml` + generated workflow

**Migration Path:**
- v0.8.0 installations: Automatically detected and upgraded
- Existing customizations: Preserved in `config.yml` (see nameback example)
- Old workflows: Deleted and replaced with `1cgs-security.yml`

### What Was New in v0.8.0 (Removed in v0.9.0)

- **Manifest tracking**: All installed components tracked in `.security-controls/manifest.yml`
- **Customization detection**: Automatically detects if you've modified workflows
- **Assisted upgrades**: Shows diffs for customized files and lets you choose
- **Automatic backups**: All workflows backed up before modification
- **Migration support**: Old installations automatically migrated to new system

## Automatic Upgrades

The installer automatically detects existing installations and triggers an upgrade:

```bash
# Simply run the installer again
./install-security-controls.sh
```

### What Happens Automatically

1. **Version Detection**: Installer detects you have v0.7.0 installed
2. **Migration** (if needed): Migrates old installation to manifest system
3. **Customization Analysis**: Scans workflows for modifications
4. **Categorization**:
   - **Pristine workflows**: Auto-upgraded without prompting
   - **Customized workflows**: Shows diffs, you choose what to do
   - **User workflows**: Skipped (never touched)

### Example Output

```
🔄 Existing installation detected (v0.7.0)
   Upgrading to v0.8.0 with modification detection...

Using manifest-based assisted upgrade...

Current version: 0.7.0
New version: 0.8.0

✅ Pristine workflows (will auto-upgrade): 1
   - pinning-validation.yml

⚠️  Customized workflows (need review): 1
   - security.yml

Proceed with upgrade? [Y/n]: y

📝 Upgrading pristine workflows...
💾 Backed up to: .security-controls/backups/2025-10-24-120000/pinning-validation.yml
✅ Updated: pinning-validation.yml

🔍 Reviewing customized workflows...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Customized workflow: security.yml
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Changes between your version and new template:

--- .github/workflows/security.yml  2025-10-24 10:00:00
+++ /tmp/new-security.yml          2025-10-24 12:00:00
@@ -205,7 +205,7 @@
-  export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH"
+  echo "PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:$PKG_CONFIG_PATH" >> $GITHUB_ENV
@@ -209,7 +209,7 @@
-  cargo cyclonedx --output-format json
+  cargo cyclonedx --format json

Options:
  1) Replace with new template (lose customizations, but get all improvements)
  2) Keep current version (miss new features and fixes)
  3) Save both for manual merge (new template saved to /tmp/)

Choice [1/2/3]: 1

⚠️  Replaced with new template
📝 Your customizations were backed up

✅ Upgrade complete!
```

## Manual Upgrades

You can also trigger upgrades explicitly:

```bash
# Run assisted upgrade
./install-security-controls.sh --upgrade

# Check for available updates
./install-security-controls.sh --check-update

# Create backup before upgrading
./install-security-controls.sh --backup
```

## Understanding the Manifest System

### The Manifest File

Located at `.security-controls/manifest.yml`, this file tracks:

```yaml
version: "1.0"
installer_version: "0.8.0"
install_date: "2025-10-24T12:00:00Z"
last_upgrade: "2025-10-24T12:00:00Z"

mode: "assisted"

components:
  workflows:
    security:
      source: "installer"
      template: "rust-security"
      template_version: "2.1.0"
      generated_hash: "abc123..."
      current_hash: "abc123..."
      customized: false
      last_updated: "2025-10-24T12:00:00Z"

    pinning-validation:
      source: "installer"
      template: "pinning-validation"
      template_version: "1.0.0"
      generated_hash: "def456..."
      current_hash: "def456..."
      customized: false
      last_updated: "2025-10-24T12:00:00Z"
```

### How Customization Detection Works

1. **Hash Comparison**: Installer compares `generated_hash` (when created) with `current_hash` (now)
2. **Different hash** = File was modified = Customized
3. **Same hash** = File unchanged = Pristine

### Workflow Categories

- **Pristine**: No modifications since installation → Auto-upgrade
- **Customized**: Modified by user → Show diff, user chooses
- **User-managed**: Not created by installer → Never touched

## Handling Customizations

### Option 1: Replace with New Template (Recommended)

**When to use**: You want all new features and fixes, can re-apply customizations

```
Choice [1/2/3]: 1
```

**What happens**:
- ✅ Get all new features and bug fixes
- ✅ Workflow backed up to `.security-controls/backups/`
- ❌ Lose your customizations (but they're backed up)

**After choosing this**:
1. Check backup: `.security-controls/backups/TIMESTAMP/security.yml`
2. Review your old customizations
3. Re-apply them if still needed (usually they're obsolete)

### Option 2: Keep Current Version

**When to use**: Your customizations are critical, can't lose them now

```
Choice [1/2/3]: 2
```

**What happens**:
- ✅ Keep your customizations
- ❌ Miss new features and bug fixes
- File marked as "user-managed" (won't prompt again)

**After choosing this**:
- You're responsible for maintaining this workflow
- Installer won't update it automatically anymore

### Option 3: Save Both for Manual Merge

**When to use**: You want to carefully merge changes yourself

```
Choice [1/2/3]: 3
```

**What happens**:
- New template saved to `/tmp/new-security.yml`
- Current version unchanged
- You can merge manually when ready

**How to merge manually**:
```bash
# Compare files
diff -u .github/workflows/security.yml /tmp/new-security.yml

# Use your favorite merge tool
meld .github/workflows/security.yml /tmp/new-security.yml

# Or use git mergetool if in git repo
git mergetool .github/workflows/security.yml
```

## Migration from Old Installations

### Automatic Migration

If you have an installation from v0.7.0 or earlier (no manifest), the installer will:

1. Detect old installation
2. Create manifest file
3. Scan existing workflows
4. Mark all as "potentially customized" (safe default)
5. Proceed with assisted upgrade

### Example Migration Output

```
⚠️  No manifest found - this is an old installation

🔄 Migrating to manifest-based upgrade system...
   Found existing security.yml
   Found existing pinning-validation.yml
✅ Migration complete - manifest created
   All existing workflows marked as potentially customized
   You can now use: ./install-security-controls.sh --upgrade

Now running assisted upgrade...
```

## Troubleshooting

### "No changes detected"

**Cause**: Workflows are identical to new templates
**Solution**: Nothing to do! You're already up-to-date

### "Manifest file corrupted"

**Cause**: Manual editing broke YAML syntax
**Solution**:
```bash
# Backup manifest
cp .security-controls/manifest.yml .security-controls/manifest.yml.bak

# Delete and regenerate
rm .security-controls/manifest.yml
./install-security-controls.sh --upgrade
```

### "Can't detect customizations"

**Cause**: `generated_hash` is "unknown" (migrated installation)
**Solution**: All migrated workflows treated as customized (safe default)

### "Want to undo upgrade"

**Cause**: Chose wrong option during upgrade
**Solution**:
```bash
# Find your backup
ls -la .security-controls/backups/

# Restore from backup
cp .security-controls/backups/TIMESTAMP/security.yml .github/workflows/

# Update manifest hash
# (or delete manifest and run upgrade again)
```

### "Lost customizations"

**Cause**: Chose option 1 (replace) but needed customizations
**Solution**:
```bash
# Your customizations are backed up!
cat .security-controls/backups/TIMESTAMP/security.yml

# Find the lines you need and re-apply them
```

## Best Practices

### Before Upgrading

1. **Commit your changes**: `git commit -am "Before security controls upgrade"`
2. **Review customizations**: Know what you've changed and why
3. **Backup if unsure**: `./install-security-controls.sh --backup`

### During Upgrade

1. **Read diffs carefully**: Understand what's changing
2. **Choose wisely**:
   - Option 1 if customizations are obsolete
   - Option 2 if customizations are critical
   - Option 3 if you need time to review
3. **Test after upgrade**: Run workflows to ensure they work

### After Upgrading

1. **Review backups**: Keep them until you're confident
2. **Test workflows**: Push a test commit, verify CI passes
3. **Clean up old backups**: After 30 days, delete old backups

## Version History

### v0.8.0 (Current)
- ✅ Manifest-based tracking
- ✅ Assisted upgrades with customization detection
- ✅ Automatic backups
- ✅ Migration from v0.7.0 and earlier

### v0.7.0
- Added action pins auto-update system
- Weekly automation workflow
- No manifest tracking (old system)

### v0.6.12 and earlier
- Manual version management
- No automatic upgrade detection
- Used `safe-upgrade.sh` script

## See Also

- [README.md](../README.md) - Installation guide
- [CHANGELOG.md](../CHANGELOG.md) - Version history
- [manifest.yml](.security-controls/manifest.yml) - Your installation manifest
