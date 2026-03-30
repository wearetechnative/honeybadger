## ADDED Requirements

### Requirement: Collect system information
The system SHALL collect system information including hostname, username, OS version, and hardware model using neofetch or Windows built-in commands.

#### Scenario: Neofetch available
- **WHEN** neofetch is installed on the system
- **THEN** system runs neofetch to collect system information and saves output to neofetch.txt

#### Scenario: Neofetch not available
- **WHEN** neofetch is not found
- **THEN** system attempts to install neofetch via `winget install neofetch`, or falls back to collecting data via Get-CimInstance Win32_OperatingSystem and Win32_ComputerSystem

### Requirement: Collect hardware serial number
The system SHALL collect hardware serial number from BIOS/UEFI using WMI (Get-CimInstance Win32_BIOS) for asset tracking and identification.

#### Scenario: Physical hardware
- **WHEN** system runs on physical hardware with valid BIOS serial number
- **THEN** serial number is extracted from Win32_BIOS SerialNumber property

#### Scenario: Virtual machine or unavailable serial
- **WHEN** Win32_BIOS SerialNumber is empty, null, or returns common VM values (e.g., "To Be Filled By O.E.M.")
- **THEN** system records serial number as "Not available (VM or unknown hardware)"

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
The system SHALL create a timestamped report directory (report-{date}) and store all collected data files for processing by the compliance reporting phase.

#### Scenario: Report directory creation
- **WHEN** RUNME.ps1 begins data collection
- **THEN** creates report/ or report-{timestamp}/ directory if it doesn't exist

#### Scenario: Data files stored
- **WHEN** each data collection step completes
- **THEN** outputs are written to report directory (bitlocker_result.txt, neofetch.txt, hardeningkitty.csv, etc.)
