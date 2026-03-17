# Change: Add Server Report Submission

## Why
Currently, Honeybadger generates local audit reports stored as compressed tarballs. For centralized compliance monitoring and reporting, reports need to be submitted to a honeybadger-server that aggregates data from multiple systems. This enables:
- Centralized dashboard for all audited systems
- Historical tracking and trend analysis
- Automated compliance status monitoring across the organization
- Reduced manual report collection overhead

## What Changes
- Add HTTP POST submission of JSON reports to honeybadger-server
- Submit four report types: lynis, neofetch, and either trivy or vulnix (CVE scanning)
- **Add new `submit` command**: `./RUNME.sh submit [output-directory]`
  - Can be run independently of audit
  - Submits existing reports from specified directory
  - Useful for re-submitting reports if server was unavailable
  - Allows testing submission without running full audit
- Add configuration file support for server URL and settings
- Auto-detect hostname and username for report identification
- Include proper HTTP headers (X-Hostname, X-Username, X-Report-Type)
- Implement error handling with optional retry logic
- Add dry-run mode for testing without actual submission
- **Submission is NOT part of audit**: Users must explicitly run `./RUNME.sh submit` to send reports

## Impact
- Affected specs: `report-submission` (new capability)
- Affected code:
  - `lib/_library`: Add `submit_report()` and related functions
  - `RUNME.sh`: Add new `submit` command function (completely separate from audit)
  - New file: `.honeybadger.conf` or similar for configuration
  - **No changes to audit command**: Audit remains unchanged, only generates local reports
- New dependencies: curl (already used for API calls)
- Server API:
  - Endpoint: `http://<server>:7123/`
  - Method: POST with Content-Type: application/json
  - Headers: X-Hostname, X-Username, X-Report-Type
  - Report types: lynis, trivy, vulnix, neofetch
- Backward compatibility: Fully backward compatible (submission is opt-in via config)
- No breaking changes: Local tarball generation continues unchanged
