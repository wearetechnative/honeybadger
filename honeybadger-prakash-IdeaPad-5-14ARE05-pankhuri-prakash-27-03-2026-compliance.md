# ISO27001 Laptop Compliance Report

**Eigenaar:** prakash
**Hostname:** pankhuri-prakash-IdeaPad-5-14ARE05
**Scan datum:** 2026-03-27 16:06:47
**OS:** Ubuntu 24.04.4 LTS

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
| Hardening score | ℹ️ | 60/100 |

---

## 💻 Systeeminformatie

### OS & Kernel Status

```
=====================================
  OS & KERNEL STATUS ANALYSIS
=====================================
Analysis Date: Mon Mar 30 03:10:16 PM CEST 2026
Source: output-pankhuri-prakash-IdeaPad-5-14ARE05-pankhuri-prakash-27-03-2026

=====================================
SECTION 1: OPERATING SYSTEM STATUS
=====================================

Detected OS: Ubuntu
Version: 24.04
Full Name: Ubuntu 24.04.4 LTS

Distribution: Ubuntu Linux

1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?
---------------------------------------------------
Status: YES - CURRENT LTS
Update Stream: ACTIVE

=====================================
SECTION 2: KERNEL VERSION STATUS
=====================================

Detected Kernel: 6.17.0


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
Hostname (Asset ID)                 | pankhuri-prakash-IdeaPad-5-14ARE05
Serial Number                       | MP1Y69AC
Model                               | 81YM IdeaPad 5 14ARE05 
Description                         | Personal Device
OS Edition + Version                | Ubuntu 24.04.4 LTS
Kernel Version                      | 6.17.0-19-generic 
Nix Installed                       | Unknown
Disk Encryption                     | Yes (LUKS)
Screen Lock                         | Yes (Auto-lock: 5 minutes)
Malware Scanner                     | No
Firewall Active                     | Yes
OS Up-to-date                       | Yes (Current)
Lynis Hardening Score               | 60/100 (Good) ❌ NON-COMPLIANT (required: ≥65)
Owner / User                        | pankhuri-prakash
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

Zie `honeybadger-prakash-IdeaPad-5-14ARE05-pankhuri-prakash-27-03-2026-actions.md` voor gedetailleerde actielijst.

### Kritiek (binnen 1 week)
- [ ] Kwetsbare software

---

## 📊 Samenvatting

**Compliance:** ❌ Niet compliant
**Blocker:** Kwetsbare software
**Deadline:** 2026-04-03

---

*Rapport volgens TN-ISO27-EN-PLCY-05.00 (sectie 3.2, 7.1, 8.1)*
