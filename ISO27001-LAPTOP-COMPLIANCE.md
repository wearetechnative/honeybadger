# ISO27001 Laptop Compliance Checker

**Context:** TechNative ISO27001 Policy TN-ISO27-EN-PLCY-05.00
**Doel:** Linux laptop compliance verificatie en rapportage

---

## 📋 Compliance Vereisten (Linux Laptops)

### Minimale Checks (Sectie 3.2, 7.1, 8.1)

| Vereiste | ISO Sectie | Check Methode | Pass/Fail |
|----------|------------|---------------|-----------|
| **Disk encryptie** | 3.2 | `blockdevices.txt` → LUKS/crypto | ✅ Verplicht |
| **Screen lock** | 3.2 | `screenlock-info.txt` | ✅ Verplicht |
| **Firewall actief** | 7.6 | Lynis/firewall status | ✅ Verplicht |
| **Lynis scan uitgevoerd** | 7.1 | `lynis-report.json` aanwezig | ✅ Verplicht |
| **MFA remote access** | 3.2 | Handmatige verificatie | ⚠️ Verify |
| **Geen kwetsbare software** | 8.1 | Lynis PKGS-7392 warning | ❌ Blocker |
| **Hardening score ≥75** | 7.1 | Lynis hardening index | ❌ Blocker |
| **NixOS Supply Chain** (NixOS only) | 8.1 | `nix-supply-chain-audit.txt` → require-sigs | ✅ Verplicht |

---

## 🔍 Scan Output Interpretatie

### Honeybadger Output Bestanden

```
output-{naam}-{datum}/
├── final-report.md           → Overzicht (hardening score, findings)
├── blockdevices.txt          → Disk encryptie check (LUKS)
├── lynis-report.json         → Volledige Lynis data
├── lynis-report-warnings_fails.html → Warnings/suggestions
├── screenlock-info.txt       → Screen lock configuratie
├── installed-packages.txt    → Package inventory
└── nix-supply-chain-audit.txt → NixOS supply chain security (NixOS only)

Generated compliance reports (via check-output command):
├── honeybadger-{user}-{date}-compliance.md → ISO27001 compliance rapport
└── honeybadger-{user}-{date}-actions.md    → Lynis security acties per severity
```

### Kritieke Velden uit final-report.md

- **Disk Encryption:** Moet "✅ Enabled" zijn
- **Screen Lock:** Moet "✅ Enabled" zijn
- **Lynis Hardening Score:** Moet ≥75/100 zijn
- **Security Findings:** Critical/High = blockers

### Blockdevices.txt - Encryptie Check

```bash
# PASS voorbeeld:
crypto_LUKS 2              # LUKS2 encryptie actief
└─nvme0n1p3_crypt          # Encrypted partition

# FAIL voorbeeld:
ext4                       # Geen encryptie!
```

---

## ⚠️ Severity & Deadlines (ISO Sectie 8.1)

| Severity | Deadline | Actie |
|----------|----------|-------|
| **Critical** | **1 week** | Triage door engineer + fix |
| **High** | **1 week** | Triage door engineer + fix |
| **Medium** | 1 maand | Fix plannen |
| **Low** | Best effort | Optioneel |

### Specifieke Issues

- **PKGS-7392** (Vulnerable packages): CRITICAL → patch binnen 1 week
- **Hardening score <75**: CRITICAL → verbeter binnen 1 week
- **Geen encryptie**: BLOCKER → onmiddellijk fixen
- **Geen screen lock**: HIGH → binnen 1 week fixen

---

## 📝 Rapport Template

```markdown
# ISO27001 Laptop Compliance Report

**Eigenaar:** {naam}
**Hostname:** {hostname}
**Scan datum:** {datum}
**OS:** {os_version}

---

## 📋 Compliance Checklist

| Vereiste (ISO27001) | Status | Bevinding |
|---------------------|--------|-----------|
| Disk encryptie | ✅/❌ | {LUKS type of "Niet actief"} |
| Screen lock | ✅/❌ | {timeout of "Niet geconfigureerd"} |
| Firewall | ✅/❌ | {Actief/Inactief} |
| Lynis malware scan | ✅/❌ | {Uitgevoerd/Niet uitgevoerd} |
| MFA remote access | ⚠️ | Niet geverifieerd in scan |
| Kwetsbare software | ✅/❌ | {PKGS-7392 status} |
| Hardening score | ✅/❌ | {score}/100 |

---

## 🔴 Acties Vereist

### Kritiek (binnen 1 week)
- [ ] {lijst met critical/high issues}

### Medium (binnen 1 maand)
- [ ] {lijst met medium issues}

---

## 📊 Samenvatting

**Compliance:** ✅ Compliant / ⚠️ Gedeeltelijk / ❌ Niet compliant
**Blocker:** {hoofdprobleem}
**Deadline:** {datum + 1 week}

---

*Rapport volgens TN-ISO27-EN-PLCY-05.00 (sectie 3.2, 7.1, 8.1)*
```

