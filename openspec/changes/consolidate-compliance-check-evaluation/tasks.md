## 1. Three-State Check Convention

- [ ] 1.1 Extend `status_icon()` in `lib/_library` to render `0` → `✅`, `1` → `❌`, `2` → `❓`;
      verify the three exit codes produce the three icons and that no other value reaches it
- [ ] 1.2 Change `check_disk_encryption()` to return `2` when `blockdevices.txt` is absent,
      keeping `1` for a present file with no `crypto_LUKS` entry; verify against
      `output-lobos-wtoorren-25-08-2026` (returns `0`) and against a copy with the file removed
      (returns `2`)
- [ ] 1.3 Change `check_firewall_status()` to return `2` when neither `lynis-report.json` nor a
      live `iptables`/`nftables` probe can establish a state, keeping `1` for an established
      absence; verify the 25-08 tarball still returns `0` with detail `Yes (iptables)`
- [ ] 1.4 Change `check_vulnerable_packages()` to return `2` when `lynis-report.json` is absent or
      `jq` is unavailable; verify the 25-08 tarball still returns `0` with detail `None`
- [ ] 1.5 Change `check_lynis_scan_exists()` to the same convention; verify it returns `0` for a
      tarball containing `lynis-report.json`
- [ ] 1.6 Update the blocker logic in `generate_compliance_report()` so only exit code `1` adds to
      `critical_issues`; verify a scan with `blockdevices.txt` removed reports the control as `❓`
      and does not list "Geen disk encryptie" as a blocker

## 2. Screen Lock Provenance

- [ ] 2.1 Add the GNOME timeout gate to the collection block in `RUNME.sh` so it emits
      `AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG` above 900 seconds like every other mechanism; verify a
      run with `idle-delay` set to 1800 writes `TIMEOUT-TOO-LONG` rather than `ENABLED`
- [ ] 2.2 Append an authoritative-source summary block to `screenlock-info.txt` in `RUNME.sh`,
      recording the selected mechanism, the rank rule that selected it, the established timeout
      or the fact that it is undetermined, and the resulting status; verify on the maintainer's
      NixOS/Hyprland machine that it selects the running `hypridle` and marks the timeout
      undetermined
- [ ] 2.3 Implement the rank order from `design.md` in the collection block: running daemon,
      config of a running daemon, settings of the DE named by `XDG_CURRENT_DESKTOP`, settings of
      any other DE; verify a machine with GNOME schemas installed but `XDG_CURRENT_DESKTOP` unset
      does not select GNOME
- [ ] 2.4 Rewrite `check_screen_lock_status()` to read the summary block when present, returning
      `0` for an established timeout ≤15 minutes, `1` above it, and `2` when auto-lock is enforced
      but the timeout is undetermined or no mechanism was found; verify each of the four outcomes
      against hand-built fixture files
- [ ] 2.5 Keep the pre-summary fallback path in `check_screen_lock_status()` for archived
      tarballs, marking the source as undetermined in the detail string; verify
      `honeybadger-lobos-wtoorren-14-07-2026.tar.gz` still evaluates without error and says the
      source could not be established

## 3. Configurable Hardening Threshold

- [ ] 3.1 Add `MIN_HARDENING_SCORE="${MIN_HARDENING_SCORE:-65}"` to `load_server_config()` in
      `lib/_library`; verify an unconfigured run reports `65` and a `.honeybadger.conf` setting
      `MIN_HARDENING_SCORE=75` reports `75`
- [ ] 3.2 Remove the local `MIN_HARDENING_SCORE=65` from `generate_asset_inventory()` and
      `HB_MIN_HARDENING_SCORE=65` from the xlsx report generator, so the configured value is the
      only declaration; verify `grep -c 'HARDENING_SCORE=65' lib/_library` returns 1
- [ ] 3.3 Remove the `✅ COMPLIANT` / `❌ NON-COMPLIANT` suffix from the hardening line in
      `asset-inventory.txt`, replacing it with the score and the applied threshold as context;
      verify the 25-08 tarball renders `64/100 (Good) - drempel >=65` with no verdict marker
