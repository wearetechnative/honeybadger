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

### Requirement: Hardening Score Is Informational
The Lynis hardening score SHALL be reported as context only. It SHALL NOT produce a pass or fail
marker, SHALL NOT appear in the list of critical blockers, and SHALL NOT affect the overall
compliance verdict.

#### Scenario: Score below threshold does not fail the device

- **WHEN** the hardening score is below the configured threshold and every other control passes
- **THEN** the overall compliance status is compliant
- **AND** the hardening row is rendered `ℹ️`
- **AND** `asset-inventory.txt` carries no `NON-COMPLIANT` marker on the score

#### Scenario: Applied threshold is stated

- **WHEN** any report shows the hardening score
- **THEN** it also states the threshold that was applied

### Requirement: Malware Rows Are Distinguishable
The report SHALL make visibly clear that the presence of a Lynis scan and the presence of an
antivirus product are different findings.

#### Scenario: Lynis ran and no antivirus is installed

- **WHEN** `lynis-report.json` exists and `.malware_scanner_installed` is `0`
- **THEN** the compliance checklist row reads `Lynis scan uitgevoerd` with `Yes`
- **AND** the asset inventory field reads `Malware Scanner (AV product)` with `No`
