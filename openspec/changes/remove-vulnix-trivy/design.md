## Context

CVE vulnerability scanning with vulnix (NixOS) and trivy (other Linux distributions) was integrated into Honeybadger in v0.3.0 as an optional feature, then made mandatory in v0.4.0 for ISO27001 Policy 8.1 compliance. The functionality consists of:

- 6 shell functions in `lib/_library` (~150 lines) for scanning and report generation
- Dependency validation in `RUNME.sh` that exits audit if scanners are missing
- Integration in the audit workflow that runs scans and generates summaries
- Report submission logic that uploads CVE scan results to honeybadger-server

The functionality is deeply integrated into the audit workflow but is self-contained enough to be removed cleanly without affecting other audit features.

## Goals / Non-Goals

**Goals:**
- Remove all CVE scanning code from the codebase
- Remove mandatory dependency requirements for vulnix and trivy
- Maintain audit functionality for all other checks (system info, users, packages, services, etc.)
- Clean up all related documentation and OpenSpec artifacts
- Ensure no broken references remain in the codebase

**Non-Goals:**
- Providing a replacement CVE scanning solution
- Maintaining backward compatibility for CVE-related output files
- Supporting server-side processing of CVE reports after removal

## Decisions

### Decision 1: Complete Removal vs. Making Optional

**Chosen**: Complete removal of all CVE scanning code

**Rationale**: Since the functionality is deemed obsolete, making it optional would leave dead code in the codebase that no one uses. Clean removal is simpler to maintain and understand.

**Alternatives considered**:
- Making scanners optional again (like v0.3.0): Would leave unused code that still requires maintenance
- Feature flag approach: Adds complexity for obsolete functionality

### Decision 2: Handling Server-Side Dependencies

**Chosen**: Remove CVE report submission from client, document breaking change

**Rationale**: If the scanning is obsolete, the reports are not needed. Server-side can handle missing CVE reports gracefully (they're just file uploads).

**Alternatives considered**:
- Sending empty/null CVE reports: Adds complexity and network traffic for no benefit
- Gradual deprecation: Delays cleanup unnecessarily

### Decision 3: Documentation of Breaking Changes

**Chosen**: Document as breaking change in CHANGELOG, update README to remove installation instructions

**Rationale**: Users need clear visibility that CVE scanning is gone. Version bump to 0.5.0 signals breaking change following semantic versioning.

**Alternatives considered**:
- Silent removal: Would confuse users expecting CVE reports
- Deprecation period: Unnecessary for obsolete functionality

### Decision 4: OpenSpec Artifacts Cleanup

**Chosen**: Keep historical OpenSpec change directories, do not delete them

**Rationale**: Preserves project history and reasoning for past decisions. The directories document why CVE scanning was added and later removed.

**Alternatives considered**:
- Delete CVE-related OpenSpec directories: Loses valuable project history
- Move to archive folder: Adds complexity without benefit

## Risks / Trade-offs

**Risk: ISO27001 Compliance Gap**
→ Mitigation: Document in removal notes that organizations requiring CVE scanning for Policy 8.1 compliance must implement alternative solutions

**Risk: Server-Side Expects CVE Reports**
→ Mitigation: Server submission already handles optional reports (some systems might not have scanners). Verify server handles missing CVE files gracefully.

**Risk: Breaking Existing User Workflows**
→ Mitigation: Clear documentation in CHANGELOG and version bump to 0.5.0 signals breaking change. Users upgrading will see explicit notice.

**Risk: Incomplete Removal Leaves Broken References**
→ Mitigation: Systematic search for vulnix/trivy references across all files (code, docs, specs) to ensure complete cleanup

**Trade-off: Lost Vulnerability Visibility**
→ Users who found CVE scanning valuable will lose this capability. However, since it's deemed obsolete, this is an intentional trade-off.
