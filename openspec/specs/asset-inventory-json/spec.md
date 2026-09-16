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

The file SHALL carry a `schema_version` identifying its generation.

#### Scenario: Version present
- **WHEN** `asset-inventory.json` is written
- **THEN** it contains `schema_version` as an integer

#### Scenario: Consumer encounters a newer generation
- **WHEN** a consumer reads a `schema_version` it does not know
- **THEN** it can identify the generation without inferring it from which keys
  are present

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
