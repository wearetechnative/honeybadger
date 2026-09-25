## 1. Recognise The Download Name

- [x] 1.1 Add a function to `lib/_library` that takes an archive base name and returns the asset ID
      and the proof_file value when it matches the pattern in `design.md`, and nothing otherwise;
      verify with shell tests for `TARI-00023-2026-09-17-wouter.toorren.tar.gz`,
      `TARI-00042-2026-09-17.tar`, `honeybadger-lobos-wtoorren-25-09-2026.tar.gz`,
      `PF3NCBYR-2026-09-17.tar.gz`, `TARI-00023-2026-09-17-wouter.toorren (1).tar.gz` and a
      non-existent date such as `TARI-00023-2026-02-30.tar.gz`

## 2. Fill A And N

- [x] 2.1 Give `generate_xlsx_asset_row_report()` an optional archive name argument; when it is a
      download name, move `A` and `N` into the determined table with the archive name as their
      provenance, and leave `C` and `O` in the operator-maintained section; verify with a render
      test that asserts the two cell values and that `A` and `N` are absent from the
      operator-maintained section
- [x] 2.2 Without the argument, or with a name that does not match, verify the report is
      byte-identical to the report the current code produces for the same output directory
- [x] 2.3 Pass the base name of the archive from `check-output` in `RUNME.sh`, and nothing when it
      is given a directory; verify by running `check-output` on a copy of a repository tarball
      renamed to `TARI-00023-2026-09-17-wouter.toorren.tar.gz`

## 3. Documentation

- [x] 3.1 Describe in `README.md`, where the xlsx report is documented, that `A` and `N` are filled
      when `check-output` runs on an archive downloaded from badgersbay
- [x] 3.2 Add a CHANGELOG entry under `## NEXT VERSION`
