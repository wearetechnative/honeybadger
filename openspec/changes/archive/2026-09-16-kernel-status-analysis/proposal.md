## Why

`analyze_kernel_status()` in `lib/_library` is a stub: het print alleen het kernelnummer en doet verder geen analyse. De bijbehorende `check-os-status` spec beschrijft al volledig hoe de functie moet werken, inclusief distro-aware vergelijking en EOL-detectie — maar de implementatie ontbreekt volledig. Daardoor geeft elk rapport "PASS" ongeacht of de kernel EOL is of een patch achterloopt.

## What Changes

- **Implementeer `analyze_kernel_status()`** — volledige uitwerking conform de bestaande `check-os-status` spec: lees `kernel_latest` uit `fastfetch.json`, pas distro-aware vergelijkingslogica toe, return `pass`/`warning`/`fail`/`unknown` via stdout
- **Update aanroeplocatie in `check_os_status()`** — vang de return-waarde van `analyze_kernel_status()` op als `kernel_status_result`
- **Extend `generate_status_summary()`** — voeg `kernel_status` toe als parameter; combineer os_status + kernel_status tot eindresultaat via worst-of logica
- **Fix `get_kernel_info()` startswith-bug** — ontbrekende trailing dot zorgt dat `"6.1"` ook `6.10.x`, `6.11.x` etc. matcht

## Capabilities

### New Capabilities
- *(geen nieuwe capabilities — dit implementeert een bestaande spec)*

### Modified Capabilities
- `check-os-status`: toevoegen van combined kernel+OS eindstatus in `generate_status_summary()`, en gedocumenteerde fallback-volgorde voor kernel data (fastfetch.json → kernel-releases.json cache)

## Impact

- `lib/_library` — vier functiewijzigingen (analyze_kernel_status, check_os_status aanroep, generate_status_summary, get_kernel_info)
- Bestaande rapporten: pankhurip-output toont nu "⚠ WARNING" in plaats van "✓ PASS" vanwege kernel 6.18.37 vs 6.18.38
- Ubuntu/Debian rapporten: krijgen nu zinvolle kernel-sectie in plaats van lege sectie
- Geen API-wijzigingen; `kernel-releases.json` wordt al opgehaald door bestaande `fetch_os_releases()`

## Reconciliation before archiving

This change was completed but never archived, and the code moved on beneath it.
Checked against the client before archiving:

| Requirement | Still true |
|-------------|------------|
| `analyze_kernel_status()` returns `pass`/`warning`/`fail`/`unknown` on stdout | yes - `fail` is emitted directly in the EOL branch |
| The report generator passes the kernel status to `generate_status_summary()` | yes |
| `generate_status_summary()` applies worst-of logic | yes |
| `get_kernel_info()` uses a trailing dot in the version match | yes |

One name was stale. `check_os_status()` became `generate_os_status_report()` in
`os-status-severity-not-an-exit-code`, because it writes a report and its exit
status never carried a severity. The requirement is restated under the new name;
nothing else changed. See bean honeybadger-9llx.
