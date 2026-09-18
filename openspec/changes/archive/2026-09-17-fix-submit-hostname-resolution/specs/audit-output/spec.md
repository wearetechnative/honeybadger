## MODIFIED Requirements

### Requirement: Resolve the hostname without requiring a package

The audit SHALL determine the machine's hostname from sources present on every
supported platform, so that naming the run's output does not depend on which
packages a host happens to carry. No shell source the audit ships SHALL invoke
`hostname(1)`.

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

#### Scenario: Suite fails on a reintroduced call
- **WHEN** a call to `hostname(1)` is added to `RUNME.sh` or to any shell
  source under `lib/`
- **THEN** the test suite fails and names the offending file and line

#### Scenario: A call without flags is caught too
- **WHEN** the reintroduced call is `$(hostname)` rather than `hostname -s`
- **THEN** the test suite fails on it as well

#### Scenario: Prose about the retired tool is not an offence
- **WHEN** a comment names `hostname -s` to record what the resolver replaced
- **THEN** the test suite does not report it
