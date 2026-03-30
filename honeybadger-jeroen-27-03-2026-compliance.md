# ISO27001 Laptop Compliance Report

**Eigenaar:** jeroen
**Hostname:** Jeroen
**Scan datum:** 2026-03-27 16:05:35
**OS:** Debian GNU/Linux 13 (trixie)

---

## 📋 Compliance Checklist

| Vereiste (ISO27001) | Status | Bevinding |
|---------------------|--------|-----------|
| Disk encryptie | ✅ | Yes (LUKS2) |
| Screen lock | ✅ | Yes (Auto-lock: 5 minutes) |
| Firewall | ✅ | Yes |
| Lynis malware scan | ✅ | Yes |
| MFA remote access | ⚠️ | Niet geverifieerd in scan |
| Kwetsbare software | ❌ | Yes |
| Hardening score | ℹ️ | 64/100 |

---

## 💻 Systeeminformatie

### OS & Kernel Status

```
=====================================
  OS & KERNEL STATUS ANALYSIS
=====================================
Analysis Date: Mon Mar 30 03:06:10 PM CEST 2026
Source: output-Jeroen-jeroen-27-03-2026

=====================================
SECTION 1: OPERATING SYSTEM STATUS
=====================================

Detected OS: Debian
Version: 13
Full Name: Debian GNU/Linux 13 (trixie)

Distribution: Debian GNU/Linux
Version: 13

=====================================
SECTION 2: KERNEL VERSION STATUS
=====================================

Detected Kernel: 6.12.48


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
Hostname (Asset ID)                 | Jeroen
Serial Number                       | FRANDGCPA5530200H9
Model                               | 
Description                         | Personal Device
OS Edition + Version                | Debian GNU/Linux 13 (trixie)
Kernel Version                      | 6.12.48+deb13-amd64 
Nix Installed                       | Yes
Disk Encryption                     | Yes (LUKS)
Screen Lock                         | Yes (Auto-lock: 5 minutes)
Malware Scanner                     | No
Firewall Active                     | Yes
OS Up-to-date                       | Yes (Current)
Lynis Hardening Score               | 64/100 (Good) ❌ NON-COMPLIANT (required: ≥65)
Owner / User                        | jeroen
Last Audit Date                     | 27-03-2026

=====================================
Notes:
  - Serial number may require manual verification
  - 'No suspicious software detected' requires manual review of:
    * installed-packages.txt
    * lynis-report.json security warnings
  - Defender (AV) status: See 'Malware Scanner' field
=====================================
```

---

## 🔴 Acties Vereist

Zie `honeybadger-jeroen-27-03-2026-actions.md` voor gedetailleerde actielijst.

### Kritiek (binnen 1 week)
- [ ] Kwetsbare software

---

## 📊 Samenvatting

**Compliance:** ❌ Niet compliant
**Blocker:** Kwetsbare software
**Deadline:** 2026-04-03

---

*Rapport volgens TN-ISO27-EN-PLCY-05.00 (sectie 3.2, 7.1, 8.1)*
