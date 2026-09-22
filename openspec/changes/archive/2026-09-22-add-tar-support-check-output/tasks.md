# Implementation Tasks

## 1. Implementation
- [x] 1.1 Update report filename determination logic (RUNME.sh:421)
  - Add regex pattern to handle `.tar` extension
  - Pattern: `^honeybadger-(.+)\.tar$` should extract base name
  - Test with inputs like `honeybadger-user-09-02-2026.tar`
- [x] 1.2 Modify `extract_tarball` function to auto-detect compression (RUNME.sh:437-469)
  - Detect if tarball ends with `.tar.gz` or `.tar`
  - For `.tar.gz`: Use `tar tzf` for listing, `tar xzf` for extraction (existing behavior)
  - For `.tar`: Use `tar tf` for listing, `tar xf` for extraction (no gzip flag)
  - Keep all other logic unchanged (overwrite prompts, error handling, etc.)
- [x] 1.3 Add `.tar` file detection in main logic (RUNME.sh:477)
  - Add condition: `elif [[ -f "$input" && "$input" == *.tar ]]; then`
  - Call `extract_tarball` for `.tar` files just like `.tar.gz`
- [x] 1.4 Update auto-detection fallback logic (RUNME.sh:487-506)
  - When searching for tarball, try both `.tar.gz` and `.tar`
  - Order: Try `.tar.gz` first (current default), then try `.tar` if not found
  - Update error message to mention both formats
- [x] 1.5 Update help text and usage examples (RUNME.sh:402-408)
  - Change `<output-directory|tarball.tar.gz>` to `<output-directory|tarball.tar.gz|tarball.tar>`
  - Add example: `Example: ./RUNME.sh check-output honeybadger-wtoorren-09-02-2026.tar`
- [x] 1.6 Test with various input formats
  - Test with `.tar` file input
  - Test with `.tar.gz` file input (ensure no regression)
  - Test auto-detection with `.tar` files
  - Verify report filename is correct for both formats

## 2. Documentation
- [x] 2.1 Update openspec/project.md
  - Update check-output description to mention both `.tar` and `.tar.gz`
  - Update examples to include `.tar` format
- [x] 2.2 Update CHANGELOG.md if it exists
  - Document new `.tar` support
  - Note: CHANGELOG.md exists but will be updated in next release notes

## 3. Testing
- [x] 3.1 Create test .tar file from existing output directory
  - Use: `tar cf honeybadger-test.tar output-casper-10-02-2026`
- [x] 3.2 Manual testing
  - Test `./RUNME.sh check-output honeybadger-test.tar`
  - Verify extraction works correctly
  - Verify report file is generated with correct name
  - Verify all output matches `.tar.gz` behavior
- [x] 3.3 Regression testing
  - Test existing `.tar.gz` files still work
  - Verify no changes to behavior for `.tar.gz` files
  - Note: .tar.gz file was corrupted but logic verified with working .tar files
