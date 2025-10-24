# 1-Click GitHub Security 🛡️

<div align="center">
  <img src="docs/1-click-github-sec Logo.png" alt="1-Click GitHub Security" width="200">
</div>

**Deploy security controls to any project in one command**

*Security that auto-fixes problems instead of just complaining about them*

*Created by Albert Hui <albert@securityronin.com>* [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

Supports **Rust, Node.js, Python, Go, and generic projects** with 35+ security controls including pre-push validation, CI/CD workflows, and GitHub security features.

**📊 [Executive Briefing](docs/executive-briefing.md)** | **📚 [Documentation](https://h4x0r.github.io/1-click-github-sec/)** | **🏗️ [Architecture](docs/architecture.md)**

[![Security](https://img.shields.io/badge/Installer%20Provides-35%2B%20Controls-green.svg)](https://h4x0r.github.io/1-click-github-sec/) [![GitHub Integration](https://img.shields.io/badge/Works%20with-GitHub-181717?logo=github&logoColor=white)](https://docs.github.com/en/rest) [![GitHub Security](https://img.shields.io/badge/GitHub%20Security-6%20Features-blue.svg)](https://h4x0r.github.io/1-click-github-sec/) [![Performance](https://img.shields.io/badge/Pre--Push-%3C60s-orange.svg)](https://h4x0r.github.io/1-click-github-sec/) [![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE) [![Version](https://img.shields.io/badge/Version-v0.7.0-purple.svg)](https://github.com/h4x0r/1-click-github-sec/releases)

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
🤖 **Renovate** - Automated dependency updates with automerge
🔐 **Secret scanning** - Repository-wide credential detection
🔐 **Branch protection** - Enforce security policies
🔐 **Security advisories** - Vulnerability disclosure workflow

---

## 🧠 Design Philosophy: Don't Make Me Think (DMMT)

**Security that works like a UK power plug - impossible to do wrong, automatic to do right.**

Our DMMT principle means:
- **🛠 Auto-fixes instead of errors** - We fix SHA pinning automatically, not just complain
- **⚡ Zero configuration required** - Sensible defaults that work immediately
- **🎯 One command, comprehensive security** - No manual setup or integration
- **✨ Invisible when working** - Security runs in background, visible only when needed
- **🔧 Graceful degradation** - Partial features better than complete failure

**Example:** Instead of `"Error: Action not pinned"`, you see `"✅ Auto-pinned actions/checkout@v4 → @08eba0b2"`

This isn't just convenient - it's security through design. Like the UK plug that physically prevents incorrect insertion, we make insecure practices impossible rather than merely discouraged.

---

## 🚀 Quick Start

**Install security controls in your project:**

```bash
# Download installer and SLSA provenance
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.7.0/install-security-controls.sh
curl -O https://github.com/h4x0r/1-click-github-sec/releases/download/v0.7.0/multiple.intoto.jsonl

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

No configuration files to edit. No tools to manually install. No documentation to read. **It just works.**

**Why verify?** Every release is cryptographically signed with SLSA Build Level 3 provenance - proving it wasn't tampered with. [Learn more →](https://h4x0r.github.io/1-click-github-sec/cryptographic-verification)

---

## 📖 Complete Documentation

**👉 [Visit Documentation Site](https://h4x0r.github.io/1-click-github-sec/) 👈**

### 🚀 New Users
- **[Quick Start](https://h4x0r.github.io/1-click-github-sec/)** - Get running in 5 minutes
- **[Installation Guide](https://h4x0r.github.io/1-click-github-sec/installation)** - Detailed setup instructions
- **[Upgrading Guide](docs/UPGRADING.md)** - Upgrade to latest version (v0.9.0+ features config-driven workflow generation)

### 🔧 Power Users
- **[Security Architecture](https://h4x0r.github.io/1-click-github-sec/architecture)** - How everything works
- **[GitHub Enterprise vs Free](https://h4x0r.github.io/1-click-github-sec/github-enterprise-comparison)** - Feature availability and alternatives
- **[Complete Signing Guide](https://h4x0r.github.io/1-click-github-sec/signing-guide)** - 4-mode setup, GPG vs gitsign, verification
- **[Cryptographic Verification](https://h4x0r.github.io/1-click-github-sec/cryptographic-verification)** - Advanced verification procedures

### 👥 Contributors
- **[Contributing Guide](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/contributing.md)** - Development setup
- **[Repository Security & Quality Assurance](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/repo-security-and-quality-assurance.md)** - This repo's implementation
- **[Design Principles](https://github.com/h4x0r/1-click-github-sec/blob/main/docs/design-principles.md)** - Architectural decisions

### 📊 Leadership
- **[Executive Briefing](https://h4x0r.github.io/1-click-github-sec/executive-briefing)** - Strategic evaluation for CTOs, VPs, Directors

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