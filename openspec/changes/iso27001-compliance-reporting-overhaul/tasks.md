## 1. Library Functions - Compliance Checks

- [x] 1.1 Add `check_disk_encryption()` function to parse blockdevices.txt for LUKS markers
- [x] 1.2 Add `check_screen_lock_status()` function to parse screenlock-info.txt for AUTO-LOCK-STATUS
- [x] 1.3 Add `check_firewall_status()` function to read firewall_active from lynis-report.json
- [x] 1.4 Add `check_hardening_score()` function to read hardening_index from lynis-report.json and compare against threshold 75
- [x] 1.5 Add `check_vulnerable_packages()` function to search lynis-report.json warnings for test ID PKGS-7392
- [x] 1.6 Add `check_lynis_scan_exists()` function to verify lynis-report.json file exists
- [ ] 1.7 Add `check_os_update_status()` function to parse os-update-history.txt for last update date and compliance status (✅ <14d, ⚠️ 14-30d, ❌ >30d)
- [x] 1.8 Add `check_iptables_firewall()` helper function to detect active iptables rules (check for non-empty chains, specifically nixos-fw for NixOS)
- [x] 1.9 Add `check_nftables_firewall()` helper function to detect active nftables rules
- [x] 1.10 Update `check_firewall_status()` to add fallback check when Lynis reports firewall_active=0 (call iptables/nftables helpers)

## 2. Library Functions - Severity Classification

- [x] 2.1 Add `classify_lynis_severity()` function with keyword-based severity mapping
- [x] 2.2 Implement CRITICAL severity detection (PKGS-7392, critical keywords in warnings)
- [x] 2.3 Implement HIGH severity detection (other warnings, high-priority suggestion keywords)
- [x] 2.4 Implement MEDIUM severity detection (default for suggestions)
- [x] 2.5 Implement LOW severity detection (low-priority suggestion keywords)
- [x] 2.6 Add case-insensitive keyword matching helper

## 3. Library Functions - Compliance Report Generation

- [x] 3.1 Add `generate_compliance_report()` main function
- [x] 3.2 Implement compliance checklist table generation with ✅/❌/⚠️ status icons
- [ ] 3.3 Add OS update status check to compliance checklist (call check_os_update_status() and include result)
- [x] 3.4 Implement overall compliance status calculation (✅ Compliant / ⚠️ Gedeeltelijk / ❌ Niet compliant)
- [x] 3.5 Add system information section integration (read os-kernel-status.txt and asset-inventory.txt)
- [ ] 3.6 Include hardware serial number in system information section (read from hardware-serial.txt)
- [x] 3.7 Add actions summary section with counts by severity level
- [x] 3.8 Implement deadline calculation (scan date + 1 week for critical issues)
- [x] 3.9 Add ISO27001 policy reference footer (TN-ISO27-EN-PLCY-05.00 sections 3.2, 7.1, 8.1)
- [x] 3.10 Write output to honeybadger-{user}-{date}-compliance.md

## 4. Library Functions - Actions Report Generation

- [x] 4.1 Add `generate_lynis_actions_report()` main function
- [x] 4.2 Extract all warnings and suggestions from lynis-report.json
- [x] 4.3 Classify each finding using classify_lynis_severity()
- [x] 4.4 Group findings by severity level (CRITICAL, HIGH, MEDIUM, LOW)
- [x] 4.5 Generate report header with scan metadata and total counts
- [x] 4.6 Generate CRITICAL section with 🔴 icon and "(fix binnen 1 week)" deadline
- [x] 4.7 Generate HIGH section with 🟠 icon and "(fix binnen 1 week)" deadline
- [x] 4.8 Generate MEDIUM section with 🟡 icon and "(fix binnen 1 maand)" deadline
- [x] 4.9 Generate LOW section with 🟢 icon and "(best effort)" deadline
- [x] 4.10 Format each finding with test ID heading and description
- [x] 4.11 Add footer reference to compliance report
- [x] 4.12 Handle empty findings case with success message
- [x] 4.13 Write output to honeybadger-{user}-{date}-actions.md
- [x] 4.14 Remove `generate_warnings_report()` function from lib/_library (replaced by generate_lynis_actions_report)

## 5. RUNME.sh Integration

- [x] 5.1 Remove terminal output capture (`exec > >(tee "$report_file")`) from check-output function
- [x] 5.2 Update report filename derivation logic to generate compliance.md and actions.md paths
- [x] 5.3 Call check_os_status() and generate_asset_inventory() as before (they write their own files)
- [x] 5.4 Call generate_compliance_report() with output directory path
- [x] 5.5 Call generate_lynis_actions_report() with output directory path
- [x] 5.6 Update final status message to reference both new report files
- [x] 5.7 Verify tarball extraction logic remains unchanged
- [x] 5.8 Verify cleanup logic handles new report filenames
- [x] 5.9 Remove generate_warnings_report() call from audit command in RUNME.sh (line 478-480)
- [x] 5.10 Remove "Generating warnings and suggestions report..." echo message

## 6. Testing and Validation

- [x] 6.1 Test with NixOS audit output directory (verify all compliance checks work)
- [x] 6.2 Test with Ubuntu audit output directory
- [x] 6.3 Test with Debian audit output directory
- [x] 6.4 Test with tarball input (.tar.gz format)
- [x] 6.5 Test with tarball input (.tar format)
- [x] 6.6 Test edge case: no disk encryption (should show CRITICAL failure)
- [x] 6.7 Test edge case: no screen lock (should show HIGH/WARNING)
- [x] 6.8 Test edge case: hardening score below 75 (should show CRITICAL failure)
- [x] 6.9 Test edge case: vulnerable packages present (PKGS-7392 warning)
- [x] 6.10 Test edge case: no firewall (should show CRITICAL failure)
- [ ] 6.11 Test edge case: OS update status compliant (last update <14 days, should show ✅ COMPLIANT)
- [ ] 6.12 Test edge case: OS update status warning (last update 14-30 days, should show ⚠️ WARNING)
- [ ] 6.13 Test edge case: OS update status critical (last update >30 days, should show ❌ NON-COMPLIANT)
- [ ] 6.14 Test serial number display in system info section (verify hardware-serial.txt content appears in compliance.md)
- [ ] 6.15 Test serial number fallback when dmidecode unavailable (should show "Not available")
- [x] 6.16 Test severity classification with sample Lynis findings
- [x] 6.17 Verify markdown formatting renders correctly
- [x] 6.18 Verify compliance.md includes all sections (checklist, system info, actions summary, ISO27001 footer)
- [x] 6.19 Verify actions.md groups findings by severity correctly
- [x] 6.15 Test firewall fallback detection on NixOS with active nixos-fw chain (Lynis reports No, fallback should detect Yes)
- [x] 6.16 Test firewall fallback on system with custom iptables rules (Lynis reports No, fallback should detect Yes)
- [x] 6.17 Test firewall fallback on system with nftables (verify nftables detection works)
- [x] 6.18 Test firewall check on system with no firewall at all (both Lynis and fallback should report No)
- [x] 6.19 Test firewall check when Lynis correctly detects firewall (fallback should not override Yes result)
- [x] 6.20 Verify HTML/PDF reports are no longer generated in audit output (lynis-report-warnings_fails.html should not exist)

## 7. Documentation

- [x] 7.1 Update ISO27001-LAPTOP-COMPLIANCE.md to reference new report filenames
- [x] 7.2 Verify compliance report template in ISO27001-LAPTOP-COMPLIANCE.md matches implementation
- [x] 7.3 Add code comments documenting severity classification logic
