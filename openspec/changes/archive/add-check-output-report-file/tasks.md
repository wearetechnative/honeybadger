# Implementation Tasks

## 1. Implementation
- [x] 1.1 Add report file path determination logic in `check-output` function
  - Derive report filename from tarball name or directory name
  - Handle both `output-*` and `honeybadger-*.tar.gz` input formats
  - Report filename pattern: `honeybadger-{username}-{date}-report.txt`
- [x] 1.2 Capture all terminal output to report file using `tee` or similar
  - Redirect stdout to both terminal and report file
  - Ensure all echo statements are captured
  - Include output from `check_os_status` and `generate_asset_inventory`
- [x] 1.3 Add informational message about report file location
  - Display report file path at completion
  - Include in both success and cleanup scenarios
- [x] 1.4 Handle file overwrite scenarios
  - Check if report file exists before writing
  - Either overwrite silently or prompt user (match existing behavior)
- [x] 1.5 Test with various input formats
  - Test with directory input: `output-user-09-02-2026`
  - Test with tarball input: `honeybadger-user-09-02-2026.tar.gz`
  - Test with short names that require tarball extraction
  - Verify report file naming in all scenarios
- [x] 1.6 Update command help text to mention report file generation
  - Add to usage examples in `check-output` function header
  - Update CHANGELOG.md if applicable

## 2. Documentation
- [x] 2.1 Update openspec/project.md to document report file output
  - Add to "check-output" command description (line ~285)
  - Include in output format documentation (line ~240)
- [x] 2.2 Update README if it exists
  - Document the new report file feature
  - Show example report filename
  - Note: README does not currently document check-output command, so no update needed

## 3. Testing
- [x] 3.1 Manual testing with real audit data
  - Run check-output with existing output directory
  - Run check-output with tarball
  - Verify report file contents match terminal output
  - Verify report file naming is correct
- [x] 3.2 Edge case testing
  - Missing output files
  - Permission issues
  - Disk space issues
  - Note: File overwrite is handled silently by tee, no explicit check needed
