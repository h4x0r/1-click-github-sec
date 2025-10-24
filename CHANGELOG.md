# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.0] - 2025-10-24

### 🚀 Major Simplification - Config-Driven Workflow Generation

**BREAKING CHANGES** - Complete architectural simplification for maximum transparency and maintainability.

### Config-Driven System
- **✨ Pure Generation**: Workflows are now 100% generated artifacts from `.security-controls/config.yml`
- **📝 Prominent Warnings**: All generated workflows have clear "AUTO-GENERATED - DO NOT EDIT" headers
- **🔧 Simple Customization**: Edit `config.yml` → re-run installer → commit both files
- **🗑️ Auto-Cleanup**: Old workflows automatically removed during upgrade
- **📦 Merged Workflows**: `security.yml` + `pinning-validation.yml` → `1cgs-security.yml`
- **🏷️ Clear Naming**: `1cgs-` prefix (1-Click GitHub Security) makes generated files obvious

### Removed Complexity
- **Removed**: Hash-based customization detection (~370 lines)
- **Removed**: Backup/diff/choice logic for customized workflows
- **Removed**: `SCRIPT_VERSION` (redundant with `INSTALLER_VERSION`)
- **Removed**: Backward compatibility mechanisms (only 2 controlled users)
- **Simplified**: Manifest system (version tracking only, no hash fields)
- **Simplified**: Assisted upgrade (26 lines vs 117 lines)

### Migration Support
- **Auto-Detection**: v0.8.0 installations automatically detected
- **Seamless Upgrade**: `./install-security-controls.sh --upgrade`
- **Preserved Customizations**: Existing customizations moved to `config.yml`
- **Example**: nameback's Linux build dependencies preserved in config

### Benefits
- **76% code reduction** in upgrade logic
- **Zero ambiguity** about workflow source (config.yml is single source of truth)
- **Faster iteration** (no hash comparison, no prompts)
- **Better DX** (edit config, not YAML workflows)
- **Clearer ownership** (1cgs- prefix vs generic names)

### Technical Details
- Fixed heredoc variable expansion bugs (`<<EOF` → `<<'EOF'`)
- Updated main installation to use `1cgs-security.yml`
- Calls `generate_merged_security_workflow` instead of split functions
- Manifest tracks template version 3.0.0 for merged workflow

## [0.6.12] - 2025-01-24

### Added
- **Cargo.lock Validation**: Pre-push hook now validates that Cargo.lock is up to date for Rust projects
  - Prevents pushes with out-of-date lockfiles that would fail CI
  - Runs `cargo update --dry-run` to detect drift
  - Provides clear error message: "Run 'cargo update' to update Cargo.lock"

### Changed
- Pre-push hook now includes Cargo.lock validation in Rust project checks
- Ensures consistency between local development and CI environment

## [0.6.11] - 2025-10-22

### 🔐 SLSA Build Level 3 Provenance (Supply Chain Security)

**CRYPTOGRAPHIC VERIFICATION RELEASE** - Complete SLSA Build Level 3 implementation with simplified verification workflow.

### SLSA Provenance Implementation
- **🏆 SLSA Build Level 3**: Industry-standard supply chain security compliance
- **🔑 Sigstore Signing**: Cryptographically signed build provenance using keyless signing
- **📋 Complete Build Context**: Verifiable who, when, and how artifacts were built
- **🔍 Supply Chain Transparency**: Public audit trail via Rekor transparency log
- **🎯 Simplified Verification**: Single verification method (SLSA-only, no legacy checksums)

### Release Workflow Enhancements
- **Three-Job Architecture**: Build → Provenance → Release
- **slsa-github-generator@v2.1.0**: Official SLSA provenance generator integration
- **Automatic Provenance Upload**: `upload-assets: true` for seamless release creation
- **Base64 Hash Encoding**: Secure artifact hash passing between workflow jobs
- **Prerelease Support**: RC releases with `-rcN` suffix validation

### Verification Simplification
- **Removed Legacy Checksums**: Eliminated ~150 lines of hash registry code
- **SLSA-Only Documentation**: Clear, single-method verification instructions
- **slsa-verifier Integration**: Official verification tool (v2.7.1)
- **Enhanced Release Notes**: Comprehensive SLSA verification examples

### Technical Improvements
- **Pinactlite v1.1.0 Exception**: Reusable workflow support for SLSA generator
- **QA Workflow Skip**: RC releases bypass QA due to pinact reusable workflow limitation
- **Provenance Structure**: DSSE envelope format with embedded subject array
- **Hash Verification**: SHA256 digests extracted from SLSA provenance

### Breaking Changes
- **No Backward Compatibility**: Legacy SHA256 checksums removed (never publicly released)
- **SLSA-Only Verification**: All releases must be verified with slsa-verifier
- **Hash Registry Removed**: No more JSON/YAML hash registry files

### Migration Guide
```bash
# Old method (removed):
curl -O checksums.txt
sha256sum -c checksums.txt

# New method (SLSA Build Level 3):
curl -O install-security-controls.sh
curl -O multiple.intoto.jsonl
slsa-verifier verify-artifact \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/h4x0r/1-click-github-sec \
  install-security-controls.sh
```

### Benefits
- **Non-Falsifiable Attestation**: Cryptographic proof of authenticity
- **Industry Standard**: SLSA Build Level 3 compliance
- **Zero Trust**: Verify, don't trust
- **Simpler Codebase**: -212 lines (removed 269, added 57)
- **Clearer Documentation**: Single verification method

## [0.6.10] - 2025-09-29

### 🔗 Link Validation & Deployment Framework

**VALIDATION FRAMEWORK RELEASE** - Comprehensive GitHub Pages deployment validation to prevent timing issues.

