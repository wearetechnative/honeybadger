# Dependency Validation

## ADDED Requirements

### Requirement: Required Tool Dependency Checks
The system SHALL check for required tools at audit startup and exit if they are missing.

#### Scenario: Check for jq at startup
- **WHEN** user runs `./RUNME.sh audit`
- **THEN** the system SHALL check if jq command is available
- **AND** SHALL add jq to MISSING_DEPS array if not found
- **AND** SHALL display installation instructions for jq
- **AND** SHALL exit with error if jq is missing (via deps_missing check)

#### Scenario: Check for curl at startup
- **WHEN** user runs `./RUNME.sh audit`
- **THEN** the system SHALL check if curl command is available
- **AND** SHALL add curl to MISSING_DEPS array if not found
- **AND** SHALL display installation instructions for curl
- **AND** SHALL exit with error if curl is missing (via deps_missing check)

#### Scenario: Display jq installation instructions
- **WHEN** jq is not found
- **THEN** the system SHALL display message: "<jq> could not be found"
- **AND** SHALL display: "Install this program first"
- **AND** SHALL provide OS-specific installation instructions:
  - Ubuntu/Debian: `sudo apt install jq`
  - Arch Linux: `sudo pacman -S jq`
  - macOS: `brew install jq`

#### Scenario: Display curl installation instructions
- **WHEN** curl is not found
- **THEN** the system SHALL display message: "<curl> could not be found"
- **AND** SHALL display: "Install this program first"
- **AND** SHALL provide OS-specific installation instructions:
  - Ubuntu/Debian: `sudo apt install curl`
  - Arch Linux: `sudo pacman -S curl`
  - macOS: curl is pre-installed

## ADDED Requirements

### Requirement: OS-Specific CVE Scanner Dependency Check
The system SHALL check for OS-appropriate CVE scanning tools at audit startup.

#### Scenario: Check vulnix on NixOS systems
- **WHEN** user runs `./RUNME.sh audit` on a NixOS system
- **AND** the system has `/etc/nixos/configuration.nix` file
- **THEN** the system SHALL check if vulnix command is available
- **AND** SHALL display informational warning if vulnix is not found
- **AND** SHALL include installation instructions: `nix-env -iA nixpkgs.vulnix`
- **AND** SHALL continue audit execution (CVE scanning is optional)

#### Scenario: Check trivy on non-NixOS systems
- **WHEN** user runs `./RUNME.sh audit` on Arch/Ubuntu/Kali/macOS
- **AND** the system does NOT have `/etc/nixos/configuration.nix` file
- **THEN** the system SHALL check if trivy command is available
- **AND** SHALL display informational warning if trivy is not found
- **AND** SHALL include OS-specific installation instructions
- **AND** SHALL continue audit execution (CVE scanning is optional)

#### Scenario: Display installation instructions for trivy
- **WHEN** trivy is not found on the system
- **THEN** the system SHALL display installation instructions appropriate for the OS:
  - Ubuntu/Debian: apt-based installation with repository setup
  - Arch Linux: yay or pacman installation
  - macOS: Homebrew installation
- **AND** SHALL provide reference URL for detailed documentation

#### Scenario: CVE scanner available
- **WHEN** user runs `./RUNME.sh audit`
- **AND** the appropriate CVE scanner is installed (vulnix on NixOS, trivy on others)
- **THEN** the system SHALL NOT display any CVE scanner warnings
- **AND** SHALL proceed with audit normally

#### Scenario: Warning does not block audit execution
- **WHEN** CVE scanner is missing
- **AND** dependency warning is displayed
- **THEN** the system SHALL NOT exit or abort the audit
- **AND** SHALL continue with other audit tasks
- **AND** CVE scanning will be skipped gracefully during the scan phase

### Requirement: Informational Warnings Only
CVE scanner dependency checks SHALL be informational, not mandatory.

#### Scenario: Missing CVE scanner is a warning, not an error
- **WHEN** CVE scanner dependency check fails
- **THEN** the system SHALL display the message as "INFO:" or "WARNING:"
- **AND** SHALL NOT add the CVE scanner to MISSING_DEPS array
- **AND** SHALL NOT prevent audit from continuing
- **AND** deps_missing check SHALL pass

#### Scenario: Required dependencies still enforced
- **WHEN** required dependencies (lynis, docker, neofetch, tar, sed) are missing
- **THEN** the system SHALL add them to MISSING_DEPS array
- **AND** SHALL call deps_missing which exits with error
- **AND** SHALL prevent audit from starting

### Requirement: OS Detection for CVE Scanner Selection
The system SHALL detect the OS type to determine which CVE scanner to check for.

#### Scenario: Detect NixOS via configuration file
- **WHEN** file `/etc/nixos/configuration.nix` exists
- **THEN** the system SHALL check for vulnix
- **AND** SHALL NOT check for trivy

#### Scenario: Detect non-NixOS systems
- **WHEN** file `/etc/nixos/configuration.nix` does NOT exist
- **THEN** the system SHALL check for trivy
- **AND** SHALL NOT check for vulnix

#### Scenario: Display OS-appropriate scanner name
- **WHEN** displaying CVE scanner warning
- **THEN** the message SHALL include the scanner name (vulnix or trivy)
- **AND** SHALL indicate it is the appropriate scanner for the detected OS
