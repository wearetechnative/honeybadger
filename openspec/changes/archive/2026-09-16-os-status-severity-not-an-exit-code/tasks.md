## 1. One name, one meaning

- [x] 1.1 Rename `check_os_status()` to `generate_os_status_report()` in
      `lib/_library`
- [x] 1.2 State its contract above it: returns whether the report was produced,
      never a severity, and say where the severity does live
- [x] 1.3 State the script's contract at the top of `lib/check-os-status.sh`:
      its exit code is a severity, and it is deliberately not the same thing

## 2. Stop implying a forwarded status

- [x] 2.1 `RUNME.sh check_output`: drop `local exit_code=0`,
      `|| exit_code=$?` and `exit $exit_code`
- [x] 2.2 Warn on a genuine failure, as the audit path already does, so both
      call sites read identically
- [x] 2.3 Exit 0, with a comment saying severity is deliberately not propagated
- [x] 2.4 Confirm the paths that must still fail - missing directory, missing
      `fastfetch.json` - are untouched

## 3. References

- [x] 3.1 Update the two call sites in `RUNME.sh`
- [x] 3.2 Update `tests/test_fastfetch_only.sh`
- [x] 3.3 Update `openspec/project.md`
- [x] 3.4 Leave archived changes and the CHANGELOG alone: they record what the
      code was called at the time

## 4. Tests

- [x] 4.1 The report generator returns 0 when it produced a report
- [x] 4.2 It returns non-zero for a missing directory and for a directory with
      no `fastfetch.json`, and writes nothing into the latter
- [x] 4.3 A warning-level OS status does not make it return non-zero
- [x] 4.4 Guard: the old function name is not reintroduced in the live code
- [x] 4.5 Guard: `check_output` does not forward a status from the generator

## 5. Verify

- [x] 5.1 `./tests/run-tests.sh` passes in full
- [x] 5.2 `shellcheck` and `bash -n` on the changed files
- [x] 5.3 `check-output` on a directory with a warning-level status exits 0
- [x] 5.4 `check-output` on a directory with no `fastfetch.json` still exits 1
- [x] 5.5 `lib/check-os-status.sh` still exits its severity
