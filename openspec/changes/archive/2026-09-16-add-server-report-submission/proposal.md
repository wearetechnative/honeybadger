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

## Reconciliation before archiving

This change was proposed in March, largely delivered, and then replaced before
it was ever archived. Its task list stands at 0 of 65 and is left that way on
purpose: it records that the change was never completed as written, which is the
truth of what happened to it.

The path it describes - submitting each report as its own HTTP request, with the
client naming the report type - was removed by `replace-submit-with-tar`. The
current `report-submission` specification says so outright: "there SHALL be none;
that path submitted to an endpoint with no concept of a hardware serial, so its
submissions could not be attributed to an asset."

Archiving it as written would have put that removed design back into the specs,
along with two statements that are now the opposite of the truth. Its
requirements were checked one by one:

| Requirement | Outcome |
|-------------|---------|
| Standalone Submit Command | superseded: per-report submission is gone; `submit` sends the archive |
| Configuration File Support | **partly uncovered, and kept.** `server-configuration` defines precedence but never says where the file is looked for, which settings exist, or what the defaults are. Rescued, and restated against today's settings - `SERVER_TOKEN` and `USE_DOCKER_CONVERTER` did not exist when this was written |
| HTTP Report Submission | contradicted: `X-Report-Type` named the type per request; the server now derives types from the file names inside the archive |
| Retry Logic with Exponential Backoff | already covered: "Transient server or network failure" |
| Dry-Run Mode | already covered, by the requirement rescued from `add-tar-submission` |
| Graceful Failure Handling | contradicted: it said `submit` exits 0 "if at least one report submitted successfully"; a submission that did not reach the server now exits non-zero |
| Report Type Identification | contradicted and obsolete: it names `neofetch`, which the server rejects, and `vulnix` and `trivy`, removed entirely by `remove-vulnix-trivy` |
| JSON File Existence Check | contradicted: a missing report file was "not an error"; a submission that could not be made is now a failure |

So one requirement survives, and it is recorded against `server-configuration`
rather than `report-submission`, because that is what it was always about.

The task numbering under group 10 was corrected from `9.x` to `10.x`; it
duplicated group 9 and would have carried that into the archive. See bean
honeybadger-9llx.