---

## 🤖 Claude Code Instructies

### Stap 1: Scan Data Inlezen

```bash
# Verwachte directory structuur:
output-{naam}-{datum}/
```

Lees minimaal:
- `final-report.md` (hoofdoverzicht)
- `blockdevices.txt` (encryptie check)
- `lynis-report-warnings_fails.html` (warnings)

### Stap 2: Compliance Evaluatie

```python
# Pseudo-code logica
compliance_status = {
    "disk_encryption": check_luks_in_blockdevices(),
    "screen_lock": check_screenlock_enabled(),
    "firewall": check_firewall_active(),
    "lynis_scan": check_lynis_executed(),
    "vulnerable_pkgs": check_pkgs_7392_warning(),
    "hardening_score": check_score >= 75
}

# Overall status
if all(compliance_status.values()):
    status = "✅ Compliant"
elif any_critical_issues():
    status = "❌ Niet compliant"
else:
    status = "⚠️ Gedeeltelijk compliant"
```

### Stap 3: Genereer Rapport

- Gebruik het rapport template hierboven
- Bereken deadline = scan_datum + 1 week
- Categoriseer acties naar severity
- Refereer naar ISO policy secties

### Stap 4: Output

Genereer markdown bestanden via `./RUNME.sh check-output`:
```
honeybadger-{user}-{date}-compliance.md  → ISO27001 compliance rapport
honeybadger-{user}-{date}-actions.md     → Lynis security acties
```

---

## 📚 Referenties

**ISO27001 Policy:** TN-ISO27-EN-PLCY-05.00
- Sectie 3.2: Portable computers and communication devices
- Sectie 7.1: Protection against viruses and mobile code
- Sectie 8.1: Development and maintenance of systems

**Lynis Checks:**
- PKGS-7392: Vulnerable packages
- NETW-2705: DNS nameservers
- BOOT-5122: GRUB password
- Hardening index: Security score

---

## ✅ Quick Reference

**Compliant laptop = ALL TRUE:**
- ✅ LUKS encryptie actief
- ✅ Screen lock enabled
- ✅ Firewall actief
- ✅ Lynis uitgevoerd
- ✅ Geen kwetsbare packages
- ✅ Hardening score ≥75

**Critical actions = binnen 1 week:**
- Patch kwetsbare software
- Fix hardening score <75
- Enable ontbrekende encryptie
- Enable ontbrekende screen lock


### NixOS Supply Chain Security (nix-supply-chain-audit.txt)

**NixOS-specific check** - only generated on NixOS systems.

**Format:**
```
=== NixOS Supply Chain Trust Check (PKGS-7398) ===

Substituters:        {configured binary cache URLs}
Trusted keys:        {public keys for signature verification}
Require signatures:  {true|false}
Trusted substituters:{trusted binary cache list}

Running store verification (this may take a while)...
Store integrity: {OK|WARNING}

=== Audit Result ===
Result: {PASS|FAIL}

=== ISO27001 Audit Statement ===
{Detailed compliance statement}

Issues identified:
- {list of configuration problems if FAIL}
```

**PASS Criteria:**
- Substituters are explicitly configured (not empty)
- Signature verification is enforced (`require-sigs = true`)
- Trusted public keys are configured for all sources
- Unsigned or tampered packages are rejected by design

**FAIL Indicators:**
- `require-sigs != true` → Signature enforcement disabled
- No trusted public keys configured
- No substituters configured

**Compliance Mapping:**
- ISO27001 Policy 8.1 (Patch Management / Software Integrity)
- Lynis control PKGS-7398 (Installed software from untrusted repositories)
- Mitigates supply chain attacks via package tampering
