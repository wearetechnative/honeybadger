## 1. Hostname resolver in the library

- [x] 1.1 Add `hb_resolve_short_hostname()` to `lib/_library`, printing the
      short hostname on stdout and returning non-zero when none can be found
- [x] 1.2 Try `uname -n`, then `$HOSTNAME`, then `/etc/hostname`, each only
      when the previous produced nothing usable
- [x] 1.3 Shorten with `${candidate%%.*}` rather than `hostname -s`
- [x] 1.4 Reject empty, whitespace, control-character and `/`-bearing
      candidates via `hb_usable_hostname()` and fall through to the next source
- [x] 1.5 Read the file path from `HB_HOSTNAME_FILE` so the suite can override
      it, defaulting to `/etc/hostname`
- [x] 1.6 Declare and assign in separate statements throughout

## 2. RUNME.sh

- [x] 2.1 Replace `local hostname=$(hostname -s)` with a declaration and a
      tested call to `hb_resolve_short_hostname()`
- [x] 2.2 Exit non-zero with an error naming the three sources when it fails,
      before `mkdir -p $output`
- [x] 2.3 Split `local target_dir=$(tar ...)` in `unpack_tarball` and report a
      failing listing
- [x] 2.4 Confirm no other `local x=$(cmd)` remains in `RUNME.sh`

## 3. Audit the pattern elsewhere

- [x] 3.1 Read every `local x=$(cmd)` in `lib/*.sh` and `lib/_library`
- [x] 3.2 Record in `design.md` why they are left alone and why the guard is
      scoped to `RUNME.sh`

## 4. Tests

- [x] 4.1 Add `tests/test_hostname_resolution.sh`
- [x] 4.2 Cover each source winning in turn, with `uname` stubbed via `PATH`
- [x] 4.3 Cover shortening of a fully qualified name and a bare name
- [x] 4.4 Cover rejection of empty, whitespace, control-character and
      `/`-bearing values, including falling through to a later usable source
- [x] 4.5 Cover `localhost` being accepted
- [x] 4.6 Cover the failure path returning non-zero with no output
- [x] 4.7 Add the guard test asserting `RUNME.sh` has no `local x=$(cmd)`
- [x] 4.8 Assert `RUNME.sh` no longer invokes `hostname -s`

## 5. Documentation

- [x] 5.1 Note in `README.md` that no hostname tool is required
- [x] 5.2 Add a `## NEXT VERSION` CHANGELOG entry

## 6. Verification

- [x] 6.1 `./tests/run-tests.sh` passes in full
- [x] 6.2 `shellcheck` on `RUNME.sh` and `lib/_library` reports nothing new
- [x] 6.3 `bash -n` on both files
- [x] 6.4 Demonstrate the Arch case: resolver succeeds with `hostname(1)`
      absent from `PATH`
