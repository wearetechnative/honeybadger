# hardware-serial-collection Specification

## Purpose

Determines the hardware serial the collection server matches a submission to an asset on. Names
the source chain per platform, what counts as a usable value, and what the audit writes and
reports when there is none - so a machine without the right package installed still yields a
serial, and a value that is not one is never recorded as though it were.

## Requirements

### Requirement: Determine the hardware serial without requiring a tool

The audit SHALL read the hardware serial from the kernel before reaching for
any external program, so that the result does not depend on which packages a
machine happens to carry.

#### Scenario: Kernel source is used first
- **WHEN** an audit runs on Linux as root
- **THEN** the serial is read from `/sys/class/dmi/id/product_serial`

#### Scenario: Same path across distributions
- **WHEN** the audit runs on NixOS, Ubuntu, Debian or Arch
- **THEN** the same kernel path is used, with no distribution-specific handling

#### Scenario: Board serial when the product serial is empty
- **WHEN** `product_serial` is empty or a placeholder and `board_serial` holds
  a usable value
- **THEN** the board serial is used

#### Scenario: dmidecode as a fallback
- **WHEN** neither sysfs path yields a usable serial and `dmidecode` is present
- **THEN** `dmidecode -s system-serial-number` is used

#### Scenario: nix as a last resort on NixOS
- **WHEN** no earlier source yields a usable serial and the system is NixOS
- **THEN** the audit attempts `nix run nixpkgs#dmidecode`

#### Scenario: Later sources are not reached unnecessarily
- **WHEN** an earlier source yields a usable serial
- **THEN** no later source is attempted

#### Scenario: dmidecode is not a hard dependency
- **WHEN** `dmidecode` is absent but the kernel path works
- **THEN** the audit completes normally and does not fail a dependency check

### Requirement: Determine the hardware serial on macOS

The audit SHALL read the platform serial as a property rather than parsing a
human-readable report.

#### Scenario: ioreg is used first
- **WHEN** an audit runs on macOS
- **THEN** the serial is read from `IOPlatformSerialNumber` via
  `ioreg -d2 -c IOPlatformExpertDevice`

#### Scenario: system_profiler as a fallback
- **WHEN** `ioreg` yields no usable value
- **THEN** `system_profiler SPHardwareDataType` is parsed on the
  `Serial Number` label

#### Scenario: Unrelated output is never written
- **WHEN** a source returns text that is not a serial, as the previous
  implementation did with `Mac OS X`
- **THEN** the value is rejected and not written as a measurement

### Requirement: Validate a serial before writing it

A value SHALL be written to `hardware-serial.txt` only when it is usable: one
token, no whitespace, no known placeholder, not all zeroes.

#### Scenario: Usable value accepted
- **WHEN** a source returns `PF50L2MR`, `MP1Y69AC` or `FRANDGCPA5530200H9`
- **THEN** the value is written

#### Scenario: Placeholder rejected
- **WHEN** a source returns `Not available`, `To Be Filled By O.E.M.`,
  `Default string`, `System Serial Number`, `None` or all zeroes
- **THEN** the value is treated as no serial

#### Scenario: Value with whitespace rejected
- **WHEN** a source returns a value containing a space or a tab
- **THEN** the value is treated as no serial

#### Scenario: Agreement with the collection server
- **WHEN** the audit writes a serial
- **THEN** it passes the same usability rule the collection server applies when
  matching a submission to an asset

### Requirement: Report when no serial can be determined

The audit SHALL distinguish a serial it could not read from one the hardware
does not have, and SHALL make the outcome visible to the operator.

#### Scenario: Nothing could read it
- **WHEN** no source in the chain returns any value
- **THEN** `hardware-serial.txt` contains `could-not-read`

#### Scenario: Hardware has none
- **WHEN** a source returns an empty or placeholder value, as a virtual machine
  commonly does
- **THEN** `hardware-serial.txt` contains `none-present`

#### Scenario: Operator is told
- **WHEN** no usable serial is determined
- **THEN** the audit reports it at the end of the run, naming which of the two
  applies, rather than completing silently

#### Scenario: Source recorded
- **WHEN** a serial is determined
- **THEN** `asset-inventory.txt` names both the serial and the source it came
  from
