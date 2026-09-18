## ADDED Requirements

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
