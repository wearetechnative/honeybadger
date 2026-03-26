## ADDED Requirements

### Requirement: Submit tar archive via HTTP POST
The system SHALL upload tar archives to the honeybadger-server `/submit-tar` endpoint using HTTP POST with binary data transfer using curl's --data-binary flag.

#### Scenario: Successful tar.gz submission
- **WHEN** user runs `./RUNME.sh submit-tar honeybadger-hostname-user-20-03-2026.tar.gz`
- **THEN** system sends HTTP POST to `$SERVER_URL/submit-tar` with Content-Type: application/x-tar
- **THEN** system includes X-Hostname and X-Username headers
- **THEN** system uploads the .tar.gz file as binary data using --data-binary
- **THEN** system reports success

#### Scenario: Submit uncompressed tar file
- **WHEN** user runs `./RUNME.sh submit-tar honeybadger-hostname-user-20-03-2026.tar`
- **THEN** system uploads the .tar file as binary data using --data-binary
- **THEN** system sends HTTP POST to `$SERVER_URL/submit-tar`

#### Scenario: Server returns success (HTTP 200)
- **WHEN** server responds with HTTP 200
- **THEN** system logs success message
- **THEN** system exits with code 0

#### Scenario: Server returns error (HTTP 400/500)
- **WHEN** server responds with HTTP 400 or 500
- **THEN** system retries according to retry logic (same as JSON submission)
- **THEN** system logs error with HTTP status code
- **THEN** system exits with non-zero code after max retries

### Requirement: Include system identification headers
The system SHALL include X-Hostname and X-Username headers in the HTTP request to identify the source system.

#### Scenario: Headers included in request
- **WHEN** submitting tar file
- **THEN** request includes `X-Hostname: $(hostname)` header
- **THEN** request includes `X-Username: $(whoami)` header
- **THEN** request includes `Content-Type: application/x-tar` header

### Requirement: Respect server configuration
The system SHALL honor all existing server configuration options from `.honeybadger.conf`.

#### Scenario: Server submission disabled
- **WHEN** SERVER_ENABLED=false in configuration
- **THEN** system logs "Server submission is disabled"
- **THEN** system exits without uploading

#### Scenario: Dry-run mode enabled
- **WHEN** DRY_RUN=true in configuration
- **THEN** system logs the curl command that would be executed
- **THEN** system does NOT make actual HTTP request
- **THEN** system shows what headers and data would be sent

#### Scenario: Custom server URL
- **WHEN** SERVER_URL is configured
- **THEN** system uploads to `$SERVER_URL/submit-tar` (appends /submit-tar to base URL)

#### Scenario: Retry on network failure
- **WHEN** network request fails or times out
- **THEN** system retries up to SERVER_RETRY_COUNT times
- **THEN** system uses exponential backoff (1s, 2s, 4s)
- **THEN** system respects SERVER_TIMEOUT for each attempt

### Requirement: Validate tar file exists
The system SHALL validate that the specified tar file exists before attempting upload.

#### Scenario: Tar file does not exist
- **WHEN** user specifies non-existent file `./RUNME.sh submit-tar missing.tar.gz`
- **THEN** system logs error "File not found: missing.tar.gz"
- **THEN** system lists available tar files in current directory
- **THEN** system exits with non-zero code

#### Scenario: Tar file exists
- **WHEN** user specifies existing file
- **THEN** system proceeds with upload
