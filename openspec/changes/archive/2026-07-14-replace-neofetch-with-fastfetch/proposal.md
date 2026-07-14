## Why

neofetch is unmaintained (archived on GitHub) and produces only flat text output that must be parsed heuristically. fastfetch is its actively maintained successor and supports native JSON output plus a flexible module system. The current honeybadger code already has partial fastfetch references (`fastfetch.txt` fallback in check-os-status.sh, `fastfetch:*` in allowed commands), indicating this migration was anticipated.

Beyond the tool swap, fastfetch with a shipped config enables collection of three compliance-relevant fields that neofetch could never provide:
- **Kernel Latest** — fetches the current upstream patch for the running kernel series from kernel.org in real time
- **Last Update** — when the system was last updated (cross-distro: apt/dnf/pacman/nix)
- **Reboot** — whether a pending reboot is required

These allow replacing the hardcoded kernel version database in check-os-status.sh (which topped out at kernel 6.12 while current stable is 6.18+) with live upstream data.

## What Changes

- Replace `neofetch` call in RUNME.sh with `fastfetch`, using a honeybadger-shipped config
- Ship `lib/fastfetch-config.jsonc` as the canonical fastfetch config for audits
- Output `fastfetch.json` (same flat JSON structure as neofetch.json, plus new fields)
- Update check-os-status.sh to recognize `fastfetch.json`
- Remove hardcoded kernel version database from check-os-status.sh
- Add live kernel comparison using `kernel_latest` field, with distro-aware logic:
  - **NixOS / Arch**: exact patch-level comparison (upstream version = running version)
  - **Debian / Ubuntu**: series EOL detection only (distro maintains own patch numbering)

## Capabilities

### New Capabilities
- `fastfetch-system-info`: Collect system information using fastfetch with a shipped config, producing `fastfetch.json` with fields including `kernel_latest`, `last_update`, and `reboot`

### Modified Capabilities
- `check-os-status`: Replace hardcoded kernel DB with live `kernel_latest` comparison; add distro-aware patch-level logic; recognize `fastfetch.json` as input source

## Impact

**Modified Files:**
- `RUNME.sh`: Replace neofetch dependency check and invocation with fastfetch; output `fastfetch.json`
- `lib/check-os-status.sh`: Recognize `fastfetch.json`; remove hardcoded kernel DB; add live `kernel_latest` comparison with distro-aware logic

**New Files:**
- `lib/fastfetch-config.jsonc`: Shipped fastfetch config, defining modules and cross-distro command modules for OS, Kernel Latest, Last Update, Reboot, Updates

**Output Files (generated during audit):**
- `output-*/fastfetch.json`: Replaces `neofetch.json`; same flat structure plus `kernel_latest`, `last_update`, `reboot`, `updates` fields

**Backward Compatibility:**
- Existing archived outputs with `neofetch.json` continue to work (check-os-status.sh retains the `neofetch.json` fallback)
- `neofetch.txt` and `fastfetch.txt` fallbacks also retained

**Dependency Change:**
- `neofetch` removed as required dependency
- `fastfetch` added as required dependency

**User Impact:**
- Kernel section in os-kernel-status.txt now shows live upstream comparison instead of static text
- NixOS/Arch users see exact patch delta (e.g., "running 6.18.37, upstream latest 6.18.38")
- Debian/Ubuntu users see series EOL status with note that distro patch numbering differs
- `Last Update` and `Reboot` fields available in fastfetch.json for future reporting use
- Audit runtime increases by ~3 seconds on systems with internet access (kernel.org lookup)
- Audit continues gracefully if kernel.org is unreachable (curl has 3s timeout; `kernel_latest` field is empty)
