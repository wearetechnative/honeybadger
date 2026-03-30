## ADDED Requirements

### Requirement: Generate ISO27001 compliance report
The system SHALL generate a markdown compliance report (`honeybadger-{user}-{date}-compliance.md`) containing system information, compliance checklist with pass/fail status, and detailed configuration data for all security controls.

#### Scenario: Compliance report generation
- **WHEN** RUNME.ps1 completes data collection
- **THEN** system creates compliance.md with system info section, compliance checklist table, and detailed sections for each control (disk encryption, screen lock, firewall, OS updates, antivirus)

#### Scenario: Compliance status calculation
- **WHEN** system evaluates collected security data
- **THEN** each control shows ✅ (compliant), ⚠️ (warning), or ❌ (non-compliant) based on ISO27001 thresholds

### Requirement: Check disk encryption compliance
The system SHALL evaluate BitLocker status and report compliance as PASS if C: drive is fully encrypted with BitLocker, otherwise FAIL.

#### Scenario: BitLocker fully encrypted
- **WHEN** C: drive has VolumeStatus "FullyEncrypted" with EncryptionPercentage 100
- **THEN** disk encryption check shows ✅ with status "BitLocker enabled and fully encrypted"

#### Scenario: BitLocker not enabled
- **WHEN** Get-BitLockerVolume returns no encryption or VolumeStatus is not "FullyEncrypted"
- **THEN** disk encryption check shows ❌ with status "BitLocker not enabled or not fully encrypted"

### Requirement: Check screen lock compliance
The system SHALL evaluate all screen lock settings (screensaver timeout, power management, lock policies) and report compliance status with detailed configuration data in the report.

#### Scenario: Multiple screen lock settings collected
- **WHEN** system collects screensaver timeout, screensaver active, screensaver secure, monitor timeout, system sleep timeout, lock on sleep policy, and inactivity timeout
- **THEN** compliance report includes "Screen Lock Configuration" section with all collected settings and their values

#### Scenario: Screen lock timeout evaluation
- **WHEN** screensaver timeout is ≤900 seconds (15 minutes) AND screensaver is active AND password is required
- **THEN** screen lock check shows ✅ compliant status

#### Scenario: Screen lock not properly configured
- **WHEN** screensaver timeout is >900 seconds OR screensaver is not active OR password is not required
- **THEN** screen lock check shows ❌ non-compliant status with specific issues listed

### Requirement: Check firewall compliance
The system SHALL evaluate Windows Firewall status for all profiles (Domain, Private, Public) and report compliance as PASS if all profiles are enabled, otherwise FAIL.

#### Scenario: All firewall profiles enabled
- **WHEN** Domain, Private, and Public firewall profiles all have Enabled=True
- **THEN** firewall check shows ✅ with status "All profiles enabled"

#### Scenario: One or more profiles disabled
- **WHEN** any firewall profile has Enabled=False
- **THEN** firewall check shows ❌ with list of disabled profiles

### Requirement: Check OS update compliance
The system SHALL evaluate Windows Update status and report compliance based on last update date: ✅ if <14 days, ⚠️ if 14-30 days, ❌ if >30 days.

#### Scenario: Recent updates installed
- **WHEN** last Windows Update (from Get-HotFix) was installed less than 14 days ago
- **THEN** OS update check shows ✅ with date and "System is up to date"

#### Scenario: Updates overdue warning
- **WHEN** last Windows Update was installed 14-30 days ago
- **THEN** OS update check shows ⚠️ with date and "Update recommended"

#### Scenario: Updates critically overdue
- **WHEN** last Windows Update was installed more than 30 days ago
- **THEN** OS update check shows ❌ with date and "Update required - system is out of compliance"

### Requirement: Check antivirus compliance
The system SHALL evaluate Windows Defender status and report compliance as PASS if real-time protection is enabled and definitions are up to date (<7 days old), otherwise FAIL.

#### Scenario: Windows Defender active and current
- **WHEN** RealTimeProtectionEnabled=True AND AntivirusSignatureLastUpdated is within 7 days
- **THEN** antivirus check shows ✅ with signature version and last updated date

#### Scenario: Windows Defender disabled or outdated
- **WHEN** RealTimeProtectionEnabled=False OR AntivirusSignatureLastUpdated is older than 7 days
- **THEN** antivirus check shows ❌ with specific issue (disabled or outdated definitions)

### Requirement: Generate security actions report
The system SHALL generate a markdown actions report (`honeybadger-{user}-{date}-actions.md`) listing HardeningKitty findings where Result differs from Recommended value, organized by severity (High, Medium, Low).

#### Scenario: Actions report with prioritized findings
- **WHEN** HardeningKitty CSV contains findings with Result != Recommended
- **THEN** actions.md lists each finding with ID, Category, Name, Severity, Current Result, and Recommended Value, grouped by severity

#### Scenario: No remediation needed
- **WHEN** all HardeningKitty checks show Result == Recommended
- **THEN** actions.md shows "No security actions required - all checks passed"

### Requirement: Include system information in compliance report
The system SHALL include system identification data (hostname, username, date, hardware serial number, OS version) at the top of the compliance report.

#### Scenario: System info section populated
- **WHEN** compliance report is generated
- **THEN** report header includes hostname, username, report date, hardware serial number (from Win32_BIOS), and OS version (from neofetch or Win32_OperatingSystem)
