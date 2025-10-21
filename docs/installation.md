# Security Controls Installation Guide

## ⚠️ What This Installer Provides

This installer adds security controls to **YOUR** multi-language project. It provides:
- **35+ pre-push security checks** (run locally before each push)
- **2 helper tools** (pinactlite, gitleakslite)
- **Optional CI workflows** (can be skipped with --no-ci)
- **Configuration files** for security tools
- **🆕 GitHub security features** (with --github-security option)

**Note**: This repository itself has additional development-specific controls. See [repo-security-and-quality-assurance.md](repo-security-and-quality-assurance.md) for details about this repo's enhanced security.

---

## 🚀 Quick Start (Verified Installation)

**Never run unverified installers!** Always check the SHA256 checksum:

```bash
# Download installer and checksum
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh.sha256

# VERIFY CHECKSUM (Critical!)
sha256sum -c install-security-controls.sh.sha256

# Run installer (includes GitHub security by default)
chmod +x install-security-controls.sh
./install-security-controls.sh

# Optional: Skip GitHub security features
./install-security-controls.sh --no-github-security
```

---

## 🛡️ What Gets Installed in YOUR Project

### 1. Pre-Push Hook (`~60 seconds` runtime)

A Git hook that runs 35+ security checks before each push:

#### Universal Checks (All Languages)
- **Secret Detection** - Prevents AWS keys, GitHub tokens, API keys, private keys from being pushed
- **GitHub Actions SHA Pinning** - Verifies action security
- **Large File Prevention** - Blocks files >10MB
- **Commit Signature Verification** - Ensures signed commits

#### Language-Specific Checks

**🦀 Rust Projects (25+ Checks) - Advanced Dependency Security:**

Rust projects get the most comprehensive security controls using a **4-tool defense-in-depth approach**:

##### **Core Security Pipeline** (Pre-Push Hook - ~60 seconds)
1. **🧹 cargo-machete** - Attack Surface Reduction (5s)
   - Removes unused dependencies to minimize supply chain risk
   - Reduces compilation time and binary size
   - Eliminates maintenance burden from unnecessary dependencies

2. **✅ cargo fmt --check** - Code Formatting (2s)
   - Enforces consistent code style
   - Prevents style-related merge conflicts

3. **🔍 cargo clippy** - Advanced Linting (15s)
   - 400+ security-focused lint rules
   - Catches common bugs and anti-patterns
   - Enforces Rust best practices

4. **🧪 cargo test** - Test Suite Validation (20s)
   - Ensures all unit and integration tests pass
   - Prevents broken code from reaching repository

5. **🛡️ cargo-deny check** - Comprehensive Security Audit (10s)
   - **Vulnerability Scanning**: Blocks known CVEs from RustSec Database
   - **License Compliance**: Enforces approved licenses only
   - **Source Verification**: Restricts dependencies to trusted registries
   - **Dependency Bans**: Blocks explicitly dangerous crates
   - **Supply Chain Protection**: Multi-layer dependency validation

6. **⚠️ cargo-geiger --quiet** - Unsafe Code Analysis (5s)
   - Quantifies unsafe code usage across all dependencies
   - Identifies potential memory safety violations
   - Guides manual security review priorities

##### **Advanced CI/CD Analysis** (Post-Push)
- **📦 cargo-auditable build** - Production builds with embedded dependency metadata
- **📊 SBOM Generation** - Complete Software Bill of Materials
- **🔍 Supply Chain Forensics** - Enable post-incident dependency analysis
- **📈 Security Metrics** - Track unsafe code trends over time

##### **Why This Approach is Superior:**
- **Minimize → Validate → Document → Deploy**: Each tool has a specific security role
- **Defense in Depth**: Multiple overlapping security controls catch different threats
- **Fast Developer Feedback**: Critical security issues caught in < 60 seconds
- **Zero False Positives**: Tools tuned for accuracy to maintain developer trust
- **Educational**: Each security failure provides learning opportunities

##### **Tool Synergy Benefits:**
- cargo-machete reduces attack surface before auditing
- cargo-deny provides authoritative security decisions
- cargo-auditable enables production incident response
- cargo-geiger adds quantified risk assessment

##### **🤖 Renovate Integration - Continuous Security Monitoring**

The security pipeline is enhanced by **Renovate integration** for proactive dependency management:

