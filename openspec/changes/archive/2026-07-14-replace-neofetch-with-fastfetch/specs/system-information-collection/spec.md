## MODIFIED Requirements

### Requirement: JSON-based System Information Storage
The audit system SHALL generate system information in JSON format for structured data access using fastfetch with the honeybadger-shipped config.

#### Scenario: Generate fastfetch JSON during audit
- **WHEN** the audit command is run
- **THEN** fastfetch SHALL be invoked as the audit user (not root) with the shipped config `lib/fastfetch-config.jsonc`
- **AND** fastfetch output SHALL be captured in text mode and parsed to JSON using jq
- **AND** the output SHALL be saved as `fastfetch.json` in the audit output directory
- **AND** the JSON SHALL contain fields with lowercase keys and underscores (e.g., `os`, `kernel`, `kernel_latest`, `last_update`, `reboot`)

#### Scenario: Extract OS information from JSON
- **WHEN** generating OS/kernel status report
- **THEN** the system SHALL use jq to extract OS name from the `os` field in `fastfetch.json`
- **AND** parsing SHALL use structured JSON queries instead of grep/sed text parsing

#### Scenario: Extract hardware information from JSON
- **WHEN** generating asset inventory
- **THEN** the system SHALL use jq to extract model from `host` field
- **AND** kernel version SHALL be extracted from `kernel` field
- **AND** owner/hostname SHALL be parsed from available JSON fields
- **AND** all extractions SHALL use jq queries on `fastfetch.json`

#### Scenario: Detect Nix installation from JSON
- **WHEN** checking for Nix package manager installation
- **THEN** the system SHALL search the `packages` field in `fastfetch.json` for `nix-` pattern using jq
- **AND** SHALL NOT rely on text-based grep parsing

### Requirement: Backward Compatibility for Legacy Formats
The check-output command SHALL support reading legacy audit outputs containing `neofetch.json`, `neofetch.txt`, or `fastfetch.txt` files.

#### Scenario: Fallback to neofetch.json for old audits
- **WHEN** check-output processes an existing audit archive
- **AND** `fastfetch.json` is not present
- **AND** `neofetch.json` exists
- **THEN** the system SHALL parse `neofetch.json` using jq JSON queries
- **AND** SHALL extract the same data fields as `fastfetch.json` would provide

#### Scenario: Fallback to text formats for older audits
- **WHEN** neither `fastfetch.json` nor `neofetch.json` is present
- **AND** `neofetch.txt` or `fastfetch.txt` exists
- **THEN** the system SHALL parse the text file using grep/sed
- **AND** SHALL extract OS and kernel fields at minimum

#### Scenario: Prefer fastfetch.json when multiple formats exist
- **WHEN** both `fastfetch.json` and `neofetch.json` exist in an audit directory
- **THEN** the system SHALL use `fastfetch.json` as the primary source
- **AND** SHALL ignore legacy files

## REMOVED Requirements

### Requirement: neofetch as system information tool
**Reason**: neofetch is unmaintained (archived on GitHub). Replaced by fastfetch which provides richer structured output and active maintenance.
**Migration**: Replace `neofetch` installation with `fastfetch`. Existing `neofetch.json` files in archived outputs remain readable via the fallback chain.
