## ADDED Requirements

### Requirement: Single Evaluation Per Control
Every compliance verdict SHALL be formed in exactly one function, and every report SHALL obtain
that verdict by calling it. No report generator may derive a verdict by reading an evidence file
directly.

#### Scenario: All reports agree on screen lock

- **WHEN** a scan is evaluated in which auto-lock is enabled with a timeout above 15 minutes
- **THEN** the compliance checklist, `asset-inventory.txt` and the xlsx report all report screen
  lock as not compliant
- **AND** each report presents that same verdict in its own format

#### Scenario: Report generators do not parse evidence files for verdicts

- **WHEN** `generate_asset_inventory()` or `generate_xlsx_asset_row_report()` needs a compliance
  verdict
- **THEN** it calls the corresponding `check_*` function
- **AND** it does not read `blockdevices.txt`, `screenlock-info.txt` or `lynis-report.json` to
  decide pass or fail

### Requirement: Three-State Check Results
Check functions SHALL distinguish a failed control from a control that could not be established.
Exit code `0` means the control is in place, `1` means the evidence shows it is not, and `2`
means no sufficient evidence was collected.

#### Scenario: Evidence file missing

- **WHEN** the evidence file backing a check is absent from the output directory
- **THEN** the check returns exit code `2`
- **AND** the reports render the control as indeterminate rather than as failed
- **AND** the control is not added to the list of critical blockers

#### Scenario: Evidence file present and control absent

- **WHEN** `blockdevices.txt` is present and contains no `crypto_LUKS` entry
- **THEN** `check_disk_encryption()` returns exit code `1`
- **AND** the control is added to the list of critical blockers

#### Scenario: Indeterminate rendering

- **WHEN** a check returns exit code `2`
- **THEN** `status_icon()` renders `❓`
- **AND** the finding column states which evidence was missing

### Requirement: Verdict and Detail Are Separate
Each check SHALL return a human-readable detail string on standard output and its verdict as an
exit code. A caller MAY reformat the detail string for its output format, and SHALL NOT re-derive
the verdict from it.

#### Scenario: Same verdict rendered three ways

- **WHEN** `check_screen_lock_status()` reports auto-lock at five minutes with exit code `0`
- **THEN** the compliance checklist shows `✅` with the detail string
- **AND** `asset-inventory.txt` shows the detail string
- **AND** the xlsx report shows cell value `Yes` with the detail string as provenance

#### Scenario: Cell value derived from exit code

- **WHEN** the xlsx report fills a Yes/No column
- **THEN** it maps exit code `0` to `Yes`, `1` to `No` and `2` to `N.A.`
- **AND** it does not inspect the detail string to make that choice

### Requirement: Screen Lock Verdict Names Its Source
The screen lock evaluation SHALL establish which locking mechanism the verdict rests on, and the
reports SHALL state it. Where the enforced timeout cannot be established, the reports SHALL say
so rather than quote a timeout from a mechanism that is not active.

#### Scenario: Running daemon outranks inactive desktop settings

- **WHEN** `screenlock-info.txt` shows a running auto-lock daemon and also GNOME `gsettings`
  values while `XDG_CURRENT_DESKTOP` is not set
- **THEN** the verdict is based on the running daemon
- **AND** the GNOME timeout is not presented as the enforced timeout

#### Scenario: Lock enforced but timeout undetermined

- **WHEN** an auto-lock daemon is running and no timeout can be read from its configuration
- **THEN** the check returns exit code `2`
- **AND** the detail string states that auto-lock is enforced by that daemon and the timeout could
  not be established

#### Scenario: Active desktop environment settings are authoritative

- **WHEN** `XDG_CURRENT_DESKTOP` names a desktop environment whose settings are present in the
  evidence file
- **THEN** that environment's settings are used for the verdict

#### Scenario: Evidence collected before the summary block existed

