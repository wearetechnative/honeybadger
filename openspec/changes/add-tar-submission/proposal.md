## Why

The honeybadger audit generates comprehensive tar archives containing all reports, but currently only supports submitting individual JSON files to the server. Organizations need a simpler, more efficient way to submit complete audit packages without extracting and uploading files individually. This enables streamlined compliance workflows and reduces network overhead by submitting a single archive instead of multiple separate files.

## What Changes

- Add new `submit-tar` command to RUNME.sh that uploads complete tar archives
- Support auto-detection of most recent tar file when no file is specified
- Upload tar files directly as binary data using `--data-binary` (no decompression needed)
- Submit to `/submit-tar` endpoint (separate from existing JSON submission endpoint)
- Include system identification headers (X-Hostname, X-Username)
- Reuse existing configuration (SERVER_ENABLED, SERVER_URL, DRY_RUN, retry logic)
- Preserve backward compatibility with existing `submit` command for JSON reports

## Capabilities

### New Capabilities
- `tar-file-submission`: Upload complete tar archives to honeybadger-server via HTTP POST with binary tar data
- `tar-file-discovery`: Auto-detect and use the most recent tar archive when no file is specified

### Modified Capabilities
<!-- No existing capabilities are being modified - this is additive only -->

## Impact

- **Code**: New command in RUNME.sh, new function `submit_tar_file()` in lib/_library
- **Configuration**: Reuses existing .honeybadger.conf (SERVER_URL, SERVER_ENABLED, etc.)
- **Server API**: New endpoint `/submit-tar` (separate from existing `/` endpoint for JSON)
- **Backward Compatibility**: Existing `submit` command remains unchanged
- **Dependencies**: None (uses curl --data-binary for direct file upload)
