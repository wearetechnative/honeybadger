# Server Report Submission - Design Document

## Context

Honeybadger currently generates security audit reports locally. Organizations need centralized monitoring to track compliance across multiple systems. A honeybadger-server provides a dashboard and API endpoint to collect reports from all audited systems.

### Stakeholders
- System administrators: Need centralized visibility into all audited systems
- Security teams: Need historical tracking and trend analysis
- Compliance auditors: Need centralized evidence collection
- DevOps teams: Need automated compliance reporting

### Constraints
- Must not break existing local audit functionality
- Must handle server unavailability gracefully (audit continues)
- Must work with existing report formats (JSON)
- Must be opt-in (backward compatible)
- Must work in air-gapped environments (when server disabled)

## Goals / Non-Goals

### Goals
- Submit JSON reports to centralized honeybadger-server via HTTP POST
- Auto-detect system identity (hostname, username)
- Support optional retry logic for network failures
- Provide dry-run mode for testing
- Make submission completely optional via configuration
- Maintain full backward compatibility

### Non-Goals
- Authentication/authorization (server handles this if needed)
- Report encryption in transit (can use HTTPS for that)
- Local report queuing (if server down, reports are not queued)
- Real-time streaming of audit progress
- Bi-directional communication (server can't send commands to client)
- Report filtering/redaction (submit complete JSON as-is)

## Decisions

### Decision 1: Configuration File Format
**What**: Use simple `key=value` format in `.honeybadger.conf`

**Why**:
- Bash-native parsing (source file directly or use grep/cut)
- Easy for users to understand and edit
- No additional dependencies (vs YAML/TOML)
- Consistent with traditional Unix configuration

**Format Example**:
```bash
# Honeybadger Server Configuration
SERVER_ENABLED=true
SERVER_URL=http://honeybadger-server:7123/
SERVER_TIMEOUT=30
SERVER_RETRY_COUNT=3
DRY_RUN=false
```

**Alternatives Considered**:
1. **JSON config**: More structured, but harder to edit manually, requires jq
2. **YAML/TOML**: Better for complex configs, but adds dependencies
3. **Environment variables only**: No persistent config, less discoverable

### Decision 2: Separate Submit Command
**What**: Provide standalone `./RUNME.sh submit` command, do NOT integrate into audit

**Why**:
- Users explicitly control when reports are submitted
- Audit remains focused on local report generation
- Allows re-submission if server was temporarily unavailable
- Can submit old reports without re-running audit
- Clearer separation of concerns (audit vs submission)
- No configuration needed to disable submission during audit

**Alternative Considered**:
- Auto-submit at end of audit if SERVER_ENABLED=true
- Rejected: Too implicit, users should explicitly submit

**Usage**:
```bash
# Run audit (generates local reports only)
sudo ./RUNME.sh audit

# Submit reports to server (separate step)
./RUNME.sh submit

# Or submit specific directory
./RUNME.sh submit output-hostname-user-16-03-2026
```

### Decision 3: Retry Strategy
**What**: Retry up to 3 times with exponential backoff (1s, 2s, 4s)

**Why**:
- Handles transient network issues
- Exponential backoff reduces server load
- 3 retries + backoff = ~10 seconds max retry time
- Doesn't significantly delay audit completion

**Implementation**:
```bash
# Retry logic
for attempt in 1 2 3; do
  if submit_via_curl; then
    return 0
  fi
  if [[ $attempt -lt 3 ]]; then
    sleep $((2 ** (attempt - 1)))  # 1s, 2s, 4s
  fi
done
return 1
```

**Do NOT retry on**:
- 400 Bad Request (client error - fix the data, not retry)
- 401 Unauthorized (auth problem, not network)
- 413 Payload Too Large (report too big, won't change)

**DO retry on**:
- Connection refused
- Timeout
- 500/502/503 server errors (temporary)

### Decision 4: Required vs Optional Reports
**What**: Enforce server-side completeness requirements, client submits all available

**Why**:
- Client submits whatever reports it generated
- Server decides if submission is "complete" based on:
  - neofetch (always required)
  - lynis (always required)
  - trivy OR vulnix (at least one)
- Client doesn't need to know server's completeness logic
- Allows server-side policy changes without client updates

**Client behavior**:
- Always try to submit: neofetch.json, lynis-report.json
- Conditionally submit: vulnix.json (NixOS), trivy.json (others)
- Log warning if expected file missing, but don't fail

### Decision 5: Configuration File Precedence
**What**: Check config files in order: `./.honeybadger.conf`, `~/.honeybadger.conf`, `/etc/honeybadger.conf`

**Why**:
- Current directory: Project-specific overrides
- Home directory: User-specific settings
- /etc: System-wide defaults
- First match wins (allows overrides)

**Alternative**: Merge all configs (complexity not worth it for simple config)

### Decision 6: Dry-Run Mode
**What**: When `DRY_RUN=true`, log what would be submitted without actual HTTP request

**Why**:
- Testing configuration without affecting server
- Debugging submission issues
- Verifying reports before enabling server
- Security review (see what data would be sent)

**Output Example**:
```
DRY-RUN: Would submit neofetch.json to http://server:7123/
  Headers: X-Hostname=webserver01 X-Username=admin X-Report-Type=neofetch
  Command: curl -X POST http://server:7123/ -H "X-Hostname: webserver01" -H "X-Username: admin" -H "X-Report-Type: neofetch" -d @neofetch.json
```

### Decision 7: Error Handling Philosophy
**What**: Submission failures MUST NOT fail the audit

**Why**:
- Primary goal: Generate local audit reports
- Server submission is a secondary feature
- Network issues shouldn't block compliance auditing
- Users should still get their local reports

**Implementation**:
- All `submit_report()` calls wrapped in `|| true`
- Log errors clearly but continue execution
- Summary at end: "X reports submitted, Y failed"

## Risks / Trade-offs

### Risk: Server Unavailability
**Description**: honeybadger-server might be down or unreachable

**Likelihood**: Medium
**Impact**: Low (audit continues, local reports preserved)

**Mitigation**:
- Retry logic with exponential backoff
- Clear error messages in logs
- Dry-run mode for testing connectivity
- Option to disable submission entirely

### Risk: Large Report Sizes
**Description**: JSON reports can be large (vulnix.json = 715KB+), might timeout

**Likelihood**: Low-Medium
**Impact**: Medium (report submission fails)

**Mitigation**:
- Configurable timeout (default 30s)
- Server should accept large payloads (this is server config)
- Future enhancement: Compress before sending (gzip)
- Future enhancement: Report size validation before submission

### Risk: Sensitive Data Leakage
**Description**: Reports contain detailed system information

**Likelihood**: N/A (by design)
**Impact**: Depends on deployment

**Mitigation**:
- Document data being transmitted
- Recommend HTTPS for production
- Future enhancement: Data redaction options
- User consent: Submission is opt-in

### Risk: Network Firewall Blocks
**Description**: Corporate firewalls might block HTTP/HTTPS to server

**Likelihood**: Medium in enterprise environments
**Impact**: Low (graceful failure, local reports still work)

**Mitigation**:
- Clear error messages (connection refused vs timeout)
- Dry-run mode to test connectivity
- Document network requirements
- Support custom ports

## Migration Plan

### Phase 1: Implementation (This Change)
1. Add configuration file support
2. Implement submission functions
3. Integrate into audit workflow
4. Add documentation and examples

### Phase 2: Testing
1. Test with local mock server
2. Test with real honeybadger-server
3. Test error scenarios (server down, network issues)
4. Validate dry-run mode

### Phase 3: Rollout
1. Ship as opt-in feature (disabled by default)
2. Provide configuration examples
3. Document server setup requirements
4. Monitor for issues

### Phase 4: Future Enhancements (Not in This Change)
1. HTTPS with certificate validation
2. Authentication tokens
3. Report compression (gzip)
4. Local report queuing when server unreachable
5. Data redaction options
6. Bandwidth throttling

### Rollback Plan
If submission causes issues:
1. Set `SERVER_ENABLED=false` in config
2. Feature is fully backward compatible (won't break audits)
3. Can be disabled globally via /etc config
4. No database migrations or persistent state to roll back

## Open Questions

1. **Configuration Format**: Should we support environment variables as alternative to config file?
   - Recommendation: Yes, check `HONEYBADGER_SERVER_URL` env var as fallback

2. **Report Compression**: Should reports be gzipped before sending?
   - Recommendation: Not in initial version, add later if needed

3. **Server Health Check**: Pre-flight check before audit, or discover failure during submission?
   - Recommendation: No pre-flight check (adds latency), fail during submission

4. **Partial Submissions**: If neofetch succeeds but lynis fails, retry only failed?
   - Recommendation: No, keep it simple. Each report submission is independent.

5. **Submission Order**: Does order matter (neofetch first for identity, then others)?
   - Recommendation: Submit in order: neofetch, lynis, vulnix/trivy
   - Reason: Server gets identity first, easier debugging

6. **Concurrent Submissions**: Submit all reports in parallel or sequential?
   - Recommendation: Sequential for simplicity, predictable behavior
   - Future: Could parallelize if performance needed

7. **Server Authentication**: How to handle if server requires API key?
   - Recommendation: Add `SERVER_API_KEY` config option
   - Send as `Authorization: Bearer $key` or `X-API-Key: $key` header
   - Not in initial version, add when server implements auth

## Technical Details

### HTTP Request Format

```bash
curl -X POST "$SERVER_URL" \
  -H "Content-Type: application/json" \
  -H "X-Hostname: $(hostname -s)" \
  -H "X-Username: ${SUDO_USER:-$(whoami)}" \
  -H "X-Report-Type: lynis" \
  --max-time "$SERVER_TIMEOUT" \
  --retry "$SERVER_RETRY_COUNT" \
  --retry-delay 1 \
  -d @"$REPORT_FILE" \
  -w "%{http_code}" \
  -o /dev/null
```

### Success Criteria
- HTTP 200: Success
- HTTP 400: Bad request (log and skip retry)
- HTTP 500+: Server error (retry)
- Timeout: Retry
- Connection refused: Retry

### Configuration Loading Logic
```bash
load_config() {
  # Default values
  SERVER_ENABLED=false
  SERVER_URL="http://localhost:7123/"
  SERVER_TIMEOUT=30
  SERVER_RETRY_COUNT=3
  DRY_RUN=false

  # Check config files in order
  for config in ./.honeybadger.conf ~/.honeybadger.conf /etc/honeybadger.conf; do
    if [[ -f "$config" ]]; then
      source "$config"
      echo "Loaded config from: $config"
      return 0
    fi
  done

  # No config found, use defaults
  return 0
}
```
