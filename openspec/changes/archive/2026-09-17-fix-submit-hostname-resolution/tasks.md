## 1. Submission resolves the hostname without a package

- [x] 1.1 Replace `hostname=$(hostname -s)` in `submit_tar_file()` with
      `hb_resolve_short_hostname()`, declared and assigned separately
- [x] 1.2 Return 1 with a message naming `uname -n`, `$HOSTNAME` and
      `/etc/hostname` when no source yields a usable name
- [x] 1.3 Confirm `hostname(1)` is called nowhere else in `RUNME.sh` or `lib/`

## 2. Widen the guard

- [x] 2.1 Scan `RUNME.sh`, `lib/_library` and `lib/*.sh` instead of `RUNME.sh`
      alone
- [x] 2.2 Match a bare `$(hostname)` and `` `hostname` `` as well as the `-s`
      and `-f` forms
- [x] 2.3 Strip full-line comments before matching, so the prose describing
      what `hostname -s` used to do is not reported
- [x] 2.4 Name the offending file and line in the failure message
- [x] 2.5 Leave the `local x=$(cmd)` guard scoped to `RUNME.sh`

## 3. Tests

- [x] 3.1 Stop linking `hostname` into the submission suite's stub PATH
- [x] 3.2 Assert `X-Hostname` carries the resolved name, not merely that the
      header is present
- [x] 3.3 Submission succeeds with a `hostname(1)` that fails loudly, and never
      invokes it
- [x] 3.4 Submission fails and sends nothing when no source yields a hostname
- [x] 3.5 Run the full suite

## 4. Close out

- [x] 4.1 `openspec validate fix-submit-hostname-resolution --strict`
- [x] 4.2 CHANGELOG entry under `## NEXT VERSION`
- [x] 4.3 Archive the change and commit
