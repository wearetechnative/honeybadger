## ADDED Requirements

### Requirement: Generate compliance checklist report
The system SHALL generate a compliance report file named `honeybadger-{username}-{date}-compliance.md` that contains an ISO27001 compliance checklist with pass/fail status for each required control.

#### Scenario: All controls pass
- **WHEN** all compliance checks pass (disk encryption enabled, screen lock configured, firewall active, hardening score ≥75, no vulnerable packages)
- **THEN** the compliance report shows ✅ status for each control and overall compliance status "✅ Compliant"

#### Scenario: Critical control fails
- **WHEN** one or more critical controls fail (no disk encryption OR no firewall OR vulnerable packages present OR hardening score <75)
- **THEN** the compliance report shows ❌ status for failed controls and overall compliance status "❌ Niet compliant"

#### Scenario: Warning conditions exist
- **WHEN** all critical controls pass but warnings exist (e.g., screen lock timeout >15 minutes)
- **THEN** the compliance report shows ⚠️ status for warning items and overall compliance status "⚠️ Gedeeltelijk compliant"

### Requirement: Check disk encryption status
The system SHALL determine disk encryption status by examining `blockdevices.txt` for LUKS encryption markers.

#### Scenario: LUKS encryption detected
- **WHEN** `blockdevices.txt` contains "crypto_LUKS" entries
- **THEN** the compliance report shows "Disk encryptie: ✅ | LUKS2 actief"

#### Scenario: No encryption detected
- **WHEN** `blockdevices.txt` does not contain "crypto_LUKS" entries
- **THEN** the compliance report shows "Disk encryptie: ❌ | Niet actief" and marks this as a CRITICAL blocker

### Requirement: Check screen lock status
The system SHALL determine screen lock status by examining `screenlock-info.txt` for auto-lock configuration.

#### Scenario: Auto-lock enabled with acceptable timeout
- **WHEN** `screenlock-info.txt` contains "AUTO-LOCK-STATUS: ENABLED" with timeout ≤15 minutes
- **THEN** the compliance report shows "Screen lock: ✅ | Auto-lock enabled ({timeout} minutes)"

#### Scenario: Auto-lock disabled
- **WHEN** `screenlock-info.txt` does not contain "AUTO-LOCK-STATUS: ENABLED"
- **THEN** the compliance report shows "Screen lock: ❌ | Niet geconfigureerd" and marks this as HIGH priority

#### Scenario: Auto-lock timeout too long
- **WHEN** `screenlock-info.txt` shows auto-lock enabled but timeout >15 minutes
- **THEN** the compliance report shows "Screen lock: ⚠️ | Timeout te lang ({timeout} minuten)"

### Requirement: Check firewall status
The system SHALL determine firewall status from `lynis-report.json` firewall_active field.

#### Scenario: Firewall active
- **WHEN** `lynis-report.json` contains `"firewall_active": "1"`
- **THEN** the compliance report shows "Firewall: ✅ | Actief"

#### Scenario: Firewall inactive
- **WHEN** `lynis-report.json` contains `"firewall_active": "0"`
- **THEN** the compliance report shows "Firewall: ❌ | Niet actief" and marks this as CRITICAL

### Requirement: Check hardening score
The system SHALL evaluate the Lynis hardening index against a minimum threshold of 75.

#### Scenario: Hardening score meets threshold
- **WHEN** `lynis-report.json` contains `"hardening_index"` ≥75
- **THEN** the compliance report shows "Hardening score: ✅ | {score}/100"

#### Scenario: Hardening score below threshold
- **WHEN** `lynis-report.json` contains `"hardening_index"` <75
- **THEN** the compliance report shows "Hardening score: ❌ | {score}/100 (vereist: ≥75)" and marks this as CRITICAL

### Requirement: Check vulnerable packages
The system SHALL detect vulnerable packages by examining Lynis warnings for test ID "PKGS-7392".

#### Scenario: No vulnerable packages
- **WHEN** `lynis-report.json` warnings do not include test ID "PKGS-7392"
- **THEN** the compliance report shows "Kwetsbare software: ✅ | Geen gevonden"

#### Scenario: Vulnerable packages detected
- **WHEN** `lynis-report.json` warnings include test ID "PKGS-7392"
- **THEN** the compliance report shows "Kwetsbare software: ❌ | {count} kwetsbare packages" and marks this as CRITICAL

### Requirement: Include system information
The system SHALL include OS/kernel status and asset inventory information in the compliance report by reading from existing generated files.

#### Scenario: System info files available
- **WHEN** `os-kernel-status.txt` and `asset-inventory.txt` exist in the output directory
- **THEN** the compliance report includes sections showing OS version, kernel version, hostname, and key asset attributes

#### Scenario: System info files missing
- **WHEN** `os-kernel-status.txt` or `asset-inventory.txt` are not available
- **THEN** the compliance report shows "System information: Not available" for missing sections

### Requirement: Generate actions summary
The system SHALL include a summary section listing the count of required actions by severity level with a reference to the detailed actions file.

#### Scenario: Actions exist across severity levels
- **WHEN** Lynis findings are classified into severity levels
- **THEN** the compliance report includes "🔴 Acties Vereist" section with counts like "Critical: 3 items (zie actions.md), High: 5 items, Medium: 12 items"

#### Scenario: No critical or high actions
- **WHEN** no CRITICAL or HIGH severity findings exist
- **THEN** the compliance report shows only MEDIUM and LOW action counts

### Requirement: Calculate compliance deadline
The system SHALL calculate remediation deadline as scan date plus 1 week for systems with critical issues.

#### Scenario: Critical issues present
- **WHEN** one or more CRITICAL compliance checks fail
- **THEN** the compliance report shows "Deadline: {scan_date + 7 days} (1 week)"

#### Scenario: Only warnings present
- **WHEN** no CRITICAL issues exist but warnings are present
- **THEN** the compliance report shows appropriate deadlines based on severity (HIGH: 1 week, MEDIUM: 1 month)

### Requirement: Reference ISO27001 policy sections
The system SHALL include footer text referencing TechNative ISO27001 Policy sections 3.2, 7.1, and 8.1.

#### Scenario: Report generated
- **WHEN** compliance report is created
- **THEN** the footer includes "*Rapport volgens TN-ISO27-EN-PLCY-05.00 (sectie 3.2, 7.1, 8.1)*"
