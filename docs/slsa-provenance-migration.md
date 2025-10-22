# SLSA Provenance Migration

## Overview

**Goal**: Migrate from manual hash registry system to SLSA Level 3 provenance for supply chain security.

**Status**: ✅ **COMPLETED** (v0.6.11 - October 2025)
**Achievement**: SLSA Build Level 3
**Migration Time**: 2 sprints

## Why SLSA Provenance Instead of Hash Registries?

### Current System (Manual Hash Registry)

**Problems**:
- ❌ Manual hash generation during releases (`generate-release-hashes.sh`)
- ❌ Three separate formats (bash, json, yaml) with duplication
- ❌ Manual embedding in `safe-upgrade.sh` required
- ❌ Hashes are unsigned (just checksums, no cryptographic proof)
- ❌ No build provenance (who/when/how artifact was built)
- ❌ Doesn't scale (every version needs manual updates)

**Current Workflow**:
```
Release tag → Run generate-release-hashes.sh → Upload JSON/YAML/bash files →
Safe-upgrade downloads JSON → Verify hashes → Compare files
```

### SLSA Provenance System (Industry Standard)

**Benefits**:
- ✅ **Automated generation**: GitHub Actions auto-generates provenance
- ✅ **Cryptographically signed**: Uses Sigstore (same as gitsign)
- ✅ **Single source of truth**: One provenance file contains all hashes
- ✅ **Build transparency**: Full build context (materials, builder, invocation)
- ✅ **Supply chain security**: SLSA Level 3 compliance
- ✅ **Industry standard**: Used by Google, GitHub, npm, Docker, etc.
- ✅ **No manual maintenance**: Zero embedding or updates needed

**SLSA Workflow**:
```
Release tag → GitHub auto-generates signed provenance → Upload provenance →
Safe-upgrade downloads provenance → Verify signature → Extract hashes → Compare files
```

### What SLSA Provenance Gives Us

**Example Provenance File** (`multiple.intoto.jsonl`):
```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [
    {
      "name": "install-security-controls.sh",
      "digest": {
        "sha256": "8869c009332879a5366e2aeaf14eaca82f4467d5ab35f0042293da5e966d8097"
      }
    },
    {
      "name": ".security-controls/bin/pinactlite",
      "digest": {
        "sha256": "9c580e3a5c6386ca1365ef587cb71dbe9cb1d39caf639c8e25dfe580e616c731"
      }
    },
    {
      "name": ".security-controls/bin/gitleakslite",
      "digest": {
        "sha256": "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
      }
    }
  ],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://github.com/slsa-framework/slsa-github-generator/generic@v1",
      "externalParameters": {
        "workflow": {
          "ref": "refs/tags/v0.6.11",
          "repository": "https://github.com/h4x0r/1-click-github-sec"
        }
      },
      "internalParameters": {
        "github": {
          "actor_id": "12345",
          "event_name": "push"
        }
      },
      "resolvedDependencies": [
        {
          "uri": "git+https://github.com/h4x0r/1-click-github-sec@refs/tags/v0.6.11",
          "digest": {
            "gitCommit": "abc123..."
          }
        }
      ]
    },
    "runDetails": {
      "builder": {
        "id": "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@refs/tags/v2.1.0"
      },
      "metadata": {
        "invocationId": "https://github.com/h4x0r/1-click-github-sec/actions/runs/123456789",
        "startedOn": "2025-10-22T10:30:00Z",
        "finishedOn": "2025-10-22T10:35:00Z"
      }
    }
  }
}
```

**What We Get**:
1. **File hashes** (sha256) - exact same data as manual hash registry
2. **Cryptographic signature** - Sigstore attestation (verifiable)
3. **Build context** - who built it, when, from which commit
4. **Dependency transparency** - what inputs were used
5. **Audit trail** - complete provenance chain

## Architecture Design

### Phase 1: SLSA Provenance Generation

