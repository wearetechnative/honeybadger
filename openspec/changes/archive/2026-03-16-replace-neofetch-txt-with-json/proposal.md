# Change: Replace neofetch.txt with neofetch.json

## Why
The current implementation uses neofetch text output which requires brittle text parsing with grep/sed. The example in `output-wtoorren-27-02-2026/neofetch-report.json` demonstrates a cleaner JSON-based approach that enables structured data access using jq, improving reliability and maintainability of system information extraction.

## What Changes
- Replace neofetch text output generation with JSON output using `neofetch --off --stdout` piped to jq
- Update all parsing code in `lib/_library` and `lib/check-os-status.sh` to use jq for JSON extraction instead of grep/sed for text parsing
- Change output file from `neofetch.txt` to `neofetch.json` in audit reports
- Remove text-based fallback code paths for neofetch data extraction

## Impact
- Affected specs: `system-information-collection` (new capability)
- Affected code:
  - `RUNME.sh:120` - neofetch generation command
  - `lib/_library:266-279` - OS info extraction
  - `lib/_library:691-702` - Hardware info extraction (owner, model, kernel, hostname)
  - `lib/_library:728` - Nix installation detection
  - `lib/check-os-status.sh:134-135` - fetch file selection
- Affected output: `neofetch.txt` → `neofetch.json` in all audit tarballs
- Existing audit outputs with `neofetch.txt` will continue to work during check-output (backward compatibility maintained)
