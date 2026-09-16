## 1. Bug fix

- [x] 1.1 Fix `get_kernel_info()` in `lib/_library`: vervang `startswith("$kernel_version")` door `startswith("${kernel_version}.")` (trailing dot toevoegen)

## 2. Implementeer analyze_kernel_status

- [x] 2.1 Vervang de stub-body van `analyze_kernel_status()` met extractielogica: lees `kernel_latest` uit `fastfetch.json` in `$output_dir` (veld `kernel_latest`)
- [x] 2.2 Voeg fallback toe: als `kernel_latest` leeg/afwezig is, zoek de kernelserie op in `kernel-releases.json` cache via `startswith("${kernel_series}.")` met trailing dot
- [x] 2.3 Implementeer EOL-detectie: kernel_latest leeg + iseol=true → `fail`; kernel_latest leeg + geen cachedata → `unknown`
- [x] 2.4 Implementeer distro-aware patchvergelijking voor NixOS en Arch: running ≠ latest → `warning`, running = latest → `pass`
- [x] 2.5 Implementeer distro-aware patchvergelijking voor Ubuntu: toon upstream patchversie als info, geen WARNING op patchdelta; voeg noot toe over eigen patchnummering
- [x] 2.6 Implementeer distro-aware patchvergelijking voor Debian: identiek aan Ubuntu (info only, geen WARNING op patchdelta)
- [x] 2.7 Zorg dat de functie de statuswaarde retourneert via `echo "$result"` op stdout (patroon consistent met `analyze_nixos_status`)

## 3. Koppel returnwaarde in check_os_status

- [x] 3.1 Update aanroeplocatie in `check_os_status()` (~regel 405-408): vervang directe aanroep door `kernel_status_result=$(analyze_kernel_status "$report_file" "$cache_dir")`
- [x] 3.2 Geef `kernel_status_result` door aan `generate_status_summary()` als extra parameter

## 4. Extend generate_status_summary

- [x] 4.1 Voeg `kernel_status` toe als derde parameter aan `generate_status_summary()` (huidige `cache_dir` wordt vierde)
- [x] 4.2 Implementeer worst-of logica vóór de case-statement: `fail` wint van `warning`, `warning` wint van `pass`, `unknown` degradeert OS-status niet
- [x] 4.3 Voeg kernel-specifieke aanbeveling toe in de `warning`-tak wanneer `kernel_status=warning` (bijv. "Update kernel via systeemupdates")
- [x] 4.4 Voeg kernel-specifieke aanbeveling toe in de `fail`-tak wanneer `kernel_status=fail`

## 5. Testen

- [x] 5.1 Voer `check-output` uit op de pankhurip-tarball: verwacht "⚠ WARNING" in Section 2 (6.18.37 vs 6.18.38) en in Overall Status
- [x] 5.2 Controleer dat het Overall Status PASS blijft wanneer kernel_status=unknown (systeem zonder fastfetch.json of cache)
- [x] 5.3 Verifieer dat een Ubuntu/Debian systeem met patch-delta geen WARNING krijgt op kernelpatch (alleen info)
- [x] 5.4 Verifieer dat een systeem met EOL-kernel (iseol=true in cache) FAIL geeft
