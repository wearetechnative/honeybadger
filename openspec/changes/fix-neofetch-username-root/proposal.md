# Change: Fix Neofetch Username Shows Root

## Why
Currently, when running `sudo ./RUNME.sh audit`, neofetch captures "root" as the username instead of the actual user who invoked sudo. This happens because:
- Audit requires root privileges (via sudo)
- neofetch runs within the audit script as root
- neofetch reports the current user (root) instead of the original user

This causes:
- **Incorrect user identification** in neofetch.json (shows "root@hostname" instead of "actualuser@hostname")
- **Inconsistent reporting**: Output directory uses correct username (via SUDO_USER), but neofetch.json shows root
- **Potential compliance issues**: Asset inventory and reports may show wrong user ownership
- **Server submission confusion**: X-Username header shows correct user, but neofetch.json shows root

Example of current behavior:
- User runs: `sudo ./RUNME.sh audit`
- Output directory: `output-hostname-wtoorren-17-03-2026` ✓ (correct)
- neofetch.json: `{"user": "root", ...}` ✗ (incorrect)
- Server X-Username header: `wtoorren` ✓ (correct)

## What Changes
- Run neofetch as the actual user (not as root)
- Use `sudo -u` to execute neofetch with original user privileges
- Preserve SUDO_USER environment variable for user detection
- Ensure neofetch.json captures correct username

## Impact
- Affected specs: `system-information-collection` (modify existing requirement)
- Affected code:
  - `RUNME.sh`: Modify neofetch command to run as actual user (line ~141)
- User experience: neofetch.json will show correct username
- Backward compatibility: Non-breaking change (fixes incorrect data)
- Reports: Asset inventory and compliance reports will show correct user ownership
- Consistency: All outputs (directory name, neofetch.json, server headers) use same username
