# Changelog HoneyBadger

## NEXT VERSION

### Added

- **`asset-inventory.json`** - the machine-readable counterpart of
  `asset-inventory.txt`, written into the output directory and therefore into
  the archive. The audit already determined every value the ISO register needs
  and wrote them twice for humans; the collection server can now read them
  instead of an operator retyping them from the xlsx report.
  - Emitted from the same determinations the xlsx report renders, so the two
    cannot disagree
  - Each finding carries the value and the finding it came from, because "Yes"
    and "Yes (LUKS)" answer different questions
  - A value the audit could not or would not determine is `null` with the
    finding intact, which is distinguishable from a key this generation does
    not report at all
  - `schema_version` lets a consumer recognise a generation it does not fully
    understand
- The `audit` command now also generates the xlsx asset row report, which is
  what writes `asset-inventory.json` into the output directory before the
  archive is created

### Added

- **`--config <file>` and `HONEYBADGER_CONFIG`** name a configuration file and
  skip the search order. A named file that does not exist is an error rather
  than a silent fallback to whatever the search finds.

### Changed

- **The environment now overrides the configuration file.** Settings resolve as
  environment, then file, then built-in default. The file used to be sourced
  after the defaults were applied, so it always won and an environment variable
  could never take effect - which meant `DRY_RUN=true` could not switch on a dry
  run when the file had `DRY_RUN=false`. A real archive was submitted twice
  while attempting a dry run.
  - The settings the environment supplied are reported, because a configuration
    file that can be silently overridden is its own kind of surprise
  - A setting exported as an empty string counts as supplied and is not refilled

### Changed

- **`submit` now submits the audit archive** - BEHAVIOUR CHANGE. It previously
  submitted reports one at a time to `SERVER_URL/`, an endpoint with no concept
  of a hardware serial, so those submissions could not be attributed to an asset
  in the ISO register. They landed under hostname and username with no evidence
  archive beside them. `submit` now sends the archive to `SERVER_URL/submit-tar`,
  which carries the serial and lets the server resolve the asset.
  - `submit-tar` keeps working as a deprecated alias and warns, so scheduled
    jobs calling it do not fail silently

### Removed

- **Per-report submission** - `submit_all_reports()` and `submit_report()` are
  gone along with the command that used them

### Added

- **Shell test suite** - `./RUNME.sh run-tests` runs the tests in `tests/`
  - Covers serial validation against the real values found on compute2, the Linux chain with each
    source stubbed in turn (asserting later steps are not reached when an earlier one succeeds),
    the macOS parsers against captured `ioreg` and `system_profiler` output, and what is written
    and reported when no usable serial exists
- **ISO27001 asset register report** - `check-output` now writes a third report,
  `honeybadger-{user}-{date}-xlsx.md`, with the field values for the `Active Assets` sheet of
  `iso27001-compliance-essential.xlsx`
  - Lists nine columns the audit can determine (serial, model, OS, disk encryption, screen lock,
    firewall, vulnerable packages, hardening score, OS up-to-date), each with the cell value to
    enter and the finding it was derived from
  - Identifies the register row by serial number, and marks the columns you maintain yourself
    (asset ID, owner, proof file, remarks) plus the two formula columns that must not be overwritten
  - Reports vulnerable packages as a finding rather than a cell value, because the spreadsheet's
    data validation and its `Status` formula disagree about which value means compliant; a system
    without a package audit tool is reported as undetermined instead of compliant
  - The spreadsheet is never read or written; updating the register remains a manual step

### Fixed

- **`submit` rejected for the system information report** - `./RUNME.sh submit` failed with
  `HTTP 400` for the system information report while `submit-tar` succeeded
  - The client read `fastfetch.json` but still labelled it `X-Report-Type: neofetch`, a type
    badgersbay retired when it moved to fastfetch. It now submits the report as `fastfetch`
  - `submit-tar` was never affected: the server derives the report type from the file name inside
    the archive, and the archive has carried `fastfetch.json` all along
