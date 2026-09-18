## ADDED Requirements

### Requirement: Emit a machine-readable asset inventory
The Windows audit SHALL write `asset-inventory.json` into the output directory
and the archive, in the shape the `asset-inventory-json` capability defines, so
that a Windows submission carries the same determinations a Linux one does.

#### Scenario: File produced by every Windows audit
- **WHEN** a Windows audit completes
- **THEN** `asset-inventory.json` is present in the output directory and in the
  archive

#### Scenario: Platform identified
- **WHEN** `asset-inventory.json` is written on Windows
- **THEN** `platform` is `windows`

#### Scenario: Determinations agree with the compliance report
- **WHEN** one audit run produces the compliance report and
  `asset-inventory.json`
- **THEN** disk encryption, screen lock, firewall and OS update status agree
  between them

#### Scenario: Valid JSON under partial failure
- **WHEN** several checks could not be completed
- **THEN** the file is still valid JSON, with those findings carrying a null
  value and a finding explaining why

### Requirement: Bundle the audit into a tar archive
The Windows audit SHALL package the output directory into
`honeybadger-<hostname>-<username>-<dd-MM-yyyy>.tar.gz`, so that it can be
submitted to the collection server.

#### Scenario: Archive produced
- **WHEN** a Windows audit completes
- **THEN** a `.tar.gz` is written, containing the output directory

#### Scenario: Layout matches the other platforms
- **WHEN** the archive is read
- **THEN** its entries are under `output-<hostname>-<username>-<dd-MM-yyyy>/`

#### Scenario: Serial travels with it
- **WHEN** the archive is produced
- **THEN** it contains `hardware-serial.txt`

#### Scenario: No second bundle
- **WHEN** a Windows audit completes
- **THEN** no zip archive is produced, because it cannot be submitted to the
  archive endpoint

#### Scenario: Archiving tool unavailable
- **WHEN** `tar` is not present on the system
- **THEN** the audit reports that the archive could not be created and names
  the tool
- **AND** the collected output directory is left in place

## MODIFIED Requirements

### Requirement: Include system information in compliance report
The system SHALL include system identification data (hostname, username, date,
hardware serial number, OS version) at the top of the compliance report, taking
the serial and the OS version from the same determinations the machine-readable
outputs carry.

#### Scenario: System info section populated
- **WHEN** the compliance report is generated
- **THEN** its header includes hostname, username, report date, hardware serial
  number and OS version

#### Scenario: Serial agrees with the archive
- **WHEN** the compliance report and `hardware-serial.txt` are both written
- **THEN** they name the same serial, including when that is `none-present` or
  `could-not-read`

#### Scenario: OS version comes from fastfetch
- **WHEN** the compliance report names the OS version
- **THEN** it is the `os` value from `fastfetch.json`, not a reference to a
  neofetch text file
