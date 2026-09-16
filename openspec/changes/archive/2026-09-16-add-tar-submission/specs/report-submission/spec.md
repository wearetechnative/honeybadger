## ADDED Requirements

### Requirement: Archive transport

The client SHALL upload the archive as binary data, so the server receives the
bytes it was given rather than a re-encoded copy.

#### Scenario: Archive is posted as binary
- **WHEN** an archive is submitted
- **THEN** it SHALL be sent with HTTP POST to `SERVER_URL/submit-tar` as binary
  data, with `Content-Type: application/x-tar`

#### Scenario: Compressed and uncompressed archives travel the same way
- **WHEN** the archive is a `.tar.gz` or a `.tar`
- **THEN** it SHALL be uploaded as-is, without being decompressed first

### Requirement: System identification headers

The client SHALL name the machine and the user a submission comes from, so the
server can attribute it when the archive alone does not resolve an asset.

#### Scenario: Headers accompany every submission
- **WHEN** an archive is submitted
- **THEN** the request SHALL carry `X-Hostname` and `X-Username`

#### Scenario: The user is the one who ran the audit
- **WHEN** the audit was run under `sudo`
- **THEN** `X-Username` SHALL name the invoking user, not `root`

### Requirement: Submission can be disabled or rehearsed

Submission SHALL be switchable off and SHALL offer a rehearsal, so that a host
can run audits without reporting and an operator can see what would be sent
before sending it.

#### Scenario: Submission disabled
- **WHEN** `SERVER_ENABLED` is not `true`
- **THEN** `submit` SHALL report that submission is disabled and name the
  setting and where it can be set
- **AND** SHALL NOT contact the server

#### Scenario: Dry run
- **WHEN** `DRY_RUN` is `true`
- **THEN** `submit` SHALL report the archive, the endpoint and the headers it
  would send
- **AND** SHALL NOT contact the server
