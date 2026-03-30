# ISO27001 Laptop Compliance Report

**Eigenaar:** wtoorren
**Hostname:** lobos
**Scan datum:** 2026-03-30 16:03:39
**OS:** NixOS 25.11 (Xantusia)

---

## 📋 Compliance Checklist

| Vereiste (ISO27001) | Status | Bevinding |
|---------------------|--------|-----------|
| Disk encryptie | ✅ | Yes (LUKS) |
| Screen lock | ✅ | Yes (Auto-lock: 5 minutes) |
| Firewall | ✅ | Yes (iptables) |
| Lynis malware scan | ✅ | Yes |
| MFA remote access | ⚠️ | Niet geverifieerd in scan |
| Kwetsbare software | ✅ | None |
| Hardening score | ℹ️ | 65/100 |
| NixOS Supply Chain | ✅ | Secure (signatures enforced) |

---

## 💻 Systeeminformatie

### OS & Kernel Status

```
=====================================
  OS & KERNEL STATUS ANALYSIS
=====================================
Analysis Date: Mon Mar 30 04:13:40 PM CEST 2026
Source: output-lobos-wtoorren-30-03-2026

=====================================
SECTION 1: OPERATING SYSTEM STATUS
=====================================

Detected OS: NixOS
Version: 25.11
Full Name: NixOS 25.11 (Xantusia)

Distribution: NixOS (Rolling/Stable)

1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?
---------------------------------------------------
Status: YES - CURRENT STABLE RELEASE
Update Stream: ACTIVE

=====================================
SECTION 2: KERNEL VERSION STATUS
=====================================

Detected Kernel: 6.12.76


=====================================
OVERALL SYSTEM STATUS
=====================================

Result: ✓ PASS

Your system is running a supported operating system version
with an active update stream. No immediate action required.

Recommendations:
  - Continue applying regular system updates
  - Monitor for new releases and security updates
  - Review this report periodically (at least quarterly)

=====================================
END OF REPORT
=====================================
```

### Asset Inventory

```
=====================================
  ASSET INVENTORY
=====================================

This table contains asset information extracted from the audit report.

Field                               | Value
------------------------------------+-----------------------------------------
Hostname (Asset ID)                 | lobos
Serial Number                       | PF50L2MR
Model                               | LENOVO 21K9CTO1WW 
Description                         | Personal Device
OS Edition + Version                | NixOS 25.11 (Xantusia)
Kernel Version                      | 6.12.76 
Nix Installed                       | Yes (NixOS)
Disk Encryption                     | Yes (LUKS)
Screen Lock                         | Yes (Auto-lock: 5 minutes)
Malware Scanner                     | No
Firewall Active                     | Yes (iptables)
OS Up-to-date                       | Yes (Current)
Lynis Hardening Score               | 65/100 (Good) ✅ COMPLIANT (≥65)
NixOS Commit Hash                   | 20260314
NixOS Generation                    | 801
NixOS Supply Chain                  | Secure (sigs enforced)
Owner / User                        | wtoorren
Last Audit Date                     | 30-03-2026

=====================================
Notes:
  - Serial number may require manual verification
  - 'No suspicious software detected' requires manual review of:
    * installed-packages.txt
    * lynis-report.json security warnings
  - Defender (AV) status: See 'Malware Scanner' field
=====================================
```

### NixOS Supply Chain Audit

```
=== NixOS Supply Chain Trust Check (PKGS-7398) ===

Substituters:        https://cache.nixos.org/
Trusted keys:        shared:txzKp1zKJU6TJqA2umdF4K5SknT0Bsm0MGokInPbch8= technativecache:xT49nn1URVv8j1JSbVoWW3EzCOUq6ndpDvw87C6LLCA= wouterscache:DYpVopjt6I+MfXXtnBH0jqJGO77Xy25KBsfqt86t/VA= wouterscache:L4MkchXumXu0jUimZ3hQ3iZ5e7bGz+X8bEbJjcfnilU= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
Require signatures:  true
Trusted substituters:

Running store verification (this may take a while)...
Store integrity: OK

=== Audit Result ===
Result: PASS

=== ISO27001 Audit Statement ===

The system uses the Nix package manager with enforced supply chain security controls.

- Binary sources (substituters) are explicitly defined: https://cache.nixos.org/
- Cryptographic verification is enforced (require-sigs = true)
- Trusted public keys are configured for all allowed sources
- Unsigned or tampered packages are rejected by design

- Local package store integrity verified successfully

This implementation mitigates risks related to untrusted or unsigned package repositories (Lynis control PKGS-7398) and provides strong assurance of software supply chain integrity.

=== End of Report ===
```

---

## 🔴 Acties Vereist

Zie `honeybadger-wtoorren-30-03-2026-actions.md` voor gedetailleerde actielijst.

---

## 📊 Samenvatting

**Compliance:** ✅ Compliant
**Blocker:** Geen
**Deadline:** N.A.

---

*Rapport volgens TN-ISO27-EN-PLCY-05.00 (sectie 3.2, 7.1, 8.1)*
