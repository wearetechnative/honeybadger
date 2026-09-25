# Windows Compliance Reporting

## Purpose
Generate ISO27001 compliance and action reports for Windows devices from collected security data.

## Requirements

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
The system SHALL evaluate all screen lock settings (screensaver timeout, power management, lock
policies) and report compliance status with detailed configuration data in the report. The report
SHALL state the timeout limit that was applied and the settings the verdict rests on, so the
finding can be traced without reading the script.

#### Scenario: Multiple screen lock settings collected
- **WHEN** system collects screensaver timeout, screensaver active, screensaver secure, monitor timeout, system sleep timeout, lock on sleep policy, and inactivity timeout
- **THEN** compliance report includes "Screen Lock Configuration" section with all collected settings and their values

#### Scenario: Screen lock timeout evaluation
- **WHEN** screensaver timeout is ≤900 seconds (15 minutes) AND screensaver is active AND password is required
- **THEN** screen lock check shows ✅ compliant status

#### Scenario: Screen lock not properly configured
- **WHEN** screensaver timeout is >900 seconds OR screensaver is not active OR password is not required
- **THEN** screen lock check shows ❌ non-compliant status with specific issues listed

#### Scenario: Applied limit is stated
- **WHEN** the compliance checklist shows the screen lock row
- **THEN** the detail states the 900-second limit that was applied
- **AND** it names the registry-derived settings the verdict rests on

#### Scenario: Password requirement is recorded as a platform difference
- **WHEN** the screen lock verdict depends on `ScreenSaverIsSecure`
- **THEN** the report states that a password on resume is required for a passing verdict on this
  platform

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
The system SHALL evaluate Windows Defender status and report compliance as PASS if real-time protection is enabled and definitions are up to date (<7 days old), otherwise FAIL. The report SHALL state the 7-day definition age limit that was applied.

#### Scenario: Windows Defender active and current
- **WHEN** RealTimeProtectionEnabled=True AND AntivirusSignatureLastUpdated is within 7 days
- **THEN** antivirus check shows ✅ with signature version and last updated date

#### Scenario: Windows Defender disabled or outdated
- **WHEN** RealTimeProtectionEnabled=False OR AntivirusSignatureLastUpdated is older than 7 days
- **THEN** antivirus check shows ❌ with specific issue (disabled or outdated definitions)

#### Scenario: Applied definition age limit is stated
- **WHEN** the compliance checklist shows the antivirus row
- **THEN** the detail states the 7-day limit that was applied

### Requirement: Generate security actions report
The system SHALL generate a markdown actions report (`honeybadger-{user}-{date}-actions.md`) listing HardeningKitty findings where Result differs from Recommended value, organized by severity (High, Medium, Low).

#### Scenario: Actions report with prioritized findings
- **WHEN** HardeningKitty CSV contains findings with Result != Recommended
- **THEN** actions.md lists each finding with ID, Category, Name, Severity, Current Result, and Recommended Value, grouped by severity

#### Scenario: No remediation needed
- **WHEN** all HardeningKitty checks show Result == Recommended
- **THEN** actions.md shows "No security actions required - all checks passed"

### Requirement: Include system information in compliance report
The system SHALL include system identification data (hostname, username, date,
hardware serial number, OS version) at the top of the compliance report, taking
the serial and the OS version from the same determinations the machine-readable
outputs carry.

#### Scenario: System info section populated
- **WHEN** the compliance report is generated
- **THEN** its header includes hostname, username, report date, hardware serial
  number and OS version

#### Scenario: Serial agrees with the archive
- **WHEN** the compliance report and `hardware-serial.txt` are both written
- **THEN** they name the same serial, including when that is `none-present` or
  `could-not-read`

#### Scenario: OS version comes from fastfetch
- **WHEN** the compliance report names the OS version
- **THEN** it is the `os` value from `fastfetch.json`, not a reference to a
  neofetch text file

### Requirement: Emit a machine-readable asset inventory
The Windows audit SHALL write `asset-inventory.json` into the output directory
and the archive, in the shape the `asset-inventory-json` capability defines, so
that a Windows submission carries the same determinations a Linux one does.

#### Scenario: File produced by every Windows audit
- **WHEN** a Windows audit completes
- **THEN** `asset-inventory.json` is present in the output directory and in the
  archive

#### Scenario: Platform identified
- **WHEN** `asset-inventory.json` is written on Windows
- **THEN** `platform` is `windows`

#### Scenario: Determinations agree with the compliance report
- **WHEN** one audit run produces the compliance report and
  `asset-inventory.json`
- **THEN** disk encryption, screen lock, firewall and OS update status agree
  between them

#### Scenario: Valid JSON under partial failure
- **WHEN** several checks could not be completed
- **THEN** the file is still valid JSON, with those findings carrying a null
  value and a finding explaining why

### Requirement: Bundle the audit into a tar archive
The Windows audit SHALL package the output directory into
`honeybadger-<hostname>-<username>-<dd-MM-yyyy>.tar.gz`, so that it can be
submitted to the collection server.

#### Scenario: Archive produced
- **WHEN** a Windows audit completes
- **THEN** a `.tar.gz` is written, containing the output directory

#### Scenario: Layout matches the other platforms
- **WHEN** the archive is read
- **THEN** its entries are under `output-<hostname>-<username>-<dd-MM-yyyy>/`

#### Scenario: Serial travels with it
- **WHEN** the archive is produced
- **THEN** it contains `hardware-serial.txt`

#### Scenario: No second bundle
- **WHEN** a Windows audit completes
- **THEN** no zip archive is produced, because it cannot be submitted to the
  archive endpoint

#### Scenario: Archiving tool unavailable
- **WHEN** `tar` is not present on the system
- **THEN** the audit reports that the archive could not be created and names
  the tool
- **AND** the collected output directory is left in place
