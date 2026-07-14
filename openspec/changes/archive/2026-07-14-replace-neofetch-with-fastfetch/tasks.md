## 1. Shipped fastfetch config

- [x] 1.1 Maak `lib/fastfetch-config.jsonc` aan met de modules: title, OS (command), host, hostname (command), kernel, kernel-built (command), kernel-latest (command), uptime, packages, updates (command), last-update (command), reboot (command), shell, terminal, cpu, gpu, memory, disk, localip, loadavg, datetime
- [x] 1.2 Verifieer dat `fastfetch --config lib/fastfetch-config.jsonc --logo none --pipe` de verwachte tekst-output geeft met alle velden inclusief `Kernel Latest:`

## 2. RUNME.sh aanpassen

- [x] 2.1 Vervang `checkdeps "neofetch" "https://github.com/dylanaraps/neofetch"` door `checkdeps "fastfetch"`
- [x] 2.2 Vervang de neofetch-aanroep en jq-parse door fastfetch met shipped config: `sudo -u "${actual_user}" fastfetch --config "$thisdir/lib/fastfetch-config.jsonc" --logo none --pipe | jq -Rn '...' > "$output/fastfetch.json"`
- [x] 2.3 Pas de jq-expressie aan zodat de eerste regel (`user@hostname`) en de separator (`---`) correct worden afgehandeld, en alle `key: value` regels worden omgezet naar lowercase underscore-keys
- [x] 2.4 Verifieer dat `fastfetch.json` de velden `os`, `kernel`, `kernel_latest`, `last_update`, `reboot`, `updates` bevat na een test-run

## 3. check-os-status.sh: fastfetch.json herkennen

- [x] 3.1 Voeg `fastfetch.json` toe als eerste optie in de file-detectie keten (vóór `neofetch.json`): `if [[ -f "$OUTPUT_DIR/fastfetch.json" ]]; then FETCH_FILE=... FETCH_FORMAT="json"`
- [x] 3.2 Verifieer dat de bestaande jq-queries (`.os`, `.kernel`) correct werken op `fastfetch.json` (zelfde flat JSON structuur)

## 4. check-os-status.sh: hardcoded kernel-database vervangen

- [x] 4.1 Verwijder de `case "$KERNEL_MAJOR.$KERNEL_MINOR"` blok met hardcoded kernel-versies en datums (regels ~534–650)
- [x] 4.2 Lees `kernel_latest` uit de fetch file: `KERNEL_LATEST=$(jq -r '.kernel_latest // empty' "$FETCH_FILE" 2>/dev/null)`
- [x] 4.3 Implementeer basis-logica: als `kernel_latest` leeg is → "upstream EOL of status onbekend"; als `kernel_latest` aanwezig is → serie wordt onderhouden

## 5. check-os-status.sh: distro-aware kernel-vergelijking

- [x] 5.1 Implementeer NixOS-branch: vergelijk `$KERNEL_VERSION` exact tegen de versie uit `kernel_latest`; rapporteer delta of "up to date"
- [x] 5.2 Implementeer Arch-branch: zelfde exacte vergelijking als NixOS
- [x] 5.3 Implementeer Debian-branch: toon upstream-serie status en versie als referentie; voeg noot toe dat Debian eigen patch-nummering heeft; geen FAIL/WARNING op basis van patch-verschil
- [x] 5.4 Implementeer Ubuntu-branch: als `kernel_latest` leeg is (serie EOL upstream), rapporteer dit met noot dat Ubuntu eigen support kan bieden; geen FAIL op basis van upstream EOL alleen
- [x] 5.5 Implementeer fallback voor ontbrekende `kernel_latest` (bijv. bij gebruik van legacy `neofetch.json`): rapporteer "status onbekend — geen kernel_latest data"

## 6. lib/_library: fastfetch.json ondersteuning

De server (badgersbay) kent alleen `X-Report-Type: neofetch` als geldig type — "fastfetch" staat niet in de whitelist. De fix: gebruik `fastfetch.json` als bestand, maar behoud `"neofetch"` als report type zodat de server het accepteert.

- [x] 6.1 Voeg `fastfetch.json` toe als eerste optie in de fetch-file detectieketen in `_library` (~regel 264): vóór `neofetch.json`, zelfde `fetch_format="json"`
- [x] 6.2 Update hardware-info extractie (~regel 748): lees `fastfetch.json` eerst (owner, model, kernel, hostname), val terug op `neofetch.json`
- [x] 6.3 Update Nix-detectie (~regel 795): controleer `fastfetch.json` op `nix-`-patroon in packages-veld vóór `neofetch.json`
- [x] 6.4 Update OS-detectie fallback (~regel 1427): controleer `fastfetch.json` vóór `neofetch.json`
- [x] 6.5 Update submit (~regel 1211): vervang `submit_report "$output_dir/neofetch.json" "neofetch"` door logica die `fastfetch.json` probeert, terug valt op `neofetch.json`, maar altijd type `"neofetch"` gebruikt

## 7. Testen

- [x] 7.1 Voer `./RUNME.sh audit` uit op het lokale systeem en verifieer dat `output-*/fastfetch.json` aanwezig is met alle verwachte velden
- [x] 7.2 Voer `./lib/check-os-status.sh <output-dir>` uit en verifieer dat het rapport een live kernel-vergelijking bevat zonder hardcoded tekst
- [x] 7.3 Test backward compatibility: voer `./lib/check-os-status.sh` uit op een bestaande output-directory met `neofetch.json` en verifieer dat het rapport zonder fouten wordt gegenereerd
- [x] 7.4 Test ontbrekende `kernel_latest` door tijdelijk het veld leeg te maken in `fastfetch.json` en te verifiëren dat check-os-status.sh graceful afhandelt
- [x] 7.5 Verifieer submit: voer `./RUNME.sh submit` uit (of dry-run) en controleer dat `fastfetch.json` wordt ingediend met type `"neofetch"` zonder "Skipping"-melding