### Link Validation Enhancements
- **🔗 Complementary Strategy**: Implemented non-overlapping link validation approach
- **⏰ Deployment Timing**: Added GitHub Pages deployment checker with 12-minute timeout
- **📊 Data-Driven Timeouts**: Based on deployment analysis (90% complete within 12 minutes)
- **🔍 Pre-Deployment Validation**: Quick check for new documentation files before GitHub Pages lag
- **🛠️ Multiple Solutions**: Clear remediation paths for deployment timing issues

### Framework Components
- **GitHub Pages Deployment Checker**: Wait for deployment with retry logic and GitHub API monitoring
- **Documentation Links Validator**: Extract and validate docs site URLs with MkDocs navigation check
- **Enhanced validate-docs.sh**: Integrated pre-deployment validation with CI fallback guidance
- **Comprehensive Documentation**: Clear purpose separation vs. existing lychee CI validation

### Technical Improvements
- **⚡ Smart Timeouts**: 720s timeout covers 90% of GitHub Pages deployments
- **🔄 Retry Logic**: 30s intervals with GitHub API status monitoring
- **📋 Multiple Validation Modes**: Individual files, batch processing, wait mode
- **🎯 Focused Scope**: Only h4x0r.github.io links (complementary to comprehensive lychee)
- **🛡️ Quality Standards**: All scripts pass shellcheck with proper Apache 2.0 licensing

### Complementary Tool Strategy
- **lychee (CI)**: Comprehensive link validation after deployment (all links)
- **validate-docs-links.sh**: Pre-deployment validation for new documentation files
- **check-docs-deployment.sh**: Deployment timing validation with GitHub API integration
- **Clear Separation**: Non-overlapping responsibilities, reduced complexity

### Usage Examples
```bash
# Wait for new file deployment
./scripts/check-docs-deployment.sh --wait new-file-name

# Pre-validate documentation links
./scripts/validate-docs-links.sh README.md

# Comprehensive validation (includes pre-deployment check)
./scripts/validate-docs.sh
```

Prevents GitHub Pages timing issues while maintaining comprehensive CI coverage through lychee.

## [0.6.8] - 2025-09-29

### 📚 Documentation Architecture Optimization

**CONSOLIDATION RELEASE** - Major documentation reorganization for better user experience and maintenance efficiency.

### Documentation Enhancements
- **📋 Content Consolidation**: Merged `repo-and-installer-sync-strategy.md` into `repo-security.md` for unified reference
- **🏷️ Enhanced Scope**: Renamed to `repo-security-and-quality-assurance.md` reflecting comprehensive content coverage
- **🎯 User Journey Optimization**: Streamlined navigation and reduced content fragmentation
- **🔗 Reference Updates**: Updated all cross-references across 8+ files for consistency
- **🧹 Repository Cleanup**: Removed 9 obsolete test and backup files from signing experiments

### Quality Assurance Improvements
- **📊 Multi-Dimensional Synchronization**: Integrated comprehensive sync strategy documentation
- **🔍 Validation Enhancement**: Updated documentation validation scripts for new structure
- **🎨 Navigation Optimization**: Improved MkDocs navigation structure and removed orphaned entries
- **📖 Comprehensive Coverage**: Combined security controls, QA processes, and sync strategies in single reference

### Maintenance Improvements
- **🗑️ File Cleanup**: Removed obsolete test files: `dual_sign_test.txt`, `gitsign-test.md`, `CLAUDE.md.txt`, etc.
- **📝 Cross-Reference Integrity**: Maintained all existing functionality while improving organization
- **✅ Validation Success**: 87% documentation validation success rate maintained

### Breaking Changes
- **📂 File Location**: `docs/repo-security.md` → `docs/repo-security-and-quality-assurance.md`
- **📂 Removed Files**: `docs/repo-and-installer-sync-strategy.md` (content merged)

This release focuses on documentation quality and developer experience improvements with no functional changes to security controls.

## [0.6.5] - 2025-09-28

### 🚫 Zero-Compromise Security Release

**CRITICAL SECURITY ENHANCEMENT** - All security scanning jobs now blocking for releases, implementing zero-compromise security posture.

### Security Enhancements
- **🚫 CodeQL SAST Analysis**: Now blocking (was analysis-only) - Application security vulnerabilities block releases
- **🚫 Supply Chain Security**: Now blocking (was analysis-only) - SHA pinning violations and dependency integrity issues block releases
- **🛡️ Complete Protection**: Zero-day protection through comprehensive static analysis
- **🔒 Consistent Security**: Same rigor applied to all security categories (known CVEs, application flaws, supply chain risks)

### Architecture Impact
- **Zero Security Gaps**: All major threat vectors now have blocking validation
- **Defense in Depth**: Comprehensive security gate with parallel validation
- **Enhanced Release Process**: Quality Assurance + ALL security scanning must pass
- **Supply Chain Attack Prevention**: Blocks malicious package substitution and SolarWinds-style attacks

### Philosophy
- **Zero-Compromise Security**: Block ALL critical security risks regardless of source
- **Application Security Parity**: Code vulnerabilities treated with same severity as known CVEs
- **Supply Chain Paranoia**: Assume all external dependencies are compromised until proven otherwise
- **Fail-Secure Design**: When in doubt, block rather than allow

### Breaking Changes
- **CodeQL failures now block releases** - Application security issues must be resolved
- **Supply chain issues now block releases** - SHA pinning and dependency integrity required
- **Longer CI times possible** - CodeQL analysis can take 5-10+ minutes

### Migration Guide
- **Existing projects**: May experience initial release blocks due to CodeQL findings
- **Recommended approach**: Review and address CodeQL security findings before release
- **Emergency bypass**: Use `--no-verify` git push flag only for critical hotfixes

