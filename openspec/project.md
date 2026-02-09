# Project Context

## Purpose
Honeybadger is a Personal Device Audit tool for ISO27001 compliance. It
performs comprehensive security audits on Linux and macOS systems, generating
detailed reports about system security posture, configuration, and compliance
status.

The tool is designed to "make your computer as tough as a honeybadger" by
thoroughly auditing device security configurations.

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
- **wkhtmltopdf** (optional): HTML to PDF conversion in Docker container

## Project Conventions

### File Structure
- **RUNME.sh**: Main entry point with command framework
- **_library**: Shared function library (sourced by RUNME.sh)
  - Cache management functions
  - OS/kernel release query functions
  - Status checking and analysis functions
  - Asset inventory generation
  - Warnings/suggestions report generation (HTML/PDF)
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
- **Library system**: _library file contains reusable functions (sourced by RUNME.sh)
- **Container-based conversion**: Docker isolates report conversion dependencies
  - Uses volume mounts instead of copying files (--rm flag for auto-cleanup)
  - Docker image caching to avoid unnecessary rebuilds
  - Read-only volume mounts for security
- **Multi-format output**: Reports generated in multiple formats (JSON, text)
- **Comprehensive data collection**: System info, security audit, package lists, lock screen configs
- **OS/Kernel status checking**: Dynamic release checking via endoflife.date API and kernel.org
- **Cache management**: 24-hour TTL for release information to minimize API calls
- **Error handling**: Exit on error (set -e), explicit error messages, graceful failure modes

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
    - Automatically extracted from Lynis audit
    - Includes severity levels and recommendations
    - Can be manually converted to PDF or viewed in browser
  - lynis-report-warnings_fails.pdf: PDF version (if PDF converter available)
    - Generated using wkhtmltopdf (in Docker) or weasyprint/pandoc (on host)
    - Fallback to HTML if no converter available
  - neofetch.txt: System information
  - honeybadger-info.txt: Tool version info
  - blockdevices.txt: Storage configuration
  - screenlock-info.txt: Screen lock settings
  - installed-packages.txt: Package inventory
  - lsb_release.txt: Distribution info (if available)

### RUNME.sh Commands
- **audit**: Run full security audit and generate report
  - Performs Lynis security audit
  - Collects system information (neofetch, packages, block devices, screen lock)
  - Generates OS/kernel status report with PASS/FAIL verdict
  - Generates asset inventory table
  - Generates filtered warnings/suggestions report (HTML/PDF)
  - Creates compressed tarball with all reports

- **check-output** `<directory|tarball.tar.gz>`: Analyze OS/kernel status and generate asset inventory from existing output
  - Accepts output directory names (e.g., `output-user-09-02-2026`)
  - Accepts tar.gz files (e.g., `honeybadger-user-09-02-2026.tar.gz`)
  - Auto-detects and extracts tarballs when directory not found
  - Prompts before overwriting existing directories (accepts y/n/yes/no)
  - Automatically fetches latest release information
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

## External Dependencies

### Required Tools
- **lynis**: https://github.com/CISOfy/lynis - Security auditing tool
- **docker**: Container runtime for report conversion
- **neofetch**: https://github.com/dylanaraps/neofetch - System info display
- **tar**: Archive creation
- **sed**: Text processing

### Docker Image Components
Built from `debian:latest` with:
- **lynis-report-converter**: https://github.com/wearetechnative/lynis-report-converter (forked from d4t4king)
- **Perl modules**:
  - HTML::HTMLDoc (latest from CPAN)
  - Excel::Writer::XLSX (latest from CPAN)
  - XML::Writer
  - Archive::Zip
  - JSON
- **htmldoc**: HTML to PDF conversion

### External APIs
- **endoflife.date**: OS release information (NixOS, Ubuntu, Debian, Kali)
  - https://endoflife.date/api/nixos.json
  - https://endoflife.date/api/ubuntu.json
  - https://endoflife.date/api/debian.json
  - https://endoflife.date/api/kali-linux.json
- **kernel.org**: Linux kernel release information
  - https://www.kernel.org/releases.json

### Optional Dependencies
- **lsb_release**: Linux distribution information
- **gsettings**: GNOME desktop settings
- **xfconf-query**: XFCE configuration query
- **kreadconfig5/6**: KDE configuration reader

## Copyright & Ownership
Copyright Technative 2024
Created by Pim, et al.
Repository: http://github.com/wearetechnative/personal-device-audit
