## Why

`sudo ./RUNME.sh submit` fails for the system information report:

```
Submitting neofetch report (attempt 1/3)...
✗ Failed to submit neofetch: HTTP 400 (client error, not retrying)
```

`submit_all_reports()` in `lib/_library` reads `fastfetch.json` but sends
`X-Report-Type: neofetch`, and the comment above it asserts that the badgersbay
whitelist accepts nothing else. That was true when the client moved from
neofetch to fastfetch; badgersbay has since shipped `use-fastfetch-system-info`
and now answers:

```
Invalid report type 'neofetch'. Supported types: lynis, fastfetch, trivy, vulnix.
```

`submit-tar` is unaffected because the server derives the report type from the
member's file name and the archive has carried `fastfetch.json` all along. The
two submission paths have drifted: one names the report after the tool that
produced it, the other after a tool the client retired.

Three further defects in the same code path made the failure harder to read
than it needed to be, and are fixed here because they are what turns a wrong
report type into a silent or misleading result:

- A missing system information file is reported as a skip and counted as a
  success, so an output directory with no `fastfetch.json` submits nothing and
  still exits 0.
- The response body is discarded (`--output /dev/null`), so the operator sees
  `HTTP 400` and never the sentence naming the problem.
- Only HTTP 200 counts as success. badgersbay answers 207 for a submission it
  stored but could not match to an asset register entry, which the tar path
  then retries three times and reports as a failure.

## What Changes

- The system information report is submitted as type `fastfetch`, read from
  `fastfetch.json`
- A missing system information file fails the submission instead of counting as
  a success
- Failed submissions print the server's response body alongside the status code
- Both submission paths treat any 2xx as success and name a 207 as a partial
  submission

## Capabilities

### Added Capabilities
- `report-submission`: submitting audit reports to the collection server, for
  both the per-report and the tar archive path

## Impact

- `lib/_library`: `submit_report()`, `submit_tar_file()`, `submit_all_reports()`
- Clients running against a badgersbay older than `use-fastfetch-system-info`
  would now be rejected for the system information report. No such server is
  deployed.