---

## [0.6.3] - 2025-09-28

### 🔄 Unified Security Workflow Release

**MAJOR IMPROVEMENT** - Consolidated all security scanning into a unified workflow for better CI performance and clearer separation of concerns.

### Added
- **🛡️ Unified Security Scanning**: Created comprehensive `security-scan.yml` workflow combining all security scanning
- **🎯 SAST Integration**: Consolidated CodeQL + Trivy vulnerability scanning with parallel execution
- **🔒 Comprehensive Secret Detection**: Full repository history scanning with gitleaks (blocking)
- **📊 Enhanced Dependency Security**: cargo-deny security audit with license compliance (blocking)
- **⛓️ Supply Chain Security**: GitHub Actions pinning analysis and dependency integrity checks

### Changed
- **🔄 Workflow Consolidation**: Merged `codeql.yml` and `trivy-security.yml` into unified `security-scan.yml`
- **⚡ CI Performance**: Improved parallelization and resource utilization across security jobs
- **🎯 Separation of Concerns**: Quality Assurance (validation/testing) vs Security Scanning (threat detection)
- **🚀 Release Dependencies**: Streamlined to Quality Assurance + Security Scanning workflows
- **📋 ShellCheck Optimization**: Moved to pre-push only (fail-fast design principle)

### Removed
- **🗑️ Redundant Workflows**: Deleted separate `codeql.yml` and `trivy-security.yml` files
- **🗑️ Binary Sync Workflows**: Consolidated `sync-gitleakslite.yml` and `sync-pinactlite.yml` into pre-push validation
- **🗑️ Duplicate Shell Validation**: Removed redundant shellcheck from CI (now pre-push only)

### Security
- **🚫 Zero-Compromise Security**: ALL security scanning jobs now blocking (CodeQL, Trivy, secrets, dependencies, supply chain)
- **✅ Enhanced Coverage**: Improved SAST + secrets + dependencies + supply chain in unified workflow
- **✅ Fail-Fast Design**: Optimized shellcheck to pre-push for immediate developer feedback
- **✅ Cryptographic Verification**: Maintained signed commits and releases
- **🛡️ Complete Protection**: Application vulnerabilities (CodeQL) and supply chain risks now block releases

### Performance
- **⚡ 4 Workflows**: Reduced from 6 to 4 specialized workflows
- **⚡ Parallel Security Scanning**: Multiple security jobs run concurrently in security-scan.yml
- **⚡ Resource Optimization**: Better CI resource allocation and utilization

### Architecture
- **🏗️ Clear Separation**: Quality Assurance focuses on validation, Security Scanning focuses on threat detection
- **🏗️ Dogfooding Plus**: Repository uses enhanced version of controls provided to users
- **🏗️ Defense in Depth**: Multiple overlapping security controls with parallel execution

---

## [0.5.2] - 2025-09-28

### 🔧 GPG Key Logic Enhancement Release

**IMPROVEMENT** - Enhanced GPG key management to intelligently reuse existing keys and clarified CI workflow status for better development experience.

### Enhanced
- **🔑 Smart GPG Key Reuse**: Installer now intelligently reuses existing GPG keys when configured, only generating new ones when none exist
- **🎯 Email Matching Logic**: Ensures generated GPG keys match Git user.email for proper GitHub verification
- **📧 Existing Key Detection**: Checks both global and local Git configuration for signing keys before generation
- **🔄 Configuration Priority**: Respects user's existing GPG setup while providing zero-friction fallback
- **📋 CI Workflow Clarity**: Confirmed shellcheck warnings are non-blocking informational messages

### Technical Details
- Enhanced `upload_gpg_key_to_github()` function logic flow:
  1. Check existing `user.signingkey` configuration first
  2. Use existing key if found (respects user setup)
  3. Generate new key only when none configured
  4. Match email with Git user.email for GitHub verification
- All shellcheck warnings are SC2086 info-level (color variable quoting)
- CI workflows marked shellcheck as "non-blocking" intentionally

### Breaking Changes
- None - this enhances existing functionality while maintaining full backward compatibility

## [0.5.1] - 2025-09-28

### 🤖 Automated GPG Key Upload Release

**ENHANCEMENT** - Added fully automated GPG key upload to GitHub for instant "Verified" badge setup with zero manual configuration required.

### Added
- **🔑 Automated GPG Key Upload**: Installer automatically uploads GPG public key to GitHub via API
- **🤖 Smart Key Generation**: Auto-generates 4096-bit RSA GPG keys when none exist
- **🔐 GitHub Integration**: Seamlessly requests and uses `admin:gpg_key` permissions
- **🛡️ Duplicate Prevention**: Checks existing keys to avoid redundant uploads
- **⚡ Zero Configuration**: Users get "Verified" badges without any manual GitHub setup
- **🔄 Graceful Fallback**: Provides manual instructions when automation isn't possible

### Enhanced
- **📦 Single-Script Architecture**: GPG key management embedded directly in installer
- **🎯 CLAUDE.md Compliance**: Follows "security by default, no thinking required" principle
- **💻 User Experience**: Complete GPG verification setup in single installer run
- **🔍 Smart Detection**: Handles existing keys, authentication, and permission requirements
- **📖 Error Guidance**: Clear manual instructions when automation fails

### Technical Details
- Uses GitHub REST API `/user/gpg_keys` endpoint for key upload
- Requests `admin:gpg_key` scope automatically via `gh auth refresh`
- Generates keys with 2-year expiration and proper email matching
- Validates key fingerprints to prevent duplicate uploads
- Maintains full backward compatibility with existing workflows

### Breaking Changes
- None - this is additive functionality that enhances existing GPG setup

## [0.5.0] - 2025-09-28

### 🔐 True Dual Signature System Release

