## Why

Honeybadger's reports are meant to be handed to an ISO27001 auditor, and an auditor reads them
as one body of evidence. Today the three reports produced from a single scan can state different
things about the same control, because each report re-derives the verdict itself.

Screen lock is the clearest case. `check_screen_lock_status()` (`lib/_library:1472`) applies the
≤15-minute policy limit. Two other places read the same evidence file with their own inline
`grep` and apply no limit at all: `generate_asset_inventory()` (`lib/_library:955`) and
`generate_xlsx_asset_row_report()` (`lib/_library:2492`). On a device with a 30-minute auto-lock
the compliance checklist says `❌ Timeout too long (30 minutes)`, the asset inventory in that
same file says `Yes (Auto-lock: 30 minutes)`, and the xlsx report proposes cell value `Yes`.

The hardening score contradicts itself in a second way. The compliance checklist marks it `ℹ️`
and excludes it from the verdict, the asset inventory appends `❌ NON-COMPLIANT (required: ≥65)`,
and `ISO27001-LAPTOP-COMPLIANCE.md:19` calls it a blocker at `≥75`. A scan scoring 64 therefore
reports `✅ Compliant` and `❌ NON-COMPLIANT` in the same document.

A third problem is not a contradiction but a gap in provenance. The evidence file records
`AUTO-LOCK-STATUS:` lines from up to six independent mechanisms, and the evaluation matches the
first `ENABLED` anywhere in the file. It never records **which** mechanism produced the verdict.
In `output-lobos-wtoorren-25-08-2026/screenlock-info.txt` the reported "5 minutes" comes from
GNOME `gsettings` on a machine with `XDG_CURRENT_DESKTOP: Not set` that is actually locked by
`hypridle`, whose config was not found. The conclusion is probably right; the stated figure is
not evidence for it. An auditor asking "how do you know it is five minutes" has no answer.

This change makes every report derive each verdict from one place, and makes each verdict state
what it was derived from. It is a precondition for the auditor-facing provenance document, which
follows as a separate change.

## What Changes

**One evaluation per control.** The `check_*` functions in `lib/_library` become the only place a
compliance verdict is formed. `generate_asset_inventory()` and `generate_xlsx_asset_row_report()`
call them instead of re-reading the evidence files. No inline `grep` on an evidence file may
produce a verdict.

**Three-state results.** Check functions gain an explicit third outcome for "no evidence
collected", distinct from "evidence says fail". Today both return exit code 1, which is why the
xlsx report cannot reliably tell `N.A.` from `No` without its own parsing. The convention becomes
`0` = pass, `1` = fail, `2` = indeterminate.

**Verdict and detail are separated.** Each check returns a human-readable detail string and a
verdict. Reports format the detail to their own needs — `Yes (Auto-lock: 5 minutes)` for the
asset inventory, `Yes` for a spreadsheet cell — without re-deciding the verdict.

**The screen lock verdict names its source.** The collection step writes a closing summary block
to `screenlock-info.txt` recording which mechanism was selected as authoritative, why, and
whether its timeout could be established. A mechanism that is installed and running outranks
settings read from a desktop environment that is not the active session. Where the timeout cannot
be established the report says so instead of quoting a number from an unrelated source.

**GNOME is gated at collection time like every other mechanism.** GNOME is the only source that
emits `AUTO-LOCK-STATUS: ENABLED` without checking its own computed timeout against the
15-minute limit. The evidence file becomes self-consistent.

**The hardening threshold becomes configurable, defaulting to 65.** `MIN_HARDENING_SCORE` moves
into `.honeybadger.conf` alongside the existing settings, with `65` as the default so no existing
scan changes outcome. Because the applied norm is now configuration rather than a constant, every
report that shows the score SHALL also state the threshold it applied.

**The hardening score is informational everywhere.** It is a relative Lynis index, not an ISO27001
control. It is shown as `ℹ️` with the score and the applied threshold, and never contributes to
the overall verdict. The `❌ NON-COMPLIANT` marker is removed from `asset-inventory.txt`.

**The malware rows stop contradicting each other.** The checklist row `Lynis malware scan` reports
whether `lynis-report.json` exists, while the asset inventory field `Malware Scanner` reports
`.malware_scanner_installed`. The checklist row is renamed to `Lynis scan uitgevoerd` and the
asset inventory field to `Malware Scanner (AV product)`, so the two answer visibly different
questions.

**Windows is aligned on thresholds and provenance.** `AUDIT.ps1` keeps its single inline
evaluation, which is already internally consistent, and keeps requiring `ScreenSaverIsSecure` —
a genuine platform difference, recorded rather than removed. Its screen lock limit is confirmed
as the same 900 seconds, and its report gains the same explicit statement of applied threshold.

## Capabilities

### Modified Capabilities

- `xlsx-asset-row-report`: cell values are derived from the shared check functions rather than
  re-parsed; `N.A.` becomes a distinct outcome from `No`; the hardening provenance states a
  configured rather than constant threshold.
- `windows-compliance-reporting`: the screen lock and antivirus rows state the applied threshold
  and the settings the verdict rests on.

### Added Capabilities

- `iso27001-compliance-reporting`: this capability has delta specs in
  `iso27001-compliance-reporting-overhaul` and `add-nixos-supply-chain-check` but was never synced
  into `openspec/specs/`, so there is no requirement text to modify. The delta here is written as
  an addition. See Impact.

## Impact

**Code**
- `lib/_library`: `check_*` functions gain the three-state convention and a detail/verdict split;
  `generate_asset_inventory()`, `generate_compliance_report()` and
  `generate_xlsx_asset_row_report()` lose their inline evaluation logic; `load_server_config()`
  gains `MIN_HARDENING_SCORE`.
- `RUNME.sh`: the screen lock collection block gains the GNOME timeout gate and the closing
  authoritative-source summary.
- `AUDIT.ps1`: threshold statement in the compliance checklist.
- `.honeybadger.conf.example`: documents `MIN_HARDENING_SCORE`.
- `ISO27001-LAPTOP-COMPLIANCE.md`: corrected to state the configured default of 65 and that the
  score is informational, not a blocker.

**Evidence format**
- `screenlock-info.txt` gains a closing summary block. Existing sections are unchanged, so
  previously collected tarballs remain parseable; the shared function falls back to current
  behaviour when the summary block is absent, and marks the source as undetermined.

**Behavioural changes to existing scans**
- A device with auto-lock enabled but a timeout over 15 minutes flips from `Yes` to `No` in
  `asset-inventory.txt` and in the xlsx report. This is the fix, not a regression.
- A device whose screen lock timeout cannot be established reports the timeout as undetermined
  rather than quoting an unrelated mechanism's figure.
- No device changes hardening-score outcome; only the presentation of that outcome changes.

**Explicitly out of scope**
- The auditor-facing provenance document. It is the motivation for this change and follows as a
  separate change once the behaviour it describes is stable.
- The remaining open tasks in `iso27001-compliance-reporting-overhaul` (OS update status check,
  hardware serial in the system information section). No overlap.
- Syncing the `iso27001-compliance-reporting` capability from its existing change deltas into
  `openspec/specs/`.
- Any change to what is collected, beyond the screen lock summary block.
- Reconciling the `Vulnerable Packages / Defender` column contradiction in the spreadsheet, which
  `add-xlsx-asset-row-report` documented and deliberately left to the operator.
