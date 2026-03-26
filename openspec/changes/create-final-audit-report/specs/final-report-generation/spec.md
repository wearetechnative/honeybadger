## ADDED Requirements

### Requirement: Generate final report from audit output
The script SHALL read existing audit output files and generate a consolidated final-report.md file.

#### Scenario: Successful report generation
- **WHEN** script is executed with valid output directory
- **THEN** final-report.md is created in the output directory

#### Scenario: Missing output directory
- **WHEN** script is executed without valid output directory argument
- **THEN** script displays usage information and exits with error code

### Requirement: Extract asset identification information
The report SHALL include asset identification section with serial number, hostname, hardware model, current user, and NixOS metadata (if applicable).

#### Scenario: Asset information on Linux system
- **WHEN** audit output contains hardware-serial.txt and system information
- **THEN** report displays serial number, hostname, and hardware model in table format

#### Scenario: Asset information with NixOS metadata
- **WHEN** audit output contains nixos-system-info.txt
- **THEN** report includes NixOS-specific metadata (nixpkgs hash, generation, rebuild date)

#### Scenario: Missing asset information
- **WHEN** any asset information file is missing
- **THEN** report displays "Not available" for missing fields

### Requirement: Extract security controls information
The report SHALL include security controls section with disk encryption, screen lock, OS update status, and firewall status.

#### Scenario: Security controls present
- **WHEN** audit output contains blockdevices.txt, screenlock-info.txt, os-update-history.txt
- **THEN** report displays each control with status indicator (✅/❌)

#### Scenario: Disk encryption enabled
- **WHEN** blockdevices.txt shows encrypted device (crypto_LUKS or dm-crypt)
- **THEN** report shows "✅ Enabled" for disk encryption

#### Scenario: Disk encryption disabled
- **WHEN** blockdevices.txt shows no encrypted devices
- **THEN** report shows "❌ Disabled" for disk encryption

#### Scenario: Screen lock configured
- **WHEN** screenlock-info.txt shows auto-lock configuration ≤15 minutes
- **THEN** report shows "✅ Enabled" with timeout value

#### Scenario: Screen lock not configured
- **WHEN** screenlock-info.txt shows no auto-lock or timeout >15 minutes
- **THEN** report shows "❌ Not configured" or "⚠️ Timeout too long"

### Requirement: Extract compliance metrics
The report SHALL include Lynis hardening score and security findings (Critical, High severity).

#### Scenario: Lynis score extraction
- **WHEN** lynis-report.json contains hardening_index field
- **THEN** report displays score with compliance indicator (✅ if ≥65, ❌ if <65)

#### Scenario: Critical findings extraction
- **WHEN** lynis-report.json contains warnings with priority "critical"
- **THEN** report lists count and details of critical findings

#### Scenario: High findings extraction
- **WHEN** lynis-report.json contains warnings with priority "high"
- **THEN** report lists count and details of high findings

#### Scenario: No critical or high findings
- **WHEN** lynis-report.json contains no critical or high priority warnings
- **THEN** report shows "✅ 0 Critical, 0 High"

### Requirement: Include audit metadata
The report SHALL include audit date at the top of the report.

#### Scenario: Audit date from directory name
- **WHEN** output directory follows naming convention output-<hostname>-<user>-<date>
- **THEN** report extracts and displays audit date in readable format

#### Scenario: Audit date from file timestamps
- **WHEN** directory name doesn't contain date
- **THEN** report uses modification timestamp of lynis-report.json

### Requirement: Detect current user (non-root)
The report SHALL identify and display the actual user who initiated the audit (not sudo/root).

#### Scenario: User from SUDO_USER variable
- **WHEN** SUDO_USER environment variable is available
- **THEN** report displays SUDO_USER as the current user

#### Scenario: User from directory name
- **WHEN** SUDO_USER is not available and directory follows naming convention
- **THEN** report extracts username from directory name

#### Scenario: User detection fallback
- **WHEN** neither SUDO_USER nor directory name provides username
- **THEN** report displays "Unknown" for user field

### Requirement: Use clear visual indicators
The report SHALL use markdown tables and status icons (✅/❌/⚠️) for readability.

#### Scenario: Compliance status indicators
- **WHEN** requirement is met (e.g., disk encryption enabled, score ≥65)
- **THEN** report displays green checkmark ✅

#### Scenario: Non-compliance indicators
- **WHEN** requirement is not met (e.g., disk encryption disabled, score <65)
- **THEN** report displays red cross ❌

#### Scenario: Warning indicators
- **WHEN** requirement is partially met or needs attention
- **THEN** report displays warning symbol ⚠️

### Requirement: Group related information
The report SHALL organize information into logical sections: Asset Identification, Operating System, Security Controls, and Compliance Metrics.

#### Scenario: Structured sections
- **WHEN** report is generated
- **THEN** report contains distinct sections with markdown headers (##) for each group
