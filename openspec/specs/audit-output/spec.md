# audit-output Specification

## Purpose
Generated audit artifacts (tarballs, output directories) must be owned by the actual user who invoked the audit, not root, to ensure users can access and manage their own audit results without requiring sudo privileges.

## Requirements

### Requirement: Output Files MUST Be Owned By Actual User

When running audit with sudo, all generated files SHALL be owned by the actual user, not root.

#### Scenario: Tarball owned by actual user after audit

**Given** a user runs `sudo ./RUNME.sh audit`
**When** the audit completes and creates a tarball
**Then** the tarball file must be owned by the actual user (from SUDO_USER), not root
**And** the user can read, modify, and delete the tarball without sudo

#### Scenario: Output directory owned by actual user after audit

**Given** a user runs `sudo ./RUNME.sh audit`
**When** the audit completes and creates an output directory
**Then** the output directory must be owned by the actual user (from SUDO_USER), not root
**And** all files within the output directory should be accessible by the user
**And** the user can delete the output directory without sudo

#### Scenario: Files created by user without sudo remain user-owned

**Given** a user runs `./RUNME.sh audit` without sudo (if permitted)
**When** the audit completes
**Then** all generated files are already owned by the user
**And** no ownership changes are necessary

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

### Requirement: Collect firewall evidence during the audit
The audit SHALL record the device's packet filter ruleset in `firewall-info.txt`, so that the
firewall verdict can be formed and re-examined from the archive alone.

#### Scenario: iptables ruleset present
- **WHEN** the audit runs on a device with an iptables ruleset, including the NixOS `nixos-fw` chain
- **THEN** `firewall-info.txt` contains the `iptables -S` output
- **AND** a closing result line states that an active ruleset was found, and by which tool

#### Scenario: nftables ruleset present
- **WHEN** the audit runs on a device with an nftables ruleset
- **THEN** `firewall-info.txt` contains the `nft list ruleset` output
- **AND** the result line states that an active ruleset was found with nftables

#### Scenario: No ruleset
- **WHEN** neither tool reports an active ruleset
- **THEN** the result line states that no active ruleset was found
- **AND** it states which tools were present and queried

### Requirement: Read per-user desktop settings as the invoking user
The audit runs as root, but desktop lock settings belong to the user who ran it. The audit SHALL
read those settings as that user, with that user's home directory, and SHALL record in the evidence
file whose settings were read.

#### Scenario: GNOME settings under sudo
- **WHEN** the audit runs under `sudo` on a GNOME desktop
- **THEN** the GNOME lock settings in `screenlock-info.txt` are the invoking user's settings
- **AND** `screenlock-info.txt` names the user whose settings were read

#### Scenario: Audit run as root without sudo
- **WHEN** the audit runs as root and no invoking user is known
- **THEN** the settings are read as root
- **AND** `screenlock-info.txt` states that they were read as root
