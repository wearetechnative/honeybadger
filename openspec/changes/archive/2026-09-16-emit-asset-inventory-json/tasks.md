## 1. Serialisation

- [x] 1.1 Emit `asset-inventory.json` from the same determinations that produce
      `asset-inventory.txt` — no second derivation path
- [x] 1.2 Include `schema_version`, `generated_at`, `honeybadger_version`,
      `platform`
- [x] 1.3 Include `identity`: serial, hostname, username, model
- [x] 1.4 Each finding carries `value` and `finding`; `hardening_score` also
      carries `tool`
- [x] 1.5 A deliberately undetermined value is `null` with a populated
      `finding`, never an omitted key

## 2. Packaging

- [x] 2.1 Include the file in the output directory
- [x] 2.2 Include it in the tar archive
- [x] 2.3 Owned by the actual user, per `audit-output`

## 3. Verify

- [x] 3.1 Values in the JSON match `asset-inventory.txt` for the same run
- [x] 3.2 Values match the cell values in the xlsx report for the same run
- [x] 3.3 Vulnerable packages serialises as `null` plus finding on a system with
      no package audit tool
- [x] 3.4 Output is valid JSON on a system where several determinations fail

## 4. Docs

- [x] 4.1 `CHANGELOG.md` under NEXT VERSION
- [x] 4.2 `README.md`: name the file and its purpose as the machine-readable
      counterpart of the asset inventory