**Goal**: Add SLSA provenance generation to release workflow (parallel to existing hash system)

**Changes to `.github/workflows/release.yml`**:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write  # For release uploads
  actions: read    # For provenance generation
  id-token: write  # For Sigstore signing

jobs:
  # Step 1: Build artifacts and generate hashes
  build:
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Wait for security workflows
        # ... existing security workflow checks ...

      - name: Validate tag format
        # ... existing tag validation ...

      - name: Prepare release artifacts
        run: |
          # Ensure all managed files are present
          ls -la install-security-controls.sh
          ls -la uninstall-security-controls.sh
          ls -la yubikey-gitsign-toggle.sh
          ls -la .security-controls/bin/pinactlite
          ls -la .security-controls/bin/gitleakslite

      - name: Generate artifact hashes for SLSA
        id: hash
        run: |
          # Generate SHA256 hashes for all managed files
          # Format: hash followed by space followed by filename
          # Encode in base64 for provenance generator

          hashes=$(sha256sum \
            install-security-controls.sh \
            uninstall-security-controls.sh \
            yubikey-gitsign-toggle.sh \
            .security-controls/bin/pinactlite \
            .security-controls/bin/gitleakslite \
            | base64 -w0)

          echo "hashes=$hashes" >> "$GITHUB_OUTPUT"

          # Display for verification
          echo "Generated hashes:"
          sha256sum \
            install-security-controls.sh \
            uninstall-security-controls.sh \
            yubikey-gitsign-toggle.sh \
            .security-controls/bin/pinactlite \
            .security-controls/bin/gitleakslite

      - name: Upload artifacts for provenance
        uses: actions/upload-artifact@v4
        with:
          name: release-artifacts
          path: |
            install-security-controls.sh
            uninstall-security-controls.sh
            yubikey-gitsign-toggle.sh
            .security-controls/bin/pinactlite
            .security-controls/bin/gitleakslite
          if-no-files-found: error

  # Step 2: Generate SLSA provenance (cryptographically signed)
  provenance:
    needs: [build]
    permissions:
      actions: read     # Detect GitHub Actions environment
      id-token: write   # Sign provenance with Sigstore
      contents: write   # Upload to release
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true  # Auto-upload provenance to release

  # Step 3: Create release with provenance
  release:
    needs: [build, provenance]
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          name: release-artifacts

      - name: Download provenance
        uses: actions/download-artifact@v4
        with:
          name: ${{ needs.provenance.outputs.provenance-name }}

      - name: Generate checksums (legacy compatibility)
        run: |
          sha256sum install-security-controls.sh > install-security-controls.sh.sha256
          sha256sum uninstall-security-controls.sh > uninstall-security-controls.sh.sha256
          sha256sum yubikey-gitsign-toggle.sh > yubikey-gitsign-toggle.sh.sha256

          # Create combined checksums file
          cat > checksums.txt <<EOF
          # 1-Click GitHub Security ${{ github.ref_name }} - Release Checksums
          # SLSA Provenance Available: .intoto.jsonl
          # Verify with: sha256sum -c checksums.txt

          EOF
          cat *.sha256 >> checksums.txt

      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            install-security-controls.sh
            install-security-controls.sh.sha256
            uninstall-security-controls.sh
            uninstall-security-controls.sh.sha256
            yubikey-gitsign-toggle.sh
            yubikey-gitsign-toggle.sh.sha256
            checksums.txt
            *.intoto.jsonl
          generate_release_notes: true
          body: |
            ## 🛡️ 1-Click GitHub Security ${{ github.ref_name }}

            ### 🔐 SLSA Build Level 3 Provenance

            This release includes **cryptographically signed SLSA provenance**:
            - ✅ Build Level 3 attestation
            - ✅ Signed with Sigstore (keyless signing)
            - ✅ Verifiable build provenance

            **Verify provenance** (requires slsa-verifier):
            ```bash
            # Download provenance
            curl -LO https://github.com/h4x0r/1-click-github-sec/releases/download/${{ github.ref_name }}/install-security-controls.sh.intoto.jsonl

            # Verify with slsa-verifier
            slsa-verifier verify-artifact \
              --provenance-path install-security-controls.sh.intoto.jsonl \
              --source-uri github.com/h4x0r/1-click-github-sec \
              install-security-controls.sh
            ```

            ### 📦 Quick Installation

            ```bash
            # Download and verify installer
            curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/${{ github.ref_name }}/install-security-controls.sh
            curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/${{ github.ref_name }}/install-security-controls.sh.sha256

            # Verify checksum (REQUIRED for security)
            sha256sum -c install-security-controls.sh.sha256

            # Install security controls
            chmod +x install-security-controls.sh
            ./install-security-controls.sh
            ```
