# 1-Click GitHub Security 🛡️

<div align="center">
  <img src="docs/1-click-github-sec Logo.png" alt="1-Click GitHub Security" width="200">
</div>

**Deploy security controls to any project in one command**

*Created by Albert Hui <albert@securityronin.com>* [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

Supports **Rust, Node.js, Python, Go, and generic projects** with 35+ security controls including pre-push validation, CI/CD workflows, and GitHub security features.

[![Security](https://img.shields.io/badge/Installer%20Provides-35%2B%20Controls-green.svg)](https://h4x0r.github.io/1-click-github-sec/)
[![GitHub Integration](https://img.shields.io/badge/Works%20with-GitHub-181717?logo=github&logoColor=white)](https://docs.github.com/en/rest)
[![GitHub Security](https://img.shields.io/badge/GitHub%20Security-6%20Features-blue.svg)](https://h4x0r.github.io/1-click-github-sec/)
[![Performance](https://img.shields.io/badge/Pre--Push-%3C60s-orange.svg)](https://h4x0r.github.io/1-click-github-sec/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.6.10-purple.svg)](https://github.com/h4x0r/1-click-github-sec/releases)

---

## 🚀 Quick Start

**Install security controls in your project:**

```bash
# Download installer and SLSA provenance
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.6.11/install-security-controls.sh
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.6.11/multiple.intoto.jsonl

# VERIFY with SLSA provenance (cryptographic proof of authenticity)
# Install slsa-verifier: https://github.com/slsa-framework/slsa-verifier#installation
slsa-verifier verify-artifact \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/h4x0r/1-click-github-sec \
  install-security-controls.sh

# Install after verification
chmod +x install-security-controls.sh
./install-security-controls.sh
```

**Python projects:** Activate your environment first for optimal tool installation:
```bash
# conda/miniconda
conda activate myproject

# pyenv/asdf/mise
pyenv local 3.11.0  # or: mise use python@3.11

# virtual environment
source venv/bin/activate

# Then run installer
./install-security-controls.sh
```

**That's it!** Your project now has comprehensive security controls with cryptographic verification!

### 🔐 Why SLSA Build Level 3?

**Every release is cryptographically signed with SLSA provenance:**

- ✅ **Non-falsifiable attestation** - Sigstore cryptographic signing
- ✅ **Verifiable build provenance** - Proves who, when, and how artifacts were built
- ✅ **Supply chain transparency** - Complete build context and materials
- ✅ **Industry standard** - SLSA Build Level 3 compliance
- ✅ **Zero trust** - Verify don't trust, with public transparency log

**Learn More:**
- [SLSA Framework](https://slsa.dev/) - Industry-standard supply chain security
- [slsa-verifier Tool](https://github.com/slsa-framework/slsa-verifier) - Verification utility
- [Our Implementation](https://h4x0r.github.io/1-click-github-sec/slsa-provenance) - Technical details

---

## 🎯 What You Get

### Pre-Push Security (< 60 seconds)
✅ **Secret detection** - Blocks API keys, passwords, tokens
✅ **Vulnerability scanning** - Catches known security issues
✅ **Code quality checks** - Language-specific linting
✅ **Test validation** - Ensures tests pass before push
✅ **Supply chain security** - SHA pinning, dependency validation

### CI/CD Workflows (Comprehensive Analysis)
🔍 **Static analysis** - SAST with CodeQL and Trivy
🔍 **Dependency auditing** - Automated vulnerability detection
🔍 **Security reporting** - SBOM generation and metrics
🔍 **Compliance checking** - License and policy validation

### GitHub Security Features (Automated Setup)
🤖 **Renovate** - Automated dependency updates with automerge and intelligent grouping
🔐 **Secret scanning** - Repository-wide credential detection
🔐 **Branch protection** - Enforce security policies
🔐 **Security advisories** - Vulnerability disclosure workflow

### Cryptographic Verification
🔑 **SLSA Build Level 3** - Cryptographically signed build provenance (v0.6.11+)
🔑 **Signed commits** - Every commit cryptographically verified via gitsign
🔑 **Signed releases** - Release artifacts with Sigstore provenance
🔑 **Certificate transparency** - Public audit trail via Rekor transparency log
🔑 **Keyless signing** - No GPG key management, OIDC-based authentication

---

## 📖 Complete Documentation

**👉 [Visit Documentation Site](https://h4x0r.github.io/1-click-github-sec/) 👈**

### 🚀 New Users
- **[Quick Start](https://h4x0r.github.io/1-click-github-sec/)** - Get running in 5 minutes
- **[Installation Guide](https://h4x0r.github.io/1-click-github-sec/installation)** - Detailed setup instructions

### 🔧 Power Users
- **[Security Architecture](https://h4x0r.github.io/1-click-github-sec/architecture)** - How everything works
- **[Complete Signing Guide](https://h4x0r.github.io/1-click-github-sec/signing-guide)** - 4-mode setup, GPG vs gitsign, verification
- **[Cryptographic Verification](https://h4x0r.github.io/1-click-github-sec/cryptographic-verification)** - Advanced verification procedures

### 👥 Contributors
- **[Contributing Guide](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/contributing.md)** - Development setup
- **[Repository Security & Quality Assurance](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/repo-security-and-quality-assurance.md)** - This repo's implementation
- **[Design Principles](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/design-principles.md)** - Architectural decisions

---

## 🔐 Security Verification

**Every release is cryptographically signed:**

```bash
# Verify release authenticity
git tag -v v0.6.10

# Expected output:
# gitsign: Good signature from [albert@securityronin.com]
# Validated Git signature: true
# Validated Rekor entry: true
```

All commits and releases are signed with [Sigstore](https://sigstore.dev/) and logged in the [Rekor transparency ledger](https://rekor.sigstore.dev/) for public verification.

---

## 📊 This Repository vs Your Project

This repository demonstrates "dogfooding plus" - it uses enhanced security controls beyond what it installs:

| Feature | What Installer Gives You | What This Repository Has |
|---------|-------------------------|--------------------------|
| **Pre-push Controls** | 24 universal security checks | 24 security checks + 5 development-specific |
| **CI/CD Workflows** | Optional installation | 6 specialized development workflows |
| **GitHub Security** | Automated setup | Enhanced with custom policies |
| **Documentation** | Installation guides | Complete documentation site + development controls documentation |
| **Cryptographic Signing** | Optional setup | All commits & releases signed |

**Bottom line:** We use an enhanced version of what we provide to others, proving it works in production.

---

## 💬 Support & Community

- **🐛 [Report Issues](https://github.com/h4x0r/1-click-github-sec/issues)** - Bug reports and feature requests
- **📖 [Documentation](https://h4x0r.github.io/1-click-github-sec/)** - Comprehensive guides and references
- **🔄 [Releases](https://github.com/h4x0r/1-click-github-sec/releases)** - Download latest version
- **🤝 [Contributing](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/contributing.md)** - Help improve the project

---

## 📄 License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.

---

**🛡️ Secure by default. Simple by design. Verified by cryptography.**