**MAJOR ENHANCEMENT** - Implemented true dual signature system that embeds both GPG and Sigstore signatures directly in Git commit objects, providing the security benefits of both signing methods with zero user friction.

### Added
- **🔑 True Dual Signing**: Both GPG and Sigstore signatures embedded in commit objects by default
- **🤖 Automatic Hook System**: Post-commit hook automatically adds Sigstore signature to GPG-signed commits
- **🔄 Seamless Integration**: Zero configuration required - dual signing happens automatically on every commit
- **📦 Portable Signatures**: Both signatures travel with commits (unlike git notes approach)
- **🛡️ Enhanced Security**: GPG signatures for GitHub verification + Sigstore signatures for transparency logging

### Enhanced
- **📋 YubiKey Toggle Compatibility**: Updated yubikey-gitsign-toggle.sh to work with true dual signing
- **🎯 Two Modes Support**: Software mode (browser OAuth) and YubiKey mode (hardware-backed OAuth)
- **💻 Default Configuration**: Installer now sets up true dual signing by default
- **📖 Documentation Updates**: Updated all documentation to reflect true dual signature system
- **🔍 Status Detection**: YubiKey toggle script correctly detects and displays dual signing status

### Technical Details
- Installer configures `gpg.format=openpgp` for GPG as primary signature
- Post-commit hook adds `x-sigstore-signature` header with Sigstore signature
- Both signatures embedded in commit object using standard Git format
- YubiKey toggle only changes OIDC issuer for Sigstore authentication
- Maintains full backward compatibility with existing Git tooling

### Breaking Changes
- None - this is additive functionality that enhances existing signing

## [0.4.12] - 2025-09-25

### 📖 Cryptographic Documentation Accuracy Release

**Critical Documentation Update** - Corrected all cryptographic signing references from GPG to Sigstore/gitsign to accurately reflect our actual implementation and prevent user confusion.

### Fixed
- **🔐 Signing Documentation** - Updated CLAUDE.md design principles to reflect Sigstore/gitsign instead of GPG signing
- **📋 Process Documentation** - Fixed release process to reference Sigstore/gitsign signing with Rekor transparency log
- **🔗 Chain of Trust** - Updated cryptographic trust model from GPG root key to Sigstore CA + GitHub OIDC + Rekor
- **📊 Architecture References** - Fixed architecture.md cryptographic verification references from GPG to Sigstore/gitsign
- **🛡️ Security Documentation** - Updated repo-security.md signing references to reflect actual Sigstore implementation

### Enhanced
- **📖 Implementation Accuracy** - All documentation now correctly describes our keyless signing approach
- **🔍 Verification Instructions** - Updated verification levels to reflect Sigstore signatures with transparency
- **🎯 User Guidance** - Eliminated confusion between GPG and Sigstore - clearly established Sigstore/gitsign usage
- **📋 Consistency** - Comprehensive review and update of all cryptographic signing references across documentation

### Technical Details
- Design principles now accurately describe Sigstore CA → GitHub OIDC → gitsign → Rekor chain of trust
- Release process reflects actual Sigstore/gitsign signing instead of traditional GPG signatures
- Architecture documentation correctly references Sigstore/gitsign signatures for cryptographic verification
- Repository security documentation updated to show Sigstore/gitsign in release and commit signing workflows
- All references to GPG key management replaced with keyless signing benefits and transparency

## [0.4.11] - 2025-09-25

### 🔗 Final Link Resolution & Reliability Release

**Critical Fixes** - Resolved all remaining lychee link checker errors through pragmatic link strategy ensuring 100% accessibility and reliability.

### Fixed
- **🌐 Documentation Site 404 Errors** - Replaced problematic MkDocs site URLs with direct GitHub repository links
- **📎 Trailing Slash Inconsistencies** - Fixed installer script URL formatting to match working patterns
- **📍 Relative Path References** - Changed docs/installation.md to use relative paths for internal references
- **✅ Complete Link Validation** - Achieved 100% lychee link checker success rate with reliable link strategy

### Enhanced
- **🔗 Link Accessibility Strategy** - Prioritized always-accessible GitHub repository links over potentially unavailable site URLs
- **📋 Reliable Documentation References** - All documentation links now point to guaranteed-available resources
- **🎯 Version Consistency** - Links point to current version of files without dependency on site deployment timing
- **⚡ Immediate Availability** - Documentation links work immediately without waiting for site rebuilds

### Technical Details
- Replaced documentation site URLs with GitHub blob URLs (e.g., github.com/h4x0r/1-click-github-sec/blob/main/docs/contributing.md)
- Fixed installer script trailing slash inconsistencies to match working URL patterns
- Changed internal doc references from external site URLs to relative file paths
- Ensured all links pass lychee validation by pointing to existing, accessible resources

## [0.4.10] - 2025-09-25

### 🔗 Documentation Link Validation & Standards Release

**Critical Fixes** - Resolved all lychee link checker errors and established comprehensive documentation link format standards to prevent future validation failures.

### Fixed
- **🔗 Internal File Links** - Fixed docs/index.md to use .md extensions instead of directory paths for lychee compatibility
- **🌐 Documentation Site URLs** - Removed trailing slashes from MkDocs site URLs to resolve 404 errors
- **📂 GitHub Username References** - Fixed old 4n6h4x0r → h4x0r username references in README.md
- **⚙️ Workflow Directory Links** - Fixed .github/workflows relative path to use full GitHub URL in docs/repo-security.md
- **✅ Lychee Validation** - Eliminated all 16 lychee link checker errors from CI workflow

