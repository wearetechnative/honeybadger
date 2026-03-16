# Cache Integratie Gids

Dit document beschrijft hoe `check-os-status.sh` kan worden geüpdatet om dynamische release informatie van internet te gebruiken.

## Overzicht

Het systeem bestaat uit twee componenten:

1. **fetch-os-releases.sh** - Haalt release info op van endoflife.date en kernel.org
2. **check-os-status.sh** - Gebruikt de gecachte data voor OS/kernel status checks

## Beschikbare API's

### endoflife.date APIs
- **NixOS**: `https://endoflife.date/api/nixos.json`
- **Ubuntu**: `https://endoflife.date/api/ubuntu.json`
- **Debian**: `https://endoflife.date/api/debian.json`

### Kernel.org API
- **Linux Kernel**: `https://www.kernel.org/releases.json`

## Cached Data Formaat

### NixOS (.cache/nixos-releases.json)
```json
[{
  "cycle": "25.11",
  "codename": "Xantusia",
  "releaseDate": "2025-11-30",
  "eol": "2026-06-30",
  "lts": false
}, ...]
```

### Ubuntu (.cache/ubuntu-releases.json)
```json
[{
  "cycle": "24.04",
  "codename": "Noble Numbat",
  "lts": true,
  "releaseDate": "2024-04-25",
  "eol": "2029-05-31",
  "support": "2029-05-31",
  "extendedSupport": "2036-05-31"
}, ...]
```

### Kernel (.cache/kernel-releases.json)
```json
{
  "releases": [{
    "moniker": "mainline|stable|longterm",
    "version": "6.19",
    "iseol": false,
    "released": {
      "timestamp": 1770584607,
      "isodate": "2026-02-08"
    }
  }, ...]
}
```

## Integratie Voorbeelden

### Helper Functies (al toegevoegd aan check-os-status.sh)

```bash
get_latest_nixos_release() {
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.[0].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null
    fi
}

get_nixos_eol_date() {
    local version="$1"
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r ".[] | select(.cycle == \"$version\") | .eol" "$CACHE_DIR/nixos-releases.json" 2>/dev/null
    fi
}

check_nixos_is_current() {
    local version="$1"
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        local latest=$(jq -r '.[0].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
        if [[ "$version" == "$latest" ]]; then
            echo "current"
        else
            local second_latest=$(jq -r '.[1].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
            if [[ "$version" == "$second_latest" ]]; then
                echo "previous"
            fi
        fi
    fi
}
```

### Gebruik in NixOS Case Statement

**VOOR (hard-coded):**
```bash
if [[ "$MAJOR" == "25" && "$MINOR" == "11" ]]; then
    echo "Status: YES - CURRENT STABLE RELEASE" >> "$REPORT_FILE"
    echo "EOL Date: May 2026 (~6 months)" >> "$REPORT_FILE"
```

**NA (dynamisch):**
```bash
# Get actual EOL date from cached data
NIXOS_STATUS=$(check_nixos_is_current "$OS_VERSION")
NIXOS_EOL=$(get_nixos_eol_date "$OS_VERSION")
LATEST_NIXOS=$(get_latest_nixos_release)

if [[ "$NIXOS_STATUS" == "current" ]]; then
    echo "Status: YES - CURRENT STABLE RELEASE" >> "$REPORT_FILE"
    echo "EOL Date: $NIXOS_EOL" >> "$REPORT_FILE"
elif [[ "$NIXOS_STATUS" == "previous" ]]; then
    echo "Status: YES - PREVIOUS STABLE (still supported)" >> "$REPORT_FILE"
    echo "EOL Date: $NIXOS_EOL" >> "$REPORT_FILE"
    echo "Recommendation: Upgrade to $LATEST_NIXOS" >> "$REPORT_FILE"
else
    echo "Status: NO - OLD RELEASE" >> "$REPORT_FILE"
    echo "Recommendation: Upgrade to $LATEST_NIXOS immediately" >> "$REPORT_FILE"
fi
```

## Voordelen

1. **Altijd actueel** - Geen handmatige updates nodig wanneer nieuwe versies uitkomen
2. **Nauwkeurige EOL dates** - Exacte datums in plaats van schattingen
3. **Automatische detectie** - Nieuwe releases worden automatisch gedetecteerd
4. **Betrouwbare bron** - endoflife.date en kernel.org zijn authoritative bronnen
5. **Cache TTL** - 24 uur cache voorkomt onnodige API calls

## Implementatie Plan

### Fase 1: Testing (Huidig)
- ✅ fetch-os-releases.sh created
- ✅ Helper functions toegevoegd aan check-os-status.sh
- ✅ Cache werkt correct

### Fase 2: NixOS Conversie
- Replace hard-coded NixOS version checks met cache queries
- Test met alle drie test outputs
- Verify correcte EOL dates

### Fase 3: Ubuntu/Debian Conversie
- Replace Ubuntu/Debian hard-coded checks
- Add helper functions voor Ubuntu/Debian
- Test LTS detectie

### Fase 4: Kernel Conversie
- Replace kernel version checks
- Use kernel.org release data
- Detect mainline/stable/longterm status dynamisch

### Fase 5: Kali/Arch
- Kali: Use Debian API as base + kernel-based estimation
- Arch: Always current (rolling release)

## Testing

```bash
# Fetch latest releases
./lib/fetch-os-releases.sh

# Test with all outputs
./lib/check-os-status.sh output-casper-30-09-2025/
./lib/check-os-status.sh output-wtoorren-04-02-2026/
./lib/check-os-status.sh output-jeroen-01-10-2025/

# Verify cache usage
ls -lh .cache/*.json
```

## Fallback Strategie

Als cache niet beschikbaar is:
1. Script probeert automatisch `fetch-os-releases.sh` uit te voeren
2. Bij falen: script valt terug op hard-coded logica (huidige implementatie)
3. Warning in output: "Using fallback version detection (cache unavailable)"

## Onderhoud

- Cache TTL: 24 uur
- Automatische refresh bij elke `check-os-status.sh` run als cache > 24h oud
- Handmatig forceren: `./lib/fetch-os-releases.sh`

## Dependencies

- **curl** - Voor API calls
- **jq** - Voor JSON parsing
- **date** - Voor datum conversies

Alle dependencies zijn standaard beschikbaar op moderne Linux/macOS systemen.
