# Change: Add .tar File Support to check-output Command

## Why
Currently, the `check-output` command only supports gzip-compressed tar archives (`.tar.gz` files). Users may have uncompressed tar archives (`.tar` files) and cannot process them without manually extracting first.

Supporting both `.tar` and `.tar.gz` formats provides:
1. Flexibility for users who may have either format
2. Compatibility with different archiving workflows
3. Reduced manual steps (no need to extract manually)
4. Consistency with standard tar tool behavior (which handles both formats)

## What Changes
- Extend `check-output` command to accept both `.tar` and `.tar.gz` files
- Auto-detect compression format and use appropriate tar flags:
  - `.tar.gz`: Use `tar tzf` (list) and `tar xzf` (extract) with gzip support
  - `.tar`: Use `tar tf` (list) and `tar xf` (extract) without compression
- Update file matching logic to search for both `.tar` and `.tar.gz` when auto-detecting
- Update report filename logic to handle `.tar` extensions
- Update help text and examples to mention both formats

## Impact
- Affected specs: `check-output` capability (modified spec)
- Affected code:
  - RUNME.sh:402-507 (`check-output` function)
    - Line 421: Report filename regex (add `.tar` support)
    - Line 437-469: `extract_tarball` function (detect format, use appropriate flags)
    - Line 477: File type check (add `.tar` check)
    - Lines 487-506: Auto-detection logic (try both `.tar.gz` and `.tar`)
- Backwards compatible: Existing `.tar.gz` behavior unchanged
- No breaking changes
