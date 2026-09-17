## MODIFIED Requirements

### Requirement: System identification headers

The client SHALL name the machine and the user a submission comes from, so the
server can attribute it when the archive alone does not resolve an asset. The
machine's name SHALL be resolved from sources present on every supported
platform, so that submitting does not depend on which packages a host happens
to carry.

#### Scenario: Headers accompany every submission
- **WHEN** an archive is submitted
- **THEN** the request SHALL carry `X-Hostname` and `X-Username`

#### Scenario: The user is the one who ran the audit
- **WHEN** the audit was run under `sudo`
- **THEN** `X-Username` SHALL name the invoking user, not `root`

#### Scenario: No external hostname tool is used
- **WHEN** a submission is made on a host where `hostname(1)` is not installed
- **THEN** the submission SHALL be sent with the machine's real hostname
- **AND** SHALL NOT invoke `hostname(1)`

#### Scenario: The header carries the resolved short name
- **WHEN** the machine resolves to `web01.example.com`
- **THEN** `X-Hostname` SHALL carry `web01`

#### Scenario: Submission stops when no hostname can be determined
- **WHEN** no source yields a usable hostname
- **THEN** `submit` SHALL report that the hostname could not be determined and
  name `uname -n`, `$HOSTNAME` and `/etc/hostname`
- **AND** SHALL NOT contact the server
- **AND** SHALL exit non-zero

#### Scenario: An empty hostname is never sent
- **WHEN** a source for the hostname exists but yields nothing usable
- **THEN** the submission SHALL NOT be sent with an empty `X-Hostname`