- **A report that was never sent counted as a success** - A missing `fastfetch.json` was reported
  as a skip, and `submit` exited 0 as long as one report went through
  - A missing report file is now a failure that names the file it expected, and `submit` exits
    non-zero when any report did not reach the server
- **Rejections gave the status code and nothing else** - Both submission paths discarded the
  response body, so `HTTP 400` arrived without the sentence explaining it
  - The server's message is now printed with the failure, lifted out of the error page when the
    server answers with one
- **A stored tar submission was retried as a failure** - badgersbay answers HTTP 207 when it
  stored a submission it could not match to an asset register entry; the client treated anything
  other than 200 as a failure and resent the same archive
  - Both paths now accept any 2xx, name a 207 a partial submission, and print the server's remark
- **Hardware serial never determined on half the fleet** - The audit now reads the serial from the
  kernel instead of depending on `dmidecode` being installed
  - `/sys/class/dmi/id/product_serial` is the primary source: root-only, but the audit already
    requires root, and it needs no tool, no package and no network. It is a kernel interface, so
    the same path works on NixOS, Ubuntu, Debian and Arch with no distribution-specific handling
  - Falls back in order to `/sys/class/dmi/id/board_serial` (some vendors fill only that one),
    `dmidecode -s system-serial-number` when the tool happens to be present, and on NixOS
    `nix run nixpkgs#dmidecode` as a last resort. Each step runs only when the previous produced
    nothing usable
  - `dmidecode` is deliberately **not** added to the dependency check: aborting an audit over a
    tool that most machines do not need would turn a soft problem into a hard failure
  - Measured across the 22 archives on compute2-prod only five systems carried a usable serial;
    `technative-casper` and `nixos-pankhurip` failed purely because `dmidecode` is not in PATH on
    NixOS, while the kernel held the value all along
- **macOS wrote a fragment of unrelated output as the serial** - `MBP-van-pim-pim` submitted
  `Mac OS X<TAB>`, almost certainly from matching the wrong line of `system_profiler`
  - The serial is now read as a property via `ioreg -d2 -c IOPlatformExpertDevice`, with
    `system_profiler SPHardwareDataType` parsed on the `Serial Number` label as the fallback
- **Lynis warnings split into bogus actions** - A single warning no longer shows up as four separate items in the actions report
  - `warning[]` is written by Lynis as one pipe-separated record (`TEST-ID|description|details|solution`), but the converter had structured parsing only for `suggestion[]`
  - The record fell through the generic pipe-split, so `warning[]` became a flat array of field values and the actions report used the array index as the test ID - rendering `### 0`, `### 1`, `### 2`, `### 3` and reporting 4 High findings where there was 1
  - The converter now parses `warning[]` into `{id, description, details, solution}` objects, and the actions report reads the test ID and description from those fields
  - Reports generated before this fix keep working: both legacy shapes (one raw string per warning, and a single warning split across the array) are normalised when the report is read
  - Singular/plural corrected in the actions header ("1 actie" instead of "1 acties")

### Changed

- **A serial is validated before it is written** - An unusable value is no longer recorded as
  though it were a measurement
  - A usable serial is one token: non-empty, free of whitespace, not a known firmware placeholder
    (`Not available`, `To Be Filled By O.E.M.`, `Default string`, `System Serial Number`, `None`,
    `Unknown`, ...) and not all zeroes
  - This is the same rule the collection server applies when matching a submission to an asset, so
    the client and the server now agree on what counts. Writing a value the server rejects helps
    nobody, and writing `Mac OS X` is worse than writing nothing: it looks like data
- **The audit says why there is no serial** - `Not available` is gone, replaced by two tokens that
  call for different responses
  - `could-not-read`: no source returned a value - a machine or packaging problem worth chasing
  - `none-present`: a source answered but the hardware has no serial, as a virtual machine
    legitimately does - such an asset needs a different key in the register rather than a repair
  - The outcome is reported at the end of the run where the operator sees it, instead of the client
    silently writing `Not available` and nobody noticing until the dashboard showed the asset as
    outstanding
  - `asset-inventory.txt` gained a **Serial Source** row, and `hardware-serial-source.txt` records
    which source produced the value. Archives written before this change are read back as
    `could-not-read` rather than being mistaken for data
