## 1. Resolver in the library

- [x] 1.1 Add `hb_parse_output_dirname()` setting `HB_DIR_HOSTNAME`,
      `HB_DIR_USERNAME` and `HB_DIR_DATE`, anchored on the `DD-MM-YYYY` suffix
- [x] 1.2 Return non-zero and leave all three empty when the name does not parse
- [x] 1.3 Add `hb_audit_username()` reading `fastfetch.json`, then
      `neofetch.json`, then `neofetch.txt`, then the parsed directory name
- [x] 1.4 Return non-zero and print nothing when no source answers
- [x] 1.5 Add `hb_report_basename()` building
      `honeybadger-{user}-{date}-{kind}.md`, falling back to
      `honeybadger-{kind}-{today}.md`

## 2. Replace the four call sites

- [x] 2.1 `generate_compliance_report` - report name and the `Eigenaar` field
- [x] 2.2 `generate_lynis_actions_report` - report name
- [x] 2.3 `generate_xlsx_asset_row_report` - report name, `scan_user`, and the
      username handed to `_write_asset_inventory_json`
- [x] 2.4 `generate_asset_inventory` - owner, so the txt and the json call the
      same function
- [x] 2.5 Confirm no `output-([^-]+)-([^-]+)-(.+)$` remains in the tree

## 3. Tests

- [x] 3.1 Add `tests/test_audit_identity.sh`
- [x] 3.2 Parse every real directory name in this repository, plus both
      acceptance-test hosts and `pankhuri-prakash-IdeaPad-5-14ARE05-root`
- [x] 3.3 Cover a username containing a hyphen, recovered from the audit data
- [x] 3.4 Cover the fetch-file precedence order and the neofetch.txt shape
- [x] 3.5 Cover the failure path: no source, no parsable name
- [x] 3.6 Cover report naming, including the fallback
- [x] 3.7 Assert `asset-inventory.txt` and `asset-inventory.json` agree on the
      username for a hyphenated hostname
- [x] 3.8 Add a guard test that the old regex is not reintroduced

## 4. Documentation

- [x] 4.1 Add a `## NEXT VERSION` CHANGELOG entry

## 5. Verification

- [x] 5.1 `./tests/run-tests.sh` passes in full
- [x] 5.2 `shellcheck` reports nothing new
- [x] 5.3 `bash -n` on the changed files
- [x] 5.4 Demonstrate against the real `output-mbp-van-pim-pim-07-04-2026` in
      this repository: username `pim`, report named `honeybadger-pim-07-04-2026`