### Enhanced
- **📖 Link Format Standards** - Added comprehensive "Documentation Link Format Standards" section to design principles
- **🔍 Tool Compatibility Guidelines** - Established context-specific link formatting rules for MkDocs vs lychee validation
- **📋 Validation Process** - Documented systematic process for testing links with both rendering and validation tools
- **🎯 Format Consistency** - Standardized link formats by context (internal docs, site URLs, GitHub references)

### Technical Details
- Internal docs now use direct file references (installation.md) instead of directory paths (installation/)
- Documentation site URLs use clean format without trailing slashes for consistent 200 responses
- GitHub repository links use full URLs for directory references to avoid file system path issues
- Added validation commands and common failure/success patterns to design principles

## [0.4.9] - 2025-09-25

### 🔧 Documentation Workflow & Process Improvement Release

**Critical Fixes** - Resolved documentation workflow failures and established systematic file management processes to prevent future issues.

### Fixed
- **📋 Documentation Workflow Failures** - Fixed .github/workflows/docs.yml to reference correct file paths after documentation consolidation
- **🔗 Broken Internal Links** - Corrected yubikey/ → yubikey-integration/ link in docs/index.md
- **📦 Version References** - Updated docs/index.md installer example from v0.4.5 to v0.4.8
- **🐚 Shellcheck Issues** - Resolved formatting and syntax issues in scripts/validate-docs.sh
- **⚠️ Lychee Link Checker** - Eliminated false failures from non-existent file references

### Enhanced
- **📖 File Management Process** - Added comprehensive "File Management and Impact Analysis" section to design principles
- **🔍 Systematic Validation** - Established 3-step process for file operations: global search → multi-dimensional update → validation
- **📋 Process Documentation** - Captured lessons learned from workflow failures as institutional knowledge
- **✅ CI Reliability** - All documentation validation now passes consistently with proper file references

### Technical Details
- Updated workflow paths from old root files to docs/ directory structure
- Fixed shellcheck SC formatting issues (comment spacing, variable expansion)
- Established mandatory global search process before file operations
- Connected file management to broader multi-dimensional synchronization strategy

## [0.4.8] - 2025-09-25

### 🔧 CI Infrastructure & Version Management Fix Release

**Critical CI Fixes** - Resolved all CI failures and improved version management process with comprehensive tooling enhancements.

### Fixed
- **🔧 Version Synchronization Issues** - Fixed version-sync.sh regex patterns for cross-platform BSD/macOS compatibility
- **📋 README Version Badge** - Corrected version badge display from v0.4.5 to proper v0.4.8
- **🔗 Broken Documentation Links** - Fixed internal references from REPO_SECURITY.md to repo-security.md
- **📦 Installer Version Mismatch** - Updated installer SCRIPT_VERSION and GitHub URLs consistency
- **🌐 GitHub URL Corrections** - Fixed all remaining 4n6h4x0r references to correct h4x0r username

### Enhanced
- **📖 Version Management Documentation** - Added mandatory version-sync.sh usage guidelines to design principles
- **🔄 Cross-Platform Compatibility** - Updated sed regex patterns to work on both GNU and BSD systems
- **⚙️ CI Validation Process** - All documentation validation now passes consistently

### Technical Details
- Fixed sed regex patterns from `[0-9]\+` to `[0-9][0-9]*` for better compatibility
- Updated installer version references and URLs throughout the codebase
- Added comprehensive version bumping guidelines emphasizing tool usage
- Resolved lychee link checker failures in documentation workflow

This release ensures all CI workflows pass and establishes proper version management practices for future releases.

## [0.4.7] - 2025-09-25

### 🚀 Minor Release Update

**Version Alignment** - Minor release to align version numbering for consistency.

### Changed
- **📋 Version Bump** - Updated version to v0.4.7 across all documentation and installer components

## [0.4.6] - 2025-09-25

### 🔗 Documentation Links Fix Release

**Critical URL Corrections** - Fixed broken documentation links in v0.4.5 release caused by incorrect GitHub username references.

### Fixed
- **🌐 GitHub Username Corrections** - Updated all references from incorrect `4n6h4x0r` to correct `h4x0r` username across all documentation
- **📋 Version References** - Updated all download links and examples to use v0.4.6
- **🔗 Documentation URLs** - Fixed cryptographic verification guide and all documentation site links
- **💬 GitHub Integration** - Changed discussions reference to issues (discussions not enabled on repository)
- **📁 URL Path Consistency** - Removed trailing slashes from documentation paths for consistent navigation

### Technical Details
- Fixed lychee link checker failures (26 errors → 0 errors)
- Corrected all GitHub Pages URLs to use h4x0r.github.io domain
- Updated maintainer references in design principles documentation
- Synchronized all version examples across documentation ecosystem

This patch release ensures all documentation links work correctly for users accessing the comprehensive guides.

## [0.4.5] - 2025-09-25

### 📖 Documentation Synchronization & Comprehensive Enhancement Release

**Complete Documentation Ecosystem** - Achieved 100% synchronization between repository documentation and installer-created documentation, with comprehensive enhancements for end-user decision-making.

### Added
- **📋 100% YubiKey Documentation Sync** - Added complete troubleshooting, comparison tables, and adoption strategy sections to installer-created guides
- **🏗️ Enhanced Architecture Documentation** - Replaced 1-line architecture stub with comprehensive 193-line user-focused guide
- **📊 Comparison Tables** - Added detailed comparisons between YubiKey+Sigstore vs Traditional GPG and SSH signing
- **🎯 Adoption Strategy Guide** - Complete guidance for individual, team, and enterprise YubiKey implementation
- **🚨 Comprehensive Troubleshooting** - Detailed solutions for common YubiKey setup and authentication issues
- **🔧 Advanced Configuration** - Documentation for custom OIDC providers, enterprise Fulcio, and CI/CD integration
- **📈 Best Practices** - Development workflow, security practices, and team adoption strategies

