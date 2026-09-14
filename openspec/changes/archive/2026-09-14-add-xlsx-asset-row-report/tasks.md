## 1. Value Extraction

- [x] 1.1 Add `generate_xlsx_asset_row_report()` to `lib/_library`, deriving the report filename
      from the output directory name with the same pattern as `generate_lynis_actions_report()`;
      verify a call against `output-lobos-wtoorren-14-09-2026` writes
      `honeybadger-wtoorren-14-09-2026-xlsx.md`
- [x] 1.2 Extract the pass-through columns `D` (serial from `hardware-serial.txt`), `E` (model from
      `fastfetch.json` `.host`) and `F` (OS from `lynis-report.json` `.os_fullname`); verify each
      matches the value shown in `asset-inventory.txt` for the same output directory
- [x] 1.3 Normalise the boolean columns `G` (LUKS in `blockdevices.txt`), `H`
      (`AUTO-LOCK-STATUS: ENABLED` in `screenlock-info.txt`) and `I` (reuse
      `check_firewall_status()`) to `Yes`/`No`; verify all three yield `Yes` for the 14-09 tarball
- [x] 1.4 Extract column `K` as the bare `.hardening_index` with no suffix or status marker, and
      capture the applied `MIN_HARDENING_SCORE` and whether it was met for the provenance column;
      verify the 14-09 tarball yields cell value `64` and provenance naming the `≥65` threshold as
      not met
- [x] 1.5 Map column `L` from `os-kernel-status.txt` with `PASS`→`Yes`, `WARNING`→`Yes`,
      `FAIL`→`No`, unrecognised→`N.A.`; verify the 14-09 tarball (a `WARNING`) yields `Yes` with
      provenance recording the warning
- [x] 1.6 Derive the column `J` finding from `.package_audit_tool_found` and
      `.vulnerable_packages_found` across the three states in `design.md`; verify the 14-09 tarball
      (both `0`) reports "not determined — no package audit tool present" and never presents the
      zero count as compliant

## 2. Report Rendering

- [x] 2.1 Render the header with hostname, scan date and the "locate the row by Serial Number"
      instruction; verify the 14-09 tarball names serial `PF50L2MR`, and that a directory with
      `hardware-serial.txt` removed instead states the row cannot be identified automatically
- [x] 2.2 Render the filled-columns table with a `Celwaarde` and a `Vastgesteld als` column for
      each of `D`–`L`; verify every row shows both a cell value and the finding it came from
- [x] 2.3 Render column `J` without a cell value, stating the finding plus the note that the
      register's data validation and `Status` formula disagree on which literal means compliant;
      verify the note is present regardless of which of the three states applies
- [x] 2.4 Render the operator-maintained section listing `A`, `C`, `N` and `O` with no cell values,
      showing the scan username as a hint for `C` and noting that the register uses full names;
      verify the 14-09 tarball shows `wtoorren` as the hint
- [x] 2.5 Render the formula section marking `B` and `M` as not-to-be-overwritten and reproducing
      `=MID(N2,12,10)`; verify both columns appear and the formula is literal
- [x] 2.6 Pad markdown tables narrower than 90 characters with spaces so the borders align; verify
      by inspecting the generated file

## 3. Integration

- [x] 3.1 Call `generate_xlsx_asset_row_report()` from `check-output` in `RUNME.sh` after the
      actions report, with a matching progress line; verify a full `check-output` run prints the
      new generation step
- [x] 3.2 Add the new file to the closing "Generated files" summary of `check-output`; verify all
      three reports are named
- [x] 3.3 Verify the report survives tarball cleanup by running `check-output` against
      `honeybadger-lobos-wtoorren-14-09-2026.tar.gz` and confirming the file remains after the
      extracted directory is removed

## 4. Robustness

- [x] 4.1 Verify the report is generated with `N.A.` for the affected columns when individual
      source files are missing, by removing `blockdevices.txt`, `screenlock-info.txt` and
      `os-kernel-status.txt` in turn from a copied output directory
- [x] 4.2 Verify the report is still generated, naming the unavailable data, when
      `lynis-report.json` is absent or unparseable, and that `check-output` exits without error
- [x] 4.3 Verify no code path opens or writes the `.xlsx`, by running `check-output` with
      `iso27001-compliance-essential.xlsx` present and confirming its checksum is unchanged

## 5. Regression and Documentation

- [x] 5.1 Run `check-output` against all three `honeybadger-lobos-wtoorren-*.tar.gz` tarballs and
      verify the compliance and actions reports are byte-identical to their pre-change output
- [x] 5.2 Cross-check each generated xlsx report against the register's data validation: `G`, `H`,
      `I`, `L` are one of `Yes`/`No`/`N.A.`, and `K` is a bare number or `N.A.`
- [x] 5.3 Document the new report in `README.md` alongside the compliance and actions reports, and
      add a `## NEXT VERSION` → `### Added` entry to `CHANGELOG.md`; verify both mention the
      filename pattern
