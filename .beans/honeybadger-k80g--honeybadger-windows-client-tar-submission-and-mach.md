---
# honeybadger-k80g
title: 'honeybadger: Windows client tar submission and machine-readable output'
status: completed
type: feature
priority: high
tags:
    - honeybadger
created_at: 2026-09-15T21:16:56Z
updated_at: 2026-09-18T09:01:07Z
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


## Summary of Changes

OpenSpec change 2026-09-18-windows-tar-submission.

The Windows client now produces the same archive every other platform does and
submits it over the same path, so the two Windows assets can be filed by
badgersbay rather than delivered by hand.

• lib/Honeybadger.psm1 holds the logic that is not Windows-specific. Nothing in
the Windows client had ever been covered by a test, because it was two
top-to-bottom scripts and the machines it is developed on have no PowerShell.
The module runs under pwsh on Linux; AUDIT.ps1 keeps only what genuinely needs
Windows.

• fastfetch.json replaces neofetch.txt, in the flat shape RUNME.sh produces,
from lib/fastfetch-config-windows.jsonc. No fallback to Win32_OperatingSystem:
a file with some keys missing is indistinguishable from a machine where those
values could not be read.

• hardware-serial.txt and hardware-serial-source.txt are written and judged by
the same rule lib/_library applies. The client stored the literal "Not
available (VM or unknown hardware)" where a measured serial belongs; that is a
placeholder under the shared rule and is now none-present, distinct from
could-not-read.

• asset-inventory.json in generation 2, platform windows. hardening_score
carries a null value with tool hardeningkitty and the measured counts, because
HardeningKitty has no 0-100 figure and an invented one would be compared
against the fleet Lynis scores.

• output-<host>-<user>-<dd-MM-yyyy>/ inside honeybadger-...tar.gz. The zip is
gone rather than kept beside it - it is the bundle the server cannot attribute.

• submit-report.ps1 posts to SERVER_URL/submit-tar as application/x-tar with a
bearer token and X-Hostname / X-Username, with 4xx / 207 / 5xx handling,
backoff, DRY_RUN and environment overrides.

## Two defects found while doing it

submit-report.ps1 printed "$config.SERVER_URL", which PowerShell renders as the
hashtable type name plus a literal .SERVER_URL, so the operator was never shown
where the report went.

$TarFile is declared [string], so assigning $null stores "" and the -eq $null
check never fired: with no archive present the operator got "Archive not found:
" with nothing after the colon instead of being told to run the audit. Found by
the end-to-end run, not by reading; a guard test now pins it.

## Verification

Full suite green: 12 files, the bash suite unchanged plus 99 Pester tests.
openspec validate --all 23/23. PSScriptAnalyzer clean on the new module; no new
findings on AUDIT.ps1 and one fewer on submit-report.ps1. No new shellcheck
findings.

Verified against the unfixed client: all 13 script guards fail there. End to
end against a real HTTP server, the client sends POST /submit-tar,
Content-Type: application/x-tar, X-Hostname, bearer token, no X-Report-Type,
and the gzip bytes as-is; 207 is reported as partial without retry, 400 prints
the server body and does not retry, 503 retries with backoff and exits
non-zero, DRY_RUN sends nothing, and an empty hostname refuses to submit.

## Not done here

Windows data collection itself is not covered by the suite - it is the part
that genuinely needs Windows. The archive has not yet been produced on a real
Windows machine; that is honeybadger-dtrv.

Whether the measured serial matches the ISO register is honeybadger-wbq4.