### Fixed
- **🌐 Critical URL Corrections** - Fixed all URLs from incorrect `4n6h4x0r.github.io` back to correct `h4x0r.github.io`
- **📁 Documentation Structure Cleanup** - Consolidated all documentation into organized `docs/` folder structure
- **🎯 Performance Claims Consistency** - Standardized all performance claims to "<60 seconds" across documentation
- **📋 Redundant Documentation Elimination** - Removed redundant `docs/security/README.md` creation from installer
- **🔤 Naming Convention Unification** - Changed installer filenames to lowercase (`architecture.md`, `yubikey-integration.md`) for consistency

### Improved
- **📖 Single Source of Truth** - Repository documentation serves as authoritative source, installer extracts relevant sections
- **🎯 End-User Decision Support** - Both individual and organizational users now have complete information for informed adoption
- **🔄 Documentation Validation** - Enhanced existing `scripts/validate-docs.sh` for new structure and 100% sync verification
- **📝 User Experience** - Installer-created documentation now provides comprehensive guidance matching repository quality

### Technical Details
- Repository YubiKey guide: 14 sections (including troubleshooting, comparisons, adoption)
- Installer YubiKey guide: 100% sync (14/14 sections)
- Architecture documentation: Enhanced from 1-line stub to 193-line comprehensive guide
- Documentation sync validation: Automated verification of repository ↔ installer consistency
- File naming: Unified lowercase conventions across repository and installer-created files

## [0.4.1] - 2025-09-25

### 🔧 CI Pipeline & Quality Assurance Fix Release

**Critical Infrastructure Fixes** - Resolved all CI pipeline failures and improved workflow reliability.

### Fixed
- **🔧 ShellCheck Warnings** - Fixed readonly variable declaration patterns in all shell scripts
- **⚙️ Functional Synchronization Check** - Corrected sync-security-controls.sh script execution issues
- **📄 Documentation Version Consistency** - Synchronized all version references to maintain accuracy
- **🔒 Gitleaks Action Reference** - Updated to latest v2.3.9 with correct commit SHA
- **🛡️ Cargo-deny Security Audit** - Added intelligent skipping when no Rust dependencies exist
- **⚠️ Deprecated GitHub Actions** - Replaced deprecated actions-rs/toolchain with dtolnay/rust-toolchain

### Improved
- **📊 CI Pipeline Reliability** - All quality assurance checks now pass consistently
- **🚀 Release Process** - Enhanced automation and error handling in workflows
- **🔍 Security Scanning** - More robust handling of multi-language project auditing

### Technical Details
- Updated gitleaks-action from cb7149b9 to ff98106e4c (v2.3.9)
- Replaced deprecated actions-rs/toolchain with dtolnay/rust-toolchain
- Enhanced cargo-deny workflow to handle empty Rust workspaces gracefully
- Fixed shell script lint compliance across all maintenance scripts

## [0.4.0] - 2025-01-25

### 🔍 Documentation Accuracy & Truth Release

**Comprehensive Documentation Audit** - Complete review and revision of all documentation, help text, and marketing claims to ensure 100% accuracy with actual implementation.

### Added
- **📋 Complete Documentation Audit** - Systematic review of all help text, README, and embedded documentation
- **🔍 Implementation Verification** - Cross-referenced all security control claims against actual code implementation
- **✅ Gitleakslite Sync Documentation** - Added missing gitleakslite sync verification to repository security features
- **📊 Accurate Security Control Counts** - Verified and documented that "35+ checks" claim is accurate for multi-language projects

### Fixed
- **🎯 Version Consistency** - Updated all scripts (installer, uninstaller, yubikey toggle) to consistent versioning
- **📝 Marketing Language Accuracy** - Removed overstated "enterprise-grade" claims, replaced with factual descriptions
- **🔧 Help Text Alignment** - Installer help text now matches README claims exactly
- **📋 Security Implementation Claims** - All documentation now reflects actual multi-language security implementation
- **🛠️ Tool Status Accuracy** - Updated Trivy and CodeQL from "under consideration" to "implemented" (they were already working)

### Changed
- **📖 Truthful Marketing** - Replaced marketing overstatements with accurate, verifiable claims
- **🎯 Realistic Positioning** - Changed from "enterprise-grade" to "multi-language security controls"
- **⚠️ Testing Status Transparency** - Added clear warnings about which language profiles are extensively tested
- **🔍 Implementation-First Documentation** - All claims now backed by actual code verification

### Verified
- **✅ "35+ Security Checks" Claim** - Confirmed accurate for multi-language projects (4 universal + 4-16 per detected language)
- **✅ Multi-Language Implementation** - Verified intelligent language detection and appropriate control application
- **✅ Security Architecture Claims** - Confirmed defense-in-depth architecture with blocking/advisory tiers
- **✅ Tool Integration Claims** - Verified Trivy, CodeQL, Gitleaks, and all claimed tools are actually implemented

### Developer Experience
- **📋 Accurate Expectations** - Users now get truthful information about capabilities and testing status
- **🔍 Clear Implementation Details** - Documentation explains exactly what security controls are provided
- **⚠️ Honest Testing Status** - Clear guidance on which language profiles are production-ready vs functional
- **📊 Verifiable Claims** - All security control counts and feature claims can be independently verified

**Truth in Documentation**: *"If we claim it, we implement it. If we implement it, we document it accurately."* - Achieved 100% alignment between documentation and implementation.

## [0.3.9] - 2025-01-25

### 🔄 CI Architecture & Quality Assurance Release

**Blocking vs Non-blocking CI Gates** - Major CI restructuring to separate functional/security validation (blocking) from quality/linting (non-blocking), plus comprehensive QA fixes.

