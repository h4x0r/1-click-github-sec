# GitHub Security Features: Free vs Enterprise

This guide explains which GitHub security features are available for free versus Enterprise-only, and how 1-Click GitHub Security provides alternatives where possible.

---

## 🎯 Quick Summary

**1-Click GitHub Security maximizes security within GitHub's free tier** by providing client-side alternatives to server-side Enterprise features.

| Capability | GitHub Enterprise | 1-Click GitHub Security Alternative |
|------------|------------------|-------------------------------------|
| **Block secrets before push** | Push Protection (server-side) | gitleaks pre-push hook (client-side) |
| **Custom secret patterns** | Organization settings | `.gitleaks.toml` configuration |
| **Security dashboard** | Security Overview | Generated reports via Actions |
| **Dependency review** | Dependency Review API | Renovate + dependency-review action |
| **Audit logging** | Audit log streaming | Git hooks + local logs |

---

## 📊 Complete Feature Comparison

### Security Scanning Features

| Feature | Free (Public Repos) | Free (Private Repos) | Enterprise | 1-Click Alternative |
|---------|-------------------|---------------------|------------|-------------------|
| **Dependabot Alerts** | ✅ Yes | ❌ No | ✅ Yes | ✅ Via package manager audit |
| **Dependabot Security Updates** | ✅ Yes | ❌ No | ✅ Yes | ✅ Via Renovate |
| **Secret Scanning (Detection)** | ✅ Yes | ❌ No | ✅ Yes | ✅ Via gitleaks |
| **Secret Scanning (Push Protection)** | ❌ No | ❌ No | ✅ Yes | ✅ Via pre-push hooks |
| **Custom Secret Patterns** | ❌ No | ❌ No | ✅ Yes | ✅ Via `.gitleaks.toml` |
| **Code Scanning/CodeQL** | ✅ Yes | ❌ No | ✅ Yes | ✅ Via Actions (public) |
| **Third-party SAST Upload** | ✅ Limited | ❌ No | ✅ Yes | ⚠️ Partial via Actions |
| **Security Advisories** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Native support |

### Advanced Security Features

| Feature | Free | Enterprise | 1-Click Alternative |
|---------|------|------------|-------------------|
| **Security Overview Dashboard** | ❌ No | ✅ Yes | ⚠️ Custom reports via Actions |
| **Dependency Review API** | ❌ No | ✅ Yes | ⚠️ dependency-review action |
| **Advanced CodeQL Queries** | ❌ No | ✅ Yes | ⚠️ Custom queries in `.github/codeql` |
| **Security Managers Role** | ❌ No | ✅ Yes | ❌ No alternative |
| **Audit Log Streaming** | ❌ No | ✅ Yes | ⚠️ Local git hooks logging |
| **SAML/SSO Enforcement** | ❌ No | ✅ Yes | ❌ No alternative |
| **IP Allow Lists** | ❌ No | ✅ Yes | ❌ No alternative |

**Legend:**
- ✅ **Full support** - Feature available/implemented
- ⚠️ **Partial support** - Limited alternative available
- ❌ **Not available** - No alternative possible

---

## 🛠️ How 1-Click Provides Alternatives

### 1. **Secret Detection & Blocking**

| Aspect | GitHub Enterprise | 1-Click Implementation |
|--------|------------------|----------------------|
| **When** | Server-side (push-time) | Client-side (pre-push) |
| **Coverage** | All pushes to GitHub | Local commits only |
| **Bypass** | Requires admin override | `git push --no-verify` |
| **Custom Patterns** | UI configuration | `.gitleaks.toml` file |
| **Performance** | Instant (server-side) | ~2 seconds locally |

**1-Click Implementation:**
```bash
# Pre-push hook automatically installed
.git/hooks/pre-push

# Custom patterns in .gitleaks.toml
[rules]
  [[rules]]
    description = "Company API Key"
    regex = '''company_api_[0-9a-f]{32}'''
```

### 2. **Dependency Management**

| Aspect | GitHub Enterprise | 1-Click Implementation |
|--------|------------------|----------------------|
| **Updates** | Dependabot | Renovate bot |
| **Vulnerability DB** | GitHub Advisory DB | Multiple sources via Renovate |
| **Auto-merge** | Native Dependabot | Renovate automerge |
| **Grouping** | Dependabot groups | Renovate packageRules |
| **Custom Rules** | Limited | Extensive via renovate.json |

**1-Click Advantages:**
- More flexible configuration
- Multiple vulnerability sources
- Better monorepo support
- Custom versioning strategies

### 3. **Code Scanning**

| Aspect | GitHub Enterprise | 1-Click Implementation |
|--------|------------------|----------------------|
| **SAST Engine** | CodeQL | CodeQL (public) + Trivy |
| **Custom Rules** | Advanced queries | Basic CodeQL + Semgrep |
| **Results Upload** | Native SARIF | Actions artifact upload |
| **PR Comments** | Native integration | Actions-based comments |
| **Dashboard** | Security tab | Actions summary |

### 4. **Security Metrics & Reporting**

| Metric | GitHub Enterprise | 1-Click Alternative |
|--------|------------------|-------------------|
| **Vulnerability Count** | Security Overview | Actions workflow output |
| **MTTR** | Insights API | Custom calculation in Actions |
| **Coverage** | Native metrics | Script-based analysis |
| **Trends** | Built-in graphs | Generated markdown reports |
| **Alerts** | Native + webhooks | Actions failure notifications |

---

## 🎯 Practical Implications

### For Open Source Projects

**You get almost everything for free!** Public repositories have access to most GitHub Advanced Security features:

| Need | Solution | Cost |
|------|----------|------|
| Secret scanning | GitHub native | Free |
| Dependency scanning | Dependabot | Free |
| Code scanning | CodeQL | Free |
| Security advisories | GitHub native | Free |
| **+ 1-Click additions** | Pre-push hooks, Renovate | Free |

### For Private Repositories (Non-Enterprise)

**1-Click GitHub Security becomes essential** since most GHAS features are unavailable:

| Need | Without 1-Click | With 1-Click |
|------|----------------|--------------|
| Secret detection | ❌ None | ✅ gitleaks |
| Dependency updates | ❌ Manual | ✅ Renovate |
| Vulnerability scanning | ❌ None | ✅ Multiple tools |
| Code scanning | ❌ None | ⚠️ Limited (Trivy) |
| Pre-push validation | ❌ None | ✅ Comprehensive |

### For Enterprise Organizations

**1-Click complements Enterprise features** by adding client-side validation:

| Scenario | Enterprise Alone | Enterprise + 1-Click |
|----------|-----------------|---------------------|
| Secret blocking | Server-side only | Client + server protection |
| Custom patterns | Org-wide only | Org + repo-specific |
| Dependency updates | Dependabot only | Dependabot + Renovate |
| Security metrics | Dashboard only | Dashboard + custom reports |
| Audit trail | Server logs only | Server + local git logs |

---

## 📈 Migration Path

### From Free to Enterprise

If you're considering GitHub Enterprise, here's what changes:

| Current State (with 1-Click) | After Enterprise | Action Required |
|-------------------------------|------------------|-----------------|
| gitleaks pre-push hooks | Push Protection | Keep both for defense-in-depth |
| Renovate bot | Dependabot | Choose one or use both |
| Custom `.gitleaks.toml` | Org secret patterns | Migrate patterns to org settings |
| Local security logs | Audit log streaming | Integrate with SIEM |
| Actions-based reports | Security Overview | Retire custom reports |

### From Enterprise to Free

If moving from Enterprise to Free tier:

| Lost Feature | 1-Click Replacement | Setup Time |
|--------------|-------------------|------------|
| Push Protection | Pre-push hooks | < 5 minutes |
| Security Overview | Custom reports | < 30 minutes |
| Dependabot (private) | Renovate | < 15 minutes |
| Secret scanning (private) | gitleaks | < 5 minutes |
| CodeQL (private) | Trivy/Semgrep | < 20 minutes |

---

## 🔐 Security Philosophy

### Defense in Depth

**Best Practice:** Use both GitHub Enterprise features AND 1-Click GitHub Security:

```
Developer Machine → Pre-push Hooks (1-Click) → Push Protection (Enterprise) → Repository
        ↓                    ↓                           ↓
   [Local Block]      [Client-side Block]         [Server-side Block]
```

### Why Client-Side Security Matters

Even with GitHub Enterprise, client-side security provides:

1. **Faster feedback** - Catch issues before push attempt
2. **Offline protection** - Works without network connection
3. **Cost savings** - Reduce Enterprise API calls
4. **Privacy** - Sensitive patterns stay local
5. **Customization** - Repository-specific rules

---

## 💡 Recommendations

### For Different Organization Types

| Organization Type | Recommended Setup | Estimated Monthly Cost |
|------------------|-------------------|----------------------|
| **Open Source Project** | GitHub Free + 1-Click | $0 |
| **Small Startup (<10 devs)** | GitHub Team + 1-Click | ~$40 |
| **Growing Company (10-50 devs)** | GitHub Team + 1-Click + Key Enterprise features | ~$200-1000 |
| **Enterprise (50+ devs)** | GitHub Enterprise + 1-Click | $21/user/month |

### Feature Priority Matrix

If budget is limited, prioritize features in this order:

| Priority | Feature | Free Alternative | Enterprise Benefit |
|----------|---------|-----------------|-------------------|
| 🔴 **Critical** | Secret blocking | gitleaks hooks | Push Protection |
| 🔴 **Critical** | Dependency scanning | Renovate | Dependabot |
| 🟡 **Important** | Code scanning | Public repos only | Private repo scanning |
| 🟡 **Important** | Security metrics | Custom reports | Security Overview |
| 🟢 **Nice-to-have** | SSO/SAML | N/A | Centralized access |
| 🟢 **Nice-to-have** | Audit streaming | Local logs | SIEM integration |

---

## 📚 Further Reading

- [GitHub Advanced Security Documentation](https://docs.github.com/en/get-started/learning-about-github/about-github-advanced-security)
- [GitHub Pricing](https://github.com/pricing) - Compare plans and features
- [1-Click Security Architecture](architecture.md) - How our tools integrate
- [Installation Guide](installation.md) - Get started with 1-Click GitHub Security

---

## 🤔 Frequently Asked Questions

**Q: If I have GitHub Enterprise, do I still need 1-Click GitHub Security?**
A: Yes! 1-Click provides client-side validation that complements server-side Enterprise features. It's defense-in-depth.

**Q: Can 1-Click completely replace GitHub Enterprise security features?**
A: No. While 1-Click provides many alternatives, server-side enforcement, SSO, and organizational controls require Enterprise.

**Q: What's the most important Enterprise feature I'm missing?**
A: Push Protection. It's the only way to guarantee secrets never enter your repository, even if developers bypass client-side hooks.

**Q: Is 1-Click GitHub Security "good enough" for compliance?**
A: Depends on your requirements. Many compliance frameworks require server-side controls and audit logs that only Enterprise provides.

---

*Last updated: October 2025*