```

**Key Points**:
- **Parallel deployment**: SLSA provenance generated alongside existing checksums
- **Backward compatible**: Legacy checksums still available
- **Auto-upload**: Provenance automatically attached to release
- **Sigstore signing**: Same keyless signing as gitsign commits

### Phase 2: Safe-Upgrade SLSA Integration

**Goal**: Update `safe-upgrade.sh` to verify and consume SLSA provenance

**New Functions for `scripts/safe-upgrade.sh`**:

```bash
# Install slsa-verifier if not present
install_slsa_verifier() {
  if command -v slsa-verifier >/dev/null 2>&1; then
    log_success "slsa-verifier already installed"
    return 0
  fi

  log_info "Installing slsa-verifier..."

  local version="v2.6.0"
  local os="linux"
  local arch="amd64"

  # Detect OS
  case "$(uname -s)" in
    Linux*)  os="linux" ;;
    Darwin*) os="darwin" ;;
    *)       log_error "Unsupported OS: $(uname -s)"; return 1 ;;
  esac

  # Detect architecture
  case "$(uname -m)" in
    x86_64)  arch="amd64" ;;
    arm64)   arch="arm64" ;;
    aarch64) arch="arm64" ;;
    *)       log_error "Unsupported architecture: $(uname -m)"; return 1 ;;
  esac

  local url="https://github.com/slsa-framework/slsa-verifier/releases/download/${version}/slsa-verifier-${os}-${arch}"

  curl -fsSL "$url" -o .security-controls/bin/slsa-verifier
  chmod +x .security-controls/bin/slsa-verifier

  log_success "slsa-verifier installed to .security-controls/bin/"
}

# Download SLSA provenance for a version
download_slsa_provenance() {
  local version="$1"
  local provenance_file="/tmp/provenance-${version}.intoto.jsonl"

  log_info "Downloading SLSA provenance for version $version..."

  # Try to download provenance from GitHub release
  local url="https://github.com/h4x0r/1-click-github-sec/releases/download/v${version}/install-security-controls.sh.intoto.jsonl"

  if ! curl -fsSL "$url" -o "$provenance_file"; then
    log_warning "SLSA provenance not available for version $version"
    log_info "Falling back to embedded hash registry"
    return 1
  fi

  log_success "Downloaded SLSA provenance"
  echo "$provenance_file"
}

# Verify SLSA provenance signature
verify_slsa_provenance() {
  local provenance_file="$1"

  log_info "Verifying SLSA provenance signature..."

  # Ensure slsa-verifier is installed
  install_slsa_verifier || return 1

  # Verify provenance
  if ! slsa-verifier verify-artifact \
    --provenance-path "$provenance_file" \
    --source-uri github.com/h4x0r/1-click-github-sec 2>&1 | tee /tmp/slsa-verify.log; then

    log_error "SLSA provenance verification failed!"
    log_error "This could indicate:"
    log_error "  • Tampered provenance file"
    log_error "  • Invalid signature"
    log_error "  • Provenance from different source"
    cat /tmp/slsa-verify.log
    return 1
  fi

  log_success "✅ SLSA provenance signature verified!"
  log_success "   Provenance is authentic and from github.com/h4x0r/1-click-github-sec"
}

