# Tar File Submission - Design Document

## Context

Honeybadger currently generates tar archives (`honeybadger-{hostname}-{user}-{date}.tar.gz`) containing all audit reports, and supports submitting individual JSON reports via the `submit` command. The honeybadger-server now provides a `/submit-tar` endpoint that accepts complete tar archives as binary uploads.

### Current State
- `./RUNME.sh submit` uploads individual JSON files (neofetch.json, lynis-report.json, etc.)
- Uses `submit_report()` function for each file
- Configuration in `.honeybadger.conf` (SERVER_URL, SERVER_ENABLED, etc.)
- Retry logic with exponential backoff

### Stakeholders
- System administrators: Want simple single-command upload
- Security teams: Need complete audit packages submitted
- Server operators: Prefer receiving complete archives over multiple file uploads

### Constraints
- Must preserve backward compatibility with existing `submit` command
- Must reuse existing configuration infrastructure
- Must upload files as binary data without modification

## Goals / Non-Goals

**Goals:**
- Add `submit-tar` command that uploads complete tar archives as-is
- Auto-detect most recent tar file when not specified
- Upload files directly as binary data using curl --data-binary
- Reuse existing server configuration and retry logic
- Provide dry-run mode for testing

**Non-Goals:**
- Modifying existing `submit` command (JSON reports)
- Decompression or compression (upload files as-is)
- Streaming large files (use --data-binary for simplicity)
- Archive validation before upload (trust tar creation)
- Parallel uploads or chunking

## Decisions

### Decision 1: Separate Command (submit-tar)
**What**: Create new `submit-tar` command instead of adding flag to existing `submit`

**Why**:
- Clear separation of concerns (JSON vs tar submission)
- Different endpoints (/submit-tar vs /)
- Different data formats (binary tar vs individual JSON)
- Easier to document and understand
- No risk of breaking existing workflows

**Alternative Considered**: `./RUNME.sh submit --tar` flag
- Rejected: Overloads single command, harder to maintain, confusing UX

### Decision 2: Upload Files As-Is Using --data-binary
**What**: Upload tar files directly without any processing using curl's --data-binary flag

**Why**:
- --data-binary sends raw binary data without modification (no URL encoding, no newline conversion)
- Server can handle decompression if needed
- Simpler implementation - no temporary files, no cleanup
- Works for both .tar and .tar.gz files
- Reduces client-side resource usage (no decompression)

**Implementation**:
```bash
curl -X POST "$endpoint" \
  --data-binary "@$tar_file" \
  -H "Content-Type: application/x-tar" \
  ...
```

**Alternative Considered**: Decompress .tar.gz before upload
- Rejected: Unnecessary complexity, requires temp files and cleanup, server can decompress

### Decision 3: Reuse Existing Configuration
**What**: Use same .honeybadger.conf settings (SERVER_URL, SERVER_ENABLED, etc.)

**Why**:
- No new configuration needed
- Consistent behavior with JSON submission
- Users already familiar with config options
- DRY_RUN, retry logic, timeouts all apply

**Server URL Construction**:
```bash
# If SERVER_URL=https://badgersbay.tools.technative.cloud/
# Tar endpoint: https://badgersbay.tools.technative.cloud/submit-tar
endpoint="${SERVER_URL%/}/submit-tar"
```

### Decision 4: Auto-Discovery Uses Modification Time
**What**: When no file specified, select most recent tar file by mtime

**Why**:
- Matches user expectation ("latest audit")
- Simple to implement (`ls -t` or `find -printf "%T@\t%p"`)
- Consistent with `submit` command behavior (finds latest output-* dir)

**Implementation**:
```bash
find_latest_tar() {
  ls -t honeybadger-*.tar.gz honeybadger-*.tar 2>/dev/null | head -1
}
```

### Decision 5: HTTP Request Format
**What**: Use `curl --data-binary @file` to upload tar files

