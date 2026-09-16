## ADDED Requirements

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