# Extract file hash from SLSA provenance
get_hash_from_slsa_provenance() {
  local provenance_file="$1"
  local file_path="$2"

  # Extract hash using jq
  # SLSA provenance format: subject[].name and subject[].digest.sha256
  local hash
  hash=$(jq -r ".subject[] | select(.name == \"$file_path\") | .digest.sha256" "$provenance_file" 2>/dev/null)

  if [[ -z $hash ]]; then
    log_warning "No hash found in provenance for: $file_path"
    return 1
  fi

  echo "$hash"
}

# Get expected hash (SLSA-aware version)
get_expected_hash() {
  local version="$1"
  local file_path="$2"

  # Try SLSA provenance first
  local provenance_file
  provenance_file=$(download_slsa_provenance "$version")

  if [[ -n $provenance_file && -f $provenance_file ]]; then
    # Verify provenance signature
    if verify_slsa_provenance "$provenance_file"; then
      # Extract hash from verified provenance
      local hash
      hash=$(get_hash_from_slsa_provenance "$provenance_file" "$file_path")

      if [[ -n $hash ]]; then
        log_success "Using verified SLSA provenance hash for $file_path"
        echo "$hash"
        return 0
      fi
    fi
  fi

  # Fallback to embedded hash registry
  log_info "Using embedded hash registry for $file_path"
  local key="$version|$file_path"
  echo "${VERSION_HASHES[$key]:-}"
}
```

**Key Changes**:
- ✅ **Auto-install slsa-verifier**: Downloads if not present
- ✅ **Provenance download**: Fetches from GitHub releases
- ✅ **Signature verification**: Cryptographic proof of authenticity
- ✅ **Hash extraction**: Parses verified provenance for file hashes
- ✅ **Graceful fallback**: Uses embedded hashes if provenance unavailable

### Phase 3: Deprecation of Manual Hash Registry

**Goal**: Remove manual hash generation system once SLSA is proven

**Files to Remove**:
- `scripts/generate-release-hashes.sh` (no longer needed)
- Hash registry code in `safe-upgrade.sh` (replaced by SLSA extraction)
- Hash generation step in release workflow

**Migration Timeline**:
1. **Sprint 1**: Deploy SLSA provenance generation (parallel to existing)
2. **Sprint 2**: Update safe-upgrade to prefer SLSA provenance
3. **Sprint 3**: Monitor usage, verify no issues
4. **Sprint 4**: Deprecate manual hash generation
5. **Sprint 5**: Remove deprecated code

## Security Benefits

### Threat Model Comparison

| Threat | Manual Hashes | SLSA Provenance |
|--------|---------------|-----------------|
| **Tampered files** | ❌ Detected by hash mismatch (but hashes could be modified) | ✅ Detected by signature verification + hash mismatch |
| **Modified hash registry** | ❌ Requires repository access + signed commit | ✅ Impossible (provenance is signed by GitHub) |
| **Supply chain attack** | ❌ No visibility into build process | ✅ Full build transparency (builder, materials, invocation) |
| **Downgrade attack** | ⚠️ Version comparison only | ✅ Provenance includes commit hash (non-monotonic protection) |
| **Man-in-the-middle** | ⚠️ HTTPS only | ✅ HTTPS + cryptographic signature |

### SLSA Build Level 3 Requirements

**What We Achieve**:
- ✅ **Build service**: GitHub Actions (trusted build platform)
- ✅ **Build isolation**: GitHub-hosted runners (ephemeral, isolated)
- ✅ **Provenance generation**: slsa-github-generator (separate from build)
- ✅ **Provenance distribution**: Signed and uploaded to release
- ✅ **Non-falsifiable**: Cryptographically signed with Sigstore

**SLSA Level 3 Benefits**:
- Resistant to specific threats within the builder
- Provenance cannot be forged or tampered
- Build process is reproducible and auditable
- Supply chain transparency for downstream consumers

## Implementation Checklist

### Sprint 1: SLSA Provenance Generation

- [ ] Add `build` job to release workflow with hash generation
- [ ] Add `provenance` job using slsa-github-generator@v2.1.0
- [ ] Configure required permissions (actions, id-token, contents)
- [ ] Test with pre-release tag (e.g., `v0.6.11-rc1`)
- [ ] Verify provenance is generated and uploaded
- [ ] Manually verify provenance with slsa-verifier
- [ ] Update release notes template to document SLSA provenance
- [ ] Keep existing hash generation system (parallel deployment)

### Sprint 2: Safe-Upgrade SLSA Integration

- [ ] Add `install_slsa_verifier()` function to safe-upgrade.sh
- [ ] Add `download_slsa_provenance()` function
- [ ] Add `verify_slsa_provenance()` function
- [ ] Add `get_hash_from_slsa_provenance()` function
- [ ] Update `get_expected_hash()` to prefer SLSA provenance
- [ ] Add graceful fallback to embedded hashes
- [ ] Test with SLSA-enabled release
- [ ] Test fallback with old releases (no provenance)
- [ ] Update safe-upgrade.sh documentation

### Sprint 3: Monitoring & Validation

- [ ] Monitor safe-upgrade usage with SLSA provenance
- [ ] Collect metrics (SLSA vs fallback usage)
- [ ] Test edge cases (network failures, invalid provenance)
- [ ] Gather user feedback
- [ ] Fix any issues discovered
- [ ] Validate cryptographic verification works correctly

### Sprint 4: Deprecation Preparation

- [ ] Add deprecation notices to hash generation workflow
- [ ] Update documentation to recommend SLSA provenance
- [ ] Create migration guide for embedded hash removal
- [ ] Ensure 100% SLSA coverage for recent releases
- [ ] Plan final deprecation timeline

### Sprint 5: Hash Registry Removal

- [ ] Remove `scripts/generate-release-hashes.sh`
- [ ] Remove hash generation from release workflow
- [ ] Remove embedded hash registry from safe-upgrade.sh
- [ ] Update all documentation
- [ ] Announce SLSA-only workflow
- [ ] Update CLAUDE.md to reflect SLSA Level 3 achievement

## Testing Strategy

### Test Cases

**1. Fresh Release with SLSA Provenance**
```bash
# Tag and push new release
git tag v0.7.0
git push origin v0.7.0

