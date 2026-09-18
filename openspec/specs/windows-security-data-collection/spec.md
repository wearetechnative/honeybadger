# Windows Security Data Collection

## Purpose
Collect system, hardware and security-control data on Windows devices for compliance reporting.

## Requirements

### Requirement: Collect hardware serial number
The system SHALL collect the hardware serial from BIOS/UEFI using
`Get-CimInstance Win32_BIOS` and SHALL write it to `hardware-serial.txt`, so
that it travels in the archive and the collection server can resolve the asset.

#### Scenario: Physical hardware
- **WHEN** the system runs on physical hardware with a valid BIOS serial
- **THEN** the serial is written to `hardware-serial.txt` and the source is
  recorded in `hardware-serial-source.txt`

#### Scenario: Value is judged by the shared rule
- **WHEN** a serial is read from WMI
- **THEN** it is accepted only if it is one token, free of whitespace and
  control characters, not all zeroes, and not a known placeholder - the same
  rule the other platforms and the collection server apply

#### Scenario: Virtual machine or unavailable serial
- **WHEN** `Win32_BIOS` returns an empty value or a placeholder such as
  `To Be Filled By O.E.M.`, `Default string` or `System Serial Number`
- **THEN** `hardware-serial.txt` contains `none-present`
- **AND** the literal `Not available (VM or unknown hardware)` is not recorded
  as though it were the measured serial

#### Scenario: Serial could not be read at all
- **WHEN** the WMI query fails
- **THEN** `hardware-serial.txt` contains `could-not-read`

#### Scenario: Operator is told
- **WHEN** no usable serial is determined
- **THEN** the audit reports it at the end of the run, naming which of the two
  cases applies

### Requirement: Collect BitLocker encryption status
The system SHALL collect BitLocker volume encryption status for all volumes using Get-BitLockerVolume, capturing VolumeType, MountPoint, CapacityGB, VolumeStatus, EncryptionPercentage, and KeyProtector.

#### Scenario: BitLocker data collection
- **WHEN** system runs Get-BitLockerVolume with elevated privileges
- **THEN** output is saved showing encryption status for each volume (at minimum C: drive)

#### Scenario: BitLocker module not available
- **WHEN** Get-BitLockerVolume cmdlet fails (insufficient permissions or feature not available)
- **THEN** system captures error message and reports "Unable to check BitLocker status - requires Administrator privileges"

### Requirement: Collect comprehensive screen lock settings
The system SHALL collect all Windows screen lock and power management settings including screensaver configuration, power timeouts, and lock policies.

#### Scenario: Screensaver settings collection
- **WHEN** system reads registry keys HKCU:\Control Panel\Desktop
- **THEN** collects ScreenSaveTimeOut (seconds), ScreenSaveActive (0/1), and ScreenSaverIsSecure (0/1)

#### Scenario: Power management settings collection
- **WHEN** system runs powercfg queries for current power scheme
- **THEN** collects monitor timeout (SUB_VIDEO VIDEOIDLE) and system sleep timeout (SUB_SLEEP STANDBYIDLE) for AC power

#### Scenario: Lock policy settings collection
- **WHEN** system reads registry keys under HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization and Power\PowerSettings
- **THEN** collects NoLockScreen policy and ACSettingIndex (require password on wake)

#### Scenario: Inactivity timeout collection
- **WHEN** system reads HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\InactivityTimeoutSecs
- **THEN** collects inactivity timeout value if configured via Group Policy

### Requirement: Collect Windows Firewall status
The system SHALL collect Windows Firewall status for all network profiles (Domain, Private, Public) using Get-NetFirewallProfile.

#### Scenario: Firewall profile status collection
- **WHEN** system runs Get-NetFirewallProfile
- **THEN** collects Enabled status, DefaultInboundAction, and DefaultOutboundAction for Domain, Private, and Public profiles

#### Scenario: Firewall cmdlet not available
- **WHEN** Get-NetFirewallProfile fails
- **THEN** system falls back to reading registry keys or netsh commands to determine firewall status

