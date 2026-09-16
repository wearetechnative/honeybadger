## REMOVED Requirements

### Requirement: Backward Compatibility for Legacy Formats

**Reason**: The client has committed to fastfetch as its only system
information format, and the collection server accepts only `fastfetch.json`.
Supporting formats the client no longer produces keeps a retired shape alive in
the code that most needs one shape, and `lib/check-os-status.sh` already labels
that path "Legacy neofetch.json used - no live data".

**Migration**: Output directories produced before the fastfetch migration must
be re-audited with a current client. They predate the 2026-03 audit round and
are archive material.

## MODIFIED Requirements

### Requirement: JSON-based System Information Storage
The audit system SHALL generate system information in JSON format for structured data access using fastfetch with the honeybadger-shipped config, and SHALL read system information from `fastfetch.json` only.

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

#### Scenario: System information file missing
- **WHEN** check-output runs against a directory with no `fastfetch.json`
- **THEN** it SHALL exit with an error naming the missing file and the command that produces it
- **AND** SHALL NOT fall back to another format

#### Scenario: Legacy format present without fastfetch.json
- **WHEN** a directory contains `neofetch.json`, `neofetch.txt` or `fastfetch.txt` but no `fastfetch.json`
- **THEN** the directory SHALL be treated as missing system information
- **AND** SHALL NOT be parsed as a fallback