- **Slimmed Docker converter image** - Removed tooling the converter never invokes
  - Dropped `wkhtmltopdf`, `texlive-latex-base`, `texlive-latex-recommended` and `pandoc`, plus the ten X11 and font libraries that existed solely to support wkhtmltopdf
  - Dropped `cpanminus` and the `Excel::Writer::XLSX` CPAN build; the converter lazily loads format modules and the JSON path needs only `libjson-perl`
  - Image size reduced from 806 MB to 169 MB (-79%), build time from minutes to roughly 25 seconds
  - JSON output verified byte-identical to the previous image
- **Pinned Docker build** - The image is now reproducible
  - Base image pinned to `debian:bookworm-slim`; `debian:latest` had already drifted to Debian 13 (trixie) while the build assumed bookworm
  - Converter pinned to commit `7a26d37cc3a0ca53ea259eee2b23f1e165ea4e6b` instead of downloading `master.zip` at build time
- **Documented Docker as optional** - README now lists Docker as required only when `USE_DOCKER_CONVERTER=true`, and lists `python3` as a required dependency
- **Corrected converter documentation** - `.honeybadger.conf.example` no longer claims the Docker converter provides HTML/PDF/Excel output; both converters emit JSON only
- **neofetch references updated to fastfetch** - README and `openspec/project.md` brought in line with the July 2026 switch

### Fixed

- **Docker image rebuild detection** - Editing the `Dockerfile` never triggered a rebuild
  - The guard compared the `Dockerfile` against the audit output directory, which is created moments before the test, so the condition could never be true
  - Staleness is now decided by comparing the `Dockerfile`'s SHA-256 against a `hb.dockerfile.sha` label stamped into the image, so a `git clone` that only rewrites mtimes no longer forces a needless rebuild
- **arm64 Docker builds** - The image hardcoded an amd64-only wkhtmltopdf `.deb`, and the failure was absorbed by a following `|| apt-get install -f`, so builds on Apple Silicon reported success while silently omitting the package
  - All remaining packages are `Architecture: all` or have arm64 builds
  - Verified by building for `linux/arm64` and confirming the resulting image produces byte-identical JSON to the amd64 build
- **Spec files unreadable by OpenSpec tooling** - Four capability specs (`dependency-validation`, `hardeningkitty-integration`, `windows-compliance-reporting`, `windows-security-data-collection`) had been archived with their `## ADDED Requirements` delta headers intact and no `## Requirements` section, making every requirement in them invisible to `openspec validate`, `list` and `archive`
- **Hostname resolution without `hostname(1)`** - The audit named its output
  directory and tar archive with `local hostname=$(hostname -s)`. `hostname(1)`
  ships in `inetutils` and is not part of Arch's base install, so on a stock
  Arch host the command was not found
  - The failure was silent: `local` is a builtin that always returns 0, so the
    assignment's exit status was the declaration's rather than the command's.
    `set -e` never fired, nothing was printed, and the run wrote
    `output--<user>-<date>` and `honeybadger--<user>-<date>.tar.gz` with an
    empty hostname in the name
  - The hostname is now resolved from `uname -n`, then `$HOSTNAME`, then
    `/etc/hostname` - none of which needs a package on any supported platform.
    The domain is cut off in the shell with `${name%%.*}` instead of by
    `hostname -s`
  - A value that cannot name a file (empty, whitespace, control characters, a
    `/`) falls through to the next source, and when no source answers the audit
    stops with an error naming all three rather than producing output without a
    hostname
  - `unpack_tarball` had the same masking on its `tar` listing; declaration and
    assignment are now separate there too, and a test fails the suite if any
    `local x=$(cmd)` is reintroduced into `RUNME.sh`
