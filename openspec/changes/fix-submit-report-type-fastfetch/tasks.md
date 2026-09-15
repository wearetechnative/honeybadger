## 1. Report type

- [ ] 1.1 `submit_all_reports()` submits the system information report as
      `fastfetch`, read from `fastfetch.json`
- [ ] 1.2 Remove the stale comment claiming the server only accepts `neofetch`

## 2. Result handling

- [ ] 2.1 A missing system information file counts as a failure and names the
      expected file
- [ ] 2.2 `submit_report()` and `submit_tar_file()` print the server's response
      body when a submission fails
- [ ] 2.3 Both paths accept any 2xx, and name a 207 as a partial submission

## 3. Tests

- [ ] 3.1 Add `tests/test_report_submission.sh` covering the report types both
      paths send, missing-file handling, and status code handling
- [ ] 3.2 `./tests/run-tests.sh` passes

## 4. Verify

- [ ] 4.1 `submit` and `submit-tar` both succeed against a local badgersbay
      instance, and the server stores `fastfetch-report.json` for both