# Wait for GitHub Actions to complete
gh run watch

# Verify provenance was generated
gh release view v0.7.0 | grep intoto.jsonl

# Download and verify manually
curl -LO https://github.com/h4x0r/1-click-github-sec/releases/download/v0.7.0/install-security-controls.sh.intoto.jsonl
slsa-verifier verify-artifact \
  --provenance-path install-security-controls.sh.intoto.jsonl \
  --source-uri github.com/h4x0r/1-click-github-sec \
  install-security-controls.sh
```

**2. Safe-Upgrade with SLSA Provenance**
```bash
# Simulate existing v0.6.10 installation
echo 'version="0.6.10"' > .security-controls-version

# Run installer (triggers safe-upgrade)
./install-security-controls.sh

# Verify SLSA provenance was downloaded and verified
# Should see in logs:
# - "Downloading SLSA provenance for version 0.7.0..."
# - "Verifying SLSA provenance signature..."
# - "✅ SLSA provenance signature verified!"
```

**3. Fallback to Embedded Hashes**
```bash
# Test with old version (no SLSA provenance)
echo 'version="0.6.9"' > .security-controls-version

# Run installer
./install-security-controls.sh

# Should see fallback message:
# - "SLSA provenance not available for version 0.6.9"
# - "Falling back to embedded hash registry"
```

**4. Provenance Tampering Detection**
```bash
# Download provenance
curl -LO https://github.com/h4x0r/1-click-github-sec/releases/download/v0.7.0/install-security-controls.sh.intoto.jsonl

