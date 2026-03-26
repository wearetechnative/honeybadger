## ADDED Requirements

### Requirement: Extract current kernel version
The script SHALL extract and display the current kernel version from audit output.

#### Scenario: Kernel version from lynis report
- **WHEN** lynis-report.json contains os_kernel_version field
- **THEN** report displays kernel version in Operating System section

#### Scenario: Kernel version from system info
- **WHEN** lynis-report.json doesn't contain kernel version
- **THEN** script extracts kernel version from available system info files

### Requirement: Determine kernel support status
The script SHALL determine if the current kernel is still supported by checking OS EOL status.

#### Scenario: Kernel is supported (OS not EOL)
- **WHEN** os-kernel-status.txt indicates OS version is not EOL
- **THEN** report displays "✅ Supported" for kernel status

#### Scenario: Kernel is EOL
- **WHEN** os-kernel-status.txt indicates OS version is EOL
- **THEN** report displays "❌ End of Life" for kernel status

#### Scenario: Kernel status unknown
- **WHEN** os-kernel-status.txt is missing or doesn't contain EOL information
- **THEN** report displays "⚠️ Unknown" for kernel status

### Requirement: Determine OS update stream status
The script SHALL determine if the current OS version has an active update stream.

#### Scenario: Active update stream
- **WHEN** os-kernel-status.txt indicates OS version receives regular updates
- **THEN** report displays "✅ Active" for update stream status

#### Scenario: Inactive update stream (EOL)
- **WHEN** os-kernel-status.txt indicates OS version no longer receives updates
- **THEN** report displays "❌ Inactive (EOL)" for update stream status

#### Scenario: LTS or Extended Support
- **WHEN** os-kernel-status.txt indicates OS version is in LTS or extended support phase
- **THEN** report displays "✅ Active (LTS)" or "⚠️ Extended Support" with end date

### Requirement: Parse OS kernel status file
The script SHALL parse os-kernel-status.txt to extract EOL and support information.

#### Scenario: Parse EOL status
- **WHEN** os-kernel-status.txt contains "EOL:" or "End of Life:" markers
- **THEN** script extracts EOL status and date

#### Scenario: Parse support status
- **WHEN** os-kernel-status.txt contains support status indicators
- **THEN** script identifies if OS is supported, LTS, or EOL

#### Scenario: Handle missing status file
- **WHEN** os-kernel-status.txt is not present
- **THEN** script marks kernel and update stream status as unknown

### Requirement: Display OS version information
The script SHALL display OS type, version, and architecture in the report.

#### Scenario: Extract OS information from lynis
- **WHEN** lynis-report.json contains os, os_version, and os_kernel_version_full fields
- **THEN** report displays complete OS information in table format

#### Scenario: Include architecture
- **WHEN** system architecture information is available (x86_64, ARM64, etc.)
- **THEN** report displays architecture in OS information section