### Requirement: Collect Windows Update history
The system SHALL collect Windows Update history including the date of the most recent update using Get-HotFix sorted by InstalledOn date.

#### Scenario: Recent updates found
- **WHEN** system runs Get-HotFix and sorts by InstalledOn descending
- **THEN** captures the most recent hotfix KB number, description, and installation date

#### Scenario: No update history available
- **WHEN** Get-HotFix returns no results or InstalledOn date is unavailable
- **THEN** system records "Unable to determine last update date"

### Requirement: Collect Windows Defender status
The system SHALL collect Windows Defender antivirus status using Get-MpComputerStatus, capturing real-time protection status, signature version, and last definition update date.

#### Scenario: Defender status collection
- **WHEN** system runs Get-MpComputerStatus
- **THEN** collects RealTimeProtectionEnabled, AntivirusSignatureVersion, AntivirusSignatureLastUpdated, and LastFullScanTime

#### Scenario: Defender module not available
- **WHEN** Get-MpComputerStatus cmdlet fails (not available or third-party antivirus)
- **THEN** system records "Windows Defender status unavailable - third-party antivirus may be in use"

### Requirement: Run HardeningKitty security audit
The system SHALL import the HardeningKitty PowerShell module and run Invoke-HardeningKitty in Config mode with Report output to generate a CSV file of security configuration checks.

#### Scenario: HardeningKitty audit execution
- **WHEN** system imports HardeningKitty.psm1 and runs Invoke-HardeningKitty -Mode Config -Report -ReportFile .\report\hardeningkitty.csv
- **THEN** CSV file is generated with columns: ID, Category, Name, Severity, Result, Recommended, TestResult, SeverityFinding

#### Scenario: HardeningKitty module import failure
- **WHEN** Import-Module fails to load HardeningKitty.psm1
- **THEN** system reports error and skips HardeningKitty audit, but continues with other data collection

### Requirement: Store all collected data in report directory
The system SHALL create an output directory named
`output-<hostname>-<username>-<dd-MM-yyyy>` and store all collected data files
in it, so that a Windows archive is laid out like every other archive.

#### Scenario: Report directory creation
- **WHEN** the audit begins data collection
- **THEN** it creates `output-<hostname>-<username>-<dd-MM-yyyy>` if it does
  not exist

#### Scenario: Data files stored
- **WHEN** each data collection step completes
- **THEN** its output is written into that directory, including
  `bitlocker_result.txt`, `fastfetch.json`, `hardeningkitty.csv` and
  `hardware-serial.txt`

#### Scenario: Directory is readable by the shared tooling
- **WHEN** the directory name is parsed by the client's shared output-name
  parser
- **THEN** the hostname, username and date are recovered from it

### Requirement: Collect system information with fastfetch
The system SHALL collect system information with fastfetch and store it as
`fastfetch.json`, in the same flat shape the Linux and macOS clients produce,
so that one consumer reads every platform's archive.

#### Scenario: fastfetch available
- **WHEN** fastfetch is installed on the system
- **THEN** the audit runs it with the shipped Windows config and writes
  `fastfetch.json` to the output directory

#### Scenario: Keys match the other platforms
- **WHEN** `fastfetch.json` is written
- **THEN** its keys are lowercase with underscores, and `user`, `hostname`,
  `os`, `host` and `kernel` carry the same meanings they carry on Linux

#### Scenario: fastfetch not available
- **WHEN** fastfetch is not found
- **THEN** the audit attempts to install it through winget

#### Scenario: fastfetch could not be installed
- **WHEN** fastfetch is absent and cannot be installed
- **THEN** the audit reports that the dependency is missing and names how to
  install it
- **AND** SHALL NOT write a `fastfetch.json` assembled from another source

#### Scenario: No legacy format is produced
- **WHEN** an audit completes
- **THEN** `neofetch.txt` SHALL NOT be written, and neofetch SHALL NOT be
  installed or invoked
