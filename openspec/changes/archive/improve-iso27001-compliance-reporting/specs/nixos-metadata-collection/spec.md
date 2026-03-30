## ADDED Requirements

### Requirement: System SHALL collect NixOS nixpkgs commit hash
When running on NixOS, the audit SHALL collect the nixpkgs commit hash for reproducibility tracking.

#### Scenario: Commit hash collected on NixOS
- **WHEN** the audit detects NixOS as the operating system
- **THEN** the system SHALL execute `nixos-version --json`
- **AND** SHALL extract the `nixpkgsRevision` field
- **AND** SHALL save the commit hash to `nixos-system-info.txt`

#### Scenario: Alternative commit hash retrieval
- **WHEN** `nixos-version --json` is not available
- **THEN** the system SHALL attempt to read `/run/current-system/nixos-version`
- **AND** SHALL extract the commit hash from the version string

#### Scenario: Non-NixOS systems skip this collection
- **WHEN** the audit runs on non-NixOS systems
- **THEN** the system SHALL NOT attempt to collect NixOS metadata
- **AND** SHALL NOT create nixos-system-info.txt file

### Requirement: System SHALL collect NixOS system generation number
The audit SHALL determine the current NixOS system generation for tracking system rebuilds.

#### Scenario: Current generation identified
- **WHEN** running on NixOS
- **THEN** the system SHALL execute `readlink /nix/var/nix/profiles/system`
- **AND** SHALL extract the generation number from the path
- **AND** SHALL save to nixos-system-info.txt

#### Scenario: Generation list retrieved
- **WHEN** collecting generation information
- **THEN** the system SHALL optionally execute `nixos-rebuild list-generations`
- **AND** SHALL include the last 3-5 generations in the output

### Requirement: System SHALL collect last system rebuild date
The audit SHALL determine when the NixOS system was last rebuilt.

#### Scenario: Rebuild date from current generation
- **WHEN** collecting NixOS metadata
- **THEN** the system SHALL use `stat -c %y /nix/var/nix/profiles/system`
- **AND** SHALL extract the modification timestamp
- **AND** SHALL format the date in readable format (YYYY-MM-DD HH:MM:SS)

#### Scenario: Rebuild date shown in output
- **WHEN** nixos-system-info.txt is generated
- **THEN** the file SHALL contain line "Last rebuild: <timestamp>"
- **AND** SHALL be easily parseable by audit tools

### Requirement: NixOS metadata SHALL be included in asset inventory
For NixOS systems, the asset inventory report SHALL include NixOS-specific information.

#### Scenario: NixOS commit hash in asset inventory
- **WHEN** generating asset inventory for NixOS system
- **THEN** the report SHALL include "NixOS Commit Hash" field
- **AND** SHALL display short commit hash (first 7-8 characters)

#### Scenario: System generation in asset inventory
- **WHEN** generating asset inventory for NixOS system
- **THEN** the report SHALL include "NixOS Generation" field
- **AND** SHALL display current generation number
