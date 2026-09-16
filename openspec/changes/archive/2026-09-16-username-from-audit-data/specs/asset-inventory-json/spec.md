## ADDED Requirements

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
