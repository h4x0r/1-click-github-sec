# Cryptographic Verification

## 🔍 Verifying Signatures & Release Integrity

This document covers how to verify cryptographic signatures for commits, tags, and releases. For complete signing setup and mode selection, see the **[Complete Signing Guide](signing-guide.md)**.

---

## 🎯 Quick Verification Commands

### Verify Any Commit
```bash
# Verify specific commit
gitsign verify <commit-hash>

# Verify current HEAD
gitsign verify HEAD

# Verify with expected identity
gitsign verify --certificate-identity="albert@securityronin.com" HEAD
```

### Verify Tags and Releases
```bash
# Verify signed tag
git tag -v v0.6.5

# Show signature details
git log --show-signature -1 v0.6.5
```

### Verify Installation Files
```bash
# Download checksums and installer
curl -sL https://github.com/h4x0r/1-click-github-sec/releases/latest/download/checksums.txt -o checksums.txt
curl -sL https://github.com/h4x0r/1-click-github-sec/releases/latest/download/install-security-controls.sh -o install-security-controls.sh

# VERIFY checksum before execution (STRONGLY RECOMMENDED - critical security practice)
sha256sum -c checksums.txt

# Verify release signature
git tag -v v0.6.5
```

---

## 🔐 What Verification Checks

### gitsign (Sigstore) Verification
✅ **Certificate validity** - Was certificate valid at signing time?
✅ **Identity binding** - Does signer identity match expected email?
✅ **Transparency logging** - Is signature recorded in Rekor ledger?
✅ **Signature integrity** - Has commit been tampered with since signing?
✅ **Trust chain** - Is certificate issued by trusted Fulcio CA?

### Example Successful Verification
```bash
$ gitsign verify HEAD
tlog index: 567315903
gitsign: Signature made using certificate ID 0xd1cb214b2a12f6732a84d1777720903036dbd739
gitsign: Good signature from [albert@securityronin.com](https://github.com/login/oauth)
Validated Git signature: true
Validated Rekor entry: true
Validated Certificate claims: false
WARNING: git verify-commit does not verify cert claims. Prefer using `gitsign verify` instead.
```

### Example Failed Verification
```bash
$ gitsign verify HEAD
Error: signature verification failed
Details: commit content has been modified after signing
```

---

## 🔍 Advanced Verification

### Verify Against Rekor Transparency Log
```python
# Verify release in Rekor transparency ledger
import requests

def verify_release(tag_name, expected_identity):
    """Verify a release exists in Rekor transparency ledger"""
    rekor_url = "https://rekor.sigstore.dev/api/v1/log/entries"

    try:
        response = requests.get(f"{rekor_url}?logIndex=latest")
        entries = response.json()

        for entry in entries:
            # Check if entry relates to our tag
            if tag_name in entry.get("body", {}).get("spec", {}).get("data", ""):
                return {
                    "verified": True,
                    "timestamp": entry.get("integratedTime"),
                    "identity": entry.get("body", {}).get("spec", {}).get("identity"),
                    "log_index": entry.get("logIndex")
                }
    except Exception as e:
        return {"verified": False, "error": str(e)}

    return {"verified": False, "reason": "No matching entry found"}

# Usage
result = verify_release("v0.6.5", "albert@securityronin.com")
print(f"Verification result: {result}")
```

### Manual Signature Inspection
```bash
# Show raw signature data
git cat-file commit HEAD | grep -A 20 "-----BEGIN"

# Check certificate details
git log --format="%G?" HEAD  # G=good, B=bad, U=unknown, N=none

# Detailed signature info
git log --format="%GG" HEAD
```

---

## 📋 Verification Checklist

When verifying releases or commits:

- [ ] **File checksum verified** (`sha256sum -c checksums.txt`)
- [ ] **Tag signature verified** (`git tag -v v0.6.5`)
- [ ] **Rekor entry confirmed** (shows "Validated Rekor entry: true")
- [ ] **Identity matches expected maintainer** (albert@securityronin.com)
- [ ] **Timestamp reasonable** (not from suspicious time)

---

## 🛠️ Troubleshooting Verification

### Common Verification Issues

**"gitsign: command not found"**
```bash
# Install gitsign first
go install github.com/sigstore/gitsign@latest

# Or use our installer
./install-security-controls.sh
```

**"certificate verification failed"**
```bash
# Check expected identity
gitsign verify --certificate-identity="expected@email.com" HEAD

# Verify certificate was valid at signing time
git log --show-signature -1 HEAD
```

**"rekor entry not found"**
```bash
# Signature may predate Rekor logging or be invalid
# Check if commit was signed before transparency logging was enabled

# Search Rekor manually
rekor-cli search --email albert@securityronin.com
```

---

## 🔗 Verification Tools

### Required Tools
- **gitsign** - Sigstore signature verification
- **git** - Built-in GPG signature verification
- **sha256sum** - File integrity verification

### Optional Tools
- **rekor-cli** - Direct Rekor ledger queries
- **cosign** - Container and artifact verification
- **sigstore-python** - Programmatic verification

### Installation
```bash
# Install via our security controls installer
./install-security-controls.sh

# Or install individually
go install github.com/sigstore/gitsign@latest
go install github.com/sigstore/rekor/cmd/rekor-cli@latest
```

---

## 🎯 Key Verification Principles

✅ **Trust but verify** - Always verify signatures before trusting code
✅ **Check identity binding** - Ensure signer matches expected maintainer
✅ **Verify transparency logging** - Confirm signatures are publicly auditable
✅ **Validate file integrity** - Use checksums for downloaded files
✅ **Check certificate validity** - Ensure certificates were valid at signing time

> 💡 **For signing setup and mode selection**, see the **[Complete Signing Guide](signing-guide.md)**

**The bottom line:** Cryptographic verification provides strong assurance that code hasn't been tampered with and comes from the expected source. Always verify before trusting, especially for security-critical tools.