### Added
- **🚫 Critical Validation Job** - New blocking CI job for functional synchronization and documentation validation
- **⚠️ Non-blocking Quality Gates** - Shell script linting, formatting, and quality checks now use `continue-on-error: true`
- **📋 License Compliance** - Added proper Apache 2.0 license headers to all validation scripts

### Fixed
- **🐛 cargo-deny Configuration** - Migrated to version 2 format, fixed `unmaintained` property value from invalid "warn" to "workspace"
- **⚡ Documentation Validation Hanging** - Fixed arithmetic expansion syntax causing indefinite hangs in `validate-docs.sh`
- **🔧 Supply Chain Security Script** - Fixed same arithmetic expansion issues preventing security validation completion
- **🎯 CI Job Dependencies** - Restructured workflow to ensure functional checks are blocking while quality is advisory

### Changed
- **🏗️ CI Philosophy** - Implemented "linting etc. are QA issues and should be non-blocking; function and doc sync should be blocking"
- **📊 Job Categorization** - Clear separation between critical validation (blocks releases) and quality assurance (improves code)
- **⚙️ Error Handling** - Quality jobs continue on error while security/functional jobs fail fast

### Performance
- **⚡ Script Reliability** - Documentation validation now completes consistently instead of hanging
- **🚀 Faster CI Feedback** - Quality issues no longer block functional validation from running
- **🎯 Focused Blocking** - Only critical functional/security issues block releases

### Developer Experience
- **✅ Reliable Release Pipeline** - Functional checks properly gate releases while quality feedback remains available
- **📋 Clear Job Status** - Easy distinction between must-fix (blocking) and should-fix (non-blocking) issues
- **🔍 Better Debugging** - Arithmetic expansion fixes eliminate mysterious script hangs

**Architecture Achievement**: *"Functional and doc sync should be blocking, correct?"* - Implemented proper CI gating philosophy with blocking functional validation and advisory quality checks.

## [0.3.8] - 2025-01-25

### 🛡️ Dogfooding Plus Compliance & CI Reliability Release

**Complete Security Control Synchronization** - Achieved full "dogfooding plus" implementation where repository uses ALL security controls provided to users, plus fixed critical CI reliability issues.

### Added
- **🔄 Complete Dogfooding Plus Implementation** - Repository now implements ALL security controls that installer provides to users:
  - ✅ Comprehensive secret scanning (Gitleaks Action with full history scan)
  - ✅ Security dependency audit (cargo-deny with vulnerability blocking)
  - ✅ Supply chain security analysis (SBOM generation and attestation)
  - ✅ License compliance checking (automated compliance reports)
- **📊 Enhanced CI Security Workflows** - Added 4 new specialized security jobs to quality-assurance.yml
- **🔍 Documentation Sync Detection** - Functional synchronization scripts now catch discrepancies between installer-provided and repository-implemented controls

### Fixed
- **🐛 Critical CI Reliability Issues** - Fixed ShellCheck warnings and script hanging that prevented sync validation from running
- **⚙️ Documentation Validation Script** - Fixed hanging issue caused by arithmetic expansion syntax in function context
- **🔧 YAML Workflow Syntax** - Fixed heredoc parsing errors in GitHub Actions workflows
- **📝 Script Quality** - All ShellCheck warnings resolved (SC2155, SC2207, SC2034)

### Changed
- **🎯 Enhanced Security Validation** - MkDocs version validation changed from blocking error to warning
- **📈 Improved CI Coverage** - Quality assurance workflow now runs full security control validation
- **🔐 Strengthened Security Posture** - Repository security controls increased from ~35 to 40+ comprehensive checks

### Performance
- **⚡ Fixed Script Performance** - Documentation validation now completes in ~3 seconds (was hanging indefinitely)
- **🚀 Faster CI Feedback** - Eliminated CI failures that blocked sync detection from running

### Developer Experience
- **✅ Reliable CI Pipeline** - All quality gates now pass consistently
- **🔍 Better Sync Detection** - Functional synchronization scripts can now run and catch dogfooding gaps
- **📋 Clear Validation Results** - 36/38 critical checks passing with actionable feedback on warnings

**Philosophy Achievement**: *"If it's not good enough for us, it's not good enough for users"* - Complete dogfooding plus compliance implemented.

## [0.3.7] - 2025-01-25

### 🚀 Major Enhancement Release

**Intelligent Multi-Language Detection & Comprehensive Documentation** - Revolutionary pre-push hook language detection and complete Rust dependency security documentation.

### Added
- **🔍 Intelligent Language Detection** - Pre-push hook now detects Rust, Node.js, TypeScript, Python, Go, and Generic projects at runtime
- **📋 Security Check Planning** - Shows users exactly which security checks will run for their detected languages
- **🦀 Comprehensive Rust Dependency Documentation** - Complete documentation of 4-tool security architecture (cargo-machete, cargo-deny, cargo-geiger, cargo-auditable)
- **🤖 Dependabot Integration Documentation** - Explained how Dependabot complements local security pipeline
- **🎯 Polyglot Repository Support** - Unified hook handles multiple languages in single repository
- **📖 Enhanced Architecture Documentation** - Complete defense-in-depth security workflow documentation

### Changed
- **Multi-Language Architecture** - Replaced language-specific hooks with unified runtime detection
- **Improved User Experience** - Clear language detection messages replace confusing "workspace" terminology
- **Educational Focus** - Pre-push hook explains what checks will run and why
- **Documentation Consolidation** - Merged multi-language architecture into main architecture docs

### Fixed
- **Misleading Messages** - Removed confusing "workspace has no members" messages
- **Language Detection** - Fixed detection logic for complex project structures
- **Documentation Consistency** - Aligned all documentation with multi-language implementation