- [ ] 3.4 Add the applied threshold to the hardening row of the compliance checklist; verify it
      renders `ℹ️ | 64/100 (drempel >=65)`
- [ ] 3.5 Confirm the hardening score is absent from `critical_issues` and from the overall status
      calculation; verify a scan scoring below the threshold with all other controls passing still
      reports `✅ Compliant`
- [ ] 3.6 Document `MIN_HARDENING_SCORE` in `.honeybadger.conf.example` with its default and a
      note that the applied value appears in every report

## 4. Report Generators Call The Shared Functions

- [ ] 4.1 Replace the inline screen lock `grep` in `generate_asset_inventory()` with a call to
      `check_screen_lock_status()`, formatting the detail string for the inventory; verify the
      25-08 tarball produces the same line as before for a compliant device
- [ ] 4.2 Replace the inline screen lock `grep` in `generate_xlsx_asset_row_report()` with a call
      to the same function, mapping exit code to `Yes`/`No`/`N.A.`; verify a fixture with a
      30-minute timeout now yields `No` where it previously yielded `Yes`
- [ ] 4.3 Replace the inline disk encryption `grep` in `generate_asset_inventory()` with a call to
      `check_disk_encryption()`; verify the 25-08 tarball still reports `Yes (LUKS)`
- [ ] 4.4 Audit the three report generators for any remaining direct read of an evidence file that
      produces a verdict; verify by grepping each generator for `blockdevices.txt`,
      `screenlock-info.txt` and `nix-supply-chain-audit.txt` and confirming every remaining hit is
      a verbatim include rather than an evaluation
- [ ] 4.5 Rename the compliance checklist row `Lynis malware scan` to `Lynis scan uitgevoerd` and
      the asset inventory field `Malware Scanner` to `Malware Scanner (AV product)`; verify the
      25-08 tarball shows `Lynis scan uitgevoerd | ✅ | Yes` alongside
      `Malware Scanner (AV product) | No` without appearing contradictory

## 5. Regression Against Collected Evidence

- [ ] 5.1 Re-run `check-output` against every tarball in the repository
      (`honeybadger-lobos-wtoorren-14-07-2026`, `-25-08-2026`, `-14-09-2026`,
      `Jeroen-jeroen-honeybadger-20260914-121249`) and record which verdicts move; produce a short
      list of device, control, old value, new value
- [ ] 5.2 Confirm every moved verdict is explained by one of the three intended corrections
      (screen lock limit now applied, indeterminate distinguished from failed, hardening marker
      removed), and that no verdict moved for another reason
- [ ] 5.3 Verify the three reports generated from one tarball state the same verdict for every
      control, for each tarball in 5.1
- [ ] 5.4 Answer the open question in `design.md` using the 5.1 results: whether an indeterminate
      screen lock sets the overall status to "Gedeeltelijk compliant" or leaves it untouched, and
      record the decision in `design.md`

## 6. Windows Alignment

- [ ] 6.1 Add the applied 900-second limit and the settings the verdict rests on to
      `$script:screenLockDetails` in `AUDIT.ps1`; verify a compliant run states both
- [ ] 6.2 Add a line to the "Screen Lock Configuration" section stating that a password on resume
      is required for a passing verdict on Windows; verify it appears in a generated report
- [ ] 6.3 Add the applied 7-day definition age limit to the antivirus detail in `AUDIT.ps1`;
      verify a compliant run states it
- [ ] 6.4 Confirm no numeric hardening threshold is introduced on Windows, since HardeningKitty
      reports per-check counts rather than an index

## 7. Documentation

- [ ] 7.1 Correct the hardening threshold in `ISO27001-LAPTOP-COMPLIANCE.md` from `≥75` to the
      configured default of `65`, and change its classification from blocker to informational;
      verify the table no longer marks the score with `❌ Blocker`
- [ ] 7.2 Update the `Check Methode` column of that table so each row names the shared check
      function rather than only the evidence file
- [ ] 7.3 Add a CHANGELOG entry under `## NEXT VERSION` describing the consolidation, the
      three-state outcome, the configurable threshold, and the screen lock provenance, noting
      explicitly that some devices will move from compliant to non-compliant on screen lock
