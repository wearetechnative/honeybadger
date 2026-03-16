# System Information Collection

## ADDED Requirements

### Requirement: JSON-based System Information Storage
The audit system SHALL generate system information in JSON format for structured data access.

#### Scenario: Generate neofetch JSON during audit
- **WHEN** the audit command is run
- **THEN** neofetch data SHALL be captured in JSON format using the command: `neofetch --off --stdout | jq -Rn '[inputs | select(length>0) | capture("(?<key>[^:]+): (?<value>.*)")]| map({(.key|ascii_downcase|gsub(" "; "_")): .value}) | add'`
- **AND** the output SHALL be saved as `neofetch.json` in the audit output directory
- **AND** the JSON SHALL contain fields with lowercase keys and underscores (e.g., "os", "host", "kernel", "packages")

#### Scenario: Extract OS information from JSON
- **WHEN** generating OS/kernel status report
- **THEN** the system SHALL use jq to extract OS name from the "os" field in neofetch.json
- **AND** parsing SHALL use structured JSON queries instead of grep/sed text parsing

#### Scenario: Extract hardware information from JSON
- **WHEN** generating asset inventory
- **THEN** the system SHALL use jq to extract model from "host" field
- **AND** kernel version SHALL be extracted from "kernel" field
- **AND** owner/hostname SHALL be parsed from available JSON fields
- **AND** all extractions SHALL use jq queries on neofetch.json

#### Scenario: Detect Nix installation from JSON
- **WHEN** checking for Nix package manager installation
- **THEN** the system SHALL search the "packages" field in neofetch.json for "nix-" pattern using jq
- **AND** shall not rely on text-based grep parsing

### Requirement: Backward Compatibility for Text Format
The check-output command SHALL support reading legacy audit outputs containing neofetch.txt files.

#### Scenario: Fallback to text format for old audits
- **WHEN** check-output processes an existing audit archive
- **AND** neofetch.json is not present
- **AND** neofetch.txt exists
- **THEN** the system SHALL parse neofetch.txt using the legacy grep/sed approach
- **AND** SHALL extract the same data fields as JSON format would provide

#### Scenario: Prefer JSON when both formats exist
- **WHEN** both neofetch.json and neofetch.txt exist in an audit directory
- **THEN** the system SHALL use neofetch.json as the primary source
- **AND** SHALL ignore neofetch.txt

## REMOVED Requirements

### Requirement: Text-based System Information Storage
**Reason**: Replacing brittle text parsing with structured JSON format for improved reliability and maintainability

**Migration**: New audits will generate neofetch.json instead of neofetch.txt. Existing audit archives with neofetch.txt will continue to be readable through backward compatibility support in check-output command.

The audit system previously generated neofetch output as plain text stored in neofetch.txt, which was parsed using grep and sed commands. This approach is being replaced by JSON-based storage.
