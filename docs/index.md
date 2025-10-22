# 1-Click GitHub Security Controls

<div align="center">
  <img src="./1-click-github-sec Logo.png" alt="1-Click GitHub Security" width="200">
</div>

**Created by Albert Hui <albert@securityronin.com>** [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

[![Documentation](https://github.com/h4x0r/1-click-github-sec/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/docs.yml)
[![Quality Assurance](https://github.com/h4x0r/1-click-github-sec/actions/workflows/quality-assurance.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/quality-assurance.yml)
[![Security Scanning](https://github.com/h4x0r/1-click-github-sec/actions/workflows/security-scan.yml/badge.svg?branch=main)](https://github.com/h4x0r/1-click-github-sec/actions/workflows/security-scan.yml)

**Deploy Security Controls to Any Project in One Command**

```bash
# Download installer and SLSA provenance
curl -LO https://github.com/h4x0r/1-click-github-sec/releases/download/v0.6.11/install-security-controls.sh
curl -LO https://github.com/h4x0r/1-click-github-sec/releases/download/v0.6.11/multiple.intoto.jsonl

# VERIFY with SLSA provenance (cryptographic proof of authenticity)
# Install slsa-verifier: https://github.com/slsa-framework/slsa-verifier#installation
slsa-verifier verify-artifact \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/h4x0r/1-click-github-sec \
  install-security-controls.sh

# Run installer
chmod +x install-security-controls.sh
./install-security-controls.sh
```

Supports **Rust, Node.js, Python, Go, and generic projects** with 35+ security controls.

---

## 🎯 What You Get

✅ **Pre-push validation** (35+ security checks in <60s)
✅ **CI/CD workflows** (comprehensive security scanning)
✅ **GitHub security features** (Renovate, CodeQL, secret scanning)
✅ **Cryptographic verification** (signed commits and releases)

---

## 🚀 **New Here?** Start With These

| Guide | Time | What You'll Learn |
|-------|------|-------------------|
| **[Installation →](installation.md)** | 5 min | Get security controls installed |
| **[Uninstall →](uninstall.md)** | 2 min | Remove controls if needed |

**That's it!** Most users don't need anything else.

---

## 🔧 **Want Technical Details?** Power User Guides

| Guide | Level | What You'll Learn |
|-------|-------|-------------------|
| **[Security Architecture →](architecture.md)** | Advanced | How everything works together |
| **[Complete Signing Guide →](signing-guide.md)** | Intermediate | 4-mode setup, GPG vs gitsign, verification |
| **[Cryptographic Verification →](cryptographic-verification.md)** | Expert | Advanced verification procedures |

---

## 👥 **Contributing?** Development Resources

| Guide | Role | What You'll Learn |
|-------|------|-------------------|
| **[Contributing →](contributing.md)** | Contributors | Development setup and guidelines |
| **[Repository Security & Quality Assurance →](repo-security-and-quality-assurance.md)** | Maintainers | This repo's security implementation |
| **[Design Principles →](design-principles.md)** | Architects | Core design decisions |

---

## 🔗 Quick Links

- **[GitHub Repository](https://github.com/h4x0r/1-click-github-sec)** - Source code & latest releases
- **[Report Issues](https://github.com/h4x0r/1-click-github-sec/issues)** - Found a bug? Let us know
- **[Latest Release](https://github.com/h4x0r/1-click-github-sec/releases/latest)** - Always get the newest version

---

*Updated: September 25, 2025 - Enhanced with cryptographic signing documentation*
