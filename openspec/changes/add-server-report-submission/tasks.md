# Implementation Tasks

## 1. Add Configuration File Support
- [ ] 1.1 Create `.honeybadger.conf` configuration file format (simple key=value or JSON)
- [ ] 1.2 Add `load_config()` function in lib/_library to read configuration
- [ ] 1.3 Support configuration options:
  - [ ] `server_url` (default: http://localhost:7123/)
  - [ ] `server_enabled` (default: false)
  - [ ] `server_timeout` (default: 30 seconds)
  - [ ] `server_retry_count` (default: 3)
  - [ ] `dry_run` (default: false)
- [ ] 1.4 Look for config in: `./.honeybadger.conf`, `~/.honeybadger.conf`, `/etc/honeybadger.conf` (in order)
- [ ] 1.5 Add config file example/template in repository

## 2. Add Report Submission Function (lib/_library)
- [ ] 2.1 Create `submit_report()` function with parameters: report_file, report_type, server_url
- [ ] 2.2 Auto-detect hostname using `hostname -s` or similar
- [ ] 2.3 Auto-detect username using `${SUDO_USER:-$(whoami)}`
- [ ] 2.4 Build HTTP headers: X-Hostname, X-Username, X-Report-Type, Content-Type
- [ ] 2.5 Use curl to POST JSON file to server with proper headers
- [ ] 2.6 Parse HTTP response code (200=success, 400/500=error)
- [ ] 2.7 Log success/failure with clear messages

## 3. Add Retry Logic and Error Handling
- [ ] 3.1 Implement retry mechanism with exponential backoff
- [ ] 3.2 Retry on network failures (connection refused, timeout)
- [ ] 3.3 Do NOT retry on 400 Bad Request (client error)
- [ ] 3.4 Log each retry attempt with attempt number
- [ ] 3.5 Return failure after max retries exceeded
- [ ] 3.6 Ensure audit completion is not blocked by submission failures

## 4. Add Dry-Run Mode
- [ ] 4.1 Check `dry_run` config option
- [ ] 4.2 If dry-run, log what would be submitted without actual HTTP request
- [ ] 4.3 Display curl command that would be executed
- [ ] 4.4 Return success in dry-run mode

## 5. Add Standalone Submit Command (RUNME.sh)
- [ ] 5.1 Create `submit()` function in RUNME.sh as new command
- [ ] 5.2 Accept optional output directory parameter (default: latest output-* directory)
- [ ] 5.3 If no directory specified, auto-detect most recent output-* directory
- [ ] 5.4 Load configuration from config file
- [ ] 5.5 Validate output directory exists and contains report files
- [ ] 5.6 Submit all available reports from directory (neofetch, lynis, vulnix/trivy)
- [ ] 5.7 Log submission summary (X succeeded, Y failed)
- [ ] 5.8 Exit with code 0 if at least one report submitted successfully
- [ ] 5.9 Exit with code 1 if all submissions failed or directory invalid
- [ ] 5.10 Support usage: `./RUNME.sh submit [output-directory]`
- [ ] 5.11 Add help text for submit command
- [ ] 5.12 **IMPORTANT**: Do NOT integrate submission into audit command - they are separate

## 7. Add Helper Functions
- [ ] 7.1 Create `check_server_reachable()` function (optional pre-flight check)
- [ ] 7.2 Create `validate_report_json()` function to verify JSON before submission
- [ ] 7.3 Add `get_server_config()` helper to extract server settings
- [ ] 7.4 Add logging helper `log_submission()` for consistent log format
- [ ] 7.5 Add `find_latest_output_dir()` to auto-detect most recent output directory

## 8. Documentation Updates
- [ ] 8.1 Create `.honeybadger.conf.example` with all configuration options
- [ ] 8.2 Update README.md with server submission documentation
- [ ] 8.3 Document `./RUNME.sh submit` command usage
- [ ] 8.4 Document required server API specification
- [ ] 8.5 Update openspec/project.md with new submit command
- [ ] 8.6 Add configuration examples for common scenarios
- [ ] 8.7 Document dry-run mode usage
- [ ] 8.8 Document retry behavior and timeouts

## 9. Testing and Validation
- [ ] 9.1 Test submission with server_enabled=false (no submission during audit)
- [ ] 9.2 Test submission with valid server (all reports submitted)
- [ ] 9.3 Test submission with unreachable server (retries and fails gracefully)
- [ ] 9.4 Test dry-run mode (logs but doesn't submit)
- [ ] 9.5 Test retry logic with temporary network failures
- [ ] 9.6 Test with missing reports (only submit existing files)
- [ ] 9.7 Verify HTTP headers are sent correctly
- [ ] 9.8 Verify server receives correct report_type for each file
- [ ] 9.9 Test configuration file precedence (./  ~/.  /etc/)
- [ ] 9.10 Verify audit still completes when server is down
- [ ] 9.11 Test standalone `./RUNME.sh submit` command
- [ ] 9.12 Test `./RUNME.sh submit output-hostname-user-date` with specific directory
- [ ] 9.13 Test submit command with non-existent directory (should fail gracefully)
- [ ] 9.14 Test submit command without any reports in directory

## 10. Security and Privacy Considerations
- [ ] 9.1 Ensure HTTPS support for production use (curl --insecure flag for self-signed)
- [ ] 9.2 Document data being transmitted (full JSON reports)
- [ ] 9.3 Add option to exclude sensitive data from reports (future enhancement note)
- [ ] 9.4 Ensure no credentials are logged in plain text