- **WHEN** `screenlock-info.txt` contains no authoritative-source summary block
- **THEN** the check falls back to matching `AUTO-LOCK-STATUS: ENABLED` and extracting the timeout
- **AND** the detail string states that the authoritative source could not be established for that
  scan

### Requirement: Screen Lock Timeout Limit Applied Uniformly
A screen lock timeout of 15 minutes or less SHALL be required for a passing verdict, and that
limit SHALL be applied identically wherever the verdict is reported.

#### Scenario: Timeout above the limit

- **WHEN** the established screen lock timeout is above 15 minutes
- **THEN** the check returns exit code `1` in every report

#### Scenario: Collection marks its own timeout breaches

- **WHEN** the collection step establishes a timeout above 900 seconds for any mechanism,
  including GNOME
- **THEN** it writes `AUTO-LOCK-STATUS: TIMEOUT-TOO-LONG` for that mechanism rather than `ENABLED`

### Requirement: Configurable Hardening Threshold
The minimum Lynis hardening score SHALL be read from configuration as `MIN_HARDENING_SCORE`,
defaulting to `65`, and SHALL be declared in exactly one place.

#### Scenario: Default applied when unconfigured

- **WHEN** no configuration file sets `MIN_HARDENING_SCORE`
- **THEN** the threshold is `65`

#### Scenario: Configured value applied everywhere

- **WHEN** `.honeybadger.conf` sets `MIN_HARDENING_SCORE=75`
- **THEN** the compliance checklist, `asset-inventory.txt` and the xlsx report all apply `75`

### Requirement: Malware Rows Are Distinguishable
The report SHALL make visibly clear that the presence of a Lynis scan and the presence of an
antivirus product are different findings.

#### Scenario: Lynis ran and no antivirus is installed

- **WHEN** `lynis-report.json` exists and `.malware_scanner_installed` is `0`
- **THEN** the compliance checklist row reads `Lynis scan uitgevoerd` with `Yes`
- **AND** the asset inventory field reads `Malware Scanner (AV product)` with `No`

## MODIFIED Requirements

### Requirement: Generate compliance checklist report
The system SHALL generate a compliance report file named `honeybadger-{username}-{date}-compliance.md`
that contains an ISO27001 compliance checklist with a status for each required control: ✅ in place,
❌ shown not to be in place, or ❓ not established from the collected evidence. The hardening score
is shown as ℹ️ and does not contribute to the overall status.

#### Scenario: All controls pass
- **WHEN** every control is in place (disk encryption, screen lock within 15 minutes, firewall, no
  vulnerable packages)
- **THEN** the compliance report shows ✅ for each control and overall compliance status
  "✅ Compliant", whatever the hardening score

#### Scenario: Critical control fails
- **WHEN** the evidence shows one or more critical controls are not in place (no disk encryption OR
  no firewall OR vulnerable packages present OR an insecure NixOS supply chain)
- **THEN** the compliance report shows ❌ for those controls and overall compliance status
  "❌ Niet compliant"

#### Scenario: Warning conditions exist
- **WHEN** no critical control fails, but the screen lock fails or any control is not established
- **THEN** the overall compliance status is "⚠️ Gedeeltelijk compliant"
- **AND** every control that is not established is listed under "Niet vastgesteld" in the
  check's own words, and is not listed as a blocker

### Requirement: Check disk encryption status
The system SHALL determine disk encryption status by examining `blockdevices.txt` for LUKS
encryption markers.

#### Scenario: LUKS encryption detected
- **WHEN** `blockdevices.txt` contains "crypto_LUKS" entries
- **THEN** the compliance report shows "Disk encryptie" as ✅ with the LUKS version

#### Scenario: No encryption detected
- **WHEN** `blockdevices.txt` is present and does not contain "crypto_LUKS" entries
- **THEN** the compliance report shows "Disk encryptie" as ❌ and marks this as a CRITICAL blocker

#### Scenario: Encryption evidence not collected
- **WHEN** `blockdevices.txt` is absent
- **THEN** the compliance report shows "Disk encryptie" as ❓, naming the missing file
- **AND** it is not a blocker