**Why**:
- --data-binary sends raw binary data without modification
- Matches server API expectation (raw binary in body)
- Simpler than multipart/form-data
- No encoding/decoding overhead
- Works for both .tar and .tar.gz files

**HTTP Request**:
```bash
curl -X POST "$endpoint" \
  -H "Content-Type: application/x-tar" \
  -H "X-Hostname: $(hostname)" \
  -H "X-Username: $(whoami)" \
  --max-time "$SERVER_TIMEOUT" \
  --data-binary "@$tar_file"
```

## Risks / Trade-offs

### Risk: Large File Sizes
**Description**: Tar archives can be large (multi-MB), may timeout

**Likelihood**: Medium
**Impact**: Upload fails

**Mitigation**:
- Configurable SERVER_TIMEOUT (default 30s, users can increase)
- Retry logic handles transient failures
- Future: Could add progress indicator for large files

### Risk: Wrong Endpoint Used
**Description**: Users might try to submit tar to old `/` endpoint

**Likelihood**: Low
**Impact**: Server returns error

**Mitigation**:
- Clear command naming: `submit-tar` vs `submit`
- Documentation explains difference
- Server error message can guide users

## Migration Plan

### Phase 1: Implementation
1. Add `submit_tar_file()` function to lib/_library
2. Add `submit-tar` command to RUNME.sh
3. Add `find_latest_tar()` helper function
4. Test with local server

### Phase 2: Testing
1. Test auto-discovery with multiple tar files
2. Test explicit file path (relative and absolute)
3. Test uploading .tar.gz files
4. Test uploading .tar files
5. Test dry-run mode
6. Test retry logic with mock failures
7. Test SERVER_ENABLED=false

### Phase 3: Documentation
1. Update README.md with `submit-tar` examples
2. Document server endpoint requirement
3. Add troubleshooting section

### Phase 4: Rollout
1. Ship as opt-in feature (requires SERVER_ENABLED=true)
2. Existing `submit` command unaffected
3. No breaking changes

### Rollback Plan
- Feature is additive only
- Can be disabled by not using `submit-tar` command
- No database migrations or persistent state
- No impact on existing workflows

## Open Questions

1. **Concurrent Submissions**: Should we prevent submitting while an upload is in progress?
   - Recommendation: No, keep it simple. Users unlikely to run concurrent uploads.

2. **Progress Indicator**: Should large uploads show progress?
   - Recommendation: Not in initial version. Add later if needed using `curl --progress-bar`

3. **Archive Integrity Check**: Should we validate tar file before upload?
   - Recommendation: No. Trust audit generation. Server can validate on receipt.

4. **Partial Upload Recovery**: Should we support resumable uploads for large files?
   - Recommendation: No. Use retry logic. Resumable uploads require server support.

5. **Automatic Submission**: Should `./RUNME.sh audit` auto-submit tar at end?
   - Recommendation: No. Keep explicit control. Users run `submit-tar` when ready.

## Technical Details

### Function Signature
```bash
# Submit tar file to server
# Usage: submit_tar_file <tar-file-path>
# Returns: 0 on success, 1 on failure
submit_tar_file() {
  local tar_file="$1"

  # Validate file exists
  if [[ ! -f "$tar_file" ]]; then
    echo "ERROR: File not found: $tar_file"
    return 1
  fi

  # Upload with retry
  local endpoint="${SERVER_URL%/}/submit-tar"
  # ... curl with retry logic ...
  curl -X POST "$endpoint" \
    -H "Content-Type: application/x-tar" \
    -H "X-Hostname: $(hostname)" \
    -H "X-Username: $(whoami)" \
    --max-time "$SERVER_TIMEOUT" \
    --data-binary "@$tar_file"
}
```

### Error Codes
- 0: Success
- 1: File not found
- 2: Upload failed (after retries)
- 3: Server disabled (SERVER_ENABLED=false)
