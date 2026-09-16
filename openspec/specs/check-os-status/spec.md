# check-os-status Specification

## Purpose
This specification defines how `check-os-status.sh` determines OS and kernel status during an audit. It covers fastfetch.json integration as the primary data source, live kernel series comparison via the `kernel_latest` field, distro-aware patch comparison logic, and removal of the hardcoded kernel version database.

## Requirements

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

### Requirement: System information source is fastfetch.json only

check-os-status.sh SHALL read system information from `fastfetch.json` only, and
SHALL refuse a directory that does not carry it rather than reading another
format.

#### Scenario: fastfetch.json is used when present
- **WHEN** check-os-status.sh is run against an output directory
- **AND** `fastfetch.json` is present
- **THEN** `fastfetch.json` SHALL be used as the fetch file source
- **AND** OS and kernel information SHALL be extracted using jq on the flat
  JSON structure

#### Scenario: No fastfetch.json present
- **WHEN** `fastfetch.json` is not present in the output directory
- **THEN** check-os-status.sh SHALL exit non-zero with an error naming the
  missing file and the command that produces it
- **AND** SHALL NOT read `neofetch.json`, `neofetch.txt` or `fastfetch.txt`

#### Scenario: A retired format is named as such
- **WHEN** the directory carries `neofetch.json`, `neofetch.txt` or
  `fastfetch.txt` but no `fastfetch.json`
- **THEN** the error SHALL say which retired format was found, so that a
  directory plainly holding system information is not simply called empty

#### Scenario: Nothing is written into a refused directory
- **WHEN** check-os-status.sh refuses a directory for missing system information
- **THEN** no `os-kernel-status.txt` is created in it

### Requirement: Kernel series comparison using kernel_latest

check-os-status.sh SHALL use the `kernel_latest` field from `fastfetch.json` to
determine kernel status, rather than a hardcoded kernel version database.

#### Scenario: kernel_latest present — series is upstream-maintained
- **WHEN** `fastfetch.json` contains a non-empty `kernel_latest` field
- **THEN** the kernel series SHALL be considered upstream-maintained
- **AND** the report SHALL show the upstream latest version

#### Scenario: kernel_latest absent or empty — series is upstream EOL
- **WHEN** `fastfetch.json` is present but `kernel_latest` is absent or empty
- **THEN** the kernel series SHALL be reported as "upstream EOL or status
  unknown"
- **AND** the report SHALL recommend checking kernel.org for the current status

### Requirement: A finding is not a failed run

The audit SHALL NOT report an OS or kernel finding through its exit status. An
exit status says whether the run worked; the finding is reported in the status
report and the compliance report.

#### Scenario: Warning does not fail the run
- **WHEN** `check-output` analyses a directory whose OS or kernel status is a
  warning
- **THEN** it exits 0
- **AND** the warning is present in `os-kernel-status.txt`

#### Scenario: End of life does not fail the run
- **WHEN** the audited system's OS is past end of life
- **THEN** `check-output` exits 0

#### Scenario: A run that could not happen does fail
- **WHEN** the directory does not exist, or carries no `fastfetch.json`
- **THEN** `check-output` exits non-zero

#### Scenario: A failure to analyse is reported
- **WHEN** the status report cannot be produced for a directory that was
  accepted
- **THEN** a warning is printed
- **AND** the remaining reports are still generated

### Requirement: Each entry point states what its exit status means

The two entry points that determine OS and kernel status SHALL NOT share a name,
and each SHALL document what its exit status means.

#### Scenario: The operator command returns a severity
- **WHEN** `lib/check-os-status.sh` is run directly
- **THEN** its exit status is a severity: 0 for pass, 1 for warning, 2 for end
  of life or fail

#### Scenario: The library step returns whether it produced a report
- **WHEN** the library function that writes `os-kernel-status.txt` is called
- **THEN** its exit status says whether the report was produced, and carries no
  severity

#### Scenario: The names are distinct
- **WHEN** a reader encounters either entry point
- **THEN** its name does not collide with the other's
- **AND** the contract is stated where the entry point is defined
