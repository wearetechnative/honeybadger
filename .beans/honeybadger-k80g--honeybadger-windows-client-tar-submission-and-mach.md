---
# honeybadger-k80g
title: 'honeybadger: Windows client tar submission and machine-readable output'
status: todo
type: feature
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:56Z
updated_at: 2026-09-15T21:16:56Z
---

The Windows client produces neither a tar nor a machine-readable summary, so
Windows assets cannot be submitted through badgersbay and have to be delivered
by hand.

## Situation

Established from Elma's output (LAPTOP-AC06CMEP, 2026-09-15). The Windows client
writes loose files into a folder; Linux and macOS produce a tar with a
structured summary.

| Item          | Linux               | macOS               | Windows            |
|---------------|---------------------|---------------------|--------------------|
| Bundle        | tar.gz              | folder              | folder             |
| Submission    | RUNME.sh submit-tar | manual              | none               |
| System info   | fastfetch.json      | fastfetch.json      | neofetch.txt (art) |
| Hardening     | lynis-report.json   | lynis-report.json   | hardeningkitty.csv |
| Serial        | hardware-serial.txt | hardware-serial.txt | only in the .md    |
| Summary       | asset-inventory.txt | asset-inventory.txt | missing            |
| Score         | Lynis 0-100         | Lynis 0-100         | none               |

Consequence: 2 of the 11 ISO assets (Richard van Os, Elma Aker) bypass the
portal entirely. There is no historical evidence and no progress measurement
for them.

## Scope

1. ~~Write `hardware-serial.txt`~~ - moved to honeybadger-ck4l, together with the
   question of whether the measured value matches the ISO register.
2. Replace `neofetch.txt` with `fastfetch.json`. Decided: badgersbay and
   honeybadger use fastfetch only. `AUDIT.ps1:132-150` currently installs and
   runs neofetch; that has to become fastfetch, in the same JSON shape
   `RUNME.sh` produces.
3. Generate `asset-inventory.json` per the schema in the honeybadger change
   `emit-asset-inventory-json` - do not invent a second shape. HardeningKitty
   has no Lynis score; `hardening_score.tool` becomes `hardeningkitty`, and
   where there is no comparable figure `value` is null with a `finding`.
4. Bundle into a tar.gz with the same `output-<host>-<user>-<date>/` structure.
5. Submit from `submit-report.ps1` to `SERVER_URL/submit-tar` with a bearer
   token, per `.honeybadger.conf`.

## Found alongside this

The serial in the reporting sheet does not match for Elma:

- sheet `Active Assets` D11: `AC06CMEP`
- client measures: `YD063JGA`

`AC06CMEP` is the random suffix of the Windows hostname `LAPTOP-AC06CMEP`, not a
BIOS serial. D10 (`PF-4VBTLB`, Richard van Os) also departs from the usual
Lenovo format and is suspect. Check the sheet before the serial is used as a
join key.

## Related

- badgersbay `asset-register-identity` expects `windows` as a platform class and
  reports those assets as `manual` while this bean is open.
- honeybadger `emit-asset-inventory-json` defines the schema to produce here.
- honeybadger `fastfetch-only-system-info` clears out the legacy fallbacks;
  Windows is explicitly out of scope there and belongs to this bean.
- honeybadger-ck4l delivers `hardware-serial.txt` and the correctness of the
  serial. Blocks this bean.
