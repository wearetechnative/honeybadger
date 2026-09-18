## Why

Two of the eleven ISO assets run Windows, and neither can reach the portal. The
Windows client writes loose files into a folder and stops; Linux and macOS
produce a tar archive with a machine-readable summary that badgersbay files
against an asset. Established from Elma's output (LAPTOP-AC06CMEP, 2026-09-15):

| Item        | Linux               | macOS               | Windows                 |
|-------------|---------------------|---------------------|-------------------------|
| Bundle      | `tar.gz`            | folder              | folder, zipped          |
| Submission  | `RUNME.sh submit`   | manual              | none that can be filed  |
| System info | `fastfetch.json`    | `fastfetch.json`    | `neofetch.txt`, as art  |
| Hardening   | `lynis-report.json` | `lynis-report.json` | `hardeningkitty.csv`    |
| Serial      | `hardware-serial.txt` | `hardware-serial.txt` | only inside the `.md` |
| Summary     | `asset-inventory.*` | `asset-inventory.*` | missing                 |

The consequence is not that submission is inconvenient on Windows. It is that
those two assets have no historical evidence and no measurable progress, while
every other asset does.

`submit-report.ps1` exists, but it posts a zip to `SERVER_URL` itself as
`application/zip`. That endpoint has no concept of a hardware serial, which is
the field the server resolves an asset by - the same path the Linux client was
moved off in `2026-09-16-replace-submit-with-tar`, for the same reason. It also
prints `"  Server: $config.SERVER_URL"`, which PowerShell renders as the
hashtable's type name followed by a literal `.SERVER_URL`, so an operator is
never actually shown where the report went.

Underneath all of it: no part of the Windows client has ever been covered by a
test, because it is two top-to-bottom scripts and the machines it is developed
on have no PowerShell.

## What Changes

- **A module the tests can reach.** `lib/Honeybadger.psm1` holds the logic that
  is not Windows-specific - the serial usability rule, fastfetch parsing, the
  asset-inventory document, output and archive naming, configuration
  precedence, submission outcome classification. `AUDIT.ps1` and
  `submit-report.ps1` import it and keep only the parts that genuinely need
  Windows. This is what makes the rest of the change verifiable rather than
  merely written.
- **fastfetch instead of neofetch.** `fastfetch.json` in the same flat
  snake_case shape `RUNME.sh` produces, from a Windows config shipped beside
  the Linux one. No legacy format is written and none is read, per
  `system-information-collection`.
- **The serial reaches the archive.** `hardware-serial.txt` and
  `hardware-serial-source.txt`, decided by the same rule `lib/_library`
  applies. The client currently stores the literal
  `Not available (VM or unknown hardware)` as if it were a measurement; that
  string is a placeholder the shared rule rejects, and it becomes
  `none-present`.
- **`asset-inventory.json` in the existing schema.** Generation 2, `platform`
  `windows`, value-and-provenance per finding, from the determinations
  `AUDIT.ps1` already makes. `hardening_score.tool` is `hardeningkitty`.
- **A tar archive laid out like the others.** `output-<host>-<user>-<date>/`
  inside `honeybadger-<host>-<user>-<date>.tar.gz`, built with the `tar.exe`
  Windows has shipped since 1803.
- **One submission path.** POST to `SERVER_URL/submit-tar` as
  `application/x-tar` with a bearer token and `X-Hostname` / `X-Username`, with
  the 4xx / 207 / 5xx handling, the backoff and the `DRY_RUN` rehearsal the
  `report-submission` capability already defines for the Linux client.

## Capabilities

### Modified Capabilities
- `windows-security-data-collection`: system information comes from fastfetch
  as JSON rather than neofetch as text; the hardware serial is written to a
  file and judged by the shared rule; the output directory follows the shared
  naming
- `windows-compliance-reporting`: the audit emits `asset-inventory.json` and a
  tar archive beside the two markdown reports
- `asset-inventory-json`: what the document carries on a platform whose
  hardening tool produces no comparable score
- `report-submission`: the Windows client submits over the same path, to the
  same endpoint, with the same result handling

## Impact

- The two Windows assets can be submitted and filed. Nothing else changes for
  the nine that already could.
- `neofetch.txt` is no longer written. Nothing reads it: the format was already
  excluded as a fallback by `2026-09-16-fastfetch-only-system-info`, which is
  why the Windows archives it produced are unreadable to the current tooling.
- The zip is replaced rather than kept beside the tar. Two bundles of one audit
  is two things to submit and two things to keep in step, and the zip is the
  one the server cannot attribute.
- The output directory is renamed from `report-<yyyyMMdd>` to
  `output-<host>-<user>-<dd-MM-yyyy>`. Archives already produced keep their old
  layout; nothing reads them today.
- fastfetch becomes a dependency on Windows, as it already is on Linux and
  macOS. The audit installs it through winget where it can and reports clearly
  when it cannot, rather than silently degrading to a shape no consumer reads.
- The suite gains a Pester file. It is skipped with a message, not failed, when
  no `pwsh` is on PATH, so the bash suite still runs unchanged on a machine
  without PowerShell.

## Non-goals

- Whether the measured serial matches the ISO register. Elma's sheet records
  `AC06CMEP`, which is the random suffix of the hostname `LAPTOP-AC06CMEP`
  rather than a BIOS serial, and `PF-4VBTLB` on row 10 is suspect for the same
  reason. That is `honeybadger-wbq4`, and it is about the register, not the
  client.
- Lynis on Windows. HardeningKitty is the hardening tool there, and the absence
  of a 0-100 score is reported rather than approximated - a number invented to
  fill the column would be compared against the Linux fleet's real ones.
- HardeningKitty's own findings and severities. This change carries them into
  the archive; it does not revisit how they are evaluated.
- The compliance and actions markdown reports. Their content is unchanged.
