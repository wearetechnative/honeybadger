## Why

NixOS systems have unique supply chain security controls (signature verification, trusted substituters) that are not covered by standard Lynis checks. The existing PKGS-7398-nix-audit.sh script validates these controls but is not integrated into the automated audit workflow. This leaves NixOS systems with incomplete compliance reporting - they may fail generic PKGS-7398 checks while actually having stronger supply chain security than traditional package managers.

## What Changes

- Integrate PKGS-7398-nix-audit.sh execution into the audit workflow for NixOS systems
- Add NixOS supply chain security status to compliance reports (compliance.md and asset-inventory.txt)
- Create new compliance check function `check_nixos_supply_chain()` in lib/_library
- Store nix-audit output in audit output directory for reference
- Update ISO27001 compliance checklist to include NixOS-specific supply chain verification

## Capabilities

### New Capabilities
- `nixos-supply-chain-audit`: Execute and parse NixOS supply chain security audit (PKGS-7398-nix-audit.sh) during system audit, validate signature enforcement, trusted substituters configuration, and store integrity

### Modified Capabilities
- `iso27001-compliance-reporting`: Add NixOS supply chain security status to compliance checklist when OS is NixOS

## Impact

**Modified Files:**
- `RUNME.sh`: Add nix-audit execution in audit command (only for NixOS systems)
- `lib/_library`: Add `check_nixos_supply_chain()` function to parse nix-audit output
- `lib/_library`: Update `generate_compliance_report()` to include NixOS supply chain status
- `lib/_library`: Update `generate_asset_inventory()` to include NixOS supply chain field

**New Files:**
- `output-*/nix-supply-chain-audit.txt` - NixOS supply chain audit output (generated during audit)

**Detection Logic:**
- Check if OS is NixOS (from lynis-report.json or neofetch.json)
- Only run nix-audit.sh if NixOS detected
- Skip gracefully on non-NixOS systems (no impact)

**User Impact:**
- NixOS users will see additional "NixOS Supply Chain" field in compliance reports
- Non-NixOS users see no change
- Audit command runtime increases by ~5-10 seconds on NixOS systems (due to `nix store verify`)
