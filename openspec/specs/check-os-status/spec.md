# check-os-status Specification

## Purpose
This specification defines how `check-os-status.sh` determines OS and kernel status during an audit. It covers fastfetch.json integration as the primary data source, live kernel series comparison via the `kernel_latest` field, distro-aware patch comparison logic, and removal of the hardcoded kernel version database.

## Requirements

### Requirement: fastfetch.json recognized as input source
check-os-status.sh SHALL recognize `fastfetch.json` in the audit output directory and use it as the primary system information source, before falling back to legacy neofetch files.

#### Scenario: fastfetch.json is used when present
- **WHEN** check-os-status.sh is run against an output directory
- **AND** `fastfetch.json` is present
- **THEN** `fastfetch.json` SHALL be used as the fetch file source with format `json`
- **AND** OS and kernel information SHALL be extracted using jq on the flat JSON structure

#### Scenario: Legacy fallback chain is preserved
- **WHEN** `fastfetch.json` is not present in the output directory
- **THEN** check-os-status.sh SHALL fall back in order: `neofetch.json` → `neofetch.txt` → `fastfetch.txt`
- **AND** existing audit archives SHALL continue to work without modification

### Requirement: Live kernel series comparison using kernel_latest
check-os-status.sh SHALL use the `kernel_latest` field from `fastfetch.json` to determine kernel status, replacing the hardcoded kernel version database.

#### Scenario: kernel_latest present — series is upstream-maintained
- **WHEN** `fastfetch.json` contains a non-empty `kernel_latest` field
- **THEN** the kernel series SHALL be considered upstream-maintained
- **AND** the report SHALL show the upstream latest version

#### Scenario: kernel_latest absent or empty — series is upstream EOL
- **WHEN** `fastfetch.json` is present but `kernel_latest` is absent or empty
- **THEN** the kernel series SHALL be reported as "upstream EOL or status unknown"
- **AND** the report SHALL recommend checking kernel.org for the current status

#### Scenario: No fastfetch.json present — graceful degradation
- **WHEN** `fastfetch.json` is not present (legacy neofetch.json used instead)
- **THEN** kernel status SHALL be reported as "unknown — no kernel_latest data available"
- **AND** the EXIT_CODE SHALL NOT be changed solely due to missing kernel_latest

### Requirement: Distro-aware kernel patch comparison
check-os-status.sh SHALL apply distro-specific logic when comparing the running kernel against `kernel_latest`.

#### Scenario: NixOS — exact patch comparison
- **WHEN** `$OS_NAME` is `NixOS`
- **AND** `kernel_latest` is present
- **THEN** the running kernel version SHALL be compared exactly against the upstream latest patch
- **AND** if the versions differ, the report SHALL indicate the delta (e.g., "running 6.18.37, upstream latest 6.18.38")
- **AND** if the versions match, the report SHALL indicate "up to date"

#### Scenario: Arch Linux — exact patch comparison
- **WHEN** `$OS_NAME` is `Arch` or `Arch Linux`
- **AND** `kernel_latest` is present
- **THEN** the running kernel version SHALL be compared exactly against the upstream latest patch

#### Scenario: Debian — series EOL detection only
- **WHEN** `$OS_NAME` is `Debian`
- **AND** `kernel_latest` is present
- **THEN** the report SHALL show the upstream latest version for the series as reference
- **AND** the report SHALL note that Debian maintains its own kernel patch numbering
- **AND** no FAIL or WARNING SHALL be issued based on patch-level difference alone

#### Scenario: Ubuntu — series EOL detection with distro support note
- **WHEN** `$OS_NAME` is `Ubuntu`
- **AND** `kernel_latest` is absent or empty (kernel series is upstream EOL)
- **THEN** the report SHALL note that the kernel series is upstream EOL
- **AND** SHALL add: "Ubuntu may continue to support this kernel series; verify via Ubuntu security advisories"
- **AND** SHALL NOT issue a FAIL based solely on upstream EOL status

### Requirement: Hardcoded kernel database removed
check-os-status.sh SHALL NOT contain a hardcoded `case "$KERNEL_MAJOR.$KERNEL_MINOR"` database of kernel versions and dates.

#### Scenario: Unknown kernel series is handled gracefully
- **WHEN** the running kernel series has no match in a static database (e.g., 6.18, 6.19)
- **THEN** check-os-status.sh SHALL use `kernel_latest` data instead of falling through to an "UNKNOWN" case
- **AND** the kernel series status SHALL be determined from whether `kernel_latest` is populated
