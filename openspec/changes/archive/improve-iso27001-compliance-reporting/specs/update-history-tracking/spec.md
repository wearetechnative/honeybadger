## ADDED Requirements

### Requirement: System SHALL integrate check-os-updates.sh into audit workflow
The audit process SHALL execute the existing `lib/check-os-updates.sh` script to collect OS update history and status.

#### Scenario: Update history collected during audit
- **WHEN** the audit command runs
- **THEN** the system SHALL execute `lib/check-os-updates.sh`
- **AND** SHALL save the output to `$output/os-update-history.txt`

#### Scenario: Update check works for supported distributions
- **WHEN** running on Arch, Ubuntu, Debian, Kali, Fedora, NixOS, or macOS
- **THEN** the system SHALL collect distribution-specific update information
- **AND** SHALL report last update date where available

### Requirement: System SHALL report last update date
The audit output SHALL include when the system was last updated with security patches.

#### Scenario: Last update date shown for Arch Linux
- **WHEN** audit runs on Arch Linux
- **THEN** the system SHALL read `/var/log/pacman.log`
- **AND** SHALL extract the most recent package upgrade/install date
- **AND** SHALL calculate days since last update

#### Scenario: Update status includes compliance indicator
- **WHEN** update history is collected
- **THEN** the output SHALL indicate compliance status:
  - COMPLIANT if updated within 14 days
  - UPDATE RECOMMENDED if 14-30 days since update
  - UPDATE REQUIRED if >30 days since update

### Requirement: System SHALL check for available updates
The audit SHALL query the package manager for pending updates.

#### Scenario: Available updates counted
- **WHEN** audit runs with appropriate privileges
- **THEN** the system SHALL query package manager for available updates
- **AND** SHALL report the number of pending updates
- **AND** SHALL handle cases where update check requires network access

#### Scenario: Update check handles network failures gracefully
- **WHEN** network is unavailable or update repositories unreachable
- **THEN** the system SHALL report "Unable to check for updates"
- **AND** SHALL NOT fail the audit
- **AND** SHALL log the error condition
