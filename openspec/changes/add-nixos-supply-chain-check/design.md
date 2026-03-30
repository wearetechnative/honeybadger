## Context

The existing Honeybadger audit system runs Lynis which includes PKGS-7398 check for "installed software from untrusted repositories". This check is generic and doesn't understand NixOS's unique supply chain security model (cryptographic signatures, trusted substituters, binary cache verification). As a result, NixOS systems may receive false warnings despite having superior supply chain controls.

The PKGS-7398-nix-audit.sh script already exists and performs NixOS-specific supply chain validation by checking:
- Binary cache substituters configuration
- Signature verification enforcement (require-sigs)
- Trusted public keys configuration
- Optional: Nix store integrity verification

The challenge is integrating this NixOS-specific check into the audit workflow and compliance reporting without impacting non-NixOS systems.

**Constraints:**
- Script must run as actual user (not root) to read correct Nix user configuration
- Audit should continue even if nix-audit.sh fails (non-blocking)
- Non-NixOS systems must not be affected
- Integration must work with existing compliance report structure

## Goals / Non-Goals

**Goals:**
- Integrate PKGS-7398-nix-audit.sh into audit command for NixOS systems
- Add NixOS supply chain status to compliance reports and asset inventory
- Parse audit results and classify as PASS/FAIL for ISO27001 compliance
- Store complete audit output for manual review

**Non-Goals:**
- Modifying or improving PKGS-7398-nix-audit.sh itself (use as-is)
- Adding similar checks for other package managers (apt, dnf, pacman)
- Changing how Lynis PKGS-7398 works
- Auto-remediation of supply chain issues

## Decisions

### Decision 1: Run nix-audit during audit command, not check-output

**Chosen:** Execute PKGS-7398-nix-audit.sh in `audit()` function of RUNME.sh

**Rationale:**
- Audit phase collects all data; check-output phase analyzes existing data
- Nix configuration can change between audit and check-output runs
- Consistent with other data collection (lynis, neofetch, blockdevices)
- nix-audit output becomes part of the audit artifact (tarball)

**Alternatives considered:**
- Run during check-output: Would require nix to be available when analyzing old tarballs (not always true)
- Run as separate command: Adds complexity, users would need to remember to run it

### Decision 2: Detect NixOS from lynis-report.json first, neofetch.json as fallback

**Chosen:** Check `os_name` field in lynis-report.json, fall back to neofetch.json if needed

**Rationale:**
- lynis-report.json is authoritative (already used for OS detection elsewhere)
- neofetch.json provides fallback if lynis fails
- Consistent with existing OS detection pattern in codebase

**Alternatives considered:**
- Only use neofetch: Less reliable, neofetch can be missing
- Check for `nix` command: False positives (Nix installed on non-NixOS systems)

### Decision 3: Execute as SUDO_USER, not root

**Chosen:** Run `sudo -u $SUDO_USER PKGS-7398-nix-audit.sh` when audit runs with sudo

**Rationale:**
- Nix configuration is per-user (~/.config/nix, user nix.conf)
- Root's nix config may differ from actual user's config
- Matches existing pattern for neofetch execution (see RUNME.sh:135)

**Alternatives considered:**
- Always run as root: Would read root's config, not user's (incorrect for personal device audit)
- Require audit without sudo: Conflicts with lynis requirement for root

### Decision 4: Non-blocking execution with error handling

**Chosen:** Wrap nix-audit.sh in try-catch, continue audit if it fails

**Rationale:**
- Script might fail (missing nix command, permission issues)
- Audit should complete for other checks even if nix-audit fails
- Graceful degradation: missing nix-audit output = "Unknown" status

**Alternatives considered:**
- Make it required: Would fail entire audit for nix-related issues
- Skip silently on error: User wouldn't know check failed

### Decision 5: Parse "Result: PASS/FAIL" line for compliance status

**Chosen:** grep for "Result: PASS" or "Result: FAIL" in nix-supply-chain-audit.txt

**Rationale:**
- Simple, reliable parsing (script has stable output format)
- Matches ISO27001 pass/fail model
- Easy to extend later if needed

**Alternatives considered:**
- Parse detailed issues: More complex, harder to maintain if script output changes
- Use exit code: Script doesn't currently use exit codes meaningfully

### Decision 6: Add as new row in compliance checklist (conditional)

**Chosen:** Add "NixOS Supply Chain" row to checklist only if OS is NixOS

**Rationale:**
- Doesn't clutter checklist for non-NixOS systems
- Clear, visible compliance indicator
- Consistent with existing checklist structure

**Alternatives considered:**
- Always show with "N/A" for non-NixOS: Adds noise
- Only show in system info: Less visible, harder to spot critical issue

## Risks / Trade-offs

**Risk:** nix-audit.sh execution adds ~5-10 seconds to audit time (due to `nix store verify`)
→ **Mitigation:** Acceptable for improved security validation; only runs on NixOS systems; could make `nix store verify` optional in future if needed

**Risk:** Script might fail on non-standard NixOS configurations (flakes, custom nix.conf locations)
→ **Mitigation:** Script uses `nix config show` which handles all configurations; failures are logged and don't block audit

**Risk:** User's Nix config might be in a locked state or require network access
→ **Mitigation:** Script runs read-only commands; network access not required for signature checks; failures degrade gracefully to "Unknown"

**Trade-off:** Adding NixOS-specific logic increases codebase complexity
→ **Justification:** NixOS has fundamentally different supply chain model; generic checks inadequate; complexity isolated to conditional blocks

**Risk:** Future changes to nix-audit.sh output format could break parsing
→ **Mitigation:** Parse only stable marker lines ("Result: PASS/FAIL"); if format changes, worst case is "Unknown" status, not crash

## Migration Plan

**Deployment Steps:**
1. Add NixOS detection helper function to lib/_library
2. Add check_nixos_supply_chain() parsing function to lib/_library
3. Update audit() in RUNME.sh to run nix-audit.sh for NixOS systems
4. Update generate_compliance_report() to include NixOS supply chain row
5. Update generate_asset_inventory() to include NixOS supply chain field

**Testing:**
- Test on NixOS system with PASS result
- Test on NixOS system with FAIL result (temporarily disable require-sigs)
- Test on non-NixOS system (should skip gracefully)
- Test with missing PKGS-7398-nix-audit.sh (should log error, continue)

**Rollback Strategy:**
- Changes are additive only (no existing functionality removed)
- If issues occur, revert RUNME.sh and lib/_library changes
- Old reports still work (just missing NixOS supply chain info)

**Backward Compatibility:**
- Old audit tarballs without nix-supply-chain-audit.txt: show "Unknown" status
- Non-NixOS systems: no impact (conditional logic)
- Existing compliance reports: still valid (new field is optional)

## Open Questions

None - design is ready for implementation.
