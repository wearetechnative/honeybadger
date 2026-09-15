---
# honeybadger-nxp0
title: 'honeybadger: submit sends the system information report as neofetch, which badgersbay rejects'
status: in-progress
type: bug
priority: high
created_at: 2026-09-15T21:42:06Z
updated_at: 2026-09-15T21:42:06Z
---

## Symptom

`sudo ./RUNME.sh submit` fails for the system information report:

```
Submitting neofetch report (attempt 1/3)...
✗ Failed to submit neofetch: HTTP 400 (client error, not retrying)
```

The lynis report in the same run succeeds, and `./RUNME.sh submit-tar` succeeds
for both reports.

## Cause

`submit_all_reports()` in `lib/_library` reads `fastfetch.json` but sends
`X-Report-Type: neofetch`. The comment above it states that the badgersbay
whitelist only accepts `neofetch`, which was true when the client moved from
neofetch to fastfetch (commit c0db247) but stopped being true when badgersbay
shipped `use-fastfetch-system-info`. The server now answers:

```
Invalid report type 'neofetch'. Supported types: lynis, fastfetch, trivy, vulnix.
```

`submit-tar` is unaffected because the server derives the report type from the
file name inside the archive, and the archive has carried `fastfetch.json` all
along.

## Scope

- Send the system information report as `fastfetch`
- Treat a missing system information file as a failure rather than a silent
  success
- Report the server's error message instead of only the status code
- Accept every 2xx, so a 207 partial submission is not retried as a failure
