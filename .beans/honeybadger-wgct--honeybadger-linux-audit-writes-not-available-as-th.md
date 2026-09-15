---
# honeybadger-wgct
title: 'honeybadger: Linux audit writes ''Not available'' as the serial'
status: scrapped
type: bug
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:56Z
updated_at: 2026-09-15T21:16:56Z
---

**Superseded by honeybadger-ck4l, which covers NixOS, Ubuntu, Debian, Arch and macOS together and brings an OpenSpec change (`openspec/changes/reliable-hardware-serial/`).**

---
---
# honeybadger-wgct
title: 'honeybadger: Linux-audit schrijft ''Not available'' als serienummer zonder root'
status: todo
type: bug
priority: high
tags:
    - honeybadger
    - linux
    - iso27001
created_at: 2026-09-15T20:35:28Z
updated_at: 2026-09-15T20:35:28Z
---

`RUNME.sh:171-175` schrijft stilzwijgend `Not available` weg zodra `dmidecode`
niet in PATH staat:

    if command -v dmidecode >/dev/null 2>&1; then
      dmidecode -s system-serial-number ... || echo "Not available" > ...
    else
      echo "Not available" > "$output/hardware-serial.txt"
    fi

## Correctie op de eerste diagnose

Dit is geen root-probleem. `RUNME.sh:84` eist al root en stopt anders, dus elke
audit die output opleverde draaide als root. De oorzaak is simpelweg dat
`dmidecode` op sommige machines niet geinstalleerd is - op NixOS zit hij niet
standaard in PATH. Waar hij wel in het profiel zit (lobos) kwam er een geldig
serienummer uit; waar niet (technative-casper, nixos-pankhurip) kwam er
`Not available`.

## De tool is niet nodig

De kernel exposeert het serienummer al, root-only, zonder externe tool:

    $ ls -l /sys/class/dmi/id/product_serial
    -r-------- 1 root root 4096 /sys/class/dmi/id/product_serial
    $ sudo cat /sys/class/dmi/id/product_serial
    PF50L2MR

Geen dmidecode, geen netwerk, geen nix, en het werkt op elke Linux met SMBIOS.
`nix run nixpkgs#dmidecode` werkt ook, maar vereist flakes, netwerk bij de
eerste run en is trager - alleen zinvol als laatste redmiddel.

## Gemeten op compute2-prod

Van de 22 opgeslagen archieven:

    FRANMDCPA750850030   lego2-pim                  bruikbaar
    PF50L2MR             lobos-wtoorren             bruikbaar
    FRANDGCPA5530200H9   Jeroen-jeroen              bruikbaar
    PF50L2ML             mathijs-p16s-mathijs       bruikbaar
    MP1Y69AC             pankhuri-... (3 archieven) bruikbaar

    Not available        SammyMBPro-Sammy           (macOS, andere tak)
    Not available        technative-casper-casper   (4 archieven)
    Not available        nixos-pankhurip            (4 archieven)

## Waarom dit nu telt

badgersbay `asset-register-identity` koppelt inzendingen op serienummer. Zonder
serial valt een inzending in `reports/unmatched/` met reden `no_serial` en telt
het asset niet mee voor de ronde. De inzending gaat niet verloren en het
dashboard zegt precies wat eraan schort, maar het asset blijft openstaan.

## Op te lossen

1. Lees `/sys/class/dmi/id/product_serial` als eerste bron. De audit draait al
   als root, dus dit werkt zonder enige afhankelijkheid.
2. Val terug op `dmidecode -s system-serial-number` als die wel aanwezig is en
   sysfs niets oplevert.
3. Als laatste redmiddel op NixOS: `nix run nixpkgs#dmidecode -- -s
   system-serial-number`, met `--extra-experimental-features "nix-command
   flakes"`. Vereist netwerk bij de eerste run.
4. Valideer wat er wordt weggeschreven met dezelfde regel die de server
   hanteert: één token, geen witruimte, geen placeholder. Voldoet het niet, dan
   luid waarschuwen in plaats van stil `Not available` wegschrijven - de
   operator moet aan het eind van de run zien dat het asset niet koppelbaar is.
5. Onderscheid "niet gevonden" van "hardware heeft er geen". Een VM heeft vaak
   legitiem geen serienummer; dat is een ander geval dan een ontbrekende tool
   en alleen het tweede is op te lossen.

## Niet als checkdeps

`dmidecode` toevoegen aan `checkdeps` (`RUNME.sh:33`) zou de audit laten falen
op machines waar sysfs het prima doet. De afhankelijkheid is het serienummer,
niet de tool die het ophaalt.
