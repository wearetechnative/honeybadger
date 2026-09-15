## 1. Serialisation

- [ ] 1.1 Emit `asset-inventory.json` from the same determinations that produce
      `asset-inventory.txt` — no second derivation path
- [ ] 1.2 Include `schema_version`, `generated_at`, `honeybadger_version`,
      `platform`
- [ ] 1.3 Include `identity`: serial, hostname, username, model
- [ ] 1.4 Each finding carries `value` and `finding`; `hardening_score` also
      carries `tool`
- [ ] 1.5 A deliberately undetermined value is `null` with a populated
      `finding`, never an omitted key

## 2. Packaging

- [ ] 2.1 Include the file in the output directory
- [ ] 2.2 Include it in the tar archive
- [ ] 2.3 Owned by the actual user, per `audit-output`

## 3. Verify

- [ ] 3.1 Values in the JSON match `asset-inventory.txt` for the same run
- [ ] 3.2 Values match the cell values in the xlsx report for the same run
- [ ] 3.3 Vulnerable packages serialises as `null` plus finding on a system with
      no package audit tool
- [ ] 3.4 Output is valid JSON on a system where several determinations fail

## 4. Docs

- [ ] 4.1 `CHANGELOG.md` under NEXT VERSION
- [ ] 4.2 `README.md`: name the file and its purpose as the machine-readable
      counterpart of the asset inventory
