## 1. Report type

- [x] 1.1 `submit_all_reports()` submits the system information report as
      `fastfetch`, read from `fastfetch.json`
- [x] 1.2 Remove the stale comment claiming the server only accepts `neofetch`

## 2. Result handling

- [x] 2.1 A missing system information file counts as a failure and names the
      expected file
- [x] 2.2 `submit` exits non-zero when any report failed, not only when all of
      them did
- [x] 2.3 `submit_report()` and `submit_tar_file()` print the server's response
      body when a submission fails
- [x] 2.4 Both paths accept any 2xx, and name a 207 as a partial submission

## 3. Tests

- [x] 3.1 Add `tests/test_report_submission.sh` covering the report types both
      paths send, missing-file handling, and status code handling
- [x] 3.2 `./tests/run-tests.sh` passes

## 4. Verify

- [x] 4.1 `submit` and `submit-tar` both succeed against a local badgersbay
      instance, and the server stores `fastfetch-report.json` for both