- **Wrong username in `asset-inventory.json` for hyphenated hostnames** - Three
  report generators recovered the username and the date by parsing them back out
  of the output directory's name with `output-([^-]+)-([^-]+)-(.+)$`
  - `[^-]+` cannot span a hyphen, so a hyphenated hostname shifted every group.
    `output-hb-ubuntu-test-hbtest-16-09-2026` yielded `ubuntu`;
    `output-pankhuri-prakash-IdeaPad-5-14ARE05-root-02-04-2026` yielded
    `prakash`; `output-mbp-van-pim-pim-07-04-2026` yielded `van`. Two of the
    eight real directory names we hold came out right
  - `asset-inventory.txt` took the owner from the audit data and was correct, so
    the two files disagreed - despite the emitter's comment saying they could
    not. `asset-inventory.json` is what the collection server reads, so the
    wrong value won
  - The username now comes from the audit data for every consumer.
    `RUNME.sh` already runs `fastfetch` as the invoking user for exactly this
    purpose, so `fastfetch.json`'s `.user` is the value the directory name was
    built from, recorded before the encoding lost it. `neofetch.json` and
    `neofetch.txt` are read for older archives
  - Where the directory name still has to be parsed - an archive with no fetch
    file - it is anchored on the `DD-MM-YYYY` suffix from the right, which is
    correct for every real name we hold
  - `asset-inventory.txt` and `asset-inventory.json` now call the same resolver,
    so they agree by construction rather than by comment
  - Report filenames are corrected on affected hosts:
    `honeybadger-van-pim-pim-07-04-2026-actions.md` becomes
    `honeybadger-pim-07-04-2026-actions.md`. Hosts that were already right keep
    the names they had
  - `identity.hostname` was never affected: it comes from `lynis-report.json`

## 0.6.0 - Enhanced ISO27001 Compliance Reporting (March 2026)

### Added

#### Hardware Asset Tracking
- **Device Serial Number Collection** - Collects hardware serial numbers via dmidecode
  - Automatically retrieves serial number during audit
  - Graceful fallback for VMs or systems without dmidecode
  - Separate "Serial Number" and "Model" fields in asset inventory
  - Output file: `hardware-serial.txt`

#### OS Update History Tracking
- **Update History Integration** - Tracks OS update status and compliance
  - Integrated existing `lib/check-os-updates.sh` into audit workflow
  - Reports last update date for Arch, Ubuntu, Debian, Kali, Fedora, NixOS, macOS
  - Compliance indicators: ✅ COMPLIANT (<14 days), ⚠️ UPDATE RECOMMENDED (14-30 days), ❌ UPDATE REQUIRED (>30 days)
  - Output file: `os-update-history.txt`

#### Lynis Hardening Score Display
- **Hardening Score Reporting** - Displays Lynis security hardening score in reports
  - Extracts `.hardening_index` (0-100 scale) from Lynis JSON
  - Status indicators: Excellent (80-100), Good (60-79), Fair (40-59), Poor (0-39)
  - Shown in `asset-inventory.txt` with compliance status

#### Lynis Hardening Score Validation
- **Compliance Threshold Checking** - Validates minimum hardening score requirement
  - **Configurable threshold: MIN_HARDENING_SCORE=65** (can be adjusted in code)
  - Compliant: `78/100 (Good) ✅ COMPLIANT (≥65)`
  - Non-compliant: `58/100 (Fair) ❌ NON-COMPLIANT (required: ≥65)`
  - Clear pass/fail indicators for policy compliance

#### NixOS Metadata Collection
- **NixOS System Information** - Collects NixOS-specific reproducibility data
  - Nixpkgs commit hash (short form, 7-8 characters)
  - Current system generation number
  - Last rebuild date and timestamp
  - Recent generation history (last 5 generations)
  - Output file: `nixos-system-info.txt`
  - Conditional fields in `asset-inventory.txt` (NixOS only)

