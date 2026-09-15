## MODIFIED Requirements

### Requirement: Check screen lock compliance
The system SHALL evaluate all screen lock settings (screensaver timeout, power management, lock
policies) and report compliance status with detailed configuration data in the report. The report
SHALL state the timeout limit that was applied and the settings the verdict rests on, so the
finding can be traced without reading the script.

#### Scenario: Multiple screen lock settings collected
- **WHEN** system collects screensaver timeout, screensaver active, screensaver secure, monitor timeout, system sleep timeout, lock on sleep policy, and inactivity timeout
- **THEN** compliance report includes "Screen Lock Configuration" section with all collected settings and their values

#### Scenario: Screen lock timeout evaluation
- **WHEN** screensaver timeout is ≤900 seconds (15 minutes) AND screensaver is active AND password is required
- **THEN** screen lock check shows ✅ compliant status

#### Scenario: Screen lock not properly configured
- **WHEN** screensaver timeout is >900 seconds OR screensaver is not active OR password is not required
- **THEN** screen lock check shows ❌ non-compliant status with specific issues listed

#### Scenario: Applied limit is stated
- **WHEN** the compliance checklist shows the screen lock row
- **THEN** the detail states the 900-second limit that was applied
- **AND** it names the registry-derived settings the verdict rests on

#### Scenario: Password requirement is recorded as a platform difference
- **WHEN** the screen lock verdict depends on `ScreenSaverIsSecure`
- **THEN** the report states that a password on resume is required for a passing verdict on this
  platform

### Requirement: Check antivirus compliance
The system SHALL evaluate Windows Defender status and report compliance as PASS if real-time protection is enabled and definitions are up to date (<7 days old), otherwise FAIL. The report SHALL state the 7-day definition age limit that was applied.

#### Scenario: Windows Defender active and current
- **WHEN** RealTimeProtectionEnabled=True AND AntivirusSignatureLastUpdated is within 7 days
- **THEN** antivirus check shows ✅ with signature version and last updated date

#### Scenario: Windows Defender disabled or outdated
- **WHEN** RealTimeProtectionEnabled=False OR AntivirusSignatureLastUpdated is older than 7 days
- **THEN** antivirus check shows ❌ with specific issue (disabled or outdated definitions)

#### Scenario: Applied definition age limit is stated
- **WHEN** the compliance checklist shows the antivirus row
- **THEN** the detail states the 7-day limit that was applied
