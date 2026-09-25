## MODIFIED Requirements

### Requirement: Operator-Maintained Columns
The system SHALL list the columns it does not fill as operator-maintained, and SHALL NOT invent
values for them. `C` Owner and `O` Remarks are always operator-maintained. `A` Asset and `N`
proof_file are operator-maintained unless the report was generated from an archive named by
badgersbay's download convention, in which case they are filled from that name.

#### Scenario: Operator-maintained columns are listed
- **WHEN** the report is generated from an output directory, or from an archive whose name does
  not follow the badgersbay download convention
- **THEN** columns `A`, `C`, `N`, and `O` appear in a section identifying them as maintained by
  the operator
- **AND** no cell values are offered for them

#### Scenario: Username offered as a hint for Owner
- **WHEN** the report lists column `C` as operator-maintained
- **THEN** it shows the username observed during the scan as a hint
- **AND** it notes that the register uses full names, which the audit cannot determine

#### Scenario: Asset and proof_file from a badgersbay download
- **WHEN** the report is generated from an archive named `TARI-00023-2026-09-17-wouter.toorren.tar.gz`
- **THEN** column `A` has cell value `TARI-00023`
- **AND** column `N` has cell value `TARI-00023-2026-09-17-wouter.toorren`
- **AND** both state that they were taken from the archive name
- **AND** only `C` and `O` remain in the operator-maintained section

#### Scenario: A name that only resembles the convention
- **WHEN** the archive name does not have an asset ID of the register's form followed by a
  `YYYY-MM-DD` date - for example a browser duplicate such as `... (1).tar.gz`, or an unmatched
  submission named for its serial
- **THEN** columns `A` and `N` stay operator-maintained
