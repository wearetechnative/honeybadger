## 1. Typed scalar rendering

- [x] 1.1 Factor the cell's rendering rule into `_inventory_scalar()`: empty is
      null, an integer is a number, anything else is a JSON string
- [x] 1.2 Use it for the cell, keeping the `N.A.` / `zie notitie` mapping in the
      cell path where it belongs
- [x] 1.3 Use it for the extra value, so `count` is a number and `tool` stays a
      string

## 2. Carry the count

- [x] 2.1 Determine the count in the column J block alongside the finding text,
      gated on `package_audit_tool_found` exactly as the finding text is
- [x] 2.2 Leave it empty when no report, or no audit tool, is present
- [x] 2.3 Pass it to `_inventory_finding` as `count`
- [x] 2.4 Leave the cell value and the xlsx report untouched

## 3. Schema version

- [x] 3.1 Bump `schema_version` to 2

## 4. Tests

- [x] 4.1 Cover `_inventory_scalar` rendering: empty, integer, negative, string,
      a string that only looks numeric
- [x] 4.2 Cover a numeric extra rendering as a number and `tool` as a string
- [x] 4.3 Cover count present, determined zero, no audit tool, no report
- [x] 4.4 Assert `value` stays null while `count` carries the measurement
- [x] 4.5 Assert a determined count is distinguishable from an undetermined one
      without reading the finding text
- [x] 4.6 Assert `schema_version` is 2
- [x] 4.7 End-to-end over a fixture output directory, through
      `generate_xlsx_asset_row_report`

## 5. Documentation

- [x] 5.1 Update the `README.md` example, which shows the old shape
- [x] 5.2 Add a `## NEXT VERSION` CHANGELOG entry

## 6. Verification

- [x] 6.1 `./tests/run-tests.sh` passes in full
- [x] 6.2 `shellcheck` reports nothing new
- [x] 6.3 `bash -n` on the changed files
- [x] 6.4 Demonstrate both platform cases from the bug report: a determined
      count of 1 and an undetermined count with no audit tool
