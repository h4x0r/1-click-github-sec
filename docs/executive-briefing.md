# Executive Briefing: 1-Click GitHub Security

## Executive Summary

**The Problem:**
- Data breaches cost [$4.45M on average](https://www.ibm.com/reports/data-breach), 74% involve human error
- [10 million secrets](https://www.gitguardian.com/state-of-secrets-sprawl-report-2023) leaked to public GitHub repos in 2022 (67% increase from 2021)
- Manual security tool integration is time-consuming and inconsistently applied across teams

**The Solution:**
One command installs 35+ security controls across Rust, Node.js, Python, Go, and generic projects. Blocks secrets, vulnerabilities, and policy violations before code reaches your repository.

**Key Benefits:**
- **Fast:** Pre-push security checks complete in < 60 seconds
- **Automated:** Fixes issues automatically where safe, blocks critical problems
- **Zero Dependencies:** Single bash script, works on any Unix system
- **Open Source:** [Apache 2.0 license](https://github.com/h4x0r/1-click-github-sec), no vendor lock-in or telemetry

**Evaluation:** Install on non-critical repository (~10 min), measure impact over 1-2 weeks, assess fit with existing tools.

**Next Steps:** [Full documentation](https://h4x0r.github.io/1-click-github-sec/) | [Technical details below](#what-it-is)

---

## Technical Overview

Open-source framework deploying 35+ security controls via git hooks and GitHub Actions. Supports Rust, Node.js, Python, Go, and generic projects with language-native tooling (cargo-deny, npm audit, bandit, govulncheck, gitleaks).

**Architecture:** Single-script installer (bash 3.2+, zero dependencies) that auto-detects project language and configures pre-push hooks (< 60s) + CI workflows for comprehensive analysis.

**What Gets Deployed:**
- Git hooks (pre-commit format checking, pre-push security scanning)
- GitHub Actions (security-audit.yml, CI, dependency-review, language-specific workflows)
- Configuration (`.gitleaks.toml`, language security configs, audit logs)

[Full technical documentation](https://h4x0r.github.io/1-click-github-sec/) | [Source code](https://github.com/h4x0r/1-click-github-sec)

---

## Architecture & Design

**Two-Tier Security Model:**
- **Pre-push tier** (< 60s): Blocks secrets, vulnerabilities, policy violations at commit time
- **CI/CD tier**: Comprehensive SAST, SBOM generation, compliance checks, security metrics

**Design Principles:**
- Single-script architecture (bash 3.2+, zero external dependencies)
- Cryptographic verification (SHA256 checksums, Sigstore/gitsign commit signing, SLSA provenance)
- Language-native tooling (leverages cargo, npm, pip, go ecosystems)
- Standards alignment (OWASP, NIST, SLSA)

**Implementation:**
- Auto-detection via file markers (Cargo.toml, package.json, go.mod, etc.)
- Installs in ~10 minutes with checksum verification
- All security decisions logged to `.security-controls/logs/`
- No telemetry or external reporting

**Maintenance:**
- Tools update via standard package managers
- Re-run installer for hook updates
- Optional Renovate bot for automated GitHub Actions updates
- Emergency bypass: `git push --no-verify` for hotfixes

**Performance:**
Pre-push hooks designed for < 60s total (actual time varies by repo size, dependency count, machine specs)

---

## Evaluation & Customization

**Pilot Process (2 weeks):**
1. Install on non-critical repository (30 min)
2. Measure pre-push hook times, false positives, developer feedback
3. Assess fit vs. existing tools, maintenance overhead, customization needs

**Customization Options:**
- `.gitleaks.toml` for secret patterns
- Environment variables for tool configuration
- Custom GitHub Actions workflows
- Language-specific security settings

---

## Resources & Support

**[Documentation](https://h4x0r.github.io/1-click-github-sec/)** | **[Source Code](https://github.com/h4x0r/1-click-github-sec)** | **[Issues/Support](https://github.com/h4x0r/1-click-github-sec/issues)**

**Author:** Albert Hui <albert@securityronin.com> [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

Enterprise security leadership at Deloitte, IBM, NTT, HSBC, Morgan Stanley
20+ years Fortune 500 experience

**License:** Apache 2.0 - Free for commercial use