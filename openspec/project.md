# Project Context

## Purpose
Honeybadger is a Personal Device Audit tool for ISO27001 compliance. It
performs comprehensive security audits on Linux and macOS systems, generating
detailed reports about system security posture, configuration, and compliance
status.

The tool is designed to "make your computer as tough as a honeybadger" by
thoroughly auditing device security configurations.

## Current Status (February 2026)

### Recent Features (v2.0)
- ✅ **Dynamic OS/Kernel Status Checking**: Real-time EOL verification via endoflife.date API
- ✅ **PASS/FAIL Compliance Reporting**: Clear verdict with actionable recommendations
- ✅ **Asset Inventory Generation**: Automated extraction of 13+ compliance fields
- ✅ **Warnings/Suggestions Report**: Filtered security issues with HTML/PDF output via Docker
- ✅ **Library Architecture**: Modular, reusable functions in _library file
- ✅ **Docker-based PDF Generation**: wkhtmltopdf in container for reliable cross-platform PDF creation
- ✅ **CVE Vulnerability Scanning**: Optional CVE scanning with vulnix (NixOS) or trivy (Arch/Ubuntu/Kali/macOS)
- ✅ **Server Report Submission**: Optional centralized reporting via HTTP POST to honeybadger-server

### In Production
- Audit generation with comprehensive security assessment
- Multi-format output (JSON, TXT, HTML, PDF)
- Automated compliance checking against ISO27001 requirements
- EOL detection for NixOS, Ubuntu, Debian, Kali Linux
- Asset registration data extraction
- Screen lock, encryption, and firewall status detection

## Tech Stack
- Bash (shell scripting for main orchestration)
- Docker (for running lynis-report-converter)
- Lynis (security auditing tool)
- Perl (for report conversion tools)
- Debian (container base image)
- jq (JSON processing)
- curl (HTTP requests for release data)

### Key Tools
- **neofetch**: System information display
- **lynis**: System security auditing
- **lynis-report-converter**: Converts Lynis reports to JSON/Excel formats (fork: wearetechnative/lynis-report-converter)
- **tar**: Report packaging and compression (gzip compression)
- **jq**: JSON parsing and processing
- **curl**: Fetching release information from APIs
- **wkhtmltopdf**: HTML to PDF conversion (installed in Docker container, not required on host)

## Project Conventions

