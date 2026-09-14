## Why

The ISO27001 asset register (`iso27001-compliance-essential.xlsx`, sheet `Active Assets`) is
maintained by hand, while `check-output` already determines most of the values that register
needs. Today the operator reads `asset-inventory.txt` and mentally translates decorated findings
such as `Yes (LUKS)` or `64/100 (Good) ❌ NON-COMPLIANT (required: ≥65)` into the constrained cell
values the spreadsheet accepts (`Yes`, `64`). That translation is repetitive, undocumented, and
easy to get wrong — and a wrong cell silently flips an asset's compliance status.

## What Changes

- `check-output` generates a third report alongside the existing compliance and actions reports:
  `honeybadger-{username}-{date}-xlsx.md`. It is always produced, never behind a flag.
- The report states, per spreadsheet column, the literal **cell value** to enter and the
  **underlying finding** it was derived from, so the entry is auditable rather than opaque.
- Nine columns are filled from scan data: `D` Serial Number, `E` Model, `F` OS Edition + Version,
  `G` Disk Encryption, `H` Screen Lock, `I` Firewall Active, `J` Vulnerable Packages / Defender,
  `K` Lynis Hardening Score, `L` OS Up-to-date.
- Four columns are listed as operator-maintained and deliberately left empty: `A` Asset,
  `C` Owner, `N` proof_file, `O` Remarks. The scan username is shown as a hint for `C`, because
  the register uses full names that the scan cannot know.
- Two columns are flagged as spreadsheet formulas that must not be overwritten: `B` Status and
  `M` Last_Audit_Date (`=MID(N2,12,10)`).
- The report identifies the target row by Serial Number, which the scan knows and which maps
  one-to-one onto column `D`.
- Column `J` reports a finding plus an explicit note instead of a cell value, because the
  spreadsheet contradicts itself about which literal means compliant (see Impact).
- Honeybadger never reads from or writes to the `.xlsx` file. The report is input for a human.

## Capabilities

### New Capabilities
- `xlsx-asset-row-report`: Generation of a human-readable report that maps audit findings onto the
  columns of the ISO27001 asset register, including value normalisation, provenance, the columns
  the tool deliberately does not fill, and the columns it must not overwrite.

### Modified Capabilities
<!-- None. The `check-output` capability has delta specs in archived changes but was never synced
     into openspec/specs/, so there is no existing requirement text to modify. Noted in Impact. -->

## Impact

**Code**
- `lib/_library`: new report-generation function, alongside `generate_compliance_report` and
  `generate_lynis_actions_report`.
- `RUNME.sh`: `check-output` calls the new function and mentions the third file in its summary.

**Data sources** (all already collected; no new collection)
- `lynis-report.json` — `.os_fullname`, `.hardening_index`, `.package_audit_tool_found`,
  `.vulnerable_packages_found`
- `hardware-serial.txt`, `fastfetch.json`, `blockdevices.txt`, `screenlock-info.txt`,
  `os-kernel-status.txt`

**Known inconsistencies in the spreadsheet, surfaced but not fixed here**
- Column `J` is contradictory: the data validation and the summary notes state
  `None` = compliant, while the `Status` formula treats `Yes` as compliant and `None` as NOK.
  All twelve existing rows contain `Yes`. The report names the conflict rather than resolving it.
- The hardening-score threshold differs per location: honeybadger uses `≥65`
  (`MIN_HARDENING_SCORE`), the `Compliance Summary` sheet flags `<75` as CRITICAL, and the
  `Status` formula checks no threshold at all. The report states which threshold it applied.
- The `Compliance Summary` sheet is broken (`#REF!`, `#VALUE!`, and "Total Assets: 1" for twelve
  assets). Out of scope.

**Explicitly out of scope**
- Writing to or modifying the `.xlsx`.
- Repairing the `Compliance Summary` sheet.
- Reconciling the hardening-score thresholds.
- Deriving Asset ID or proof_file; the operator maintains those.
