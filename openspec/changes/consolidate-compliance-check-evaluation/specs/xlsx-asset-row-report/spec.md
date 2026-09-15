## MODIFIED Requirements

### Requirement: Column Value Normalisation
The system SHALL normalise audit findings into the values the register's data validation accepts:
`Yes`, `No`, or `N.A.` for columns `G`, `H`, `I`, and `L`, and a number or `N.A.` for column `K`.
It SHALL derive each value from the verdict returned by the shared check function for that
control, and SHALL NOT re-read the underlying evidence files to decide the value.

#### Scenario: Boolean security controls
- **WHEN** a control was detected as present
- **THEN** the cell value is `Yes`
- **AND** when the control was detected as absent the cell value is `No`

#### Scenario: Cell value follows the shared check verdict
- **WHEN** the shared check function for a boolean column returns exit code `0`, `1` or `2`
- **THEN** the cell value is `Yes`, `No` or `N.A.` respectively
- **AND** the detail string returned by that function is shown as the provenance for the cell

#### Scenario: Screen lock timeout above the limit
- **WHEN** auto-lock is enabled with a timeout above 15 minutes
- **THEN** the cell value for column `H` is `No`
- **AND** the provenance states the established timeout and the 15-minute limit

#### Scenario: OS up-to-date status maps three states onto two values
- **WHEN** the OS and kernel check resulted in a pass
- **THEN** the cell value for column `L` is `Yes`
- **AND** when the check resulted in a warning, meaning the system is supported but not on the
  latest release, the cell value is also `Yes`
- **AND** when the check resulted in a failure, meaning the system is end-of-life, the cell value
  is `No`

#### Scenario: Undetermined value
- **WHEN** a value could not be determined from the collected data
- **THEN** the cell value is `N.A.` rather than a guess or an empty cell

### Requirement: Tolerance for Missing Source Data
The system SHALL generate a complete report when source files are missing or unreadable,
substituting an undetermined value for the affected columns rather than failing. It SHALL
establish that a value is undetermined from the shared check function's indeterminate verdict
rather than by testing for the evidence file itself.

#### Scenario: A source file is missing
- **WHEN** one of the audit source files is absent from the output directory
- **THEN** the shared check function for the affected control returns the indeterminate verdict
- **AND** the columns derived from that file report an undetermined value
- **AND** all other columns are filled normally
- **AND** `check-output` completes without error

#### Scenario: Audit data is unusable
- **WHEN** the Lynis report is absent or cannot be parsed
- **THEN** the report is still generated with the columns that could be determined from other
  sources
- **AND** the report states which data was unavailable

## ADDED Requirements

### Requirement: Hardening Threshold Provenance
The report SHALL state the hardening threshold that was applied to column `K`, reading it from the
shared configured value rather than from a constant declared in the report generator.

#### Scenario: Configured threshold is reflected
- **WHEN** the configured minimum hardening score is `75` and the measured score is `64`
- **THEN** the cell value for column `K` is `64`
- **AND** the provenance states that the applied threshold was `75` and was not met

#### Scenario: Threshold is not redeclared
- **WHEN** the report generator needs the hardening threshold
- **THEN** it uses the single configured value
- **AND** it does not declare its own copy of that number
