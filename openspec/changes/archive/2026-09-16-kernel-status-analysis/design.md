## Context

`analyze_kernel_status()` in `lib/_library` (regel 549) is een lege stub die alleen `$KERNEL_VERSION` print. De omliggende infrastructuur is volledig aanwezig:

- `fastfetch.json` bevat al een `kernel_latest`-veld (bijv. `"6.18.38 (2026-07-04)"`) dat door het fastfetch-script tijdens collectie wordt ingevuld via kernel.org
- `kernel-releases.json` wordt al opgehaald door `fetch_os_releases()` als cache-fallback
- `check_os_status()` roept `analyze_kernel_status()` al aan maar vangt de returnwaarde niet op
- `generate_status_summary()` werkt alleen op `os_status_result`, niet op kernelstatus

De bestaande `check-os-status` spec beschrijft distro-aware kernelanalyse. Deze change implementeert die spec.

## Goals / Non-Goals

**Goals:**
- `analyze_kernel_status()` volledig implementeren: type (LTS/stable/mainline), EOL-status, patchcurrency
- Distro-aware logica: exacte vergelijking voor NixOS/Arch, EOL-only voor Ubuntu/Debian
- Gecombineerde eindstatus in `generate_status_summary()` via worst-of(os_status, kernel_status)
- `get_kernel_info()` startswith-bug fixen (ontbrekende trailing dot)

**Non-Goals:**
- Kerneldata ophalen buiten de bestaande `fetch_os_releases()` flow
- Wijzigingen in collectiescripts (fastfetch-script is buiten scope)
- Windows of macOS kernelanalyse

## Decisions

### Beslissing 1: Data-bronvolgorde — fastfetch.json boven kernel-releases.json

`kernel_latest` in `fastfetch.json` is de primaire bron. Deze waarde is tijdens collectie al opgezocht en gecached per systeem. `kernel-releases.json` dient als fallback als `fastfetch.json` ontbreekt of `kernel_latest` leeg is.

**Reden:** `fastfetch.json` bevat de exacte versie voor de draaiende serie — geen extra jq-parsing over een volledige releaselijst nodig. Bovendien werkt check-output dan ook offline (na collectie hoeft geen netwerkverzoek).

**Alternatief overwogen:** Altijd `kernel-releases.json` gebruiken. Nadeel: vereist netwerk tijdens check-output; trage analyse als cache verlopen is.

### Beslissing 2: kernel_latest parseformaat

`kernel_latest` heeft het formaat `"6.18.38 (2026-07-04)"`. De versie wordt geëxtraheerd met `grep -oE '^[0-9]+\.[0-9]+\.[0-9]+'` op het eerste woord, de datum met `grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}'`.

**Reden:** Simpele POSIX-compatibele extractie zonder jq-afhankelijkheid voor dit veld. Robuust tegen extra annotaties in het veld.

### Beslissing 3: Distro-aware vergelijkingslogica

| OS | Logica |
|----|--------|
| NixOS, Arch | Exacte patch-vergelijking: running ≠ latest → WARNING |
| Ubuntu | Serie EOL → WARNING + noot "Ubuntu may backport"; patch-delta: alleen tonen als info, geen WARNING |
| Debian | Serie EOL → WARNING + noot "Debian maintains own patch numbering"; patch-delta: info only |

**Reden:** Ubuntu en Debian backporten security-patches naar hun eigen kernelnummering. Een patch-delta ten opzichte van upstream zegt niets over Debian/Ubuntu security coverage. Serie-EOL is wél relevant omdat Ubuntu/Debian dan ook stoppen met backports.

### Beslissing 4: Returnwaarde via stdout (consistent patroon)

`analyze_kernel_status()` schrijft rapportinhoud naar `$report_file` via `>>` en geeft status (`pass`/`warning`/`fail`/`unknown`) via `echo` op stdout — identiek aan `analyze_nixos_status()` en `analyze_ubuntu_status()`.

**Reden:** Bestaand patroon in de library; geen globale variabelen nodig.

### Beslissing 5: Worst-of combinatie in generate_status_summary

```
combined = fail   als os_status=fail OFWEL kernel_status=fail
combined = warning als os_status=warning OFWEL kernel_status=warning
combined = pass   als beide pass
combined = os_status als kernel_status=unknown (geen kernel-data beschikbaar)
```

Kernel-status `unknown` degradeert de OS-status niet, zodat systemen zonder fastfetch-data of zonder kernel-releasecache niet onterecht een lagere score krijgen.

## Risks / Trade-offs

- **kernel_latest formaat verandert** → Mitigation: de extractie-regex is specifiek genoeg om stille mismatch te detecteren; functie valt terug op `unknown` bij lege extractie, geen foutieve status
- **fastfetch.json ontbreekt in oude archieven** → Mitigation: fallback naar kernel-releases.json cache; als beide ontbreken: `unknown`, geen rapport-fout
- **kernel.org releases.json listing EOL-datum ontbreekt** → kernel.org's `iseol` boolean is voldoende; expliciete EOL-datum is niet nodig
- **startswith-bug fix in get_kernel_info()** → bestaande callers gebruiken deze functie niet in productiepad; fix is veilig

## Migration Plan

Geen datamigratiepad nodig. Bestaande output-directories werken ongewijzigd:
- Archieven met `fastfetch.json` krijgen betere kernelrapportage
- Archieven zonder `fastfetch.json` vallen terug op cache of tonen `unknown`

Rollback: de vier gewijzigde functies zijn onafhankelijk van externe state — revert van de commits herstelt vorig gedrag.
