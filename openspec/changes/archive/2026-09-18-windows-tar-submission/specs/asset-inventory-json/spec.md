## ADDED Requirements

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
