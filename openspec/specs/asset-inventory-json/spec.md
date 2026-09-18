# asset-inventory-json Specification

## Purpose
This specification defines `asset-inventory.json`, the machine-readable
counterpart of `asset-inventory.txt`. The audit determines every value the ISO
register needs and writes them for humans in two places; this file is the same
findings in a shape the collection server can read, so an operator does not
retype them. It is emitted from the determinations the xlsx report renders
rather than deriving them again - whether a disk counts as encrypted or a
hardening score as compliant is platform-specific knowledge that lives in this
client.

## Requirements

### Requirement: Machine-readable asset inventory

The audit SHALL write `asset-inventory.json` containing the same determinations
as `asset-inventory.txt`, into both the output directory and the tar archive.

#### Scenario: File produced by every audit
- **WHEN** an audit completes on any supported platform
- **THEN** `asset-inventory.json` is present in the output directory and in the
  tar archive

#### Scenario: Values agree with the human-readable outputs
- **WHEN** a single audit run produces `asset-inventory.txt`,
  the xlsx report and `asset-inventory.json`
- **THEN** the determined values agree across all three

#### Scenario: Valid JSON under partial failure
- **WHEN** several determinations cannot be made on the audited system
- **THEN** the file is still valid JSON

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

### Requirement: Identity block

The file SHALL carry the hardware serial as the stable identity of the audited
system.

#### Scenario: Serial recorded
- **WHEN** the hardware serial is `PF50L2MR`
- **THEN** `identity.serial` is `PF50L2MR`

#### Scenario: Serial unavailable
- **WHEN** the hardware serial cannot be read
- **THEN** `identity.serial` is null and the remaining identity fields are
  still populated

### Requirement: Value and provenance per finding

Each finding SHALL carry both the determined value and the finding it was
derived from.

#### Scenario: Determined value with provenance
- **WHEN** disk encryption is determined as enabled via LUKS
- **THEN** the entry carries value "Yes" and finding "Yes (LUKS)"

#### Scenario: Hardening score names its tool
- **WHEN** a hardening score is determined
- **THEN** the entry carries the score, the tool that produced it, and the
  finding text

#### Scenario: Deliberately undetermined value
- **WHEN** the audit declines to assert a value, as it does for vulnerable
  packages when no package audit tool is present
- **THEN** the entry carries a null value and a finding explaining why

#### Scenario: Undetermined is distinct from unsupported
- **WHEN** a consumer reads the file
- **THEN** a null value with a finding is distinguishable from a key this
  generation of the client does not emit at all

### Requirement: Identity username agrees with the human-readable inventory

`identity.username` SHALL be the same determination `asset-inventory.txt`
records as the owner, so that the collection server and an operator reading the
archive see the same person.

#### Scenario: The two files agree
- **WHEN** one audit run produces `asset-inventory.txt` and
  `asset-inventory.json`
- **THEN** `identity.username` equals the `Owner / User` value in
  `asset-inventory.txt`

#### Scenario: Agreement holds for a hyphenated hostname
- **WHEN** the audited machine's hostname contains a hyphen
- **THEN** the two files still agree, and both name a user that exists on the
  machine

#### Scenario: Username is not derived from the output directory name
- **WHEN** `asset-inventory.json` is written
- **THEN** `identity.username` is not recovered by parsing the output
  directory's name, unless no recorded source is present in the archive

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

### Requirement: Hardening score on a platform without a comparable figure

Where the platform's hardening tool produces no figure comparable to the one
the asset register's column expects, the entry SHALL carry a null value, name
the tool that was run, and report what was measured in its finding - rather
than approximating a score.

#### Scenario: HardeningKitty has no 0-100 score
- **WHEN** an audit runs on Windows, where HardeningKitty reports counts by
  severity rather than a score out of 100
- **THEN** `findings.hardening_score.value` is null
- **AND** `findings.hardening_score.tool` is `hardeningkitty`
- **AND** the finding reports the counts that were measured

#### Scenario: No score is invented
- **WHEN** a consumer compares hardening scores across the fleet
- **THEN** no Windows submission contributes a number derived from a different
  scale

#### Scenario: The tool is always named
- **WHEN** a hardening score entry is written on any platform
- **THEN** `tool` names the tool that produced it, so a null value is
  attributable

### Requirement: Platform identifies the client that produced the document

`platform` SHALL name the operating system family the audit ran on, so a
consumer can tell which collection rules produced the findings.

#### Scenario: Windows
- **WHEN** the document is written by the Windows client
- **THEN** `platform` is `windows`

#### Scenario: Known set
- **WHEN** a consumer reads `platform`
- **THEN** it is one of `linux`, `macos` or `windows`
