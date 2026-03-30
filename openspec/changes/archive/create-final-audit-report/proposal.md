## Why

Honeybadger genereert momenteel meerdere output bestanden per audit, maar mist een overzichtelijk finaal rapport dat alle kritieke informatie samenbrengt. Gebruikers moeten door verschillende bestanden navigeren om compliance status te begrijpen. Een gestructureerd finaal rapport maakt audits transparanter en gemakkelijker te interpreteren voor zowel gebruikers als CISO's.

## What Changes

- Nieuw script dat bestaande audit output bestanden leest en transformeert naar een overzichtelijk finaal rapport
- Automatische generatie van `final-report.md` aan het einde van elke audit
- Integratie in RUNME.sh audit workflow
- Gestructureerde weergave van:
  - Asset identificatie (serienummer, hostname, hardware, gebruiker, NixOS metadata)
  - Security controls (disk encryptie, screen lock, OS updates, firewall)
  - Compliance metrics (Lynis score, critical/high findings)
  - OS/kernel support status met duidelijke indicatoren
  - Audit metadata (datum)
- Overzichtelijke groepering van informatie met gebruik van tabellen
- Duidelijke statusindicatoren (✅/❌) voor compliance items

## Capabilities

### New Capabilities
- `final-report-generation`: Script dat bestaande audit output bestanden (lynis-report.json, asset-inventory.txt, os-kernel-status.txt, etc.) leest en transformeert naar een gestructureerd markdown rapport
- `kernel-support-status`: Extractie van kernel support status en OS update stream status uit bestaande output bestanden en weergave in rapport

### Modified Capabilities
<!-- Geen bestaande capabilities worden aangepast aan requirements niveau -->

## Impact

**Modified files:**
- `RUNME.sh` - Aanroep van generate-final-report.sh toegevoegd aan einde van audit functie

**New files:**
- `lib/generate-final-report.sh` - Script dat bestaande output bestanden leest en final-report.md genereert

**Output changes:**
- Nieuwe `final-report.md` automatisch gegenereerd in output directory na elke audit
- Geen wijzigingen aan bestaande output bestanden
