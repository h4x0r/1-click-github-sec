# CLAUDE.md - Design Principles for 1-Click GitHub Security

**Created by Albert Hui <albert@securityronin.com>** [![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/alberthui) [![Website](https://img.shields.io/badge/Website-4285F4?style=flat-square&logo=google-chrome&logoColor=white)](https://www.securityronin.com/)

## 🎯 Project Mission

**1-Click GitHub Security** provides cryptographically verified, comprehensive security controls for multi-language projects with zero compromise on developer experience. We democratize enterprise-grade security for all development ecosystems - starting with Rust, Node.js, Python, and Go.

---

## 🏗️ Core Design Principles

### 1. **Security Without Compromise**
> "Security tools must be more secure than the problems they solve"

- **Verification-First Principle**: As a security vendor, we MUST consistently promote secure practices - never show unverified downloads or execution
- **Cryptographic Verification First**: Every installer, update, and component must be cryptographically verified
- **No Pipe-to-Bash**: Force conscious verification before execution
- **Supply Chain Paranoia**: Assume all external dependencies are compromised until proven otherwise
- **Defense in Depth**: Multiple overlapping security controls, not single points of failure
- **Fail Secure**: When in doubt, block rather than allow

**Implementation Guidelines:**
- **Documentation Standards**: ALL documentation must "strongly recommend" checksum verification with emphatic security language
- **No Insecure Examples**: Never show installation commands without corresponding checksum verification
- **Consistency Requirement**: Installer help, embedded docs, and website must use identical verification language
- SHA256 checksums for all downloadable components
- Sigstore/gitsign signatures for all commits and releases (keyless cryptographic signing)
- Signed commits for all repository changes with Rekor transparency log verification
- Reproducible builds with deterministic outputs
- Audit trails for all security decisions with public transparency

**Verification-First Language Standard:**
```bash
# VERIFY checksum before execution (STRONGLY RECOMMENDED - critical security practice)
```

### 2. **Developer Experience as Security Feature**
> "Friction is the enemy of security adoption"

- **Sub-80 Second Pre-Push**: Fast feedback prevents security bypass behavior
- **Clear Fix Instructions**: Every failure provides specific remediation steps
- **Progressive Enhancement**: Start minimal, add security incrementally
- **Sensible Defaults**: Secure-by-default configuration requiring no expertise
- **Emergency Escape Hatches**: `--no-verify` available but discouraged

**Performance Budget:**
- Pre-push hook: < 60 seconds total
- Individual checks: < 30 seconds each
- Tool installation: < 5 minutes
- First-time setup: < 10 minutes

### 3. **Two-Tier Security Architecture**
> "Fast blocking for critical issues, comprehensive analysis for everything else"

**Pre-Push Tier (< 60s):**
- Blocks secrets, vulnerabilities, and critical policy violations
- Provides immediate feedback to developers
- Optimized for speed and zero false positives
- Essential security controls only

**Post-Push Tier (CI Pipeline):**
- Comprehensive security analysis and reporting
- SAST, vulnerability scanning, compliance checks
- Artifact generation (SBOMs, reports, metrics)
- Human review workflows

### 4. **Cryptographic Trust Model**
> "Trust but verify, with emphasis on verify"

**Chain of Trust:**
```
Sigstore Certificate Authority → GitHub OIDC Identity → gitsign Signing → Rekor Transparency Log → Component Verification
```

**Verification Levels:**
1. **SHA256 Checksums**: Minimum verification (integrity)
2. **Sigstore/gitsign Signatures**: Recommended verification (keyless authenticity + integrity with transparency)
3. **Repository Clone**: Maximum verification (full transparency with Rekor audit trail)

**Trust Boundaries:**
- Package managers (cargo, npm, brew) - considered trusted
- GitHub releases - verify signatures
- Direct downloads - require checksums
- User-generated content - never trusted

### 5. **Ecosystem Integration**
> "Work with each language ecosystem, not against it"

- **Language-Native Tooling**: Leverage existing tooling and conventions for each language
  - **Rust**: Cargo, rustc, clippy, deny, audit
  - **Node.js**: npm, ESLint, Prettier, Snyk, retire.js
  - **Python**: pip, safety, bandit, black, flake8
  - **Go**: go toolchain, govulncheck, gofmt, golint
- **Standard Tool Chain**: Use community-standard security tools for each ecosystem
- **Backward Compatibility**: Don't break existing workflows in any language
- **Cross-Platform**: Support Linux, macOS, Windows (WSL) across all languages
- **CI/CD Friendly**: Integrate seamlessly with GitHub Actions, GitLab CI, etc.

### 6. **Observable Security**
> "Security you can't measure is security you don't have"

- **Comprehensive Logging**: All security decisions logged with context
- **Metrics Collection**: Performance, adoption, effectiveness metrics
- **Audit Trails**: Complete history of security control evolution
- **Reporting**: Clear, actionable security reports for all stakeholders
- **Alerting**: Proactive notification of security issues

### 7. **Single-Script Architecture**
> "True 1-click means zero external dependencies"

- **Standalone Installer**: Single shell script with no external dependencies
- **Built-in Components Only**: Uses only bash, curl, git, and standard Unix tools
- **Self-Contained Framework**: Error handling, logging, and rollback embedded within installer
- **Zero Configuration**: Works out-of-the-box on any Unix-like system
- **Offline Capable**: Core functionality works without internet (after initial download)

**Architectural Constraints:**
- No Python/Node.js/Ruby dependencies
- No package manager requirements beyond system defaults
- No external configuration files or databases
- No separate framework or library installations
- No multi-file deployments or complex directory structures

**Benefits:**
- **Universal Compatibility**: Works on any system with bash 3.2+
- **Zero Installation Friction**: Download one file, run one command
- **Corporate Firewall Friendly**: No complex dependency resolution
- **Airgap Compatible**: Can be transferred and run offline
- **Minimal Attack Surface**: No external code execution or network dependencies

**Implementation Strategy:**
- Embed all framework code directly in `install-security-controls.sh`
- Use bash built-ins and standard Unix utilities only
- Inline all configuration and templates as heredocs
- Self-contained error handling, logging, and rollback systems
- Progressive enhancement: add features without breaking simplicity

### 8. **Dogfooding Plus Philosophy**
> "If it's not good enough for us, it's not good enough for users"

- **Repository as Alpha Test**: This repository implements ALL security controls that the installer provides to users
- **Enhanced Development Controls**: Additional controls specific to our development needs (tool sync, docs, releases)
- **Functional Synchronization**: Automated verification that repo controls match installer templates
- **Quality Assurance Through Use**: We discover issues in our daily development before users encounter them
- **Trust Through Transparency**: Users can inspect our repository to see security controls in action

**Implementation Requirements:**
- Every security control in installer templates must exist in repository workflows
- Repository-only controls are clearly documented and justified
- Automated sync tools prevent functional drift between installer and repository
- Regular audits ensure dogfooding plus philosophy is maintained

**Benefits:**
- **Rapid Bug Discovery**: Issues surface during development before user deployment
- **Continuous Validation**: Daily development workflow validates security control effectiveness
- **User Trust**: Transparent demonstration of security controls in practice
- **Quality Assurance**: Maintains high standards through self-use

---

## 🔧 Implementation Standards

### Code Quality
- **Rust Best Practices**: Idiomatic Rust code following community standards
- **Security-First**: All code assumes hostile input and environments
- **Error Handling**: Comprehensive error handling with user-friendly messages
- **Testing**: Unit, integration, and security tests for all components
- **Documentation**: Inline documentation explaining security decisions

### Engineering Best Practices
> "Quality code is security code"

**Core Programming Principles:**
- **DRY (Don't Repeat Yourself)**: Extract common patterns into reusable functions/modules
- **YAGNI (You Aren't Gonna Need It)**: Implement only what's needed now, avoid over-engineering
- **KISS (Keep It Simple, Stupid)**: Choose simple solutions over complex ones when both work
- **SINE (Simple Is Not Easy)**: Simple solutions require more effort and thought than complex ones
- **Single Responsibility**: Each function/module has one clear purpose
- **No Special Cases**: Design general solutions rather than hardcoded exceptions
- **Fail Fast**: Validate inputs early and provide clear error messages
- **Immutable by Default**: Prefer immutable data structures and functional approaches

**External Integration Standards:**
- **Documentation-First**: Study API documentation thoroughly before implementation
- **Version Pinning**: Always pin external dependencies to specific versions
- **Graceful Degradation**: Handle external service failures without breaking core functionality
- **Rate Limiting**: Respect external API limits and implement backoff strategies
- **Timeout Handling**: Set reasonable timeouts for all external calls

**Code Organization:**
- **Modular Architecture**: Organize code into logical, testable modules
- **Clear Interfaces**: Define explicit contracts between components
- **Separation of Concerns**: Keep business logic separate from I/O operations
- **Configuration Management**: Externalize configuration, never hardcode values
- **Resource Management**: Proper cleanup of files, connections, and other resources

**Security-Focused Development:**
- **Input Validation**: Validate all inputs at system boundaries
- **Least Privilege**: Request minimal permissions necessary
- **Defense in Depth**: Layer multiple validation and security checks
- **Audit Trail**: Log security-relevant operations with sufficient detail
- **Secret Management**: Never commit secrets; use secure storage mechanisms

**Performance and Reliability:**
- **Early Optimization**: Profile before optimizing, measure impact
- **Caching Strategy**: Cache expensive operations with proper invalidation
- **Memory Management**: Be conscious of memory usage and potential leaks
- **Concurrent Safety**: Design for thread safety when applicable
- **Idempotency**: Operations should be safe to retry

### Tool Integration
- **Tool Selection Criteria**:
  - Community adoption and maintenance
  - Performance characteristics
  - Integration complexity
  - False positive rates
  - Security effectiveness

- **Tool Configuration**:
  - Sensible security-focused defaults
  - Customizable for different project needs
  - Performance-optimized settings
  - Clear documentation of trade-offs

### Performance Requirements
- **Pre-Push Hook Performance**:
  - Total time: < 60 seconds
  - Individual tools: < 30 seconds
  - Parallel execution where possible
  - Caching for repeated operations

- **Installation Performance**:
  - Full setup: < 10 minutes
  - Tool downloads: Progress indicators
  - Network resilience: Retry logic
  - Offline operation: Cached tools when possible

---

## 📋 Security Control Framework

### Control Categories

**Tier 1 - Critical (Pre-Push Blocking)**
- Secret detection (gitleaks)
- Known vulnerabilities (cargo-deny)
- Code quality (cargo clippy)
- Test failures (cargo test)
- License violations (cargo-deny)
- Supply chain attacks (pinact)

**Tier 2 - Important (CI Analysis)**
- Static analysis (Semgrep, CodeQL)
- Unsafe code detection (cargo-geiger)
- SBOM generation (cargo-auditable)
- Compliance checks (various)
- Security metrics (OpenSSF Scorecard)

**Tier 3 - Valuable (Optional/Advanced)**
- Fuzzing (cargo-fuzz)
- Binary analysis
- Container scanning
- Infrastructure analysis

### Control Selection Criteria

**Pre-Push Controls Must:**
- Execute in < 30 seconds individually
- Have < 1% false positive rate
- Block genuine security risks
- Provide clear remediation guidance
- Work reliably across platforms

**CI Controls May:**
- Take longer execution time
- Generate complex reports
- Require human review
- Have higher false positive rates
- Depend on external services

---

## 🎨 User Experience Principles

### Installation Experience
- **Verification-First**: Never allow unverified execution
- **Progressive Disclosure**: Show basic options first, advanced on request
- **Sensible Defaults**: Work out-of-the-box for 80% of projects
- **Clear Feedback**: Progress indicators and status messages
- **Graceful Degradation**: Partial installation better than complete failure

### Developer Workflow
- **Invisible When Working**: Security runs automatically without intervention
- **Visible When Broken**: Clear, actionable error messages with fixes
- **Respectful of Time**: Fast feedback loops, no waiting
- **Learning Oriented**: Help developers understand security concepts
- **Emergency Friendly**: Bypass mechanisms for critical fixes

### Error Messages and Guidance
```bash
❌ Security vulnerabilities found in dependencies
   
   Affected crates:
   • serde_json 1.0.50 (RUSTSEC-2020-0001: Stack overflow in Value::clone)
   
   Fix: cargo update serde_json
   
   For emergency bypass: git push --no-verify
   (Use bypass only for critical hotfixes)
```

### Documentation Organization and User Journey
- **Quickstart First**: Always put installation and quickstart guides at the top of documentation lists
- **Cognitive Load Minimization**: Order content by user journey complexity (basic → intermediate → expert)
- **Smooth Flow and Pacing**: Optimize information architecture for immediate action, then progressive learning
- **User-Centric Navigation**: Structure all documentation around user intent, not system architecture

**Implementation Standards:**
- **New Users**: Quick Start → Installation Guide → Basic Configuration
- **Power Users**: Architecture → Advanced Features → Customization
- **Contributors**: Contributing Guide → Technical Details → Design Principles
- **Navigation Order**: Get Started → Power Users → Development/Contributing
- **Link Organization**: Essential actions before technical deep-dives

**Rationale**: Users arrive with specific intents - most want to get started quickly. Bury advanced technical details below actionable guides to reduce abandonment and improve success rates.

### Visual Priority and Reading Patterns
- **Left-to-Right Priority**: Place highest priority information in leftmost columns (users read left→right, top→bottom)
- **Scannable Priority**: Use visual indicators (emojis, colors, typography) in the leftmost position for instant priority recognition
- **Table Design**: Priority column should be first column, followed by identification, then details
- **Executive Readability**: Senior management should see critical vs. non-critical items within first 2 seconds of scanning

**Examples:**
```markdown
✅ Good: | 🚨 CRITICAL | V1 | Identity Spoofing | ...
❌ Bad:  | V1 | Identity Spoofing | ... | 🚨 CRITICAL
```

**Rationale**: Human reading patterns follow F-pattern (focus on left edge), so priority indicators must be positioned where attention naturally falls first.

---

## 🚀 Development Workflow

### Adding New Security Controls

**Evaluation Criteria:**
1. **Security Value**: Does it prevent real attacks?
2. **Performance Impact**: Fits within tier performance budgets?
3. **False Positive Rate**: < 1% for pre-push, < 10% for CI?
4. **Community Adoption**: Widely used and maintained?
5. **Integration Complexity**: Reasonable implementation effort?
6. **Single-Script Compatibility**: Can be embedded without external dependencies?

**Implementation Process:**
1. **Research**: Tool capabilities, community feedback, alternatives
2. **Prototype**: Minimal implementation and testing
3. **Performance Test**: Measure impact on different project sizes
4. **Documentation**: Update architecture and usage documentation
5. **Rollout**: Gradual deployment with monitoring

### Task Prioritization: "Informed Frog Eating" Approach

**Philosophy**: Optimize for both peak cognitive utilization and context building through strategic task sequencing.

**Three-Phase Process:**

**Phase 1: Rapid Reconnaissance (2-3 minutes)**
- Quick scan of ALL tasks to identify true complexity and scope
- Surface hidden dependencies, cascade effects, and blockers
- Assess context switching costs and information requirements
- Map relationships between tasks (which enable/block others)

**Phase 2: Strategic Prioritization**
- **Eat the Frog IF**: Clear scope + no dependencies + truly blocking other work
- **Build Context IF**: Multiple simple tasks create foundational understanding for complex work
- **Parallel Process IF**: Can batch related tasks efficiently with shared context
- **Defer Complex IF**: Insufficient information or context requires preliminary work

**Phase 3: Adaptive Execution**
- Monitor for emerging blockers and complexity escalation
- Switch to frog-eating mode when blockers become apparent
- Continue context-building on simple tasks when they inform complex work
- Batch context-heavy operations (file reads, system analysis)

**Decision Matrix:**
```
High Impact + High Complexity + Clear Scope = EAT THE FROG 🐸
High Impact + Low Complexity = BUILD CONTEXT FIRST ⚡
Low Impact + High Complexity = DEFER OR ELIMINATE ⏸️
Multiple Related Tasks = BATCH PROCESS 📦
```

**Applied Examples:**
- **Frog**: Establishing core security principles (affects all documentation)
- **Context**: Fixing typos across multiple files (builds codebase understanding)
- **Batch**: Reading multiple config files for comprehensive understanding
- **Defer**: Complex refactoring when requirements are still unclear

**Anti-Patterns to Avoid:**
- ❌ Starting complex work without understanding full scope
- ❌ Building context through work that will be invalidated by harder tasks
- ❌ Context switching between unrelated complex problems
- ❌ Avoiding hard but critical decisions that block progress

### File Management and Impact Analysis

**Critical Rule**: File renames, moves, and deletions require comprehensive impact analysis across the entire codebase.

**Problem**: When files are renamed or moved, references can be scattered across:
- Documentation internal links
- CI/CD workflow files (`.github/workflows/*.yml`)
- Scripts and automation tools
- Configuration files (`mkdocs.yml`, `lychee.toml`)
- Installer script embedded documentation
- Cross-references in other documentation

**Required Process for File Changes:**
1. **Pre-Change Analysis**: Search globally for ALL references to the file(s)
   ```bash
   # Search git-tracked files for references (most important)
   git grep -n "old-filename\.md"
   git grep -n "OLD_FILENAME"
   git grep -n "old_filename"

   # Also search filesystem for broader analysis (optional)
   rg "old-filename\.md"  # includes untracked files, may find additional references

   # Find actual files being renamed/moved
   fd "old-filename" || find . -name "*old-filename*" -type f
   ```

2. **Multi-Dimensional Update**: Update ALL discovered references simultaneously:
   - Documentation links and cross-references
   - Workflow trigger paths and file lists
   - Script file arguments and parameters
   - Configuration navigation and includes
   - Any hardcoded file paths or names

3. **Validation**: Test all affected systems after changes:
   ```bash
   # Test documentation builds
   mkdocs build
   # Test workflow validation
   ./scripts/validate-docs.sh
   # Test link checking
   lychee docs/**/*.md README.md
   ```

**Common Failure Pattern**:
- ❌ Updating documentation links but forgetting workflow files
- ❌ Updating workflows but missing configuration files
- ❌ Updating repository files but missing installer script references
- ❌ Moving files without checking cross-references

**Success Pattern**:
- ✅ Global search reveals ALL references before making changes
- ✅ All references updated atomically in same commit
- ✅ Validation tools run to confirm no broken links or references
- ✅ CI workflows tested to ensure they pass after changes

**Lesson**: File structural changes are **multi-dimensional operations** that require systematic impact analysis across all project components. The synchronization complexity described in `docs/repo-and-installer-sync-strategy.md` applies to file management operations as well.

### Documentation Link Format Standards (GitHub + MkDocs)

**Critical Rule**: Understand how different tools interpret documentation links and use appropriate formats for each context.

**Context**: These standards are optimized for GitHub repositories with MkDocs documentation sites and lychee link validation.

**Problem**: Documentation systems use different link formatting conventions, leading to validation failures when formats are mixed incorrectly:

**MkDocs vs Lychee Link Interpretation**:
- **MkDocs** (site generation): Converts directory-style links (`installation/`) to proper web URLs
- **Lychee** (link validation): Interprets links literally as file system paths during CI validation
- **Mixed formats** cause CI failures when lychee can't find files that MkDocs handles correctly

**Link Format Standards by Context**:

1. **Internal Documentation Links** (within docs/ folder):
   ```markdown
   # ✅ CORRECT - Direct file references
   [Installation Guide](installation.md)
   [Security Architecture](architecture.md)
   [4-Mode Signing Configuration](installation.md#4-configure-commit-signing-4-modes-available)

   # ❌ INCORRECT - Directory-style (breaks lychee)
   [Installation Guide](installation/)
   [Security Architecture](architecture/)
   ```

2. **Documentation Site URLs** (external references):
   ```markdown
   # ✅ CORRECT - No trailing slashes
   https://h4x0r.github.io/1-click-github-sec/installation
   https://h4x0r.github.io/1-click-github-sec/architecture

   # ❌ INCORRECT - Trailing slashes (404 errors)
   https://h4x0r.github.io/1-click-github-sec/installation/
   https://h4x0r.github.io/1-click-github-sec/architecture/
   ```

3. **GitHub Repository Links**:
   ```markdown
   # ✅ CORRECT - Full GitHub URLs for directories
   [Workflow Sources](https://github.com/h4x0r/1-click-github-sec/tree/main/.github/workflows)

   # ❌ INCORRECT - Relative paths to directories
   [Workflow Sources](.github/workflows/)
   ```

**Validation Process for Links**:
1. **Test with MkDocs**: `mkdocs build` - ensures site generates correctly
2. **Test with Lychee**: `lychee docs/**/*.md README.md` - ensures CI validation passes
3. **Manual Verification**: Click links in both rendered site and raw markdown

**Common Failure Patterns**:
- ❌ Using MkDocs-style directory links (`installation/`) in contexts where lychee validates
- ❌ Adding trailing slashes to documentation site URLs
- ❌ Using relative paths for repository directory references
- ❌ Mixing link formats without testing both rendering and validation

**Success Pattern**:
- ✅ Use file extensions (`.md`) for internal documentation links
- ✅ Use clean URLs without trailing slashes for external documentation site links
- ✅ Use full GitHub URLs for repository directory and file references
- ✅ Test links with both MkDocs build and lychee validation
- ✅ Maintain consistency within each link type category

**Tools and Commands**:
```bash
# Test MkDocs rendering
mkdocs build -d site

# Test lychee link validation
lychee docs/**/*.md README.md --config lychee.toml

# Test both in CI pipeline
.github/workflows/docs.yml
```

**Lesson**: Documentation link formats must be **context-appropriate** and **tool-compatible**. Different tools have different expectations, and mixing formats without understanding the interpretation differences causes validation failures. Always test links with both rendering and validation tools.

**Scope Limitation**: These guidelines are specific to GitHub + MkDocs + lychee workflows. Other documentation ecosystems (GitLab + Hugo, Bitbucket + Jekyll, etc.) may have different link format requirements.

### Preferred Development Tools

**Critical Rule**: Use the fastest, most reliable tools available for common operations.

**Modern Development Tools** (use when available, with fallbacks):

**Search and File Operations**:
- **git grep** - Search git-tracked files (repository scope, most accurate for version control)
- **ripgrep (`rg`)** - Search filesystem (broader scope, 10-100x faster than grep, respects .gitignore)
- **fd (`fd`)** - Find files (faster than find, simpler syntax, respects .gitignore)
- **/bin/ls** - Use full path to bypass slow aliases (developers often alias ls to colorized versions)

**Package Managers** (by ecosystem):
- **pnpm** over npm - Faster installs, disk space efficient, strict dependency resolution
- **bun** - Ultra-fast JavaScript runtime and package manager
- **uv** over pip - Extremely fast Python package manager (10-100x faster)

**Developer Experience**:
- **zoxide (`z`)** - Smart cd that learns your patterns
- **fzf** - Fuzzy finder for files, history, processes
- **delta** - Better git diff with syntax highlighting
- **dust (`dust`)** - Disk usage analyzer (better than du)
- **procs** - Modern ps with tree view and search
- **sd** - Intuitive sed alternative for find-and-replace
- **tokei** - Fast code statistics (lines of code, languages)

**Tool Selection by Use Case**:
```bash
# Search git-tracked files (most common for repository analysis)
git grep "pattern"                    # searches git index
git grep -n "pattern"                 # with line numbers

# Search all files (broader analysis, includes untracked)
rg "pattern"                          # fast filesystem search
rg "pattern" --type py                # specific file types
rg "pattern" -A 3 -B 3               # with context

# Find files (locate files by name/pattern)
fd "filename"                         # fast file finding
fd -e py                              # by extension
fd -t f "pattern"                     # files only

# List files (bypass slow aliases)
/bin/ls -la                           # use full path to bypass colorized aliases
command ls -la                        # alternative: use command builtin
\\ls -la                              # alternative: escape alias with backslash

# Package management (JavaScript)
pnpm install                          # faster, more efficient
bun install                           # ultra-fast alternative
npm install                           # fallback

# Package management (Python)
uv pip install package                # extremely fast pip replacement
pip install package                   # fallback

# Find-and-replace
sd "old" "new" file                   # intuitive sed alternative
sed 's/old/new/g' file               # fallback

# Tool availability checks
command -v pnpm >/dev/null && pnpm install || npm install
command -v uv >/dev/null && uv pip install package || pip install package

# Fast ls (bypass aliases)
/bin/ls -la                           # always use native ls for performance
```

**Why These Tools Matter**:
- **Performance**: 10-100x speed improvement for large codebases and operations
- **Ergonomics**: Better defaults, cleaner output, more intuitive syntax
- **Git Integration**: Automatically respects .gitignore, shows git status, integrates with workflows
- **Developer Experience**: Syntax highlighting, fuzzy finding, intelligent suggestions
- **Modern Standards**: Becoming standard in modern development environments
- **Disk Efficiency**: Tools like pnpm save significant disk space and bandwidth

**Installation Check**:
```bash
# Core modern tools check
echo "Checking modern development tools..."
command -v rg && echo "✅ ripgrep" || echo "❌ ripgrep (install: brew install ripgrep)"
command -v fd && echo "✅ fd" || echo "❌ fd (install: brew install fd)"
command -v pnpm && echo "✅ pnpm" || echo "❌ pnpm (install: npm install -g pnpm)"
command -v uv && echo "✅ uv" || echo "❌ uv (install: pip install uv)"
test -x /bin/ls && echo "✅ native ls available" || echo "❌ /bin/ls not found"

# Alternative: one-liner check
(command -v rg && command -v fd) >/dev/null && echo "✅ Core modern tools available" || echo "⚠️ Consider installing modern CLI tools for better performance"
```

### Preserving Single-Script Architecture

**Critical Design Decision**: The installer must remain a single, standalone shell script with zero external dependencies.

**Why This Matters:**
- **Enterprise Adoption**: Corporate environments often restrict external dependencies
- **Security Posture**: Minimizes attack surface and supply chain risks
- **Reliability**: No complex dependency resolution or version conflicts
- **Universality**: Works on any Unix-like system without preparation

**Development Guidelines:**
- **Embed, Don't Import**: All framework code must be inline within the installer
- **Standard Tools Only**: bash, curl, git, awk, sed - no Python/Node.js/Ruby
- **Self-Contained Templates**: Use heredocs for all configuration templates
- **No External Files**: All logic, configuration, and data embedded in script
- **Progressive Degradation**: Features work without internet when possible

**Rejected Approaches:**
- ❌ Separate framework files that must be sourced
- ❌ Package manager dependencies (pip, npm, gem)
- ❌ External configuration databases or files
- ❌ Multi-file installer packages
- ❌ Docker containers or virtual environments

**Approved Enhancements:**
- ✅ Embedded error handling frameworks
- ✅ Inline logging and rollback systems
- ✅ Heredoc-based configuration templates
- ✅ Built-in retry and timeout mechanisms
- ✅ Self-contained testing and validation

### Testing Strategy
- **Unit Tests**: Individual component functionality
- **Integration Tests**: End-to-end workflow validation
- **Performance Tests**: Timing and resource usage
- **Security Tests**: Verify security controls actually work
- **User Acceptance Tests**: Real-world usage scenarios

### Release Process
1. **Version Bumping**: **CRITICAL - Always use `./scripts/version-sync.sh X.Y.Z`** to maintain consistency across:
   - VERSION file (Single Source of Truth)
   - README.md version badge
   - install-security-controls.sh SCRIPT_VERSION
   - mkdocs.yml site version
   - CHANGELOG.md entries (manual verification)
   - **Never manually update version numbers** - this causes CI validation failures
2. **Testing**: Full test suite on multiple platforms
3. **Documentation**: Update all relevant documentation
4. **Signing**: Sigstore/gitsign sign all commits and release tags (cryptographically verifiable via Rekor transparency log)
5. **Checksums**: Generate and publish SHA256 hashes for release artifacts
6. **Announcement**: Security-focused release notes with cryptographic verification instructions

---

## 🏛️ Architectural Decision Records (ADRs)

Our design philosophy represents formal architectural decisions that guide all development. These decisions are captured across multiple documents:

### ADR-001: Single-Script Architecture (CLAUDE.md § 7)
**Decision**: Installer must be a single shell script with zero external dependencies
**Status**: ✅ Accepted
**Context**: Enterprise adoption, security posture, reliability, universality
**Consequences**:
- ✅ Works in any Unix environment without preparation
- ✅ Minimal attack surface and supply chain risks
- ❌ Cannot use external frameworks or multi-file architectures
- ❌ All functionality must be embedded inline

### ADR-002: External Service Rejection (README.md § Design Philosophy)
**Decision**: Reject security tools requiring external account registration or GitHub App installation
**Status**: ✅ Accepted
**Context**: True 1-click installation requires zero out-of-band setup
**Consequences**:
- ✅ Works identically for personal and organizational repositories
- ✅ No corporate approval barriers or individual friction
- ❌ Cannot integrate with Socket.dev, Snyk Cloud, Semgrep Cloud
- ❌ Limited to GitHub-native and downloadable tools

### ADR-003: GitHub-Native Tool Preference (Multiple Documents)
**Decision**: Prefer GitHub-native security features over third-party services
**Status**: ✅ Accepted
**Context**: Zero setup, universal availability, no external dependencies
**Consequences**:
- ✅ CodeQL, Dependabot, secret scanning work immediately
- ✅ No authentication or configuration required
- ❌ Limited to GitHub's security feature set
- ❌ Cannot leverage specialized third-party analytics

### ADR-004: Performance Budget for Pre-Push (CLAUDE.md § 2)
**Decision**: Pre-push hook must complete in under 60 seconds total
**Status**: ✅ Accepted
**Context**: Developer experience is a security feature - friction leads to bypass
**Consequences**:
- ✅ Fast feedback prevents security bypass behavior
- ✅ Parallel execution and caching required
- ❌ Cannot run comprehensive analysis in pre-push
- ❌ Deep scanning must be deferred to CI tier

### ADR-005: Cryptographic Verification First (CLAUDE.md § 1)
**Decision**: Every installer, update, and component must be cryptographically verified
**Status**: ✅ Accepted
**Context**: Security tools must be more secure than problems they solve
**Consequences**:
- ✅ SHA256 checksums for all downloadable components
- ✅ Supply chain attack prevention
- ❌ Additional complexity in release process
- ❌ Cannot use tools without verifiable checksums

### ADR-006: Multi-Language Universal Design (CLAUDE.md § 5)
**Decision**: Work with each language ecosystem, not against it
**Status**: ✅ Accepted
**Context**: Leverage existing tooling and conventions for maximum effectiveness
**Consequences**:
- ✅ Use cargo for Rust, npm for Node.js, pip for Python, etc.
- ✅ Backward compatibility with existing workflows
- ❌ More complex installer logic for language detection
- ❌ Must maintain expertise across multiple ecosystems

### Decision Documentation Strategy

**Primary Documentation**: CLAUDE.md (authoritative design principles)
**User Documentation**: README.md (philosophy explanation with examples)
**Technical Documentation**: SECURITY_CONTROLS_ARCHITECTURE.md (implementation details)

**Review Process**: All architectural decisions must align with documented principles
**Change Process**: Principle changes require updating all three documents
**Rationale Capture**: Tool inclusion/rejection decisions documented with specific principle violations

---

## 📊 Success Metrics

### Security Effectiveness
- Vulnerabilities blocked (pre-push)
- Secrets prevented from reaching repositories
- Compliance violations caught
- Supply chain attacks prevented
- Time to security issue resolution

### Developer Experience
- Pre-push hook performance (< 60s target)
- Installation success rate (> 95% target)
- False positive rates (< 1% pre-push, < 10% CI)
- Developer satisfaction surveys
- Security tool adoption rates

### Ecosystem Impact
- Projects using 1-click-rust-sec
- Security issues prevented ecosystem-wide  
- Community contributions and feedback
- Enterprise adoption metrics
- Integration with other security tools

---

## 🔮 Future Vision

### ✅ **Recently Implemented (v0.3.7)**
- ✅ **Multi-language support** - Rust, Node.js, Python, Go, Java, Generic projects
- ✅ **Advanced SAST integration** - CodeQL + Trivy defense-in-depth
- ✅ **Enhanced CI/CD integrations** - 6 specialized workflows with comprehensive security
- ✅ **Documentation synchronization** - Automated consistency validation
- ✅ **Functional synchronization** - Dogfooding plus philosophy implementation
- ✅ **Container security controls** - Trivy vulnerability scanning
- ✅ **GitHub security features** - Dependabot, CodeQL, secret scanning, branch protection

### Short-Term (3-6 months)
- **Enterprise policy management** - Custom policy templates and enforcement
- **Performance optimizations** - Sub-30 second pre-push targets
- **Community ecosystem** - Plugin system for custom security controls
- **SLSA Level 3 compliance** - Enhanced supply chain security
- **Security metrics dashboard** - Real-time security posture visualization

### Medium-Term (6-12 months)
- **AI-assisted security analysis** - LLM-powered vulnerability assessment
- **Automated security remediation** - Self-healing security controls
- **Zero-trust architecture patterns** - Advanced access control frameworks
- **WebAssembly sandbox** - Isolated execution for untrusted code
- **Formal verification** - Mathematical proof of critical security properties

### Long-Term (1-2 years)
- **Predictive vulnerability detection** - Machine learning for threat prediction
- **Industry standard compliance automation** - SOC2, FedRAMP, NIST frameworks
- **Cross-platform mobile support** - iOS/Android security control integration
- **Blockchain integration** - Immutable security audit trails
- **Quantum-resistant cryptography** - Future-proof security algorithms

---

## 🤝 Community Guidelines

### Contribution Principles
- **Security First**: All contributions must maintain or improve security posture
- **Performance Conscious**: Consider impact on developer workflow
- **Backward Compatible**: Don't break existing installations
- **Well Tested**: Include tests demonstrating security effectiveness
- **Documented**: Explain security rationale and trade-offs

### Code Review Standards
- **Security Review**: All changes reviewed for security implications
- **Performance Review**: Timing impact measured and approved
- **Usability Review**: Consider developer experience impact
- **Documentation Review**: Ensure guides remain accurate

### Issue Triage
- **Security Issues**: Highest priority, private disclosure process
- **Performance Regressions**: High priority, block releases
- **Feature Requests**: Evaluated against design principles
- **Bug Reports**: Prioritized by user impact

---

## 🔒 Security Considerations for Development

### Development Environment Security
- Use signed commits for all changes
- Require 2FA for all maintainers
- Regular security audits of the development process
- Secure key management for signing operations
- Principle of least privilege for repository access

### Third-Party Dependencies
- All dependencies security audited before inclusion
- Prefer dependencies with active maintenance
- Pin specific versions with hash verification
- Regular dependency updates with security review
- Alternative dependencies evaluated for critical components

### Release Security
- Reproducible builds with deterministic outputs
- Multiple independent verification of releases
- Signed releases with published checksums
- Security-focused release notes highlighting security changes
- Post-release monitoring for security issues

---

## 📝 Maintenance Philosophy

### Tool Lifecycle Management
- **Evaluation**: Continuous assessment of tool effectiveness
- **Integration**: Thoughtful integration minimizing disruption
- **Maintenance**: Regular updates and security patches
- **Deprecation**: Graceful removal when tools become obsolete
- **Migration**: Smooth transitions between tool versions

### Breaking Changes
- **Avoid When Possible**: Maintain backward compatibility
- **Migrate Gradually**: Provide migration paths and tools
- **Communicate Clearly**: Advanced notice and documentation
- **Support Legacy**: Maintain security updates for previous versions
- **Learn from Experience**: Feedback-driven improvement process

---

**This document serves as the foundation for all development decisions in 1-click-github-sec. When in doubt, refer to these principles to guide technical and product choices.**

---

## 📄 License

**Creative Commons Attribution 4.0 International (CC BY 4.0)**

You are free to:
- **Share** — copy and redistribute the material in any medium or format
- **Adapt** — remix, transform, and build upon the material for any purpose, even commercially

**Under the following terms:**
- **Attribution** — You must give appropriate credit to Albert Hui <albert@securityronin.com>, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.

**Attribution Format:**
```
Based on "Design Principles for 1-Click GitHub Security" by Albert Hui
License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)
Source: https://github.com/h4x0r/1-click-github-sec/blob/main/CLAUDE.md
```

For universal AI-assisted development principles, see: https://t.ly/CLAUDE.md

---

*Last Updated: January 2025*
*Version: 1.1.0*
*Maintainers: @h4x0r and community contributors*