#### Security Finding Severity Categorization
- **Severity-Based Lynis Findings** - Categorizes security findings by priority
  - Keyword-based heuristic categorization: Critical, High, Medium, Low, Unspecified
  - HTML report restructured with severity sections:
    - 🔴 **CRITICAL FINDINGS** (red) - Root access, authentication, encryption issues
    - 🟠 **High Priority** (orange) - Security controls, permissions, credentials
    - 🟡 **Medium Priority** (yellow) - Updates, patches, configuration warnings
    - 🔵 **Low Priority** (blue) - Optional improvements and suggestions
    - ⚪ **Other Findings** (gray) - Unclassified items
  - Summary shows counts per severity: "2 critical, 5 high, 12 medium findings"
  - Color-coded severity badges on each finding
  - Automatic categorization when Lynis doesn't provide severity data

### Changed

#### Asset Inventory Report
- Separated "Serial Number / Model" into two distinct fields
- Added "Lynis Hardening Score" field with compliance indicators
- Added conditional "NixOS Commit Hash" and "NixOS Generation" fields for NixOS systems
- Updated notes section

#### HTML Warnings Report
- Completely restructured to group findings by severity
- Added severity badge CSS styling (critical: red, high: orange, medium: yellow, low: blue, unspecified: gray)
- Enhanced summary section with per-severity counts
- Improved visual hierarchy with color-coded sections

### Documentation

#### README.md
- Added dmidecode to dependencies (recommended, not required)
- New "What Gets Audited" section documenting all collected information
- New "ISO27001 Compliance Requirements" section with minimum thresholds
- Documented new output files (hardware-serial.txt, os-update-history.txt, nixos-system-info.txt)
- Listed compliance requirements with checkmarks

### Technical Details

#### Modified Files
- `lib/_library` - Updated `generate_asset_inventory()` and `generate_warnings_report()`
- `RUNME.sh` - Added serial number collection and NixOS metadata collection

#### New Functions
- `categorize_severity()` - Keyword-based severity detection for Lynis findings

#### Configuration
- Hardening score threshold configurable via `MIN_HARDENING_SCORE` constant (default: 65)

### Migration Notes
- All changes are backward compatible - existing audit functionality unchanged
- New output files are created automatically, no user action required
- dmidecode is optional - audit continues if not available

### Fixed

#### NixOS Metadata Extraction Regex Error
- **Fixed**: Bash regex syntax error in NixOS commit hash extraction (lib/_library line 834)
  - Issue: Problematic regex pattern `\(([^)]+)\)` caused conditional expression error
  - Impact: Library functions failed to load, breaking `generate_asset_inventory` and `generate_warnings_report`
  - Solution: Replaced regex matching with more portable sed-based extraction
  - Before: `[[ "$version_line" =~ \(([^)]+)\) ]]` (failed on some bash versions)
  - After: `sed -n 's/.*(\([^)]*\)).*/\1/p'` (portable, reliable)
  - Testing: Verified on NixOS 25.11 - all functions load correctly

## 0.5.0 - Remove CVE Scanning (March 2026)

### Breaking Changes

#### CVE Vulnerability Scanning Removed
- **CVE vulnerability scanning has been removed** as the functionality was determined to be obsolete
  - Removed vulnix scanner support (NixOS)
  - Removed trivy scanner support (other Linux distributions)
  - Audit no longer checks for CVE scanners at startup
  - Output files no longer include:
    - `vulnix.json` - CVE scan results from vulnix
    - `trivy.json` - CVE scan results from trivy
    - `cve-summary.txt` - Human-readable CVE summary report
  - Server submission no longer includes CVE scan reports
  - **Note**: Organizations requiring CVE scanning for ISO27001 Policy 8.1 compliance must implement alternative vulnerability assessment solutions

### Removed

#### Code Removal
- Removed 6 CVE scanning functions from `lib/_library` (~255 lines):
  - `scan_cve_vulnerabilities()` - Main CVE scanning orchestrator
  - `scan_vulnix()` - NixOS vulnerability scanner
  - `scan_trivy()` - General Linux vulnerability scanner
  - `generate_cve_summary()` - Summary report generator
  - `generate_vulnix_summary()` - Vulnix report formatter
  - `generate_trivy_summary()` - Trivy report formatter
