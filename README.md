# Honeybadger - a Personal Device Audit tool for ISO27001

Make your computer as tough as a honeybadger. And that is tough. Check this video...

[![YouTube](http://i.ytimg.com/vi/4r7wHMg5Yjg/hqdefault.jpg)](https://www.youtube.com/watch?v=4r7wHMg5Yjg)

## Prerequisites

### Linux and macOS

Install the required dependencies:

- **Docker**: Container runtime (required)
- **Lynis**: Security auditing tool (required)
- **neofetch**: System information display (required)
- **jq**: JSON processor (required)
- **curl**: HTTP client for API calls (required)
- **dmidecode**: Hardware information tool (recommended for serial number collection)
- **tar, sed**: Standard Unix utilities (usually pre-installed)

**Note:** `dmidecode` is recommended for hardware serial number collection but not required. On virtual machines or if dmidecode is unavailable, the serial number field will show "Not available".

#### Installing Lynis

**Debian/Ubuntu:**
```bash
sudo apt install lynis
```

**Fedora/RHEL:**
```bash
sudo dnf install lynis
```

**Arch Linux:**
```bash
sudo pacman -S lynis
```

**macOS (via Homebrew):**
```bash
brew install lynis
```

**From source (latest version):**
```bash
git clone https://github.com/CISOfy/lynis
cd lynis
sudo ./lynis audit system
```

To ensure you have the latest version, check https://github.com/CISOfy/lynis for updates.

## Usage on Linux and macOS

Open a terminal and execute the following:

```bash
git clone https://github.com/wearetechnative/honeybadger
cd honeybadger
sudo ./RUNME.sh audit
```

**Note:** The audit requires root privileges to perform a complete system security scan. The script will not run without sudo.

## What Gets Audited

Honeybadger performs a comprehensive security audit and collects the following information:

### Hardware & System Information
- **Device Serial Number** - Collected via dmidecode for hardware asset tracking
- **Hostname** - System identification
- **Model/Description** - Hardware model information
- **Operating System** - OS type, version, and kernel information
- **NixOS Metadata** (NixOS only) - Nixpkgs commit hash, system generation, last rebuild date

### Security Controls
- **Disk Encryption** - LUKS/dm-crypt detection
- **Screen Lock** - Auto-lock configuration for GNOME, KDE, Hyprland, Sway
- **OS Update Status** - Last update date, available updates, EOL checking
- **Firewall Status** - Active firewall detection
- **Malware Scanner** - Antivirus/scanner presence

### Compliance Metrics
- **Lynis Hardening Score** - Security hardening rating (0-100)
  - **Compliance Threshold: ≥65** - Systems must score 65 or higher to be compliant
  - Scores are categorized: Excellent (80-100), Good (60-79), Fair (40-59), Poor (0-39)
- **Security Findings** - Categorized by severity: Critical, High, Medium, Low
- **Package Information** - Installed software inventory

### Output Files

The audit generates the following reports in `output-<hostname>-<user>-<date>/`:

- `final-report.md` - **Consolidated final audit report** with all key information (asset ID, OS/kernel status, security controls, compliance metrics)
- `asset-inventory.txt` - Summary of all collected information with compliance status
- `lynis-report.json` - Detailed Lynis security audit data
- `lynis-report-warnings_fails.html` - HTML report with color-coded security findings
- `os-kernel-status.txt` - Operating system EOL status and recommendations
- `os-update-history.txt` - OS update history and last update date
- `hardware-serial.txt` - Device serial number
- `nixos-system-info.txt` - NixOS-specific metadata (NixOS only)
- `screenlock-info.txt` - Screen lock configuration details
- `blockdevices.txt` - Disk encryption information
- `installed-packages.txt` - Complete package listing

## ISO27001 Compliance Requirements

**Minimum Requirements:**
- ✅ Lynis Hardening Score ≥ 65
- ✅ Disk encryption enabled (LUKS or equivalent)
- ✅ Screen lock configured with auto-lock ≤15 minutes
- ✅ OS on supported version (not EOL)
- ✅ Regular updates (within 30 days)

Systems failing these requirements will be flagged in the `asset-inventory.txt` report with ❌ indicators.

## Usage on Windows

- download honeybadger as a zip-file from https://github.com/wearetechnative/honeybadger/archive/refs/heads/main.zip
- extract the zip-file 
- open a powershell as admin
- change you directory to the honeybadger directorty you've extracted.
- check copy full path of the RUNME.ps1 file
- `powershell -ExecutionPolicy Bypass -File $FULL_PATH_OF_RUNME.ps1`
- ./RUNME.ps1

## The results files

When the script has run successfully a zip or tarball with findings is stored in the
same directory. It looks like this: `honeybadger-pim-28-02-2025.tar.bz2`. Send
this file to the CISO or the person who asked you to do run this audit script.

The output is available in a bz2 file.

## Server Report Submission

Honeybadger can optionally submit audit reports to a centralized honeybadger-server for compliance monitoring and tracking.

### Configuration

Create a configuration file at one of these locations (checked in order):
1. `./.honeybadger.conf` (current directory)
2. `~/.honeybadger.conf` (user home directory)
3. `/etc/honeybadger.conf` (system-wide)

Example configuration (see `.honeybadger.conf.example`):

```bash
# Enable server submission
SERVER_ENABLED=true

# Server URL
SERVER_URL=http://honeybadger-server:7123/

# Connection timeout in seconds
SERVER_TIMEOUT=30

# Number of retry attempts on network failures
SERVER_RETRY_COUNT=3

# Dry-run mode: log what would be submitted without actual HTTP requests
DRY_RUN=false
```

### Submitting Reports

After running an audit, you can submit the reports to the server:

```bash
# Submit the most recent audit reports
./RUNME.sh submit

# Submit reports from a specific directory
./RUNME.sh submit output-hostname-user-17-03-2026
```

**Note:** Report submission is completely separate from the audit command. The audit generates local reports only. You must explicitly run the submit command to send reports to the server.

### Dry-Run Mode

To test submission without actually sending data to the server:

```bash
# Set DRY_RUN=true in your config file, then run:
./RUNME.sh submit
```

This will show what would be submitted, including the exact curl commands that would be executed.

## Credits

- [Video Embedding](https://githubvideo.com/)
- [Lynis](https://cisofy.com/lynis/)
- [Lynis Report Converter](https://github.com/d4t4king/lynis-report-converter)
- [Lynis Report Converter Dockerfile](https://github.com/oceanlazy/docker-lynis-report-converter)

---

© Technative 2024-2025
