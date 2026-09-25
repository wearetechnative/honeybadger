# xlsx-asset-row-report Specification

## Purpose

Translates the findings of a device audit into the constrained cell values required by the
`Active Assets` sheet of the ISO27001 asset register, so an operator can update the register by
hand without re-deriving each value, and can afterwards see which finding every cell came from.

## Requirements

### Requirement: Report File Generation
The `check-output` command SHALL generate a markdown report named
`honeybadger-{username}-{date}-xlsx.md` in the current directory on every invocation, without
requiring a flag or option.

#### Scenario: Report generated for directory input
- **WHEN** the operator runs `check-output` on an output directory
- **THEN** the system creates `honeybadger-{username}-{date}-xlsx.md` in the current directory
- **AND** the filename uses the same username and date as the compliance and actions reports

#### Scenario: Report generated for tarball input
- **WHEN** the operator runs `check-output` on a `.tar.gz` or `.tar` archive
- **THEN** the system creates the report after extracting the archive
- **AND** the report is retained after the extracted directory is cleaned up

#### Scenario: Report generated alongside the existing reports
- **WHEN** `check-output` completes successfully
- **THEN** the compliance report, the actions report, and the xlsx report have all been written
- **AND** the command's closing summary names all three files

### Requirement: Row Identification
The report SHALL identify which row of the asset register it applies to, using the hardware serial
number as the matching key, and SHALL state the hostname and scan date.

#### Scenario: Serial number available
- **WHEN** the hardware serial number was collected during the audit
- **THEN** the report instructs the operator to locate the register row by that serial number
- **AND** the same serial number is offered as the cell value for column `D`

#### Scenario: Serial number unavailable
- **WHEN** the hardware serial number could not be determined
- **THEN** the report states that the row cannot be identified automatically
- **AND** the report is still generated with all other columns filled

### Requirement: Cell Value and Provenance
For every column the system fills, the report SHALL present both the literal cell value to enter
and the underlying finding that value was derived from, so that an auditor can trace each entry
back to collected evidence.

#### Scenario: Normalised value shows its source finding
- **WHEN** disk encryption was detected as LUKS
- **THEN** the cell value for column `G` is `Yes`
- **AND** the accompanying finding identifies LUKS as the basis for that value

#### Scenario: Hardening score is reported as a bare number
- **WHEN** the Lynis hardening index is 64
- **THEN** the cell value for column `K` is `64`, with no suffix, percentage, or status marker
- **AND** the accompanying finding states the applied compliance threshold and whether it was met

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

### Requirement: Vulnerable Packages Reporting
Because the register contradicts itself about which literal value of column `J` indicates
compliance, the system SHALL report the observed finding together with a note describing the
contradiction, and SHALL NOT emit a cell value for that column.

#### Scenario: No package audit tool present
- **WHEN** the audit found no package audit tool on the system
- **THEN** the report states that vulnerable packages could not be determined
- **AND** the report does not present a zero count as evidence of compliance

#### Scenario: Package audit tool present and no vulnerable packages found
- **WHEN** a package audit tool was present and reported no vulnerable packages
- **THEN** the report states that no vulnerable packages were found

#### Scenario: Package audit tool present and vulnerable packages found
- **WHEN** a package audit tool was present and reported one or more vulnerable packages
- **THEN** the report states how many vulnerable packages were found

#### Scenario: Contradiction is disclosed
- **WHEN** the report presents column `J`
- **THEN** it notes that the register's data validation and its `Status` formula disagree about
  which literal value means compliant
- **AND** it leaves the choice of cell value to the operator

### Requirement: Operator-Maintained Columns
The system SHALL list the columns it does not fill — `A` Asset, `C` Owner, `N` proof_file, and
`O` Remarks — as operator-maintained, and SHALL NOT invent values for them.

#### Scenario: Operator-maintained columns are listed
- **WHEN** the report is generated
- **THEN** columns `A`, `C`, `N`, and `O` appear in a section identifying them as maintained by
  the operator
- **AND** no cell values are offered for them

#### Scenario: Username offered as a hint for Owner
- **WHEN** the report lists column `C` as operator-maintained
- **THEN** it shows the username observed during the scan as a hint
- **AND** it notes that the register uses full names, which the audit cannot determine

### Requirement: Formula Column Protection
The system SHALL identify columns `B` (Status) and `M` (Last_Audit_Date) as spreadsheet formulas
and SHALL warn that entering values into them would overwrite those formulas.

#### Scenario: Formula columns are flagged
- **WHEN** the report is generated
- **THEN** columns `B` and `M` appear in a section marking them as formulas that must not be
  overwritten
- **AND** the report reproduces the `Last_Audit_Date` formula so the operator can restore it if it
  is lost

### Requirement: Spreadsheet Is Never Modified
The system SHALL NOT read from, write to, or otherwise modify the `.xlsx` file. The report is the
only output, and updating the register remains a manual action.

#### Scenario: No spreadsheet access
- **WHEN** `check-output` runs, whether or not the `.xlsx` file is present
- **THEN** the `.xlsx` file is neither opened nor altered
- **AND** the report is generated identically in both cases

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
