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
  a success, and `submit` exits non-zero when any report failed
- Failed submissions print the server's response body alongside the status code
- Both submission paths treat any 2xx as success and name a 207 as a partial
  submission

## Capabilities

### Added Capabilities
- `report-submission`: submitting audit reports to the collection server, for
  both the per-report and the tar archive path

## Note on the existing report-submission delta

`openspec/changes/add-server-report-submission` has never been archived, so
`report-submission` does not exist under `openspec/specs/` and this change adds
it. That older delta still describes the behaviour this change corrects: it
names `neofetch` as the system information report type, treats a missing report
file as "not an error", and exits 0 as long as one report succeeded. Whoever
archives it must reconcile it with the requirements added here rather than
restate them. Tracked as bean `honeybadger-9llx`.

`.gitignore` is corrected in the same breath: the unanchored `report-**`
pattern matches any directory named `report-submission`, so a spec delta for
this capability could not be added without `-f` - and once archived, neither
could `openspec/specs/report-submission/`. The pattern is now anchored to the
repository root, the same fix the repository already applied to
`/honeybadger-*.md`.

## Impact

- `lib/_library`: `submit_report()`, `submit_tar_file()`, `submit_all_reports()`
- `.gitignore`: `report-**` anchored to the repository root
- Clients running against a badgersbay older than `use-fastfetch-system-info`
  would now be rejected for the system information report. No such server is
  deployed.
