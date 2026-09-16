## Why

The audit has two ways to submit, and only one of them produces evidence that
can be attributed to an asset.

`submit` sends one report at a time to `POST /`. That endpoint has no concept of
a hardware serial, so its submissions land in
`<period>/<hostname>-<username>/` with no serial, no asset matching and no
evidence archive. The collection server cannot tell which asset in the ISO
register they belong to.

`submit-tar` sends the whole archive to `POST /submit-tar`. The server reads
`hardware-serial.txt` from it, resolves the asset, stores each extracted report
next to the archive under `submissions/<serial>/<timestamp>/`, and keeps the
archive itself as the evidence of record.

Keeping both invites submitting the one that does not count. The names make it
worse: `submit` reads as the ordinary choice and `submit-tar` as a variant,
which is the wrong way round.

## What Changes

- `submit` submits the tar archive. It is the only submission path.
- `submit_all_reports()` and the per-report submission are removed.
- `submit-tar` remains as a deprecated alias: it warns and then does what
  `submit` does.

## Capabilities

### Modified Capabilities
- `report-submission`: one submission path, carrying the serial

## Impact

- **`submit` changes what it does.** It submitted individual reports; it now
  submits the archive. Anyone calling it gets attributable evidence instead of
  orphaned reports, which is the point, but it is a behaviour change rather
  than a fix.
- **`submit-tar` keeps working.** Scheduled jobs on colleagues' machines do not
  fail, they warn. A clean break would fail in the way hardest to notice: a
  cron job printing an error nobody reads.
- No change to what the audit collects or writes.

## Non-goals

- Removing `POST /` from badgersbay. The endpoint stays; this change only stops
  this client from using it. Whether the server should keep accepting
  single reports at all is a separate decision.