**Automated Security Update Workflow:**
1. **🔍 Renovate Monitoring** - Scans for dependency updates every 6 hours
2. **📝 PR Creation** - Automatically creates pull requests with intelligent grouping
3. **🛡️ Local Validation** - Each Renovate PR triggers the full security pipeline
4. **✅ Automerge** - Automatically merges patch/minor updates after CI passes
5. **📊 Forensic Documentation** - Complete audit trail of all updates

**Key Benefits:**
- **Continuous Monitoring**: Renovate runs every 6 hours automatically
- **Intelligent Grouping**: Groups related updates (workspace deps, GitHub Actions) to reduce PR noise
- **Automerge**: Reduces manual review burden for non-breaking changes
- **Better Workspace Support**: Properly handles Rust workspace dependencies
- **Scheduled PRs**: Creates PRs during work hours (9am-5pm Pacific weekdays)
- **Stability Period**: 3-day wait before automerge ensures package stability

**Configuration**: Self-hosted via GitHub Actions - no manual app installation required.

This creates the most comprehensive dependency security available anywhere, automatically installed and configured with continuous monitoring.

**📦 Node.js Projects (12-Point Security Audit):**
- **Comprehensive npm audit** - Standard + enhanced auditing
- **Vulnerability Scanning** - Snyk + retire.js for JS libraries
- **Code Formatting** - Prettier enforcement
- **Security Linting** - ESLint with security rules
- **License Compliance** - License compatibility checking
- **Package Integrity** - package-lock.json validation
- Plus additional Node.js-specific security checks

**🐍 Python Projects:**
- **Vulnerability Scanning** - safety + pip-audit for Python packages
- **SAST Analysis** - bandit for security issues
- **Code Formatting** - black formatter enforcement
- **Linting** - flake8/pylint with security rules
- **Test Suite** - pytest/unittest execution
- Plus additional Python-specific security checks

**🐹 Go Projects:**
- **Vulnerability Scanning** - govulncheck for Go modules
- **Code Formatting** - gofmt enforcement
- **Linting** - golint with security focus
- **Test Suite** - go test execution
- Plus additional Go-specific security checks


### 2. Helper Tools

Located in `.security-controls/bin/`:

#### pinactlite
```bash
# Check if GitHub Actions are SHA-pinned
.security-controls/bin/pinactlite pincheck --dir .github/workflows

# Auto-pin unpinned actions
.security-controls/bin/pinactlite autopin --dir .github/workflows --actions
```

#### gitleakslite
```bash
# Scan repository for secrets
.security-controls/bin/gitleakslite detect --no-banner

# Check staged changes before commit
.security-controls/bin/gitleakslite protect --staged --no-banner
```

### 3. Configuration Files

#### `.security-controls/config.env`
Controls which checks run and how:
```bash
# Example settings (defaults shown)
SKIP_FORMAT_CHECK=false
SKIP_SECRET_SCAN=false  # NEVER set to true!
CARGO_AUDIT_TOOL="cargo-deny"
MAX_FILE_SIZE_MB=10
```

#### `.security-controls/secret-allowlist.txt`
Patterns to exclude from secret detection (one per line):
```
example-api-key-[0-9]+
test-token-.*
```

#### `.security-controls/gitleaks.toml`
Full gitleaks configuration for secret detection patterns.

### 4. Optional: CI Workflows (--no-ci to skip)

Basic GitHub Actions workflows for continuous security validation.

### 5. Optional: Documentation (--no-docs to skip)

Security guides and architecture documentation.

### 6. 🔐 GitHub Security Features (enabled by default)

Comprehensive GitHub repository security configuration (use `--no-github-security` to skip):

#### ✅ **Automatically Configured**
- **Renovate Automated Updates** - Self-hosted dependency management with automerge
- **Vulnerability Alerts** - Automated dependency scanning with immediate automerge
- **Branch Protection Rules** - Requires PR reviews and status checks
- **CodeQL Security Scanning** - Adds `.github/workflows/codeql.yml`
- **Secret Scanning** - Server-side secret detection (auto-enabled for public repos)
- **Secret Push Protection** - Blocks secret pushes at GitHub level

