# report-submission Specification

## Purpose
This specification defines how the Honeybadger client submits audit results to the collection server: what it sends, how the server learns what it received, and how the client reads the answer. There is one path. The archive carries the hardware serial, which is what lets the server attribute a submission to an asset in the ISO register, and the server derives each report type from the file names inside it.

## Requirements

### Requirement: Submission Result Reporting
The client SHALL report what the server said about a submission, so an operator can act on a rejection without reproducing it by hand.

#### Scenario: Server rejects a submission
- **WHEN** the server answers with a 4xx status
- **THEN** the client SHALL print the status code and the server's response body
- **AND** SHALL NOT retry

#### Scenario: Server stores a submission it could not fully resolve
- **WHEN** the server answers 207
- **THEN** the client SHALL treat the submission as successful
- **AND** SHALL name it a partial submission in its output
- **AND** SHALL NOT retry

#### Scenario: Transient server or network failure
- **WHEN** the server answers with a 5xx status or the request fails to complete
- **THEN** the client SHALL retry with exponential backoff up to the configured attempt count

### Requirement: Submit audit results to the collection server

The client SHALL submit audit results as the tar archive, so that the hardware
serial travels with them and the server can attribute the submission to an asset.

#### Scenario: Submit sends the archive
- **WHEN** an operator runs `./RUNME.sh submit`
- **THEN** the most recent archive SHALL be submitted to `SERVER_URL/submit-tar`

#### Scenario: Explicit archive
- **WHEN** an operator runs `./RUNME.sh submit <file>`
- **THEN** that archive SHALL be submitted

#### Scenario: Serial travels with the submission
- **WHEN** an archive is submitted
- **THEN** it SHALL carry `hardware-serial.txt`, so the server can resolve the asset

#### Scenario: Report types come from the archive
- **WHEN** an archive is submitted
- **THEN** the client SHALL name no report types; the server derives them from
  the file names inside the archive

#### Scenario: Per-report submission is gone
- **WHEN** an operator looks for a way to submit individual reports
- **THEN** there SHALL be none; that path submitted to an endpoint with no
  concept of a hardware serial, so its submissions could not be attributed to
  an asset

### Requirement: Missing Archive Handling

The client SHALL distinguish a submission that could not be made from one that
was made, and SHALL NOT report a submission that never happened as a success.

#### Scenario: No archive found
- **WHEN** `submit` runs and no archive can be found
- **THEN** it SHALL report that none was found
- **AND** SHALL name the command that produces one

#### Scenario: Named archive does not exist
- **WHEN** `submit` is given a path that is not a file
- **THEN** it SHALL fail and name the path it was given

#### Scenario: Submission did not reach the server
- **WHEN** the archive could not be submitted
- **THEN** `submit` SHALL exit non-zero

### Requirement: Keep submit-tar working as a deprecated alias

`submit-tar` SHALL keep working and SHALL say it is deprecated, so that
scheduled jobs still calling it do not fail.

#### Scenario: Alias still submits
- **WHEN** an operator or a scheduled job runs `./RUNME.sh submit-tar`
- **THEN** the archive SHALL be submitted exactly as `submit` would

#### Scenario: Alias warns
- **WHEN** `submit-tar` runs
- **THEN** it SHALL report that the command is deprecated and name `submit`

#### Scenario: Exit code unchanged
- **WHEN** `submit-tar` runs
- **THEN** it SHALL exit with the same code `submit` would for the same archive

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

### Requirement: The Windows client submits over the same path

The Windows client SHALL submit the tar archive to `SERVER_URL/submit-tar`, so
that a Windows submission is attributed to an asset the same way every other
submission is.

#### Scenario: Windows submits the archive
- **WHEN** an operator runs `submit-report.ps1`
- **THEN** the most recent `.tar.gz` SHALL be submitted to
  `SERVER_URL/submit-tar`

#### Scenario: Explicit archive
- **WHEN** `submit-report.ps1` is given a path to an archive
- **THEN** that archive SHALL be submitted

#### Scenario: Archive transport
- **WHEN** a Windows submission is made
- **THEN** the archive SHALL be posted as binary with
  `Content-Type: application/x-tar`

#### Scenario: The zip path is gone
- **WHEN** an operator looks for a way to submit a zip from Windows
- **THEN** there SHALL be none; that endpoint has no concept of a hardware
  serial, so its submissions could not be attributed to an asset

#### Scenario: Identification headers
- **WHEN** a Windows submission is made
- **THEN** the request SHALL carry `X-Hostname`, `X-Username` and a bearer
  token

#### Scenario: An empty hostname is never sent
- **WHEN** the machine name cannot be determined
- **THEN** the submission SHALL NOT be sent, and the client SHALL exit non-zero

#### Scenario: Report types come from the archive
- **WHEN** a Windows archive is submitted
- **THEN** the client SHALL name no report types; the server derives them from
  the file names inside it

#### Scenario: The operator is told where it went
- **WHEN** `submit-report.ps1` reports the server it is submitting to
- **THEN** it SHALL print the configured URL itself

### Requirement: The Windows client reports the submission result

The Windows client SHALL apply the same result handling as the Linux client, so
an operator can act on a rejection without reproducing it by hand.

#### Scenario: Server rejects a submission
- **WHEN** the server answers with a 4xx status
- **THEN** the client SHALL print the status code and the server's response
  body
- **AND** SHALL NOT retry
- **AND** SHALL exit non-zero

#### Scenario: Server stores a submission it could not fully resolve
- **WHEN** the server answers 207
- **THEN** the client SHALL treat the submission as successful
- **AND** SHALL name it a partial submission in its output
- **AND** SHALL NOT retry

#### Scenario: Transient server or network failure
- **WHEN** the server answers with a 5xx status or the request fails to
  complete
- **THEN** the client SHALL retry with exponential backoff up to the configured
  attempt count

#### Scenario: Submission did not reach the server
- **WHEN** the archive could not be submitted
- **THEN** the client SHALL exit non-zero

### Requirement: The Windows client honours the shared configuration

The Windows client SHALL read the same settings from the same configuration
file as the other platforms, and SHALL let the environment override them.

#### Scenario: Environment overrides the file
- **WHEN** a setting is present both in the configuration file and in the
  environment
- **THEN** the environment value SHALL be used

#### Scenario: Overrides are reported
- **WHEN** a setting is taken from the environment
- **THEN** the client SHALL report which settings came from there

#### Scenario: Submission disabled
- **WHEN** `SERVER_ENABLED` is not `true`
- **THEN** the client SHALL report that submission is disabled and name the
  setting
- **AND** SHALL NOT contact the server

#### Scenario: Dry run
- **WHEN** `DRY_RUN` is `true`
- **THEN** the client SHALL report the archive, the endpoint and the headers it
  would send
- **AND** SHALL NOT contact the server

#### Scenario: No archive found
- **WHEN** no archive can be found
- **THEN** the client SHALL report that none was found and name the command
  that produces one