### File Structure
- **RUNME.sh**: Main entry point with command framework
- **lib/**: Library directory containing helper scripts and shared functions
  - **_library**: Shared function library (sourced by RUNME.sh)
    - Cache management functions
    - OS/kernel release query functions
    - Status checking and analysis functions
    - Asset inventory generation
    - Warnings/suggestions report generation (HTML/PDF)
  - **check-os-status.sh**: OS and kernel status checker
  - **check-os-updates.sh**: OS update stream checker
  - **fetch-os-releases.sh**: Release information fetcher
  - **lynis-report-parser.sh**: Lynis report parser
- **Dockerfile**: Container build configuration (includes wkhtmltopdf for PDF generation)
- **.cache/**: Cached API responses (24-hour TTL)
  - nixos-releases.json
  - ubuntu-releases.json
  - debian-releases.json
  - kernel-releases.json

### Code Style
- Bash scripts follow traditional Unix shell conventions
- Use RUNME.sh framework for command management
- Library functions are reusable and testable
- Dependency checking before execution
- OS-specific code paths for Linux vs macOS
- All user-facing messages in English

### Architecture Patterns
- **Main script**: RUNME.sh orchestrates all operations with command framework
- **Library system**: lib/_library file contains reusable functions (sourced by RUNME.sh)
  - Modular design with clearly separated concerns
  - Functions grouped by domain (cache, OS queries, status checking, reporting)
  - Easy to test and maintain
- **Container-based processing**: Docker isolates report conversion and PDF generation dependencies
  - Uses volume mounts instead of copying files (--rm flag for auto-cleanup)
  - Docker image caching to avoid unnecessary rebuilds
  - Read-only volume mounts for Lynis data, read-write for PDF generation
  - wkhtmltopdf included in container for cross-platform PDF generation (380MB image)
  - Two-stage approach: JSON conversion (read-only), then PDF generation (read-write)
- **Multi-format output**: Reports generated in multiple formats (JSON, TXT, HTML, PDF)
- **Comprehensive data collection**: System info, security audit, package lists, lock screen configs
- **Dynamic compliance checking**:
  - Real-time EOL verification via endoflife.date API and kernel.org
  - PASS/WARNING/FAIL verdicts with actionable recommendations
  - ISO27001-specific compliance notes
- **Cache management**: 24-hour TTL for release information to minimize API calls
- **Error handling**: Exit on error (set -e), explicit error messages, graceful failure modes

### Library Functions (lib/_library)

#### Cache Management
- `is_cache_valid()`: Check if cached data is still valid (24h TTL)
- `fetch_url()`: Wrapper for curl with error handling
- `fetch_os_releases()`: Update all OS/kernel release caches

#### OS/Kernel Queries
- `get_latest_nixos_release()`: Get current NixOS stable version
- `get_nixos_eol_date()`: Get EOL date for specific NixOS version
- `check_nixos_is_current()`: Returns current/previous/supported/eol
- `get_latest_ubuntu_lts()`: Get current Ubuntu LTS version
- `check_ubuntu_is_current()`: Check Ubuntu version support status
- `get_kernel_info()`: Query kernel.org releases

#### Status Analysis
- `extract_os_info()`: Extract OS data from multiple sources (lynis, neofetch, lsb_release)
- `check_os_status()`: Main analysis function generating os-kernel-status.txt
- `analyze_nixos_status()`: NixOS-specific analysis with PASS/WARNING/FAIL
- `analyze_ubuntu_status()`: Ubuntu-specific analysis
- `analyze_debian_status()`: Debian-specific analysis
- `analyze_arch_status()`: Arch Linux (rolling) analysis
- `analyze_kali_status()`: Kali Linux (rolling) analysis
- `analyze_kernel_status()`: Kernel version analysis
- `generate_status_summary()`: Creates final verdict with recommendations

#### Reporting
- `generate_asset_inventory()`: Creates asset-inventory.txt with 13+ fields
- `generate_warnings_report()`: Creates filtered HTML/PDF from Lynis warnings/suggestions
  - Extracts only warnings and suggestions from JSON using jq
  - Generates styled HTML with color-coded sections
  - Converts HTML to PDF using Docker + wkhtmltopdf
  - Attempts to fix ownership of root-created PDF files

#### CVE Vulnerability Scanning
- `scan_cve_vulnerabilities()`: Scan for CVE vulnerabilities using OS-specific tools
  - Uses vulnix on NixOS (scans /run/current-system)
  - Uses trivy on Arch/Ubuntu/Kali/macOS (scans filesystem and OS packages)
  - Generates JSON output with vulnerability details
  - Handles exit code 2 from scanners (vulnerabilities found, not error)
  - 300-second timeout for large scans
  - Validates JSON output before accepting results
- `generate_cve_summary()`: Create human-readable CVE summary report
  - Parses JSON from vulnix or trivy
  - Counts vulnerabilities by severity (Critical, High, Medium, Low)
  - Generates actionable recommendations based on findings
  - Separate summary generators for vulnix and trivy formats

#### Server Report Submission
- `load_server_config()`: Load configuration from .honeybadger.conf files
  - Checks: ./.honeybadger.conf, ~/.honeybadger.conf, /etc/honeybadger.conf
  - Uses first found, falls back to defaults
  - Configuration options: SERVER_ENABLED, SERVER_URL, SERVER_TIMEOUT, SERVER_RETRY_COUNT, DRY_RUN
- `find_latest_output_dir()`: Auto-detect most recent output-* directory
  - Sorts by modification time (newest first)
  - Returns error if no output directories found
- `submit_report()`: Submit single report to server via HTTP POST
  - Auto-detects hostname and username
  - Sets proper HTTP headers (Content-Type, X-Hostname, X-Username, X-Report-Type)
  - Implements retry logic with exponential backoff (1s, 2s, 4s)
  - Handles client errors (4xx) without retry
  - Retries on server errors (5xx) and network failures
  - Supports dry-run mode (logs without submitting)
- `submit_all_reports()`: Submit all reports from output directory
  - Submits neofetch.json, lynis-report.json, vulnix.json/trivy.json
  - Tracks success/failure counts
  - Generates submission summary
  - Returns 0 if at least one report succeeded, 1 if all failed

### Testing Strategy
- Dependency validation before execution (checkdeps function)
- OS detection to ensure compatibility
- Error handling for missing tools

### Git Workflow
- Main branch: `main`
- Feature branches for development
- VERSION-honeybadger file tracks version information

## Domain Context

### Security Audit Scope
The tool audits and reports on:
1. **System Security**: Via Lynis comprehensive security scan
2. **System Information**: Hardware, OS, distribution details
3. **Installed Packages**: Complete package inventory (dpkg, rpm, pacman, nix)
4. **Block Devices**: Disk encryption and storage configuration
5. **Screen Lock Configuration**: Auto-lock settings across multiple desktop environments
   - GNOME (gsettings)
   - KDE Plasma (kscreenlockerrc)
   - XFCE (xfconf)
   - Hyprland/Sway (config files, hypridle/swayidle)
   - Generic X11 (xautolock, xss-lock)

### ISO27001 Compliance
The tool specifically targets ISO27001 compliance requirements for personal device security, ensuring devices meet organizational security standards.

### Compliance Status Decision Logic

The OS status checking system uses a 4-tier verdict system to assess compliance:

#### ✓ PASS - Current and Supported
**Criteria:**
- System is running the latest stable release
- Active update stream with regular security patches
- No end-of-life concerns

**Examples:**
- NixOS 25.11 (when it is the current stable release)
- Ubuntu 24.04 LTS (when it is the current LTS)
- Kali Rolling (always current if regularly updated)
- Arch Linux (rolling release, no versions)

**Actions:**
- Continue applying regular system updates
- Monitor for new releases and security updates
- Review report periodically (at least quarterly)

#### ⚠ WARNING - Older but Still Supported
**Criteria:**
- System is NOT running the latest version
- BUT still receives security updates and patches
- Support has not expired (not EOL)

**Examples:**
- NixOS 25.05 (when 25.11 is current but 25.05 still supported)
- Ubuntu 22.04 LTS (when 24.04 is current but 22.04 still receives updates)

**Actions:**
- Plan an upgrade to the latest stable release
- Continue applying security updates in the meantime
- Review upgrade path and test in staging environment
- Target version is specified in the report

#### ✗ FAIL - End of Life (Critical)
**Criteria:**
- System NO LONGER receives security updates
- Version has reached End-of-Life (EOL)
- Poses significant security risk

**Examples:**
- NixOS 23.11 (after its EOL date has passed)
- Ubuntu 18.04 LTS (after May 2028)
- Any version where current_date > eol_date

**Actions:**
- DO NOT connect to untrusted networks
- Plan immediate upgrade to supported version
- If upgrade not immediately possible:
  - Isolate system from internet
  - Restrict network access to essential services only
  - Increase monitoring and auditing
- Document security risk and create upgrade timeline
- ISO27001 compliance note: May violate security policies

#### ? UNKNOWN - Unable to Determine
**Criteria:**
- Unsupported or unrecognized operating system
- Missing or incomplete system information
- Unable to fetch release data from external sources

**Actions:**
- Verify system information is correctly reported
- Check internet connectivity for release data updates
- Manually verify OS version support status
- Consult OS vendor's support lifecycle documentation

## Important Constraints

### Platform Support
- Primary: Linux distributions (Debian, Ubuntu, Fedora, Arch, NixOS)
- Secondary: macOS
- Requires root/sudo access for Lynis audit

### Runtime Requirements
- Docker must be installed and running
- Sufficient permissions to read system logs (/var/log/lynis-report.dat)
- Network access for Docker image building (on first run)

### Output Format
- Reports packaged as .tar.gz archives (gzip compression)
- Naming convention: honeybadger-{username}-{date}.tar.gz
- Output directory: output-{username}-{date}/
- Generated reports:
  - lynis-report.json: Security audit in JSON format
  - os-kernel-status.txt: OS and kernel version analysis with PASS/FAIL verdict
    - Section 1: Operating system version and EOL status
    - Section 2: Kernel version information
    - Overall System Status: Clear PASS/FAIL/WARNING/UNKNOWN result
    - Recommendations: Specific actions based on status
    - ISO27001 compliance notes for failing systems
  - asset-inventory.txt: Asset registration information table
    - Hostname/Asset ID, Serial/Model, OS Edition + Version
    - Kernel Version, Nix Installation status
    - Disk Encryption status (LUKS detection)
    - Screen Lock configuration (auto-lock timeout)
    - Malware Scanner and Firewall status
    - OS Up-to-date status (Current/Supported/EOL)
    - Owner/User, Last Audit Date
    - Notes section for manual verification items
  - lynis-report-warnings_fails.html: Filtered security report with warnings and suggestions
    - Styled HTML report with only security issues
    - Automatically extracted from Lynis audit using jq
    - Includes severity levels and recommendations
    - Color-coded sections (red for warnings, blue for suggestions)
  - lynis-report-warnings_fails.pdf: PDF version
    - Generated automatically via Docker + wkhtmltopdf
    - Created during audit phase, not in check-output
    - File ownership may be root (from Docker), attempts automatic fix
  - neofetch.json: System information (JSON format)
  - honeybadger-info.txt: Tool version info
  - blockdevices.txt: Storage configuration
  - screenlock-info.txt: Screen lock settings
  - installed-packages.txt: Package inventory
  - lsb_release.txt: Distribution info (if available)
  - vulnix.json: CVE vulnerability scan results (NixOS only, if vulnix installed)
  - trivy.json: CVE vulnerability scan results (Arch/Ubuntu/Kali/macOS, if trivy installed)
  - cve-summary.txt: Human-readable CVE summary with severity counts

### RUNME.sh Commands
- **audit**: Run full security audit and generate report (Usage: `sudo ./RUNME.sh audit`)
  - **Requires root privileges** - script will exit with error if not run with sudo
  - **Dependency checks at startup**:
    - Required: lynis, docker, neofetch, jq, curl, tar, sed (exits if missing)
    - Required CVE scanners: vulnix (NixOS) or trivy (others) - exits if missing
  - Performs Lynis security audit
  - Converts Lynis report to JSON using Docker
  - Collects system information (neofetch, packages, block devices, screen lock)
  - Scans for CVE vulnerabilities (vulnix on NixOS, trivy on others - optional)
  - Generates OS/kernel status report with PASS/FAIL verdict
  - Generates asset inventory table
  - Generates filtered warnings/suggestions report (HTML/PDF via Docker)
  - Generates CVE summary report (if vulnerability scan completed)
  - Creates compressed tarball with all reports

- **check-output** `<directory|tarball.tar.gz|tarball.tar>`: Re-analyze existing audit output
  - Accepts output directory names (e.g., `output-user-09-02-2026`)
  - Accepts tar.gz files (e.g., `honeybadger-user-09-02-2026.tar.gz`)
  - Accepts tar files (e.g., `honeybadger-user-09-02-2026.tar`)
  - Auto-detects and extracts archives when directory not found (tries .tar.gz first, then .tar)
  - Prompts before overwriting existing directories (accepts y/n/yes/no)
  - Automatically fetches latest release information
  - Does NOT regenerate warnings/suggestions PDF (only created during audit)
  - **Generates report file**: `honeybadger-{username}-{date}-report.txt` containing all terminal output
    - Report includes all processing messages, status analysis, and inventory
    - Saved in current working directory
    - Filename derived from input (e.g., `output-user-09-02-2026` → `honeybadger-user-09-02-2026-report.txt`)
  - Generates OS/kernel status report with PASS/FAIL conclusion:
    - **PASS**: System is current, continue regular updates
    - **WARNING**: System is older but supported, upgrade recommended
    - **FAIL**: System is EOL, immediate upgrade required with security warnings
    - **UNKNOWN**: Unable to determine status, manual verification needed
  - Generates asset inventory table with:
    - Hardware identification (hostname, model, serial number)
    - OS and kernel versions
    - Security features (disk encryption, screen lock, firewall, AV)
    - Compliance status (OS up-to-date, Nix installation)
    - Owner/user and audit date information
  - Auto-cleanup of extracted files

- **fetch-releases** `[cache-dir]`: Update cached OS release information from APIs
  - Fetches from endoflife.date (NixOS, Ubuntu, Debian, Kali)
  - Fetches from kernel.org
  - Respects 24-hour cache TTL
  - Optional custom cache directory

- **submit** `[output-directory]`: Submit audit reports to honeybadger-server
  - **IMPORTANT**: Completely separate from audit command
  - Audit generates local reports only - submission is explicit opt-in
  - Usage: `./RUNME.sh submit` (submits most recent reports)
  - Usage: `./RUNME.sh submit output-hostname-user-17-03-2026` (submit specific directory)
  - Requires configuration file (.honeybadger.conf) with SERVER_ENABLED=true
  - Configuration locations (checked in order):
    1. ./.honeybadger.conf (current directory)
    2. ~/.honeybadger.conf (user home directory)
    3. /etc/honeybadger.conf (system-wide)
  - Configuration options:
    - SERVER_ENABLED: Enable/disable submission (default: false)
    - SERVER_URL: Server endpoint (default: http://localhost:7123/)
    - SERVER_TIMEOUT: Connection timeout in seconds (default: 30)
    - SERVER_RETRY_COUNT: Number of retry attempts (default: 3)
    - DRY_RUN: Test mode without actual HTTP requests (default: false)
  - Submits JSON reports: neofetch.json, lynis-report.json, vulnix.json/trivy.json
  - HTTP POST with headers: X-Hostname, X-Username, X-Report-Type
  - Retry logic with exponential backoff (1s, 2s, 4s)
  - Fails gracefully if server unavailable
  - Returns exit code 0 if at least one report submitted successfully
  - Returns exit code 1 if all submissions failed or invalid directory
  - Dry-run mode: Logs what would be submitted with curl command preview

## External Dependencies

### Required Tools
- **lynis**: https://github.com/CISOfy/lynis - Security auditing tool
- **docker**: Container runtime for report conversion
- **neofetch**: https://github.com/dylanaraps/neofetch - System info display
- **jq**: JSON processor for parsing and processing JSON reports
- **curl**: HTTP client for fetching OS release information from APIs
- **tar**: Archive creation
- **sed**: Text processing
- **CVE Scanners** (OS-specific, required):
  - **vulnix**: https://github.com/flyingcircusio/vulnix - CVE scanner for NixOS (install: `nix-env -iA nixpkgs.vulnix`)
  - **trivy**: https://aquasecurity.github.io/trivy/ - CVE scanner for Arch/Ubuntu/Kali/macOS

### Docker Image Components
Built from `debian:latest` with:
- **lynis-report-converter**: https://github.com/wearetechnative/lynis-report-converter (forked from d4t4king)
- **wkhtmltopdf**: 0.12.6.1 (manual install from GitHub releases)
  - Used for HTML to PDF conversion of warnings/suggestions report
  - Includes all required X11 and font dependencies
- **pandoc**: Document converter (from apt, used for fallback PDF generation)
- **texlive-latex-base** and **texlive-latex-recommended**: LaTeX support for pandoc
- **jq**: JSON processing (used for filtering warnings/suggestions)
- **Perl modules**:
  - Excel::Writer::XLSX (latest from CPAN)
  - XML::Writer (from system packages)
  - Archive::Zip (from system packages)
  - JSON (from system packages)

### External APIs
- **endoflife.date**: OS release information (NixOS, Ubuntu, Debian, Kali)
  - https://endoflife.date/api/nixos.json
  - https://endoflife.date/api/ubuntu.json
  - https://endoflife.date/api/debian.json
  - https://endoflife.date/api/kali-linux.json
- **kernel.org**: Linux kernel release information
  - https://www.kernel.org/releases.json

### Optional Dependencies (on host system)
- **lsb_release**: Linux distribution information
- **gsettings**: GNOME desktop settings
- **xfconf-query**: XFCE configuration query
- **kreadconfig5/6**: KDE configuration reader

Note: wkhtmltopdf, pandoc, and jq are NOT required on the host system as they are available in the Docker container.

## Copyright & Ownership
Copyright Technative 2024
Created by Pim, et al.
Repository: http://github.com/wearetechnative/personal-device-audit
