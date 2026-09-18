---
# honeybadger-l134
title: 'Windows: submit the archive to SERVER_URL/submit-tar'
status: completed
type: task
priority: high
created_at: 2026-09-18T08:40:28Z
updated_at: 2026-09-18T09:01:00Z
parent: honeybadger-k80g
---

submit-report.ps1 posts a zip to SERVER_URL itself as application/zip, an endpoint with no concept of a hardware serial, and it never retries. The report-submission capability defines one path: POST the archive to SERVER_URL/submit-tar as application/x-tar with a bearer token and X-Hostname / X-Username.

Bring the Windows client onto that path: the tar endpoint, binary transport, the 4xx / 207 / 5xx handling the spec describes, retry with backoff on transient failures, DRY_RUN, and environment variables overriding the config file as they do on the Linux client. It also prints "$config.SERVER_URL" - PowerShell renders that as the hashtable followed by a literal .SERVER_URL, so the operator is never shown where the report went.


## Summary of Changes

submit-report.ps1 posts the archive to SERVER_URL/submit-tar as
application/x-tar with a bearer token, X-Hostname and X-Username, and names no
report type - the server derives those from the file names inside. 4xx prints
the server body and does not retry, 207 is reported as a partial submission and
does not retry, 5xx and a request that did not complete retry with exponential
backoff. DRY_RUN rehearses; environment variables override the config file and
the client reports which settings came from there.

Two defects fixed along the way. It printed "$config.SERVER_URL", which
PowerShell renders as the hashtable type name plus a literal .SERVER_URL, so
the operator was never shown where the report went. And $TarFile is declared
[string], so assigning $null stored "" and the -eq $null check never fired:
with no archive present the operator saw "Archive not found: " with nothing
after the colon rather than being told to run the audit. Found by the
end-to-end run; a guard test pins it.
