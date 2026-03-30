## Why

The current `check-output` command generates a technical `report.txt` file focused on OS/kernel status and asset inventory, but lacks structured ISO27001 compliance reporting. Organizations need a clear compliance status report that maps to ISO27001 requirements (disk encryption, screen lock, firewall, hardening score) with actionable remediation items prioritized by severity. The current output requires manual interpretation to determine compliance status and extract action items from Lynis warnings/suggestions.

Additionally, the firewall compliance check relies solely on Lynis detection (`firewall_active` field), which produces false negatives on systems with active firewalls that Lynis doesn't recognize (e.g., NixOS with nixos-fw iptables chain, custom iptables/nftables configurations). This results in compliant systems being incorrectly flagged as non-compliant.

## What Changes

- Replace `honeybadger-{user}-{date}-report.txt` with two new markdown reports:
  - `honeybadger-{user}-{date}-compliance.md`: Master ISO27001 compliance report with checklist, system info, and compliance summary
  - `honeybadger-{user}-{date}-actions.md`: Detailed Lynis security actions organized by severity (Critical/High only - Medium/Low excluded for focus)
- Add new library functions for compliance checking and severity classification
- Integrate existing OS/kernel status and asset inventory into the compliance report
- **Include hardware serial numbers** from `hardware-serial.txt` (collected via dmidecode during audit) in compliance report
- **Include OS update status** from `os-update-history.txt` (collected via check-os-updates.sh during audit) as compliance check
- Implement market-standard severity mapping for Lynis findings based on ISO27001, NIST, and vulnerability management best practices
- Filter actions report to show only CRITICAL and HIGH severity findings (Medium/Low omitted to reduce noise and focus on urgent remediation)
- **Improve firewall detection with fallback check**: When Lynis reports no firewall, verify by checking actual iptables/nftables rules (NixOS nixos-fw chain detection + generic active rules check) to eliminate false negatives
- **Remove redundant HTML/PDF generation**: Remove `generate_warnings_report()` function and its call from audit command (replaced by markdown actions report)

## Capabilities

### New Capabilities
- `iso27001-compliance-reporting`: Generate ISO27001-compliant compliance reports with pass/fail checklists for required controls (disk encryption, screen lock, firewall, hardening score, vulnerable packages, OS updates)
- `lynis-severity-classification`: Classify Lynis warnings and suggestions by severity (Critical/High/Medium/Low) using market-standard security practices and keyword analysis
- `compliance-action-reports`: Generate focused action reports with CRITICAL and HIGH severity findings only (Medium/Low excluded), including remediation deadlines (1 week for Critical/High)
- `firewall-detection-fallback`: When Lynis reports no firewall, perform direct iptables/nftables check to detect active firewall rules (NixOS nixos-fw chain + generic non-empty ruleset detection)
- `serial-number-reporting`: Include hardware serial numbers in compliance report system info section (from hardware-serial.txt collected during audit)
- `os-update-status-checking`: Check and report OS update compliance status (last update <14 days = compliant, 14-30 days = warning, >30 days = non-compliant)

### Modified Capabilities
- `check_firewall_status`: Enhanced to include fallback detection when Lynis reports firewall_active=0, checking for NixOS nixos-fw chain or generic iptables/nftables active rules

## Impact

**Modified Files:**
- `RUNME.sh`: Update `check-output` function to call new report generators instead of current output logic
- `lib/_library`: Add new functions for compliance checks, severity classification, and report generation

**New Files:**
- Generated reports: `honeybadger-{user}-{date}-compliance.md` and `honeybadger-{user}-{date}-actions.md`

**Removed:**
- `honeybadger-{user}-{date}-report.txt` (replaced by compliance.md)
- `lynis-report-warnings_fails.html` and `.pdf` generation (replaced by actions.md)
- `generate_warnings_report()` function from lib/_library (no longer needed)
- `lib/generate-final-report.sh` script (replaced by new compliance reporting)

**Data Sources:**
- Existing Lynis JSON reports (`lynis-report.json`)
- Existing system files (`blockdevices.txt`, `screenlock-info.txt`, `os-kernel-status.txt`, `asset-inventory.txt`)
- Hardware information (`hardware-serial.txt` - collected via dmidecode during audit)
- OS update status (`os-update-history.txt` - collected via check-os-updates.sh during audit)

**User Impact:**
- Users running `./RUNME.sh check-output` will receive new markdown reports instead of text reports
- Actions report focuses on urgent items only (CRITICAL/HIGH severity) - Medium and Low findings are not included to reduce report noise and focus attention on items requiring immediate action
- Backward compatibility: None required (report files are ephemeral output, not stored artifacts)
