# Fix Neofetch Username Shows Root - Design Document

## Context

Honeybadger requires root privileges to perform complete security audits (Lynis, system information collection). Users run the audit with `sudo ./RUNME.sh audit`.

However, when neofetch runs during the audit, it executes as root and captures "root" as the username instead of the actual user who invoked sudo. This creates inconsistencies:

1. **Output directory**: `output-hostname-wtoorren-17-03-2026` (uses SUDO_USER ✓)
2. **neofetch.json**: `{"user": "root", ...}` (captures effective user ✗)
3. **Server headers**: `X-Username: wtoorren` (uses SUDO_USER ✓)

### Stakeholders
- Compliance officers: Need accurate user ownership in reports
- System administrators: Need to know who ran the audit
- Asset management: Need correct user attribution
- Security teams: Need accurate audit trail

### Constraints
- Audit must continue to run as root (Lynis requirement)
- neofetch must capture actual user, not root
- Must work when SUDO_USER is not set (direct root execution)
- Must maintain existing JSON structure

## Goals / Non-Goals

### Goals
- Capture actual username in neofetch.json (not root)
- Use sudo -u to run neofetch as original user
- Maintain consistency across all outputs
- Preserve existing neofetch.json structure

### Non-Goals
- Changing neofetch output format
- Running entire audit as non-root
- Modifying other system information collection
- Changing output directory naming (already correct)

## Decisions

### Decision 1: Use sudo -u to Run Neofetch
**What**: Execute neofetch with `sudo -u "${SUDO_USER:-$(whoami)}"`

**Why**:
- neofetch collects user-specific information (shell, terminal, etc.)
- Running as actual user provides accurate system information
- SUDO_USER preserves original username when using sudo
- Falls back to whoami when not using sudo

**Implementation**:
```bash
# Current (incorrect):
neofetch --off --stdout | jq -Rn '...'

# Fixed (correct):
sudo -u "${SUDO_USER:-$(whoami)}" neofetch --off --stdout | jq -Rn '...'
```

**Alternatives Considered**:
1. **Post-process neofetch.json to replace "root"**
   - Rejected: Hacky, doesn't fix root cause
   - Rejected: Loses other user-specific info
2. **Set environment variables to trick neofetch**
   - Rejected: Fragile, may not work
   - Rejected: Doesn't fix actual user context
3. **Run neofetch before sudo**
   - Rejected: Requires restructuring entire audit flow
   - Rejected: Loses root privileges for other operations

### Decision 2: Placement in Audit Flow
**What**: Keep neofetch in current location but add sudo -u wrapper

**Why**:
- Minimal code change
- SUDO_USER is available at that point
- No dependencies on later variables
- Doesn't affect audit flow

**Note**: The `actual_user` variable is defined later in the code, but we can use `${SUDO_USER:-$(whoami)}` directly.

### Decision 3: Preserve Existing Pipeline
**What**: Keep existing jq pipeline for JSON conversion

**Why**:
- JSON structure is already correct
- Just needs correct input (user@hostname)
- No changes needed to downstream consumers
- Backward compatible

### Decision 4: Error Handling
**What**: Allow neofetch failure to be non-fatal (existing behavior)

**Why**:
- neofetch is system information, not critical
- User might not have neofetch access
- Existing error handling is sufficient

## Risks / Trade-offs

### Risk: sudo -u Might Fail in Some Environments
**Description**: sudo -u might not work in restricted environments

**Likelihood**: Low
**Impact**: Low (neofetch would fail, audit continues)

**Mitigation**:
- Use || true to make failure non-fatal
- Log error but continue audit
- Existing error handling catches this

### Risk: User Environment Different from Root
**Description**: neofetch might show different info when run as user vs root

**Likelihood**: Medium
**Impact**: Low (this is actually desirable - we want user's environment)

**Mitigation**:
- This is the correct behavior
- User environment is more accurate for user info
- Shell, terminal, etc. should be user's, not root's

### Risk: SUDO_USER Not Set
**Description**: When run directly as root, SUDO_USER is empty

**Likelihood**: Low (most users use sudo)
**Impact**: Low (falls back to whoami, which returns "root")

**Mitigation**:
- Use ${SUDO_USER:-$(whoami)} for fallback
- Behavior matches current for direct root execution
- No regression

## Implementation Notes

### Current Code (line ~141)
```bash
neofetch --off --stdout | jq -Rn '
  ([inputs | select(length>0)] |
   (.[0] | capture("^(?<user>[^@]+)@(?<hostname>\\S+)") // {}) +
   (.[1:] | map(select(contains(":"))) | map(capture("(?<key>[^:]+): (?<value>.*)")) | map({(.key|ascii_downcase|gsub(" "; "_")): .value}) | add // {})
  )' > $output/neofetch.json
```

### Fixed Code
```bash
sudo -u "${SUDO_USER:-$(whoami)}" neofetch --off --stdout | jq -Rn '
  ([inputs | select(length>0)] |
   (.[0] | capture("^(?<user>[^@]+)@(?<hostname>\\S+)") // {}) +
   (.[1:] | map(select(contains(":"))) | map(capture("(?<key>[^:]+): (?<value>.*)")) | map({(.key|ascii_downcase|gsub(" "; "_")): .value}) | add // {})
  )' > $output/neofetch.json
```

**Change**: Add `sudo -u "${SUDO_USER:-$(whoami)}"` before neofetch

### Testing Verification

Before fix:
```json
{
  "user": "root",
  "hostname": "lobos",
  ...
}
```

After fix:
```json
{
  "user": "wtoorren",
  "hostname": "lobos",
  ...
}
```

## Migration Path

### For Existing Installations
- No migration needed
- Next audit will capture correct username
- Old neofetch.json files remain unchanged (historical data)
- New audits will have correct data

### Communication
- Document as bug fix in CHANGELOG
- No user action required
- Transparent improvement

## Future Enhancements (Not in This Change)

1. Validate username consistency across all outputs
2. Add test to verify neofetch username matches SUDO_USER
3. Consider running other user-specific commands with sudo -u
4. Add warning if username inconsistency detected
