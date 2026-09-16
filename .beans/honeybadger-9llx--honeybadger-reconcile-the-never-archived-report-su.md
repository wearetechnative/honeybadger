---
# honeybadger-9llx
title: 'honeybadger: reconcile the never-archived report-submission delta'
status: todo
type: task
priority: normal
created_at: 2026-09-15T21:51:25Z
updated_at: 2026-09-15T21:51:25Z
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
