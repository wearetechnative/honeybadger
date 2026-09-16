## ADDED Requirements

### Requirement: Vulnerable package count

The `vulnerable_packages` finding SHALL carry the number of vulnerable packages
the audit counted, as a `count` field separate from the spreadsheet cell value.

#### Scenario: Count recorded when packages were found
- **WHEN** the audit counted one vulnerable package
- **THEN** `findings.vulnerable_packages.count` is `1`
- **AND** the finding text is retained

#### Scenario: Count is a number, not a string
- **WHEN** `count` carries a measured value
- **THEN** it is a JSON number

#### Scenario: Determined zero
- **WHEN** a package audit tool is present and no vulnerable packages were found
- **THEN** `count` is `0`

#### Scenario: Nothing looked is not zero
- **WHEN** no package audit tool is present, which Lynis reports with a
  vulnerable package count of zero
- **THEN** `count` is null rather than `0`

#### Scenario: No audit data at all
- **WHEN** `lynis-report.json` is unavailable
- **THEN** `count` is null

#### Scenario: Determined count distinguishable from an undetermined one
- **WHEN** a consumer reads two documents, one from a machine where the count
  was determined and one from a machine where it could not be
- **THEN** the two are distinguishable without reading the finding text

### Requirement: Spreadsheet cell stays undecided

`vulnerable_packages.value` SHALL remain null, because the asset register
contradicts itself about which literal means compliant.

#### Scenario: Value is null even when a count is carried
- **WHEN** the audit counted one vulnerable package
- **THEN** `value` is null and `count` is `1`

#### Scenario: Column J is still left to the operator
- **WHEN** the xlsx report renders column J
- **THEN** it reports the finding and gives no cell value

## MODIFIED Requirements

### Requirement: Schema version

The file SHALL carry a `schema_version` identifying its generation, and it SHALL
be incremented when the shape of the document changes.

#### Scenario: Version present
- **WHEN** `asset-inventory.json` is written
- **THEN** it contains `schema_version` as an integer

#### Scenario: Consumer encounters a newer generation
- **WHEN** a consumer reads a `schema_version` it does not know
- **THEN** it can identify the generation without inferring it from which keys
  are present

#### Scenario: A new field is a new generation
- **WHEN** a field is added to the document
- **THEN** `schema_version` is greater than the generation that lacked it