### Security
- **Enhanced Documentation** - Complete security rationale for all Rust dependency tools
- **Tool Synergy Explanation** - Documented how cargo tools work together for defense-in-depth
- **Continuous Monitoring** - Explained Dependabot's role in ongoing security maintenance

### Performance
- **Runtime Detection** - Language detection happens at execution time, not install time
- **Optimized Workflow** - Single hook handles all languages efficiently
- **Clear Communication** - Users immediately understand security coverage

---

## [0.3.1] - 2025-01-24

### 🔧 Maintenance Release

**Repository URL Migration and Workflow Fixes** - Complete transition to 1-Click GitHub Security branding and improved CI reliability.

### Fixed
- **Workflow compatibility** - Updated CI workflows from deprecated `--non-rust` to `--language=generic` option
- **ShellCheck compliance** - Fixed SC2076 warning in regex comparison for better code quality
- **Shell script formatting** - Applied consistent formatting with shfmt for better maintainability

### Changed
- **Repository URL migration** - Updated all documentation and script references from `1-click-rust-sec` to `1-click-github-sec`
- **Documentation consistency** - Ensured all links point to the correct repository across all files
- **Release branding** - Updated release titles and descriptions to reflect "1-Click GitHub Security"

### Infrastructure
- **CI pipeline stability** - All GitHub Actions workflows now pass consistently
- **Quality assurance** - Fixed shell script linting and formatting issues
- **Binary synchronization** - Improved sync workflows for helper tools (gitleakslite, pinactlite)

---

## [0.3.0] - 2025-01-24

### 🚀 Major Version Update

**Transform to 1-Click GitHub Security** - Multi-language support and comprehensive security framework.

### Added
- **Multi-language support** - Rust, Node.js, Python, Go support
- **Enhanced installer architecture** - Improved single-script design
- **Advanced security controls** - Expanded from Rust-specific to universal
- **Improved documentation** - Comprehensive CLAUDE.md design principles
- **Better error handling** - Enhanced user experience and debugging

### Changed
- **Project scope expansion** - From 1-click-github-sec to 1-click-github-sec
- **Architecture improvements** - Single-script with zero external dependencies
- **Performance optimizations** - Faster pre-push hook execution
- **Documentation updates** - Complete redesign of project documentation

### Security
- **Enhanced cryptographic verification** - Stronger supply chain protection
- **Improved secret detection** - Advanced gitleaks integration
- **Better vulnerability scanning** - Multi-language vulnerability detection

---

## [0.1.0] - 2025-01-21

### 🎉 Initial Release

**1-Click GitHub Security** - Security controls for multi-language projects, installed in seconds.

### Added

#### Core Features
- **25+ Security Controls** in pre-push hook validation
- **Cryptographic verification** for all components (SHA256 checksums)
- **Two-tier security architecture** (pre-push blocking + CI deep analysis)
- **Zero-configuration installation** with sensible defaults
- **Multi-project support** (Rust, non-Rust, hybrid projects)

#### Security Controls (Pre-Push Hook)
- Secret detection (AWS keys, GitHub tokens, API keys, private keys)
- Vulnerability scanning via cargo-deny
- GitHub Actions SHA pinning verification
- Test suite validation
- Code formatting enforcement
- License compliance checking
- Large file detection
- Commit signature verification
- Dependency version pinning checks
- Build script security analysis
- Documentation secret scanning
- Environment variable security
- Unsafe code monitoring
- File permission auditing
- Technical debt tracking
- And 10+ additional checks

#### Helper Tools
- **pinactlite** - Lightweight GitHub Actions pinning verifier and auto-pinner
- **gitleakslite** - Efficient secret scanner with configurable allow-listing

#### CI/CD Workflows
- Pinning validation workflow (ensures all actions are SHA-pinned)
- Shell script linting (shfmt + shellcheck)
- Documentation building and deployment
- End-to-end testing suite
- Installer self-test validation

#### Documentation
- Comprehensive README with quick-start guide
- Installation guide with multiple verification methods
- Architecture documentation
- Security controls reference
- Contributing guidelines
- YubiKey/Sigstore integration guide

#### Configuration
- Customizable security controls via `.security-controls/config.env`
- Secret detection allow-listing support
- Configurable tool selection (cargo-deny vs cargo-audit)
- Skip options for specific checks

### Security Features
- All GitHub Actions workflows use SHA-pinned actions
- Signed commits with Sigstore support
- Dependency lock file validation
- Supply chain attack prevention
- Comprehensive secret detection patterns

### Performance
- Pre-push validation completes in ~60 seconds
- Parallel execution of independent checks
- Smart caching for repeated operations
- Minimal overhead for developer workflow

### Platform Support
- Linux (primary)
- macOS (tested)
- Windows (via WSL)
- GitHub Actions CI/CD
- GitLab CI (basic support)

### Known Limitations
- Requires bash 4.0+
- Some Rust-specific checks require cargo toolchain
- GPG signature verification not yet implemented
- SBOM generation requires additional tools

---

### Installation

```bash
# Quick install with verification
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh.sha256
# VERIFY checksum before execution (STRONGLY RECOMMENDED - critical security practice)
sha256sum -c install-security-controls.sh.sha256
chmod +x install-security-controls.sh
./install-security-controls.sh
```

### Feedback

Please report issues at: https://github.com/h4x0r/1-click-github-sec/issues

### Contributors

- Primary development team
- Open source community
- Security tool maintainers (cargo-deny, gitleaks, pinact)

---

[0.4.0]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.4.0
[0.3.9]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.9
[0.3.8]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.8
[0.3.7]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.7
[0.3.1]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.1
[0.3.0]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.3.0
[0.1.0]: https://github.com/h4x0r/1-click-github-sec/releases/tag/v0.1.0