- Removed CVE scanner dependency checks from audit startup
- Removed CVE report submission from `submit_all_reports()`

#### Documentation Updates
- Removed CVE scanner installation instructions from README
- Removed vulnix and trivy from required dependencies list
- Updated project documentation to remove CVE scanning references

## 0.4.1 - Output Ownership Fix (March 2026)

### Fixed

#### Tarball and Output Directory Ownership
- **Fixed**: Audit output files now owned by actual user instead of root
  - Previously: Running `sudo ./RUNME.sh audit` created root-owned tarball and output directory
  - Now: Files are owned by the user who invoked sudo (e.g., `wtoorren:users`)
  - Uses `chown` with `SUDO_USER` environment variable after tar creation
  - Graceful handling when running without sudo (ownership already correct)
  - Users can now delete audit results without needing sudo:
    - Tarball: `honeybadger-hostname-user-date.tar.gz` ✓
    - Output directory: `output-hostname-user-date/` ✓
  - Improved user experience: files belong to user, not system

## 0.4.0 - Required Dependencies & Bug Fixes (March 2026)

### Breaking Changes

#### CVE Scanners Now Required
- **CVE vulnerability scanning is now mandatory** for complete security audits
  - NixOS systems: vulnix is required (install: `nix-env -iA nixpkgs.vulnix`)
  - Other systems: trivy is required (see installation instructions in README)
  - Audit will exit with error if appropriate scanner is not installed
  - Ensures ISO27001 compliance (Policy 8.1 - vulnerability assessment)
  - No more silent skipping of CVE scanning

#### Additional Required Dependencies
- **jq**: JSON processor is now required (was implicitly required but not enforced)
  - Used extensively for parsing lynis-report.json, neofetch.json, OS status checking
  - Audit will exit if jq is not installed
- **curl**: HTTP client is now required (was implicitly required but not enforced)
  - Used for fetching OS release information from APIs
  - Audit will exit if curl is not installed

### Fixed

#### Neofetch Username Shows Actual User
- **Fixed**: neofetch.json now captures actual username instead of "root"
  - Previously: Running `sudo ./RUNME.sh audit` captured "root" as username
  - Now: Captures original user who invoked sudo (e.g., "wtoorren")
  - Uses `sudo -u "${SUDO_USER:-$(whoami)}"` to run neofetch as actual user
  - Ensures consistent user identification across all outputs:
    - Output directory: `output-hostname-user-date` ✓
    - neofetch.json: `{"user": "actualuser"}` ✓
    - Server headers: `X-Username: actualuser` ✓
  - Improves compliance reporting and asset inventory accuracy

### Migration Guide

**For users upgrading from 0.3.0:**

1. **Install CVE scanner** (now required):
   - NixOS: `nix-env -iA nixpkgs.vulnix`
   - Ubuntu/Debian: Follow trivy installation in README
   - Arch: `sudo pacman -S trivy` or `yay -S trivy`
   - macOS: `brew install trivy`

2. **Verify jq and curl are installed** (usually already present):
   - Most systems: `sudo apt install jq curl` or `sudo pacman -S jq curl`
   - macOS: `brew install jq curl`

3. **Next audit will capture correct username** in neofetch.json (no action needed)

## 0.3.0 - Security & Compliance Enhancement (March 2026)

### Added

