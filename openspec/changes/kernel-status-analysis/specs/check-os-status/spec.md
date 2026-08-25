## ADDED Requirements

### Requirement: analyze_kernel_status retourneert een statuswaarde
`analyze_kernel_status()` SHALL een statuswaarde retourneren via stdout (`pass`, `warning`, `fail`, of `unknown`) zodat de aanroepende functie deze kan verwerken.

#### Scenario: Kernel is ondersteund en up-to-date (NixOS/Arch)
- **WHEN** `analyze_kernel_status()` wordt aangeroepen
- **AND** de kernelserie is niet EOL
- **AND** de draaiende patchversie overeenkomt met `kernel_latest`
- **THEN** SHALL de functie `pass` retourneren via stdout

#### Scenario: Kernel is ondersteund maar patch achter (NixOS/Arch)
- **WHEN** `analyze_kernel_status()` wordt aangeroepen voor een NixOS of Arch systeem
- **AND** de kernelserie is niet EOL
- **AND** de draaiende patchversie is lager dan `kernel_latest`
- **THEN** SHALL de functie `warning` retourneren via stdout
- **AND** SHALL het rapport de draaiende versie en de beschikbare versie tonen

#### Scenario: Kernel is ondersteund maar patch achter (Ubuntu/Debian)
- **WHEN** `analyze_kernel_status()` wordt aangeroepen voor een Ubuntu of Debian systeem
- **AND** de kernelserie is niet EOL
- **AND** de draaiende patchversie is lager dan `kernel_latest`
- **THEN** SHALL de functie `pass` retourneren via stdout
- **AND** SHALL het rapport de upstream patchversie tonen als referentie-informatie
- **AND** SHALL het rapport een noot bevatten dat Ubuntu/Debian eigen kernel-patchnummering bijhoudt

#### Scenario: Kernelserie is EOL (alle distros)
- **WHEN** `analyze_kernel_status()` wordt aangeroepen
- **AND** `kernel_latest` is leeg of afwezig (serie EOL)
- **AND** `kernel-releases.json` bevestigt `iseol: true` voor de serie
- **THEN** SHALL de functie `fail` retourneren via stdout
- **AND** SHALL het rapport de serie melden als "upstream EOL"

#### Scenario: Geen kerneldata beschikbaar
- **WHEN** `fastfetch.json` geen `kernel_latest`-veld bevat
- **AND** `kernel-releases.json` niet beschikbaar is of de serie niet bevat
- **THEN** SHALL de functie `unknown` retourneren via stdout
- **AND** SHALL de kernelstatus het eindsysteem-oordeel niet negatief beïnvloeden

### Requirement: check_os_status combineert OS- en kernelstatus
`check_os_status()` SHALL de returnwaarde van `analyze_kernel_status()` opvangen en doorgeven aan `generate_status_summary()`.

#### Scenario: Kernelstatus wordt doorgegeven aan samenvatting
- **WHEN** `check_os_status()` wordt aangeroepen
- **AND** `analyze_kernel_status()` retourneert een statuswaarde
- **THEN** SHALL die waarde als `kernel_status_result` worden opgeslagen
- **AND** SHALL `generate_status_summary()` worden aangeroepen met zowel `os_status_result` als `kernel_status_result`

### Requirement: generate_status_summary verwerkt gecombineerde status
`generate_status_summary()` SHALL zowel `os_status` als `kernel_status` accepteren en het eindoordeel bepalen via worst-of logica.

#### Scenario: OS pass, kernel warning — eindresultaat is warning
- **WHEN** `generate_status_summary()` wordt aangeroepen met `os_status=pass` en `kernel_status=warning`
- **THEN** SHALL het rapport "⚠ WARNING" tonen als eindresultaat
- **AND** SHALL de aanbevelingen kernel-specifiek advies bevatten

#### Scenario: OS pass, kernel fail — eindresultaat is fail
- **WHEN** `generate_status_summary()` wordt aangeroepen met `os_status=pass` en `kernel_status=fail`
- **THEN** SHALL het rapport "✗ FAIL" tonen als eindresultaat

#### Scenario: Kernel unknown degradeert OS-status niet
- **WHEN** `generate_status_summary()` wordt aangeroepen met `kernel_status=unknown`
- **THEN** SHALL het eindresultaat gelijk zijn aan `os_status`
- **AND** SHALL geen degradatie plaatsvinden vanwege ontbrekende kerneldata

### Requirement: get_kernel_info gebruikt trailing dot in versievergelijking
`get_kernel_info()` SHALL een trailing dot toevoegen aan het zoekpatroon om te voorkomen dat `"6.1"` ook `6.10.x`, `6.11.x` etc. matcht.

#### Scenario: Zoekpatroon met trailing dot voorkomt valse matches
- **WHEN** `get_kernel_info()` wordt aangeroepen met kernel_version `"6.1"`
- **THEN** SHALL alleen releases die beginnen met `"6.1."` worden gematcht
- **AND** SHALL releases zoals `"6.10.x"` of `"6.11.x"` niet worden geretourneerd