### Requirement: Check screen lock status
The system SHALL determine screen lock status from `screenlock-info.txt`, using the authoritative
source recorded in its summary block, and SHALL require a timeout of at most 15 minutes.

#### Scenario: Auto-lock enabled with acceptable timeout
- **WHEN** the authoritative source locks the screen within 15 minutes
- **THEN** the compliance report shows "Screen lock" as ✅ with the timeout and the mechanism

#### Scenario: Auto-lock disabled
- **WHEN** the authoritative source shows auto-lock disabled
- **THEN** the compliance report shows "Screen lock" as ❌ and the overall status is at most
  "⚠️ Gedeeltelijk compliant"

#### Scenario: Auto-lock timeout too long
- **WHEN** the authoritative source locks the screen after more than 15 minutes
- **THEN** the compliance report shows "Screen lock" as ❌ with the timeout and the 15-minute limit
- **AND** the overall status is at most "⚠️ Gedeeltelijk compliant"

#### Scenario: Auto-lock not established
- **WHEN** a lock daemon is running but its timeout cannot be read, or no mechanism is found
- **THEN** the compliance report shows "Screen lock" as ❓ and says why

### Requirement: Check firewall status
The system SHALL determine firewall status from `lynis-report.json` firewall_active field, falling
back to an active iptables or nftables ruleset.

#### Scenario: Firewall active
- **WHEN** `lynis-report.json` contains `"firewall_active": "1"`, or an active ruleset is found
- **THEN** the compliance report shows "Firewall" as ✅

#### Scenario: Firewall inactive
- **WHEN** `lynis-report.json` contains `"firewall_active": "0"` and no active ruleset is found
- **THEN** the compliance report shows "Firewall" as ❌ and marks this as CRITICAL

#### Scenario: Firewall evidence unavailable
- **WHEN** `lynis-report.json` is absent or unreadable and no active ruleset is found
- **THEN** the compliance report shows "Firewall" as ❓ and it is not a blocker

### Requirement: Check hardening score
The system SHALL report the Lynis hardening index as context only, beside the configured threshold
it was read against. It SHALL NOT produce a pass or fail marker, SHALL NOT appear in the list of
critical blockers, and SHALL NOT affect the overall compliance verdict.

#### Scenario: Hardening score meets threshold
- **WHEN** `lynis-report.json` contains a `"hardening_index"` at or above the configured threshold
- **THEN** the compliance report shows "Hardening score" as ℹ️ with `{score}/100 (drempel >={threshold})`

#### Scenario: Hardening score below threshold
- **WHEN** the hardening index is below the configured threshold and every other control passes
- **THEN** the hardening row is rendered ℹ️ with the score and the threshold
- **AND** the overall compliance status is "✅ Compliant"
- **AND** `asset-inventory.txt` carries no `NON-COMPLIANT` marker on the score

### Requirement: Check vulnerable packages
The system SHALL establish whether vulnerable packages are present only where a package audit tool
looked, from the Lynis vulnerable package count and PKGS-7392 warnings, and SHALL use the same
determination for the checklist and for xlsx column `J`.

#### Scenario: No vulnerable packages
- **WHEN** a package audit tool looked, the count is zero and no PKGS-7392 warning is present
- **THEN** the compliance report shows "Kwetsbare software" as ✅, naming the tool

#### Scenario: Vulnerable packages detected
- **WHEN** a package audit tool reports a count above zero, or a PKGS-7392 warning is present in
  either the string or the object warning format
- **THEN** the compliance report shows "Kwetsbare software" as ❌ with the count, and marks this as
  CRITICAL

#### Scenario: No package audit tool looked
- **WHEN** `lynis-report.json` shows no package audit tool (`package_audit_tool_found` is not `1`)
- **THEN** the compliance report shows "Kwetsbare software" as ❓, stating that no package audit
  tool was present
- **AND** the absence of a PKGS-7392 warning is not reported as "no vulnerable packages"

