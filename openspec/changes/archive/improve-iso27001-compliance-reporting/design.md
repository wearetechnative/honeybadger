## Context

Honeybadger is an ISO27001 compliance audit tool that collects system information for policy verification. The current implementation has gaps in compliance reporting:

**Current State:**
- `lib/_library` contains `generate_asset_inventory()` which builds compliance reports
- `lib/check-os-updates.sh` exists but is NOT called during audits
- Lynis hardening score is available in JSON but not displayed in reports
- No serial number collection (variable declared but never populated)
- No NixOS-specific metadata collection
- No severity filtering for Lynis findings

**Constraints:**
- Must maintain backward compatibility with existing output format
- Requires root/sudo privileges (Lynis already requires this)
- Must work across multiple distributions (Arch, Ubuntu, Debian, NixOS, macOS)
- Must handle missing tools gracefully (dmidecode may not be available in VMs)

**Stakeholders:**
- Compliance auditors need complete asset inventory data
- System administrators need clear pass/fail criteria
- NixOS users need reproducibility tracking

## Goals / Non-Goals

**Goals:**
- Collect and display hardware serial numbers in asset inventory
- Integrate OS update history checking into audit workflow
- Display Lynis hardening score with pass/fail validation (threshold: ≥65)
- Collect NixOS metadata (commit hash, generation, rebuild date)
- Categorize Lynis findings by severity for prioritization
- Maintain graceful degradation when tools are unavailable

**Non-Goals:**
- Changing existing Lynis integration or configuration
- Modifying the core audit flow or adding new dependencies
- Supporting non-Linux platforms beyond existing macOS support
- Implementing automated remediation for failed checks
- Adding CVE vulnerability scanning (Vulnix/Trivy were recently removed)

## Decisions

### Decision 1: Keep check-os-updates.sh as separate script

**Chosen Approach:** Call `lib/check-os-updates.sh` from `RUNME.sh audit` as a separate step, save output to `$output/os-update-history.txt`.

**Rationale:**
- Script already exists and is well-tested (16KB, handles 7+ distributions)
- Separation of concerns: update checking is distinct from asset inventory
- Easy to test and maintain independently
- Clear output file makes debugging simpler

**Alternatives Considered:**
- Merge into `lib/_library::check_os_status()`: Would create a monolithic function, harder to test
- Rewrite update checking inline: Duplicates existing working code

**Trade-off:** Extra output file, but clearer separation of concerns wins.

### Decision 2: Use dmidecode for serial number collection

**Chosen Approach:** Execute `dmidecode -s system-serial-number`, handle failures gracefully.

**Rationale:**
- Industry standard tool for hardware information
- Already commonly available on most systems
- Reliable cross-platform (works on physical hardware and many VMs)

**Alternatives Considered:**
- Parse `/sys/class/dmi/id/product_serial`: Less portable, requires different permissions
- Use neofetch: Doesn't provide serial numbers
- lshw: Heavier tool, less commonly pre-installed

**Trade-off:** Requires root (but audit already needs sudo). VMs may return generic serials (acceptable, not an error).

### Decision 3: Extract hardening score from existing JSON

**Chosen Approach:** Read `.hardening_index` from `lynis-report.json` in `generate_asset_inventory()`.

**Rationale:**
- Data already available, no additional Lynis runs needed
- Consistent with existing pattern (we already read from this JSON)
- Simple jq query

**Implementation:**
```bash
hardening_score=$(jq -r '.hardening_index // "Unknown"' "$output_dir/lynis-report.json")
```

### Decision 4: Hardening score threshold as configurable constant

**Chosen Approach:** Define `MIN_HARDENING_SCORE=65` at top of `generate_asset_inventory()`.

**Rationale:**
- Easy to modify if policy changes
- Self-documenting code
- Single source of truth

**Display format:**
- Pass: `78/100 ✅ COMPLIANT (≥65)`
- Fail: `58/100 ❌ NON-COMPLIANT (required: ≥65)`

### Decision 5: NixOS metadata collection in dedicated section

**Chosen Approach:** Add NixOS-specific check in `RUNME.sh audit` after neofetch, save to `nixos-system-info.txt`.

**Rationale:**
- NixOS metadata is only relevant for NixOS systems
- Keeps audit logic clean with conditional execution
- Separate output file for NixOS-specific data

**Commands:**
```bash
if [[ "$OS_NAME" =~ "NixOS" ]]; then
  nixos-version --json > "$output/nixos-system-info.txt"
  readlink /nix/var/nix/profiles/system >> "$output/nixos-system-info.txt"
  nixos-rebuild list-generations | tail -5 >> "$output/nixos-system-info.txt"
fi
```

### Decision 6: Severity categorization requires Lynis JSON research

**Chosen Approach:**
1. First, examine actual `lynis-report.json` structure to identify severity fields
2. If severity exists: use it directly
3. If not: implement keyword-based heuristic

**Rationale:**
- Lynis JSON structure may vary by version
- Must verify actual field availability before implementation
- Heuristic fallback ensures functionality even without explicit severity

**Research needed:** Check if `.suggestion[]` or `.warning[]` contain severity/priority fields.

