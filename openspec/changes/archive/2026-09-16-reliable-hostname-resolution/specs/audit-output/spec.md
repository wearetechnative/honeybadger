## ADDED Requirements

### Requirement: Resolve the hostname without requiring a package

The audit SHALL determine the machine's hostname from sources present on every
supported platform, so that naming the run's output does not depend on which
packages a host happens to carry.

#### Scenario: No external hostname tool is used
- **WHEN** an audit runs on a host where `hostname(1)` is not installed
- **THEN** the output directory and tar archive are named with the machine's
  real hostname
- **AND** the run does not invoke `hostname(1)`

#### Scenario: Kernel is asked first
- **WHEN** `uname -n` reports a usable name
- **THEN** that name is used and no further source is consulted

#### Scenario: Shell variable when uname cannot be run
- **WHEN** `uname` is not available and `$HOSTNAME` holds a usable name
- **THEN** `$HOSTNAME` is used

#### Scenario: Configuration file as the last resort
- **WHEN** neither `uname -n` nor `$HOSTNAME` yields a usable name and
  `/etc/hostname` holds one
- **THEN** the value from `/etc/hostname` is used

#### Scenario: Same result as the previous implementation
- **WHEN** an audit runs on a host where `hostname -s` previously worked
- **THEN** the resolved name is the one `hostname -s` reported

### Requirement: Shorten the hostname to its first label

The audit SHALL use only the portion of the hostname before the first dot, so
that a fully qualified name does not become the output directory's name.

#### Scenario: Fully qualified name is shortened
- **WHEN** the resolved hostname is `web01.example.com`
- **THEN** the run is named with `web01`

#### Scenario: Name without a domain is unchanged
- **WHEN** the resolved hostname is `lobos`
- **THEN** the run is named with `lobos`

### Requirement: Reject a hostname that cannot name a file

The hostname becomes a path component and part of an archive's filename, so the
audit SHALL reject a candidate that cannot serve as one and move to the next
source.

#### Scenario: Empty value falls through
- **WHEN** a source returns an empty value or only a newline
- **THEN** that source is treated as having produced nothing and the next
  source is consulted

#### Scenario: Whitespace or control characters fall through
- **WHEN** a source returns a value containing whitespace or control characters
- **THEN** that source is treated as having produced nothing

#### Scenario: Path separator falls through
- **WHEN** a source returns a value containing `/`
- **THEN** that source is treated as having produced nothing

#### Scenario: A usable later source still wins
- **WHEN** `/etc/hostname` is empty but `uname -n` reports a usable name
- **THEN** the run is named with the name from `uname -n`

#### Scenario: localhost is accepted
- **WHEN** the machine is genuinely named `localhost`
- **THEN** that name is used rather than a substitute

### Requirement: Stop when no hostname can be determined

The audit SHALL stop with an error when no source yields a usable hostname,
rather than producing output whose name has an empty hostname in it.

#### Scenario: Run aborts instead of naming output with an empty hostname
- **WHEN** no source yields a usable hostname
- **THEN** the audit exits non-zero before creating an output directory
- **AND** no directory named `output--<user>-<date>` and no archive named
  `honeybadger--<user>-<date>.tar.gz` is created

#### Scenario: Error names what was tried
- **WHEN** the audit stops because no hostname could be determined
- **THEN** the message states that the hostname could not be determined and
  names `uname -n`, `$HOSTNAME` and `/etc/hostname`

### Requirement: A failing command SHALL NOT be masked by its declaration

`RUNME.sh` SHALL NOT combine a variable declaration with a command
substitution, because `local`, `declare`, `export` and `readonly` return their
own exit status and discard the command's.

#### Scenario: Declaration and assignment are separate statements
- **WHEN** `RUNME.sh` assigns the result of a command substitution to a local
  variable
- **THEN** the variable is declared in one statement and assigned in the next,
  so the command's exit status is the assignment's

#### Scenario: Suite fails on a reintroduced occurrence
- **WHEN** a `local <name>=$(<command>)` is added to `RUNME.sh`
- **THEN** the test suite fails and reports the offending line number

#### Scenario: Archive listing failure is observable
- **WHEN** `tar` fails to list an archive while unpacking a submitted report
- **THEN** the failure is detected rather than continuing with an empty target
  directory name
