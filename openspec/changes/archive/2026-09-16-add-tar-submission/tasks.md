## 1. Helper Functions

- [x] 1.1 Add `find_latest_tar()` function to lib/_library that searches for honeybadger-*.tar.gz and honeybadger-*.tar files and returns the most recent by modification time

## 2. Core Submission Function

- [x] 2.1 Add `submit_tar_file()` function to lib/_library that handles tar file upload with retry logic
- [x] 2.2 Implement tar file validation (check file exists before upload)
- [x] 2.3 Build /submit-tar endpoint URL by appending to SERVER_URL
- [x] 2.4 Implement HTTP POST with --data-binary for binary file upload
- [x] 2.5 Add Content-Type: application/x-tar header to request
- [x] 2.6 Add X-Hostname and X-Username headers to request
- [x] 2.7 Implement retry logic with exponential backoff (reuse pattern from submit_report)
- [x] 2.8 Add dry-run mode support (log curl command without executing)

## 3. RUNME.sh Command

- [x] 3.1 Add `submit-tar` command registration using make_command
- [x] 3.2 Implement submit-tar() function in RUNME.sh
- [x] 3.3 Parse optional tar file parameter ($1)
- [x] 3.4 Implement auto-discovery when no parameter (call find_latest_tar)
- [x] 3.5 Validate tar file exists and show available files on error
- [x] 3.6 Load server configuration using load_server_config
- [x] 3.7 Check SERVER_ENABLED and exit if disabled
- [x] 3.8 Call submit_tar_file() with validated tar path
- [x] 3.9 Handle exit codes and display appropriate success/error messages

## 4. Configuration Integration

- [x] 4.1 Verify existing .honeybadger.conf supports all needed options (SERVER_URL, SERVER_ENABLED, DRY_RUN, SERVER_TIMEOUT, SERVER_RETRY_COUNT)
- [x] 4.2 Test that load_server_config() works with submit-tar command
- [x] 4.3 Update .honeybadger.conf.example with comment about submit-tar endpoint

## 5. Error Handling

- [x] 5.1 Add error message for missing tar file with usage example
- [x] 5.2 Add error message for no tar files found during auto-discovery
- [x] 5.3 Add error message for upload failure with HTTP status code
- [x] 5.4 Add error message when SERVER_ENABLED=false

## 6. Testing

- [x] 6.1 Test submit-tar with explicit .tar.gz file
- [x] 6.2 Test submit-tar with explicit .tar file
- [x] 6.3 Test submit-tar with no arguments (auto-discovery)
- [x] 6.4 Test submit-tar when no tar files exist
- [x] 6.5 Test submit-tar when tar file does not exist
- [x] 6.6 Test dry-run mode (DRY_RUN=true)
- [x] 6.7 Test with SERVER_ENABLED=false
- [x] 6.8 Test retry logic with mock server errors

## 7. Documentation

- [x] 7.1 Update README.md with submit-tar command usage
- [x] 7.2 Add examples for both auto-discovery and explicit file
- [x] 7.3 Document /submit-tar endpoint requirement for honeybadger-server
- [x] 7.4 Add troubleshooting section for common issues