### Decision 7: Keep check-os-updates.sh separate from check_os_status()

**Chosen Approach:** Maintain check-os-updates.sh as a separate script, do NOT merge with check_os_status() function.

**Rationale:**
- Separation of concerns: update checking is distinct from EOL status verification
- check-os-updates.sh is a standalone, well-tested script (16KB, handles 7+ distributions)
- check_os_status() focuses on release lifecycle (current/EOL) via endoflife.date API
- Different data sources: check-os-updates uses local package manager timestamps, check_os_status uses external APIs
- Merging would create a monolithic function that's harder to test and maintain
- Each script has clear, independent purpose and output file

**Implementation:**
- check-os-updates.sh called from RUNME.sh audit after OS status check
- Outputs to separate file: os-update-history.txt
- check_os_status() continues to output: os-kernel-status.txt
- Both contribute to compliance reporting without overlapping functionality

## Risks / Trade-offs

### Risk: dmidecode may not be available or return empty values
**Mitigation:** Graceful fallback to "Not available", continue audit without failing.

### Risk: NixOS commands may fail on older NixOS versions
**Mitigation:** Use `command -v` checks, fallback to alternative methods (read `/run/current-system/nixos-version`).

### Risk: Lynis JSON structure changes break score extraction
**Mitigation:** Use `.hardening_index // "Unknown"` fallback, document JSON version in code.

### Risk: check-os-updates.sh may have stale logic for newer distributions
**Mitigation:** Test on target distributions before release. Script already handles unknown distros gracefully.

### Risk: Severity categorization may not match Lynis structure
**Mitigation:** Research Lynis JSON first, implement heuristic fallback, document limitations.

### Trade-off: Additional output files increase audit output size
**Acceptable:** New files (os-update-history.txt, nixos-system-info.txt) are small (<5KB each) and valuable for compliance.

### Trade-off: More checks = longer audit time
**Acceptable:** Additional checks add ~2-5 seconds total (dmidecode: <1s, nixos-version: <1s, check-os-updates: 1-3s).

## Migration Plan

**Deployment:**
1. Merge changes to main branch
2. Update README.md with new compliance requirements
3. Tag new version (follow semantic versioning)
4. Test on representative systems (Arch, Ubuntu, NixOS)

**Rollback Strategy:**
- All changes are additive, not modifying existing functionality
- If issues arise, revert the commits (no data migration needed)
- Output files are independent, removing them doesn't break existing reports

**Testing:**
Run audit on:
- Physical hardware (to verify serial number)
- Virtual machines (to verify graceful VM handling)
- NixOS system (to verify metadata collection)
- System with Lynis score <65 (to verify threshold validation)
- System without dmidecode (to verify graceful degradation)

## Open Questions

1. **Should hardening score threshold be per-distribution or universal?**
   - Current: Universal threshold of 65
   - Alternative: Different thresholds for server vs desktop, or by distro
   - Decision: Start with universal, adjust if needed based on user feedback

2. **Should audit fail (non-zero exit) when hardening score <65?**
   - Current: Display NON-COMPLIANT but continue
   - Alternative: Exit with error code
   - Recommendation: Display only, don't fail audit (allows users to see all findings)

3. **How detailed should NixOS generation history be?**
   - Current: Last 5 generations
   - Alternative: Only current generation, or full history
   - Decision: Last 5 is sufficient for typical troubleshooting

4. **Should severity categorization apply to both warnings AND suggestions?**
   - Current: Apply to both (`.warning[]` and `.suggestion[]`)
   - Verify if both arrays have severity information
   - Decide during implementation based on actual JSON structure

## Implementation Notes

### NixOS Metadata Extraction - Regex Issue

**Problem Encountered:**
During testing, bash regex syntax error was discovered in NixOS metadata extraction:
```bash
lib/_library: line 834: syntax error in conditional expression: unexpected token `)'
```

The problematic pattern was:
```bash
[[ "$version_line" =~ \(([^)]+)\) ]]
```

**Root Cause:**
Bash has complex rules for regex escaping inside `[[ =~ ]]`. The pattern for matching parentheses with capture groups can be ambiguous across different bash versions.

**Solution Implemented:**
Replaced regex pattern matching with sed-based extraction for better portability:
```bash
# Before (problematic):
elif [[ -n "$version_line" && "$version_line" =~ \(([^)]+)\) ]]; then
    local full_hash="${BASH_REMATCH[1]}"
    nixos_commit="${full_hash:0:8}"
fi

# After (reliable):
else
    # Try to extract from parentheses using sed as fallback
    local paren_content=$(echo "$version_line" | sed -n 's/.*(\([^)]*\)).*/\1/p')
    if [[ -n "$paren_content" ]]; then
        nixos_commit="${paren_content:0:8}"
    fi
fi
```

**Rationale:**
- Sed is more portable and predictable for pattern extraction
- Avoids bash version-specific regex interpretation issues
- More readable and maintainable
- Same functionality, more reliable implementation

**Testing:**
Verified on NixOS 25.11 with bash - functions load correctly and metadata extraction works.
