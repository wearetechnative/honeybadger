## 1. Replace the submission path

- [x] 1.1 `submit` submits the tar archive, taking an optional tar file argument
- [x] 1.2 Remove `submit_all_reports()` from `lib/_library`
- [x] 1.3 Remove the per-report constants that only that function used, keeping
      the ones the tar path relies on
- [x] 1.4 `submit-tar` warns that it is deprecated and calls `submit`
- [x] 1.5 Usage and error messages name `submit`, not `submit-tar`

## 2. Tests

- [x] 2.1 Drop the assertions covering the removed per-report path
- [x] 2.2 Assert `submit` submits the archive and reaches `/submit-tar`
- [x] 2.3 Assert `submit-tar` still works and warns
- [x] 2.4 Keep the 2xx, 207 and failure classification coverage
- [x] 2.5 Full suite passes

## 3. Verify

- [x] 3.1 `submit` against a local badgersbay: archive stored under the serial,
      reports extracted beside it, asset resolved
- [x] 3.2 `submit-tar` produces the same result plus a deprecation warning
- [x] 3.3 Dry-run mode still works on both

## 4. Docs

- [x] 4.1 `README.md`: one submission path, with a note on the alias
- [x] 4.2 `CHANGELOG.md` under NEXT VERSION, flagged as a behaviour change
