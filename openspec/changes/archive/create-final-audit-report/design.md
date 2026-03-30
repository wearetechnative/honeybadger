## Context

Honeybadger's audit genereert momenteel diverse output bestanden:
- `asset-inventory.txt` - Samenvatting van asset informatie
- `lynis-report.json` - JSON met alle Lynis audit data
- `os-kernel-status.txt` - OS EOL en kernel status
- `hardware-serial.txt`, `screenlock-info.txt`, `blockdevices.txt`, etc.

Gebruikers moeten deze bestanden handmatig doornemen. Een geconsolideerd rapport vereenvoudigt review en compliance verificatie.

**Constraints:**
- Moet werken met bestaande output formaten zonder wijzigingen aan audit flow
- Shell script voor consistentie met bestaande Honeybadger codebase
- Moet omgaan met ontbrekende bestanden (bijv. NixOS-specifieke data op niet-NixOS systemen)

## Goals / Non-Goals

**Goals:**
- Script dat bestaande audit output leest en `final-report.md` genereert
- Automatische uitvoering aan het einde van elke audit
- Overzichtelijk markdown rapport met gegroepeerde informatie
- Extractie van kernel support status en OS update stream status
- Duidelijke compliance indicatoren (✅/❌)
- Template-gebaseerde rapportage voor consistentie

**Non-Goals:**
- Wijzigingen aan bestaande audit output formaten
- Real-time rapportage tijdens audit (werkt op completed audit output)
- HTML of PDF conversie (alleen markdown)
- Interactieve rapportage of user input tijdens generatie

## Decisions

### 1. Automatische Integratie in RUNME.sh Audit Flow
**Beslissing:** Script `lib/generate-final-report.sh` wordt automatisch aangeroepen aan het einde van RUNME.sh audit functie

**Rationale:**
- Gebruiker krijgt altijd een compleet overzicht zonder extra actie
- Consistent gedrag - elk audit produceert final report
- Vermindert kans op vergeten rapport generatie
- Script blijft wel modulair en testbaar

**Alternatief overwogen:** Volledig standalone - verworpen omdat gebruikers dan handmatig rapport moeten genereren, wat vaak wordt vergeten

### 2. Data Extractie Strategie
**Beslissing:** Parse bestaande output bestanden met combinatie van:
- `jq` voor JSON parsing (lynis-report.json)
- `grep`/`awk`/`sed` voor text-based bestanden
- Conditional checks voor optionele bestanden (NixOS metadata)

**Rationale:**
- Hergebruikt bestaande, reeds gegenereerde data
- Geen duplicatie van logic
- Minimale dependencies (tools zijn al vereist voor Honeybadger)

**Alternatief overwogen:** Directe system calls - verworpen omdat het duplicatie zou veroorzaken en inconsistenties kan introduceren

### 3. Rapport Template
**Beslissing:** Embedded template in script met placeholders

**Rationale:**
- Eenvoudige implementatie
- Geen externe template files nodig
- Gemakkelijk aan te passen

**Alternatief overwogen:** Externe template file - verworpen voor simpliciteit en minder file dependencies

### 4. Kernel Support Status Detectie
**Beslissing:** Parse `os-kernel-status.txt` en supplement met lynis-report.json data

**Rationale:**
- `os-kernel-status.txt` bevat al EOL informatie
- lynis-report.json bevat kernel versie
- Combinatie geeft volledig beeld

### 5. Gebruiker Detectie (niet sudo/root)
**Beslissing:** Parse audit directory naam (bevat username) en cross-reference met `$SUDO_USER` environment variable indien beschikbaar

**Rationale:**
- Output directory format is `output-<hostname>-<user>-<date>`
- `$SUDO_USER` bevat original user wanneer via sudo gedraaid
- Fallback naar directory naam parsing

## Risks / Trade-offs

**[Risk]** Output bestanden zijn niet aanwezig of incomplete
→ **Mitigation:** Script checkt bestandsexistentie en toont "Not available" voor ontbrekende data

**[Risk]** Wijzigingen aan output formaten breken parsing
→ **Mitigation:** Gebruik robust parsing met error handling; documenteer dependencies op bestandsformaten

**[Risk]** jq niet beschikbaar op systeem
→ **Mitigation:** jq is reeds vereiste dependency voor Honeybadger (gedocumenteerd in README)

**[Trade-off]** Embedded template vs externe file
→ Embedded is simpeler maar minder flexibel; acceptabel voor MVP, kan later worden gerefactored

**[Trade-off]** Shell script complexiteit
→ Shell parsing kan fragiel zijn; acceptabel omdat input bestanden stabiel zijn en onder onze controle
