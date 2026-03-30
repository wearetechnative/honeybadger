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

### Prerequisites (Windows 11)

Honeybadger for Windows uses HardeningKitty for security auditing. No additional software installation is required.

**Optional:** `neofetch` (automatically installed via winget if missing)

### Running the Audit

**Important:** Administrator privileges are required for complete system auditing (BitLocker, Windows Defender, some firewall checks).

#### Step 1: Download Honeybadger

Download as ZIP from: https://github.com/wearetechnative/honeybadger/archive/refs/heads/main.zip

Extract to a location like `C:\temp\honeybadger-main`

#### Step 2: Run the Audit

**Option A: Double-click (Easiest)**

1. Navigate to `C:\temp\honeybadger-main`
2. Right-click on **`RUNME.cmd`**
3. Select **"Run as administrator"**
4. Click "Yes" on the UAC prompt

The script will automatically start with the correct settings.

**Option B: Command Line**

1. Press `Windows Key`
2. Type `cmd`
3. Right-click on "Command Prompt"
4. Select **"Run as administrator"**
5. Run:

```cmd
cd C:\temp\honeybadger-main
RUNME.cmd
```

**Option C: PowerShell (Advanced)**

```powershell
cd C:\temp\honeybadger-main
.\AUDIT.ps1
```

#### Step 3: Submit Report (Optional)

After the audit completes, you can optionally submit the ZIP file to your compliance server:

```powershell
.\submit-report.ps1
```

**First time:** Copy `.honeybadger.conf.example` to `.honeybadger.conf` and configure:
- `SERVER_ENABLED=true`
- `SERVER_URL=https://your-server.com/api/reports`
- `SERVER_TOKEN=hb_token_your_token_here`

### Output Files (Windows)

The audit generates reports in `report-<date>/`:

- `honeybadger-<user>-<date>-compliance.md` - ISO27001 compliance report with pass/fail status
- `honeybadger-<user>-<date>-actions.md` - Prioritized security remediation items
- `hardeningkitty.csv` - Detailed HardeningKitty audit results
- `honeybadger-<hostname>-<user>-<date>.zip` - ZIP archive containing all reports (created automatically)

### What Gets Audited (Windows)

- **BitLocker Encryption** - Full disk encryption status and protection status (detects suspended BitLocker)
- **Screen Lock Settings** - Screensaver timeout, power management, lock policies
- **Windows Firewall** - Domain, Private, and Public profile status
- **Windows Update** - Last update date and compliance status (<14 days compliant, 14-30 days warning, >30 days non-compliant)
- **Windows Defender** - Real-time protection status and definition age
- **HardeningKitty Security Audit** - 300+ Windows security configuration checks against CIS benchmarks and Microsoft security baselines
- **Hardware Information** - Serial number, system model, OS version

### Compliance Thresholds (Windows)

| Control | Threshold | Status |
|---------|-----------|--------|
| BitLocker | Encrypted AND Protection On | ✅/❌ |
| Screen Lock | ≤15 minutes + password required | ✅/❌ |
| Firewall | All profiles enabled | ✅/❌ |
| OS Updates | <14 days ✅, 14-30 days ⚠️, >30 days ❌ | ✅/⚠️/❌ |
| Antivirus | Defender enabled + definitions <7 days | ✅/❌ |

### Without Administrator Privileges

The script will run without Administrator privileges but with limited functionality:
- ✅ HardeningKitty audit (works)
- ✅ Firewall check (works)
- ✅ Windows Update check (works)
- ✅ Screen Lock check (works)
- ❌ BitLocker check (requires Administrator)
- ⚠️ Windows Defender check (may be limited)

The script will warn you which checks are unavailable and continue with remaining checks.

## The Result Files

When the script has run successfully, a compressed archive with findings is stored in the same directory:

**Linux/macOS:** `honeybadger-hostname-user-date.tar.bz2` (tarball)
**Windows:** `honeybadger-hostname-user-date.zip` (ZIP archive)

Send this file to your CISO or the person who requested the audit.

### Submitting Reports

You can also submit reports directly to a centralized compliance server (see Server Report Submission section below).

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

# Bearer token for authentication (required)
# Example: SERVER_TOKEN=hb_token_faa0c072984086bf2c32055cbbf40c2
SERVER_TOKEN=hb_token_your_token_here

# Connection timeout in seconds
SERVER_TIMEOUT=30

# Number of retry attempts on network failures
SERVER_RETRY_COUNT=3

# Dry-run mode: log what would be submitted without actual HTTP requests
DRY_RUN=false
```

### Submitting Reports

After running an audit, you can submit reports to the server in two ways:

#### Submit Individual JSON Reports

Submit individual report files (neofetch.json, lynis-report.json, etc.):

```bash
# Submit the most recent audit reports
./RUNME.sh submit

# Submit reports from a specific directory
./RUNME.sh submit output-hostname-user-17-03-2026
```

#### Submit Complete Tar Archive

Submit the complete audit package as a single tar archive (simpler, single upload):

```bash
# Submit the most recent tar archive (auto-discovery)
./RUNME.sh submit-tar

# Submit a specific tar archive
./RUNME.sh submit-tar honeybadger-hostname-user-20-03-2026.tar.gz
```

**Server Requirements:**
- Individual JSON submission uses endpoint: `SERVER_URL/`
- Tar archive submission uses endpoint: `SERVER_URL/submit-tar`

**Note:** Report submission is completely separate from the audit command. The audit generates local reports only. You must explicitly run the submit command to send reports to the server.

### Dry-Run Mode

To test submission without actually sending data to the server:

```bash
# Set DRY_RUN=true in your config file, then run:
./RUNME.sh submit
# Or for tar submission:
./RUNME.sh submit-tar
```

This will show what would be submitted, including the exact curl commands that would be executed.

### Troubleshooting

**No tar files found:**
- Run an audit first: `sudo ./RUNME.sh audit`
- Check if tar files exist: `ls honeybadger-*.tar.gz`

**Connection timeout:**
- Increase `SERVER_TIMEOUT` in config (default: 30 seconds)
- Large tar files may need longer timeout (e.g., 60-120 seconds)

**Server returns 404 on /submit-tar:**
- Ensure honeybadger-server supports the `/submit-tar` endpoint
- Verify `SERVER_URL` is correct in configuration

**Permission denied:**
- Config file: `chmod 600 .honeybadger.conf`
- Tar files: ensure readable by current user

## Credits

- [Video Embedding](https://githubvideo.com/)
- [Lynis](https://cisofy.com/lynis/)
- [Lynis Report Converter](https://github.com/d4t4king/lynis-report-converter)
- [Lynis Report Converter Dockerfile](https://github.com/oceanlazy/docker-lynis-report-converter)

---

© Technative 2024-2025
