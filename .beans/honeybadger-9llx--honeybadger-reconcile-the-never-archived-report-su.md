---
# honeybadger-9llx
title: 'honeybadger: reconcile the never-archived report-submission delta'
status: completed
type: task
priority: normal
created_at: 2026-09-15T21:51:25Z
updated_at: 2026-09-16T13:17:07Z
---

`openspec/changes/add-server-report-submission` has been sitting unarchived
since the submission feature shipped. Its delta still describes behaviour that
is no longer true:

- `X-Report-Type` for system information is `neofetch`; badgersbay rejects that
  type and the client now sends `fastfetch`
- A missing report file is "not an error"; it is now counted as a failure
- `submit` exits 0 "if at least one report submitted successfully"; it now
  exits non-zero when any report failed

The corrected requirements live in the `report-submission` capability added by
`fix-submit-report-type-fastfetch`. Archiving the older change as-is would
restate the bug in the specs. Reconcile the two before archiving it, or drop
the requirements that the newer capability already covers.

The same applies to `add-tar-submission`, which is also still open.

## Summary of Changes

Three never-archived changes reconciled and archived, each in its own commit.
The bean named two; a third had the same defect and was included.

### What "reconcile" meant in practice

Every requirement in all three was checked against the client and against the
current specifications, one at a time, rather than archived wholesale or dropped
wholesale. The outcome differed per change, and each change's own proposal now
carries the per-requirement mapping so the archive says what happened to each.

### kernel-status-analysis

Entirely true except one name: `check_os_status()` became
`generate_os_status_report()` in `os-status-severity-not-an-exit-code`.
Restated under the new name and archived; everything else verified against the
code, including that `analyze_kernel_status()` really does return `fail` - it is
emitted directly in the EOL branch rather than through the `result` variable.

### add-tar-submission

Its two proposed capabilities had been absorbed into `report-submission` by
`replace-submit-with-tar`, and `submit-tar` had become a deprecated alias.
Archiving it as written would have created two duplicate capabilities described
against the wrong command.

Seven requirements were already covered. Three were not stated anywhere and are
still true, so they were kept and recorded against `report-submission`: the
binary transport and content type, the `X-Hostname` / `X-Username` headers, and
`SERVER_ENABLED` / `DRY_RUN`.

One was dropped as never implemented - "display usage on invalid arguments".
Verified rather than assumed: `submit --help` answers "File not found: --help",
and two archive arguments are accepted with the last one winning.

### add-server-report-submission

The one the bean was named after. It describes per-report submission, which
`replace-submit-with-tar` removed outright, and carries two statements that are
now the opposite of the truth (exit 0 "if at least one report submitted
successfully"; a missing report file is "not an error"). Its report types name
`neofetch`, which the server rejects, and `vulnix` and `trivy`, removed in March.

One requirement turned out **not** to be superseded, which is why checking each
one mattered: `server-configuration` defines precedence but never says where the
configuration file is looked for, which settings exist, or what the defaults are
- it refers to "the search order" without defining it. That is rescued and
recorded there, restated against today's settings, and verified against a real
run.

Its task list stays at 0 of 65: it was never completed as written, and that is
the truth of what happened to it. Group 10's items were renumbered from `9.x`,
which duplicated group 9 and would have carried into the archive.

### Result

`openspec validate --all --strict` goes from 3 failures to 2, and
`openspec list` drops from 10 open changes to 7.

### Found while reading, not fixed here

`lib/_library:1819` still resolves the hostname with `hostname -s` in
`submit_tar_file()` - the defect fixed in honeybadger-y9ul, in a second place
the guard test did not cover because it was scoped to `RUNME.sh`. On Arch that
aborts `submit` under `set -e`; elsewhere it can submit an empty `X-Hostname`.
Filed as honeybadger-brlj, high.

### Not done

Four other complete-but-unarchived changes remain: `modernize-docker-converter`,
`add-nixos-supply-chain-check`, `make-cve-scanners-required`,
`move-scripts-to-lib-folder`, `add-tar-support-check-output`. They were not in
this bean's scope and were not examined for staleness.
