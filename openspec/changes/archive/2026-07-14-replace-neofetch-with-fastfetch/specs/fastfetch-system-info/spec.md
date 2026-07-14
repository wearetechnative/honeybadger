## ADDED Requirements

### Requirement: Shipped fastfetch config for consistent audit output
honeybadger SHALL ship `lib/fastfetch-config.jsonc` as the canonical fastfetch configuration for audits. This config SHALL be used explicitly via `--config`, overriding any personal fastfetch config the audit user may have.

#### Scenario: Shipped config is used regardless of user config
- **WHEN** the audit command runs fastfetch
- **THEN** fastfetch SHALL be invoked with `--config "$thisdir/lib/fastfetch-config.jsonc"`
- **AND** the user's personal `~/.config/fastfetch/config.jsonc` SHALL be ignored

### Requirement: fastfetch JSON output with compliance fields
The audit system SHALL collect system information using fastfetch in text mode, parse it to flat JSON, and save as `fastfetch.json` in the audit output directory.

#### Scenario: Generate fastfetch.json during audit
- **WHEN** the audit command runs
- **THEN** fastfetch SHALL be invoked as the audit user (not root) with the shipped config
- **AND** output SHALL be parsed to flat JSON with lowercase underscore-separated keys
- **AND** the result SHALL be saved as `fastfetch.json` in the audit output directory

#### Scenario: Standard fields are present in fastfetch.json
- **WHEN** `fastfetch.json` is generated
- **THEN** the file SHALL contain at minimum: `user`, `hostname`, `os`, `kernel`, `shell`, `cpu`, `memory`
- **AND** keys SHALL use lowercase with underscores (e.g., `local_ip`, `kernel_latest`)

#### Scenario: Compliance fields are present in fastfetch.json
- **WHEN** `fastfetch.json` is generated on a system with internet access
- **THEN** `kernel_latest` SHALL contain the upstream latest version for the running kernel series (e.g., `"6.18.38 (2026-07-04)"`)
- **AND** `last_update` SHALL contain the date of the last system update, or `"n/a"` if not determinable
- **AND** `reboot` SHALL contain `"not required"` or `"REQUIRED"` depending on reboot-required marker files
- **AND** `updates` SHALL contain the number of available updates or the update command for the detected package manager

#### Scenario: kernel_latest is empty when kernel.org is unreachable
- **WHEN** `fastfetch.json` is generated on a system without internet access
- **AND** the curl call to kernel.org times out (3 second timeout)
- **THEN** `kernel_latest` SHALL be absent or empty in the output
- **AND** the audit SHALL continue without error

### Requirement: fastfetch is a required dependency
RUNME.sh SHALL check for fastfetch as a required dependency before running the audit.

#### Scenario: Dependency check fails when fastfetch is missing
- **WHEN** the audit command is run
- **AND** fastfetch is not installed
- **THEN** the dependency check SHALL fail with a clear error message before the audit starts
- **AND** the error SHALL suggest installing fastfetch
