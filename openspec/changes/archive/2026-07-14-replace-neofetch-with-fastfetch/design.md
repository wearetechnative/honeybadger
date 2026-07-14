## Context

honeybadger gebruikt neofetch om system-metadata te verzamelen (OS, kernel, hostname, CPU, geheugen) en slaat dit op als `neofetch.json` in de audit output. `check-os-status.sh` leest dit bestand en vergelijkt kernel-versies tegen een hardcoded database die stopt bij kernel 6.12 — terwijl de huidige stable 6.18 is.

neofetch is gearchiveerd op GitHub en wordt niet meer onderhouden. fastfetch is de actief ontwikkelde opvolger. fastfetch ondersteunt een JSON-configuratiesysteem waarmee extra Command-modules kunnen worden toegevoegd die honeybadger-specifieke compliance-data opleveren: live kernel-vergelijking via kernel.org, laatste update-datum, en reboot-status.

## Goals / Non-Goals

**Goals:**
- Vervang neofetch door fastfetch als systeem-info tool
- Ship een honeybadger-specifieke fastfetch config (`lib/fastfetch-config.jsonc`) voor consistente output ongeacht de persoonlijke config van de gebruiker
- Voeg `kernel_latest`, `last_update`, `reboot` en `updates` velden toe aan de audit output
- Vervang de hardcoded kernel-database in check-os-status.sh door live vergelijking via `kernel_latest`
- Implementeer distro-aware kernel-vergelijking: exacte patch-vergelijking voor NixOS/Arch, serie-EOL-detectie voor Debian/Ubuntu

**Non-Goals:**
- Nieuwe secties toevoegen aan het compliance-rapport voor `last_update` of `reboot` (velden worden verzameld, nog niet gerapporteerd)
- macOS-ondersteuning voor `kernel_latest` (macOS gebruikt geen Linux-kernel, kernel.org is niet van toepassing)
- Ondersteuning voor andere fastfetch-versies dan die beschikbaar is via de distro package manager

## Decisions

### 1. Text output → flat JSON (niet native fastfetch JSON)

**Beslissing:** Roep fastfetch aan in tekst-modus en parse naar flat JSON, identiek aan de huidige neofetch-aanpak.

**Reden:** fastfetch's `--json` output bevat geen `key`-veld voor Command-modules — alleen `{"type": "Command", "result": "..."}` zonder label. De tekst-output wél: `OS: NixOS 26.05...`, `Kernel Latest: 6.18.38`. Positie-gebaseerde extractie uit JSON is fragiel bij config-wijzigingen.

**Alternatief overwogen:** Native fastfetch JSON opslaan en per type-positie extracten. Afgewezen: breekt bij elke config-aanpassing en maakt de parseer-logica afhankelijk van module-volgorde.

**Resulterende aanroep:**
```bash
sudo -u "${actual_user}" fastfetch \
  --config "$thisdir/lib/fastfetch-config.jsonc" \
  --logo none --pipe \
  | jq -Rn '...' > "$output/fastfetch.json"
```

### 2. Shipped config in lib/

**Beslissing:** Ship `lib/fastfetch-config.jsonc` als canonieke config voor audits; negeer de persoonlijke config van de gebruiker via expliciete `--config`.

**Reden:** Zonder shipped config produceert fastfetch voor elke gebruiker andere output (andere modules, andere volgorde). De jq-parser verwacht een vaste set velden. De drie nieuwe compliance-velden (Kernel Latest, Last Update, Reboot) zitten in de config als Command-modules — die bestaan alleen als ze in de config staan.

### 3. Output bestandsnaam: `fastfetch.json`

**Beslissing:** Gebruik `fastfetch.json` als output-bestandsnaam. Behoud `neofetch.json` als fallback in check-os-status.sh voor achterwaartse compatibiliteit met gearchiveerde outputs.

**Reden:** Duidelijkere naamgeving. Oude audit-outputs blijven werken.

### 4. Distro-aware kernel-vergelijking

**Beslissing:** Splits kernel-vergelijkingslogica op basis van OS:
- **NixOS, Arch**: exacte patch-vergelijking (running kernel = upstream versie)
- **Debian, Ubuntu**: alleen serie-EOL-detectie; toon upstream versie als referentie, geen patch-vergelijking

**Reden:** Debian en Ubuntu onderhouden hun eigen kernel-patchnummering. Debian 12's kernel is `6.1.0-28-amd64` — het "0" is geen upstream patch maar Debian's ABI-versie. Upstream heeft 6.1.177. Dit verschil van 177 patches is misleidend. Ubuntu 24.04 draait kernel 6.8 die upstream EOL is, maar door Ubuntu zelf nog wordt ondersteund — ook dit vereist een nuance in de melding.

**Detectie:** `$OS_NAME` is al beschikbaar in check-os-status.sh via de bestaande OS-extractielogica.

### 5. Verwijder hardcoded kernel-database volledig

**Beslissing:** Verwijder de `case "$KERNEL_MAJOR.$KERNEL_MINOR"` database en vervang door logica gebaseerd op `kernel_latest`.

**Reden:** De database was al verouderd (max 6.12, huidige stable 6.18). Live data via `kernel_latest` is altijd actueel. Als `kernel_latest` leeg is (serie bestaat niet in kernel.org releases), is de serie upstream EOL.

**Fallback:** Als `kernel_latest` ontbreekt (geen internet, fastfetch.json afwezig, oud neofetch.json), rapporteer "kernel-serie status onbekend — controleer kernel.org" zonder EXIT_CODE te wijzigen.

## Risks / Trade-offs

**Netwerk-afhankelijkheid tijdens audit** → Mitigatie: curl heeft 3s timeout in de fastfetch config. Als kernel.org niet bereikbaar is, is `kernel_latest` leeg; check-os-status.sh handelt dit af als "onbekend" zonder te falen.

**fastfetch niet geïnstalleerd op doelsystemen** → Mitigatie: `checkdeps "fastfetch"` in RUNME.sh geeft een duidelijke foutmelding voor de audit start. Honeybadger werkt al op NixOS (altijd beschikbaar), Ubuntu/Debian (package: `fastfetch`), Arch (package: `fastfetch`).

**Achterwaartse compatibiliteit gearchiveerde outputs** → Mitigatie: check-os-status.sh behoudt de volledige fallback-keten: `fastfetch.json` → `neofetch.json` → `neofetch.txt` → `fastfetch.txt` → `lsb_release.txt`.

**Cross-distro Command-modules** → Trade-off: de `Last Update` Command-module heeft geen Arch Linux-pad (gebruikt `pacman` log niet). Veld wordt dan `n/a`. Dit is acceptabel voor de eerste versie; Arch-support kan later worden toegevoegd aan de config.