#### Server Report Submission
- **Centralized Compliance Monitoring**: Submit audit reports to honeybadger-server via HTTP POST
  - New command: `./RUNME.sh submit [output-directory]`
  - **Important**: Submit is completely separate from audit (explicit opt-in)
  - Auto-detection of most recent output directory
  - Configuration file support (.honeybadger.conf)
  - Configuration precedence: ./.honeybadger.conf → ~/.honeybadger.conf → /etc/honeybadger.conf
  - HTTP POST with custom headers (X-Hostname, X-Username, X-Report-Type)
  - Retry logic with exponential backoff (1s, 2s, 4s delays)
  - Graceful failure handling (submission errors don't block audit)
  - Dry-run mode for testing without actual submission
  - Configuration options:
    - SERVER_ENABLED (default: false)
    - SERVER_URL (default: http://localhost:7123/)
    - SERVER_TIMEOUT (default: 30 seconds)
    - SERVER_RETRY_COUNT (default: 3)
    - DRY_RUN (default: false)
  - Submits JSON reports: neofetch.json, lynis-report.json, vulnix.json/trivy.json
  - Returns exit 0 if at least one report submitted successfully

#### CVE Vulnerability Scanning
- **Automated CVE Detection**: CVE scanning during audit (ISO27001 Policy 8.1)
  - NixOS systems: Uses vulnix to scan Nix packages for known vulnerabilities
  - Arch/Ubuntu/Kali/macOS: Uses trivy for comprehensive filesystem vulnerability scanning
  - Generates machine-readable JSON output (vulnix.json or trivy.json)
  - Generates human-readable CVE summary with severity breakdown (cve-summary.txt)
  - Optional feature: Gracefully skips if scanning tool not installed
  - 5-minute timeout protection for long-running scans
  - Proper exit code handling (vulnix/trivy return non-zero when CVEs found)
  - JSON validation before accepting scan results
  - Installation instructions provided when tools are missing

### Changed
- **Root Privilege Enforcement**: Audit command now requires root privileges
  - Script exits with error if not run with sudo
  - Clear error message with usage instructions
  - Removed redundant sudo calls within script

- **Improved Output Naming**: Output directories now use hostname-user-date format
  - Format: `output-{hostname}-{user}-{date}`
  - Preserves original username when using sudo (via SUDO_USER variable)
  - Tarball naming follows same pattern: `honeybadger-{hostname}-{user}-{date}.tar.gz`

- **JSON-based System Information**: Replaced neofetch.txt with neofetch.json for structured data access
  - Uses jq for reliable JSON parsing instead of brittle grep/sed text parsing
  - Backward compatibility maintained for existing audit archives with neofetch.txt
  - Improved data extraction reliability for OS info, hardware details, and package detection

### Security
- **Root Check**: Audit now validates root privileges before execution
- **CVE Detection**: Proactive vulnerability identification in installed packages
- **Centralized Monitoring**: Optional server submission for organization-wide compliance tracking

## 0.2.0 - ISO27001 Compliance Enhancement (February 2026)

### Major Features

#### Dynamic OS/Kernel Status Checking
- Real-time End-of-Life (EOL) verification via endoflife.date API and kernel.org
- Support for NixOS, Ubuntu, Debian, Kali Linux, and Arch Linux
- 24-hour cache TTL for release information to minimize API calls
- Intelligent version detection from multiple sources (Lynis JSON, neofetch, lsb_release)

#### PASS/FAIL Compliance Reporting
- 4-tier verdict system: PASS, WARNING, FAIL, UNKNOWN
- **PASS**: Current stable release with active updates
- **WARNING**: Older version but still receives security updates (upgrade recommended)
- **FAIL**: End-of-Life system, no longer receives updates (critical security risk)
- **UNKNOWN**: Unable to determine status (manual verification needed)
- Actionable recommendations for each status level
- ISO27001-specific compliance notes for failing systems

#### Asset Inventory Generation
- Automated extraction of 13+ compliance fields from audit data
- Hardware identification (hostname, model, serial number)
- OS and kernel versions
- Security features:
  - Disk encryption status (LUKS detection)
  - Screen lock configuration with auto-lock timeout
  - Malware scanner presence
  - Firewall active status
- Compliance status (OS up-to-date, Nix installation)
- Owner/user and last audit date tracking
- Formatted table output (asset-inventory.txt)

#### Warnings/Suggestions Report with PDF Generation
- Filtered security report extracting only warnings and suggestions from Lynis audit
- Styled HTML report with color-coded sections:
  - Red for warnings (security issues)
  - Blue for suggestions (improvements)
- Severity levels and detailed recommendations
- Automatic PDF generation via Docker + wkhtmltopdf
- Cross-platform PDF creation without host dependencies

#### Library Architecture
- Modular, reusable function library (_library file)
- Functions organized by domain:
  - Cache management (is_cache_valid, fetch_url, fetch_os_releases)
  - OS/Kernel queries (get_latest_nixos_release, check_nixos_is_current, etc.)
  - Status analysis (check_os_status, analyze_*_status, generate_status_summary)
  - Reporting (generate_asset_inventory, generate_warnings_report)
- Easy to test and maintain
- Sourced by RUNME.sh for consistent behavior

### Technical Improvements

#### Docker-based PDF Generation
- wkhtmltopdf 0.12.6.1 installed in Docker container from GitHub releases
- All X11 and font dependencies included
- pandoc and LaTeX packages for fallback PDF generation
- Two-stage approach:
  1. JSON conversion from Lynis report (read-only mount)
  2. PDF generation from HTML (read-write mount)
- Automatic ownership fix for root-created PDF files
- No PDF tools required on host system

#### Enhanced RUNME.sh Commands
- **audit**: Full security audit with all new features
  - Lynis security scan (requires sudo)
  - JSON conversion via Docker
  - System information collection
  - OS/kernel status report with PASS/FAIL verdict
  - Asset inventory table generation
  - Warnings/suggestions HTML/PDF report via Docker
  - Compressed tarball with all reports

- **check-output**: Re-analyze existing audit output
  - Accepts output directories or tar.gz files
  - Auto-extracts tarballs when directory not found
  - Prompts before overwriting existing directories
  - Automatically fetches latest release information
  - Regenerates OS/kernel status with current EOL data
  - Regenerates asset inventory
  - Does NOT regenerate warnings/suggestions PDF (audit-only)

- **fetch-releases**: Update cached OS release information
  - Fetches from endoflife.date (NixOS, Ubuntu, Debian, Kali)
  - Fetches from kernel.org
  - Respects 24-hour cache TTL
  - Optional custom cache directory

#### Docker Image Enhancements
- Base image: debian:latest
- Added wkhtmltopdf 0.12.6.1 with full X11/font dependencies
- Added pandoc for document conversion
- Added texlive-latex-base and texlive-latex-recommended
- Added jq for JSON processing
- Optimized layer caching for faster rebuilds
- Image size: ~380MB (includes all PDF generation tools)

### Output Files

New generated reports in output directory:
- **lynis-report.json**: Security audit in JSON format
- **os-kernel-status.txt**: OS and kernel analysis with PASS/FAIL verdict
- **asset-inventory.txt**: Compliance data table with 13+ fields
- **lynis-report-warnings_fails.html**: Filtered security report (color-coded)
- **lynis-report-warnings_fails.pdf**: PDF version of warnings report
- **neofetch.txt**: System information display
- **honeybadger-info.txt**: Tool version information
- **blockdevices.txt**: Storage and encryption configuration
- **screenlock-info.txt**: Desktop screen lock settings
- **installed-packages.txt**: Complete package inventory
- **lsb_release.txt**: Distribution info (if available)

### Bug Fixes
- Fixed kernel version parsing from multiple sources
- Fixed screen lock timeout extraction with human-readable format
- Fixed NixOS package listing for flakes-based profiles
- Improved error handling for missing optional dependencies
- Fixed PDF ownership issues from Docker (automatic chown/chmod)

### Breaking Changes
- check-output no longer regenerates warnings/suggestions PDF (audit-only)
- Removed standalone generate-warnings-pdf.sh script (moved to _library)
- Removed host-based PDF converter detection (now Docker-only)

## 0.1.0 - Initial Version

- Initial working version for Linux and macOS using Lynis
- First prototype working version for Windows using HardeningKitty
- Create a report tarball
