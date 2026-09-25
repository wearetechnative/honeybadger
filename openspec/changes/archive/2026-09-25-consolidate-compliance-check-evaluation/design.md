## Context

See `proposal.md` — Why. Requirements are in `specs/`.

Honeybadger separates collection from evaluation. `RUNME.sh` runs on the device and writes plain
text evidence files; `lib/_library` reads those files later, offline, and forms verdicts by
pattern-matching the text. That split is the reason the tool is auditable at all — the evidence
travels in the tarball and can be re-examined independently of the verdict.

The split is sound. What went wrong is that evaluation was never centralised, so it happened
three times with three slightly different rules.

```
 TODAY                                    screenlock-info.txt
                                                  │
                    ┌─────────────────────────────┼─────────────────────────────┐
                    │                             │                             │
          check_screen_lock_status()    inline grep (l.955)          inline grep (l.2492)
            grep ENABLED                  grep ENABLED                 grep ENABLED
            + extract minutes             + extract minutes            (no minutes)
            + GATE ≤15 min                NO GATE                      NO GATE
                    │                             │                             │
                    ▼                             ▼                             ▼
            compliance checklist          asset-inventory.txt            xlsx cell H
            "Timeout too long (30)"       "Yes (Auto-lock: 30 min)"      "Yes"
                    ❌                            ✅                            ✅
                                    ^^^^ same scan, same file, three answers ^^^^
```

```
 AFTER                                    screenlock-info.txt
                                                  │
                                                  ▼
                                    check_screen_lock_status()
                                      ├─ select authoritative source
                                      ├─ extract minutes (or: undetermined)
                                      └─ GATE ≤15 min
                                                  │
                                  detail string  +  verdict (0/1/2)
                    ┌─────────────────────────────┼─────────────────────────────┐
                    ▼                             ▼                             ▼
            compliance checklist          asset-inventory.txt            xlsx cell H
            formats to ❌/✅/⚠️            formats to prose              formats to Yes/No/N.A.
```

## Goals / Non-Goals

**Goals**
- One place per control where a verdict is formed.
- A verdict that can name the evidence it rests on.
- Reports that never contradict each other for the same scan.
- Configuration of the hardening threshold without making it invisible to the reader.

**Non-Goals**
- Changing what any check concludes, except where the current conclusion is inconsistent.
- Restructuring the evidence file format. Only an additive summary block.
- Unifying Linux and Windows evaluation into shared code. Two languages, two collection models;
  alignment is on thresholds and on what gets stated, not on implementation.

## Decisions

### Three-state exit convention

`0` pass, `1` fail, `2` indeterminate.

Today `check_disk_encryption`, `check_screen_lock_status`, `check_firewall_status` and
`check_vulnerable_packages` all return `1` both when the evidence says the control is absent and
when the evidence file itself is missing. `status_icon()` renders both as `❌`. That is wrong in
an audit context: "encryption is off" and "we could not establish whether encryption is on" are
different findings, and only the first is a blocker.

The xlsx report already needs the distinction and currently obtains it by bypassing the check
functions entirely and testing for the file itself — which is precisely the duplication this
change removes. Making it a first-class outcome removes the reason to bypass.

`status_icon()` gains a third rendering: `0` → `✅`, `1` → `❌`, `2` → `❓`. An indeterminate
control is reported as such and excluded from the blocker list, because the tool cannot assert a
failure it did not observe.

**Alternative considered:** keep two states and have callers test for the evidence file
separately. Rejected — that is the current design, and the knowledge of which file backs which
check would stay spread across three functions.

### Detail string on stdout, verdict in the exit code

Each check keeps its current shape: a human-readable string on stdout, a verdict in `$?`. The
callers differ only in formatting.

This is deliberately not a structured return (an associative array, or `key=value` on stdout).
The existing functions already work this way, callers already capture both, and the reports need
prose anyway. A structured return would be the right call if a fourth consumer appeared needing
machine-readable fields; two report formats do not justify it.