#### 📋 **Manual Setup Required**
- **Security Advisories** - Private vulnerability reporting (requires repository admin web access)
- **Advanced Security** - ❌ GitHub Enterprise only (not available for public repositories)

#### 🛠️ **Requirements**
- GitHub CLI (`gh`) installed and authenticated
- Repository admin permissions for branch protection
- GitHub repository (not local-only)

#### 💡 **Smart Fallbacks**
If requirements aren't met, the installer provides detailed manual setup instructions.

---

## 📦 Installation Options

### Auto-Detection (Recommended)
```bash
./install-security-controls.sh
```
Automatically detects your project language and installs optimized security controls.

**Supported Languages:**
- **🦀 Rust** - cargo-deny, clippy, fmt, audit, geiger
- **📦 Node.js** - 12-point npm audit, ESLint, Prettier, Snyk
- **🐍 Python** - safety, bandit, black, flake8, pip-audit
- **🐹 Go** - govulncheck, gofmt, golint, go test
- **⚙️ Generic** - Universal security controls for any project

### Force Specific Language
```bash
./install-security-controls.sh --language=nodejs    # Node.js/JavaScript/TypeScript
./install-security-controls.sh --language=python    # Python projects
./install-security-controls.sh --language=go        # Go projects
./install-security-controls.sh --language=rust      # Rust projects
./install-security-controls.sh --language=generic   # Language-agnostic
```

### Polyglot Repository Support
```bash
# For repositories with multiple languages
./install-security-controls.sh --language=rust,nodejs,python
```

### Without GitHub Security Features
```bash
./install-security-controls.sh --no-github-security
```
Local security only (skips GitHub repository configuration).

### Minimal (Hooks Only)
```bash
./install-security-controls.sh --no-ci --no-docs --no-github-security
```
Just the pre-push hook, no extras.

### Preview Mode
```bash
./install-security-controls.sh --dry-run
```
See what would be installed without making changes.

### Force Reinstall
```bash
./install-security-controls.sh --force
```
Overwrite existing security controls.

### Advanced Options
```bash
./install-security-controls.sh --help
```
See all available options.

---

## 📋 Prerequisites

### Always Required
- Git repository (`git init`)
- Bash 4.0+
- curl
- jq

### For Language-Specific Projects

**Rust Projects:**
- Rust toolchain (rustup)
- Cargo
- Optional: cargo-deny, cargo-audit, cargo-geiger, cargo-machete

**Node.js Projects:**
- Node.js runtime
- npm or yarn
- Optional: ESLint, Prettier, audit-ci

**Python Projects:**
- Python 3.6+
- pip
- Optional: black, flake8, safety, bandit

**Go Projects:**
- Go toolchain 1.16+
- Optional: govulncheck, golint, gofmt

---

## 🔧 Post-Installation Configuration

### 1. Test the Installation
```bash
# Create a test file with a fake secret
echo "aws_access_key_id=AKIAIOSFODNN7EXAMPLE" > test.txt
git add test.txt
git commit -m "test"
git push  # Should be blocked!
```

### 2. Customize Security Controls
Edit `.security-controls/config.env`:
```bash
# Skip specific checks if needed (not recommended)
SKIP_FORMAT_CHECK=true  # Skip format checking
SKIP_TESTS=true         # Skip test execution

# Choose audit tool
CARGO_AUDIT_TOOL="cargo-audit"  # or "cargo-deny"
```

### 3. Handle False Positives
Add patterns to `.security-controls/secret-allowlist.txt`:
```
# Example: Allow test API keys
test-api-key-[a-z0-9]+
```

### 4. Configure Commit Signing (Optional)

The installer supports **4 cryptographic signing modes** for securing your commits and releases:

| **Mode** | **Security Level** | **GitHub Badges** | **Setup Command** |
|----------|-------------------|-------------------|-------------------|
| **gitsign + software** | High | No | `./install-security-controls.sh` (default) |
| **gitsign + YubiKey** | Maximum | No | `./install-security-controls.sh --yubikey` |
| **GPG + software** | Medium | Yes | `./install-security-controls.sh --signing=gpg` |
| **GPG + YubiKey** | High | Yes | `./install-security-controls.sh --signing=gpg --yubikey` |

> 📖 **For complete signing setup, comparison, and verification guide**, see **[Complete Signing Guide](signing-guide.md)**

#### Quick Commands

