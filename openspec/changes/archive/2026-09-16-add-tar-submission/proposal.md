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

## Reconciliation before archiving

This change was completed in March and never archived. By the time it was, the
capabilities it proposed - `tar-file-discovery` and `tar-file-submission` - had
been absorbed into `report-submission` by `replace-submit-with-tar`, and the
command it describes, `submit-tar`, had become a deprecated alias for `submit`.

Archiving it as written would have created two capabilities duplicating one that
already exists, described against a command name that is no longer the one to
use. Its requirements were checked one by one against the client and against the
current `report-submission` specification:

| Requirement | Outcome |
|-------------|---------|
| Auto-detect most recent tar file | already covered: "Submit sends the archive" |
| No tar files found | already covered: "No archive found" |
| Accept explicit tar file parameter | already covered: "Explicit archive" |
| Validate tar file exists | already covered: "Named archive does not exist" |
| Submit via HTTP POST to `/submit-tar` | endpoint already covered; the binary transport and content type were not, and are kept |
| Include `X-Hostname` / `X-Username` headers | not covered anywhere, still true, kept |
| Retry with exponential backoff | already covered: "Transient server or network failure" |
| Custom `SERVER_URL` | already covered by `server-configuration` |
| `SERVER_ENABLED` and `DRY_RUN` | not covered anywhere, still true, kept |
| Display usage on invalid arguments | **dropped: never implemented.** `submit --help` is read as a filename and two archive arguments are not rejected - the last one wins. Nothing was lost by dropping it, because nothing ever did it |

What survives is recorded against `report-submission`, which is where it
belongs. See bean honeybadger-9llx.