The rule that makes this work: **a caller may reformat the detail string, but may not re-derive
the verdict from it.** The xlsx report maps exit code `0`/`1`/`2` to `Yes`/`No`/`N.A.` and prints
the detail string in the provenance column. It does not parse the detail string.

### Vulnerable packages: nothing looked is not clean

The checklist row and xlsx column `J` used different Lynis fields: the checklist looked for a
PKGS-7392 warning, the xlsx report read `vulnerable_packages_found` and `package_audit_tool_found`.
On a machine without a package audit tool Lynis raises PKGS-7398, reports zero and raises no
PKGS-7392, so the checklist said `✅ None` while column `J` said "not determined". Worse, the
checklist's query applied `contains()` to warnings that current Lynis writes as objects; jq failed,
the error was discarded, and the check reported `None` whatever the report contained.

`check_vulnerable_packages()` becomes the one determination: indeterminate without a package audit
tool, failed on a count above zero or a PKGS-7392 warning in either format, passed otherwise. Column
`J` still declines a cell value - the spreadsheet's contradiction is unchanged - but its finding is
the check's detail string, and the count travels only when a tool looked.

### Authoritative source selection for screen lock

`screenlock-info.txt` can contain up to six `AUTO-LOCK-STATUS:` lines. Matching the first
`ENABLED` anywhere in the file is a genuine bug in the making: GNOME `gsettings` answers on
machines that do not run GNOME, because the schemas are installed as a dependency.

Selection order, most to least authoritative:

| Rank | Source                        | Why it ranks here                                  |
|------|-------------------------------|----------------------------------------------------|
| 1    | Daemon found **and** running  | Observed enforcing behaviour, not stated intent    |
| 2    | Config of a running daemon    | Intent of the mechanism that is actually active    |
| 3    | Settings of the active DE     | Matched against `XDG_CURRENT_DESKTOP`              |
| 4    | Settings of any other DE      | Installed schemas; may answer for nobody           |

Rank 1 establishes that *something* locks the screen but often not with what timeout — a running
`hypridle` on NixOS has its config in `/nix/store`, not `~/.config/hypr/`. The honest outcome is
then "auto-lock enforced by hypridle, timeout undetermined", which is a `2`, not a `0`. An
auditor can accept that and ask for the NixOS module definition; they cannot accept a figure
lifted from a mechanism that is not running.

The collection step writes this selection into the evidence file rather than leaving it to
evaluation, because only the device knows what was running at scan time.

**Alternative considered:** have evaluation rank the sources by re-reading the existing sections.
Rejected — the process list is already in the file but the mapping from process to config to
timeout is device-specific, and encoding it in the offline parser means the parser drifts from
what the collector knows.

### Backwards compatibility with existing tarballs

The summary block is additive and appended last. When it is absent — every tarball collected
before this change — the shared function falls back to the current behaviour (`grep` for
`ENABLED`, extract minutes, apply the gate) and marks the source as undetermined. Re-running
`check-output` on an archived tarball therefore still works, and says plainly that the
authoritative source could not be established for that scan.

### Hardening threshold as configuration

`MIN_HARDENING_SCORE` joins the existing `.honeybadger.conf` settings, loaded by
`load_server_config()`, default `65`. Two constants disappear: `MIN_HARDENING_SCORE` in
`generate_asset_inventory()` and `HB_MIN_HARDENING_SCORE` in the xlsx report, which are separate
declarations of the same number today and could already drift.

The cost of configuration is that a report no longer implies its own norm. Mitigation is a
requirement, not a convention: any report showing the score must state the threshold it applied.
The xlsx report already does this (`64/100 - drempel >=65 niet gehaald`); the compliance checklist
and asset inventory must start doing it.

`load_server_config()` is named for its original purpose but is already the general config entry
point — it loads `USE_DOCKER_CONVERTER`, which has nothing to do with the server. Renaming it is
churn for no gain and is left alone.

### Hardening score is informational

