# Changelog HoneyBadger

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
