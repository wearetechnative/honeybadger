## ADDED Requirements

### Requirement: Collect system information with fastfetch
The system SHALL collect system information with fastfetch and store it as
`fastfetch.json`, in the same flat shape the Linux and macOS clients produce,
so that one consumer reads every platform's archive.

#### Scenario: fastfetch available
- **WHEN** fastfetch is installed on the system
- **THEN** the audit runs it with the shipped Windows config and writes
  `fastfetch.json` to the output directory

#### Scenario: Keys match the other platforms
- **WHEN** `fastfetch.json` is written
- **THEN** its keys are lowercase with underscores, and `user`, `hostname`,
  `os`, `host` and `kernel` carry the same meanings they carry on Linux

#### Scenario: fastfetch not available
- **WHEN** fastfetch is not found
- **THEN** the audit attempts to install it through winget

#### Scenario: fastfetch could not be installed
- **WHEN** fastfetch is absent and cannot be installed
- **THEN** the audit reports that the dependency is missing and names how to
  install it
- **AND** SHALL NOT write a `fastfetch.json` assembled from another source

#### Scenario: No legacy format is produced
- **WHEN** an audit completes
- **THEN** `neofetch.txt` SHALL NOT be written, and neofetch SHALL NOT be
  installed or invoked

## MODIFIED Requirements

### Requirement: Collect hardware serial number
The system SHALL collect the hardware serial from BIOS/UEFI using
`Get-CimInstance Win32_BIOS` and SHALL write it to `hardware-serial.txt`, so
that it travels in the archive and the collection server can resolve the asset.

#### Scenario: Physical hardware
- **WHEN** the system runs on physical hardware with a valid BIOS serial
- **THEN** the serial is written to `hardware-serial.txt` and the source is
  recorded in `hardware-serial-source.txt`

#### Scenario: Value is judged by the shared rule
- **WHEN** a serial is read from WMI
- **THEN** it is accepted only if it is one token, free of whitespace and
  control characters, not all zeroes, and not a known placeholder - the same
  rule the other platforms and the collection server apply

#### Scenario: Virtual machine or unavailable serial
- **WHEN** `Win32_BIOS` returns an empty value or a placeholder such as
  `To Be Filled By O.E.M.`, `Default string` or `System Serial Number`
- **THEN** `hardware-serial.txt` contains `none-present`
- **AND** the literal `Not available (VM or unknown hardware)` is not recorded
  as though it were the measured serial

#### Scenario: Serial could not be read at all
- **WHEN** the WMI query fails
- **THEN** `hardware-serial.txt` contains `could-not-read`

#### Scenario: Operator is told
- **WHEN** no usable serial is determined
- **THEN** the audit reports it at the end of the run, naming which of the two
  cases applies

### Requirement: Store all collected data in report directory
The system SHALL create an output directory named
`output-<hostname>-<username>-<dd-MM-yyyy>` and store all collected data files
in it, so that a Windows archive is laid out like every other archive.

#### Scenario: Report directory creation
- **WHEN** the audit begins data collection
- **THEN** it creates `output-<hostname>-<username>-<dd-MM-yyyy>` if it does
  not exist

#### Scenario: Data files stored
- **WHEN** each data collection step completes
- **THEN** its output is written into that directory, including
  `bitlocker_result.txt`, `fastfetch.json`, `hardeningkitty.csv` and
  `hardware-serial.txt`

#### Scenario: Directory is readable by the shared tooling
- **WHEN** the directory name is parsed by the client's shared output-name
  parser
- **THEN** the hostname, username and date are recovered from it

## REMOVED Requirements

### Requirement: Collect system information
**Reason**: neofetch is unmaintained and its output is ASCII art around a
handful of values. The decision recorded in `2026-09-16-fastfetch-only-system-
info` is that the client writes and reads `fastfetch.json` only, with no
fallback to a legacy format; Windows was explicitly left out of that change and
is brought onto it here. Replaced by "Collect system information with
fastfetch".
**Migration**: Windows hosts install fastfetch through winget on the next
audit. `neofetch.txt` in archives already produced is not read by any current
consumer, and was not readable by one before this change either.
