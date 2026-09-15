---
# honeybadger-nt8k
title: 'honeybadger: macOS client writes ''Mac OS X'' into hardware-serial.txt'
status: scrapped
type: bug
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:56Z
updated_at: 2026-09-15T21:16:56Z
---

**Superseded by honeybadger-ck4l, child task honeybadger-ny1g.**

---
---
# honeybadger-nt8k
title: 'honeybadger: macOS-client schrijft ''Mac OS X'' in hardware-serial.txt'
status: todo
type: bug
priority: high
tags:
    - honeybadger
    - macos
    - iso27001
created_at: 2026-09-15T20:35:28Z
updated_at: 2026-09-15T20:35:28Z
---

De macOS-client schrijft geen serienummer maar een fragment van andere output
in `hardware-serial.txt`.

## Gemeten

`2026-09/MBP-van-pim-pim/submission-20260415-083502.tar.gz` bevat:

    Mac OS X<TAB>

Dat is geen serienummer. Vermoedelijk wordt de uitvoer van
`system_profiler SPHardwareDataType` verkeerd gefilterd — daar staat "Mac OS X"
in een van de regels.

## Waarom dit telt

badgersbay `asset-register-identity` koppelt op serienummer. Deze waarde matcht
op niets en is bovendien misleidend: hij ziet eruit als een gevulde waarde,
terwijl `Not available` tenminste eerlijk is over het ontbreken.

## Op te lossen

1. Het juiste veld uitlezen. Op macOS:
   `system_profiler SPHardwareDataType | awk -F": " '/Serial Number/{print $2}'`
   of `ioreg -l | grep IOPlatformSerialNumber`
2. Valideren wat er wordt weggeschreven: een serienummer bevat geen spaties en
   geen tabs. Voldoet de waarde daar niet aan, schrijf dan `Not available`
   in plaats van de rommel.
3. Nagaan of dit ook de macOS-tak van `asset-inventory` raakt.
