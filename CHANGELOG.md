# Changelog HoneyBadger

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
