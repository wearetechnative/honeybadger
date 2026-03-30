# System Information Collection

## MODIFIED Requirements

### Requirement: Capture Actual User in System Information
The system SHALL capture the actual user who initiated the audit, not the effective user (root).

#### Scenario: Run neofetch as actual user when using sudo
- **WHEN** user runs audit with sudo (e.g., `sudo ./RUNME.sh audit`)
- **AND** SUDO_USER environment variable is set
- **THEN** the system SHALL execute neofetch as the original user (SUDO_USER)
- **AND** SHALL NOT execute neofetch as root
- **AND** neofetch.json SHALL contain the original username

#### Scenario: Preserve original username in neofetch output
- **WHEN** neofetch is executed
- **THEN** the output SHALL contain the original user in format "user@hostname"
- **AND** the user field in neofetch.json SHALL match SUDO_USER
- **AND** SHALL NOT show "root" as the username when run via sudo

#### Scenario: Handle non-sudo execution
- **WHEN** audit is run directly as root (not via sudo)
- **AND** SUDO_USER is not set
- **THEN** the system SHALL use current user from whoami
- **AND** neofetch SHALL run as current user

#### Scenario: Consistent username across all outputs
- **WHEN** audit generates output files and directories
- **THEN** output directory name SHALL use same username as neofetch.json
- **AND** server submission X-Username header SHALL use same username as neofetch.json
- **AND** all reports SHALL show consistent user ownership

### Requirement: Use sudo -u for User Context Switching
The system SHALL use sudo -u to execute commands in the original user's context when needed.

#### Scenario: Execute neofetch with sudo -u
- **WHEN** running neofetch during audit
- **THEN** the system SHALL use `sudo -u "${SUDO_USER:-$(whoami)}"` to execute neofetch
- **AND** SHALL preserve user environment for accurate system information
- **AND** SHALL NOT run neofetch directly as root

#### Scenario: Fallback when SUDO_USER not available
- **WHEN** SUDO_USER environment variable is not set
- **THEN** the system SHALL fall back to `$(whoami)` for username
- **AND** SHALL execute neofetch with that username

## REMOVED Requirements

None - this is a bug fix, not a removal of existing requirements.
