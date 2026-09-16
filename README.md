# Honeybadger - a Personal Device Audit tool for ISO27001

Make your computer as tough as a honeybadger. And that is tough. Check this video...

[![YouTube](http://i.ytimg.com/vi/4r7wHMg5Yjg/hqdefault.jpg)](https://www.youtube.com/watch?v=4r7wHMg5Yjg)

## Prerequisites

### Linux and macOS

Install the required dependencies:

- **Lynis**: Security auditing tool (required)
- **fastfetch**: System information display (required)
- **python3**: Runs the Lynis report converter (required)
- **jq**: JSON processor (required)
- **curl**: HTTP client for API calls (required)
- **Docker**: Container runtime (optional, only when `USE_DOCKER_CONVERTER=true`)
- **dmidecode**: Hardware information tool (optional, a fallback only - see below)
- **tar, sed**: Standard Unix utilities (usually pre-installed)

**Note:** `dmidecode` is not required and is deliberately not a dependency
check. The serial is read from the kernel first, which works on every
distribution without installing anything. See
[Hardware serial number](#hardware-serial-number).

**Note:** no hostname tool is required either. `hostname(1)` lives in
`inetutils` and is not part of Arch's base install, so the audit resolves the
machine's name from `uname -n`, then `$HOSTNAME`, then `/etc/hostname`. If none
of the three yields a usable name the audit stops rather than writing output
whose name has an empty hostname in it.

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
- **Device Serial Number** - Read from the kernel, with tool-based fallbacks (see [Hardware serial number](#hardware-serial-number))
- **Hostname** - System identification
- **Model/Description** - Hardware model information
- **Operating System** - OS type, version, and kernel information
- **NixOS Metadata** (NixOS only) - Nixpkgs commit hash, system generation, last rebuild date

### Hardware serial number

The hardware serial is the key the collection server matches a submission to an
asset on, so the audit reads it from the kernel rather than depending on which
packages a machine happens to carry. Each source is tried only when the previous
one produced nothing usable.

**Linux** (identical on NixOS, Ubuntu, Debian and Arch - these are kernel
interfaces, not distribution features):

| Order | Source                               | Notes                              |
|-------|--------------------------------------|------------------------------------|
| 1     | `/sys/class/dmi/id/product_serial`   | root only, no tool, no network     |
| 2     | `/sys/class/dmi/id/board_serial`     | some vendors fill only this one    |
| 3     | `dmidecode -s system-serial-number`  | only when the tool is present      |
| 4     | `nix run nixpkgs#dmidecode`          | NixOS last resort, needs a network |

**macOS:**

| Order | Source                                | Notes                               |
|-------|---------------------------------------|-------------------------------------|
| 1     | `ioreg -d2 -c IOPlatformExpertDevice` | reads the serial as a property      |
| 2     | `system_profiler SPHardwareDataType`  | parsed on the `Serial Number` label |

A value is written only when it is usable: one token, no whitespace, not a
known firmware placeholder (`Not available`, `To Be Filled By O.E.M.`,
`Default string`, `System Serial Number`, `None`, `Unknown`, ...) and not all
zeroes. This is the same rule the collection server applies when matching, so
the client and the server agree on what counts as a serial.

When no usable serial is found, `hardware-serial.txt` holds one of two tokens
and the audit says which applies before it finishes:

| Token            | Meaning                                                     |
|------------------|-------------------------------------------------------------|
| `could-not-read` | No source returned a value - a machine or packaging problem |
| `none-present`   | A source answered, but the hardware has no serial - a VM    |

The first is worth chasing. The second is a fact about the machine: such an
asset needs a different key in the register rather than a repair.

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
- `hardware-serial.txt` - Device serial number, or `could-not-read` / `none-present`
- `hardware-serial-source.txt` - Which source the serial came from
- `nixos-system-info.txt` - NixOS-specific metadata (NixOS only)
- `screenlock-info.txt` - Screen lock configuration details
- `blockdevices.txt` - Disk encryption information
- `installed-packages.txt` - Complete package listing

### Compliance Reports

Running `./RUNME.sh check-output <output-directory|tarball>` analyses a completed audit and
writes three reports to the current directory:

- `honeybadger-<user>-<date>-compliance.md` - ISO27001 compliance checklist with pass/fail status
- `honeybadger-<user>-<date>-actions.md` - Critical and high severity Lynis findings to remediate
- `honeybadger-<user>-<date>-xlsx.md` - Field values for the ISO27001 asset register
  (`iso27001-compliance-essential.xlsx`, sheet `Active Assets`)

The xlsx report lists, per spreadsheet column, the cell value to enter and the audit finding it
was derived from. It also marks the columns you maintain yourself (asset ID, owner, proof file,
remarks) and the two columns that contain formulas and must not be overwritten. Honeybadger never
reads from or writes to the spreadsheet - updating the register stays a manual step.

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

### Asset Inventory

Each audit writes two views of the same findings into the output directory:

| File | For |
|------------------------|-----------------------------------------------|
| `asset-inventory.txt` | Reading - a formatted table |
| `asset-inventory.json` | The collection server, and anything else that parses |

Plus `honeybadger-{user}-{date}-xlsx.md` in the current directory, which lists
the cell values for the `Active Assets` sheet.

All three come from one set of determinations. Whether a disk counts as
encrypted or a hardening score as compliant is platform-specific knowledge that
lives in this client, and a second implementation of those rules elsewhere would
drift from it.

Each finding in the JSON carries both the determined value and the finding it
came from, because "Yes" and "Yes (LUKS)" answer different questions:

```json
"disk_encryption": { "value": "Yes", "finding": "Yes (LUKS)" }
```

A value the audit could not determine, or deliberately declines to assert, is
`null` with the finding intact:

```json
"vulnerable_packages": {
  "value": null,
  "finding": "niet vastgesteld - geen package audit tool aanwezig"
}
```

That is not the same as an absent key. `null` means "not determined, and here
is why"; an absent key means this generation of the client does not report it at
all. `schema_version` is how a consumer tells generations apart.

### Server Configuration

Copy `.honeybadger.conf.example` to `.honeybadger.conf` and fill in the server
URL and the token the badgersbay administrator issued you. The file is local to
each machine and gitignored; the token is what distinguishes you from anyone
else who might try to upload.

Settings resolve in this order, first match wins:

| Source | Example |
|--------------------|---------------------------------------------|
| Environment | `SERVER_URL=http://localhost:7123/ ./RUNME.sh submit` |
| Configuration file | `SERVER_URL=https://badgersbay.example/` |
| Built-in default | `http://localhost:7123/` |

The environment winning is deliberate and announced in the output, because a
configuration file that can be silently overridden is its own kind of surprise:

```
Loading configuration from: ./.honeybadger.conf
From the environment (overriding the file): DRY_RUN
```

A setting exported as an empty string counts as supplied, so an intentionally
empty token is not quietly refilled from the file.

#### Naming a configuration file

```bash
# On the command line
./RUNME.sh submit --config /path/to/test.conf

# Or from the environment, for callers that cannot pass arguments
HONEYBADGER_CONFIG=/path/to/test.conf ./RUNME.sh submit
```

Either skips the search order entirely. A named file that does not exist is an
error rather than a silent fallback - falling back would submit somewhere you
did not ask for.

Without one, the search order is `./.honeybadger.conf`, then
`~/.honeybadger.conf`, then `/etc/honeybadger.conf`.

### Submitting Reports

After running an audit, submit the archive:

```bash
# Submit the most recent archive (auto-discovery)
./RUNME.sh submit

# Submit a specific archive
./RUNME.sh submit honeybadger-hostname-user-20-03-2026.tar.gz
```

The archive goes to `SERVER_URL/submit-tar`. It carries `hardware-serial.txt`,
which is how the server resolves which asset in the ISO register the submission
belongs to. The submission names no report types of its own: the server derives
them from the file names inside the archive.

The server answers HTTP 207 when it stored a submission but could not resolve
it fully - most often because the hardware serial is not in the asset register.
That counts as submitted; the server's remark is printed rather than the same
evidence being resent.

#### Why there is only one path

There used to be a second command that submitted reports one at a time to
`SERVER_URL/`. That endpoint has no concept of a hardware serial, so its
submissions could never be attributed to an asset: they landed under hostname
and username with no evidence archive beside them. It has been removed.

`submit-tar` still works as a deprecated alias, so scheduled jobs calling it do
not fail, but it prints a warning and does exactly what `submit` does.

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