Decided as policy: the Lynis hardening index is a relative measure of how many Lynis tests passed,
weighted by Lynis's own opinion, and it moves when Lynis adds tests. It is not an ISO27001
control and a threshold on it is a local convention. It is therefore shown everywhere as `ℹ️`
with score and applied threshold, and never enters the blocker list or the overall verdict.

This resolves the contradiction in the direction the compliance checklist already took, and
removes the `❌ NON-COMPLIANT` suffix from the asset inventory that contradicted it.

### Windows stays separate

`AUDIT.ps1` evaluates screen lock once, at collection time, from registry values — there is no
second implementation to reconcile. Its extra requirement (`ScreenSaverIsSecure = 1`, password on
resume) has no clean Linux equivalent: GNOME's `lock-enabled` implies it, and for a bare
`hyprlock` there is nothing to read. Removing the Windows requirement to match Linux would weaken
a correct check to match a weaker one.

So the platforms are aligned on the 900-second limit and on stating the applied threshold, and
the difference in what each platform can establish is documented rather than flattened. The
provenance document that follows this change will state it per platform.

Windows has no numeric hardening index — HardeningKitty reports per-check pass/fail counts — so
the threshold decision does not apply there.

## Risks / Trade-offs

**Devices flip to non-compliant.** Any device with auto-lock over 15 minutes currently shows `Yes`
in two of three reports and will show `No` in all three. This is the intended correction, but it
will look like a regression in the asset register. Mitigation: the tasks include re-running
`check-output` against the tarballs in the repository and recording which outcomes move, so the
change lands with a known list rather than a surprise.

**Indeterminate outcomes will appear where certainty appeared before.** Notably screen lock on
NixOS/Hyprland, which is the maintainer's own machine. `❓` is less comfortable than `✅` but it is
the accurate statement, and an auditor is better served by a named gap than by a confident number
with no basis.

**Configuration hides the norm.** Addressed by requiring the threshold in every report that shows
the score, but a reader of a raw `asset-inventory.txt` from an unknown host now needs that line to
interpret the number.

## Migration Plan

No data migration. Old tarballs remain readable through the documented fallback. The change is a
single release; reports regenerated after it are internally consistent, reports generated before
it are not, and the provenance document will state from which version consistency is guaranteed.

## Resolved Questions

### An indeterminate control holds the device at partial compliance

**Question:** should an indeterminate screen lock (`❓`) set the overall status to "Gedeeltelijk
compliant", as a disabled screen lock does, or leave the overall status untouched?

**Decision:** "Gedeeltelijk compliant", with the gap named. Confirmed by the maintainer after the
re-run in task 5.1.

An unverifiable control is not a demonstrated control. The same rule applies to every control that
returns `2`, not only screen lock: an indeterminate disk encryption, firewall, vulnerable-package or
NixOS supply chain check is not a blocker - the tool cannot assert a failure it did not observe -
but it keeps the device out of "✅ Compliant". The compliance report lists each one under
`### Niet vastgesteld` in the check's own words.

**What 5.1 showed:** for screen lock, none of the six archived tarballs moves. Every one predates the summary block
and records a 5-minute timeout with all evidence files present, so the fallback evaluates them as
before. The re-run also showed that the maintainer's own NixOS/Hyprland machine
would have been the first device affected: `hypridle` runs, but its configuration was read from
`$HOME/.config/hypr`, which under `sudo` is root's home. Task 2.6 reads it from `$SUDO_USER`'s home
instead, so that machine resolves to `hypridle` at rank 2 with its configured timeout.

Task 4.6 does move verdicts. Every NixOS tarball reports vulnerable packages as `❓`, because no
package audit tool looked; the three that were `✅ Compliant` (15-09, 17-09, 22-09) become
"Gedeeltelijk compliant", and 14-07 and 25-08 stay "Niet compliant" on their firewall. Jeroen's
Debian scan, where `apt-get` looked, stays `✅ None (apt-get)`. This is the intended correction:
those scans never established that the packages were clean.