```bash
# Check current signing mode
./install-security-controls.sh status

# Switch modes after installation
./install-security-controls.sh switch-to-gitsign
./install-security-controls.sh switch-to-gpg

# Test current configuration
./install-security-controls.sh test
```

---
## 🚨 Troubleshooting

### Pre-push Hook Takes Too Long
- Run tests before push: `cargo test`
- Build in release mode: `cargo build --release`
- Skip non-critical checks in config

### False Positive Secret Detection
- Add pattern to `.security-controls/secret-allowlist.txt`
- Use environment variables instead of hardcoded values

### Missing Tools
The installer will show instructions for installing missing tools:
```bash
# Example: Install cargo-deny
cargo install cargo-deny

# Example: Install cargo-geiger
cargo install cargo-geiger
```

### Emergency Bypass
**Use only for critical hotfixes:**
```bash
git push --no-verify
```

---

## 🔄 Updating

### Check for Updates
```bash
./install-security-controls.sh --check-update
```

### Upgrade to Latest
```bash
./install-security-controls.sh --upgrade
```

### Manual Update
```bash
# Download latest installer
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/install-security-controls.sh.sha256

# Verify and run
sha256sum -c install-security-controls.sh.sha256
chmod +x install-security-controls.sh
./install-security-controls.sh --force
```

---

## 🗑️ Uninstallation

```bash
# Download uninstaller
curl -O https://raw.githubusercontent.com/h4x0r/1-click-github-sec/main/uninstall-security-controls.sh

# Run uninstaller
chmod +x uninstall-security-controls.sh
./uninstall-security-controls.sh
```

Or manually remove:
```bash
rm -rf .security-controls/
rm .git/hooks/pre-push
rm -rf .github/workflows/security-*.yml  # If CI was installed
rm -rf docs/security/  # If docs were installed
```

---

## 📊 Performance Optimization

### Expected Timings
| Check | Typical Time | Optimization |
|-------|-------------|--------------|
| Format | ~2s | Run `cargo fmt` regularly |
| Clippy | ~15s | Fix warnings promptly |
| Tests | ~20s | Keep tests focused |
| Security Audit | ~5s | Update dependencies regularly |
| Secret Scan | ~2s | Use allowlist for false positives |
| Other | ~15s | - |
| **Total** | **~60s** | **Target: Under 90s** |

### Speed Tips
1. **Warm caches**: Pre-build before pushing (language-specific)
2. **Fix issues early**: Don't let warnings accumulate
3. **Optimize tests**: Focus on fast unit tests
4. **Update regularly**: Keep dependencies current
5. **Language-specific optimizations**:
   - **Rust**: Run `cargo build --release` before pushing
   - **Node.js**: Use `npm ci` for faster installs
   - **Python**: Use virtual environments and activate before installation
   - **Go**: Keep module cache warm

### Python Environment Best Practices

**Activate your preferred Python environment before running the installer:**

```bash
# Example with conda
conda activate myproject
./install-security-controls.sh

# Example with pyenv
pyenv local 3.11.0
./install-security-controls.sh

# Example with mise/asdf
mise use python@3.11
./install-security-controls.sh

# Example with virtual environment
source venv/bin/activate  # or: .venv/bin/activate
./install-security-controls.sh
```

The installer will detect and use your active environment's Python and install security tools accordingly. For fastest performance, install `uv` first: `pip install uv`

---

## 🆘 Getting Help

### Resources
- [Project Overview](https://github.com/h4x0r/1-click-github-sec) - GitHub repository
- [Issues](https://github.com/h4x0r/1-click-github-sec/issues) - Report problems
- [Repository Security & Quality Assurance](repo-security-and-quality-assurance.md) - This repository's enhanced security

### Common Issues
- **"Command not found"**: Install missing tools per instructions
- **"Permission denied"**: Run `chmod +x` on scripts
- **"Not a git repository"**: Run `git init` first
- **"Checksum mismatch"**: Re-download both files

---

## 🔒 Security Notes

1. **Always verify checksums** before running the installer
2. **Never skip secret detection** in production
3. **Use --no-verify sparingly** and only for emergencies
4. **Keep tools updated** for latest security patches
5. **Review configuration** regularly

---

**Questions?** Open an issue at https://github.com/h4x0r/1-click-github-sec/issues