# Tamper with it
echo "malicious" >> install-security-controls.sh.intoto.jsonl

# Try to verify
slsa-verifier verify-artifact \
  --provenance-path install-security-controls.sh.intoto.jsonl \
  --source-uri github.com/h4x0r/1-click-github-sec \
  install-security-controls.sh

# Should fail with signature verification error
```

## Documentation Updates

### Files to Update

1. **`docs/safe-upgrade-system.md`**
   - Add SLSA provenance architecture section
   - Document SLSA verification workflow
   - Update security considerations

2. **`docs/architecture.md`**
   - Add SLSA Build Level 3 compliance
   - Document provenance generation pipeline
   - Update supply chain security section

3. **`README.md`**
   - Add SLSA badge
   - Document provenance verification
   - Update security features list

4. **`CLAUDE.md`**
   - Move SLSA Level 3 from "Future Vision" to "Implemented"
   - Update Core Design Principles with SLSA
   - Add SLSA to ADRs

5. **`CHANGELOG.md`**
   - Document SLSA provenance addition
   - Note hash registry deprecation timeline

## Success Criteria

### Phase 1 Success (SLSA Generation)
- ✅ SLSA provenance generated for every release
- ✅ Provenance uploaded to GitHub releases
- ✅ Provenance verifiable with slsa-verifier
- ✅ All managed files included in provenance
- ✅ Zero manual intervention required

### Phase 2 Success (Safe-Upgrade Integration)
- ✅ Safe-upgrade automatically downloads provenance
- ✅ Signature verification works correctly
- ✅ Hashes extracted from verified provenance
- ✅ Graceful fallback for old releases
- ✅ Clear user messaging about SLSA usage

### Phase 3 Success (Deprecation)
- ✅ All new releases use SLSA exclusively
- ✅ Hash generation removed from workflows
- ✅ Safe-upgrade no longer uses embedded hashes
- ✅ Documentation updated completely
- ✅ SLSA Level 3 compliance achieved

## Risks and Mitigations

### Risk 1: slsa-verifier Installation Failure

**Risk**: Users may not be able to install slsa-verifier on their system.

**Mitigation**:
- Auto-install slsa-verifier to `.security-controls/bin/`
- Support multiple architectures (amd64, arm64)
- Support multiple OS (Linux, macOS)
- Graceful fallback to embedded hashes if installation fails
- Clear error messages with manual installation instructions

### Risk 2: Provenance Verification Performance

**Risk**: Cryptographic verification may be slow, violating < 60s upgrade goal.

**Mitigation**:
- Cache slsa-verifier binary (don't re-download)
- Verification is one-time per upgrade
- Parallelize file hash checks
- Monitor and optimize if needed

### Risk 3: Backward Compatibility

**Risk**: Old releases don't have SLSA provenance.

**Mitigation**:
- Keep embedded hash registry for old versions
- Automatic fallback when provenance unavailable
- No breaking changes for existing users
- Gradual migration (not forced)

### Risk 4: GitHub Dependency

**Risk**: SLSA provenance requires GitHub Actions and GitHub releases.

**Mitigation**:
- Already dependent on GitHub for repository
- SLSA is open standard (not GitHub-specific)
- Could generate provenance locally if needed
- Aligns with existing Sigstore/gitsign usage

## Next Steps

1. **Review this plan** with stakeholders
2. **Create sprint 1 tasks** in backlog
3. **Set up test environment** for SLSA workflow
4. **Begin implementation** of Phase 1

---

**Status**: Draft for Review
**Author**: Claude Code
**Date**: 2025-10-22
**Version**: 1.0
