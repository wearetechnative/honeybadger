# Honeybadger - a Personal Device Audit tool for ISO27001

Make your computer as tough as a honeybadger. And that is tough. Check this video...

[![YouTube](http://i.ytimg.com/vi/4r7wHMg5Yjg/hqdefault.jpg)](https://www.youtube.com/watch?v=4r7wHMg5Yjg)

## Prerequisites

### Linux and macOS

Install the required dependencies:

- **Docker**: Container runtime (required)
- **Lynis**: Security auditing tool (required)
- **neofetch**: System information display (required)
- **tar, sed**: Standard Unix utilities (usually pre-installed)

Optional dependencies for CVE vulnerability scanning:

- **vulnix**: CVE scanner for NixOS (optional, NixOS only)
- **trivy**: CVE scanner for Arch/Ubuntu/Kali/macOS (optional)

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

#### Installing CVE Scanners (Optional)

For CVE vulnerability scanning support, install the appropriate tool for your system:

**NixOS (vulnix):**
```bash
nix-env -iA nixpkgs.vulnix
```

**Ubuntu/Debian (trivy):**
```bash
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt update
sudo apt install trivy
```

**Arch Linux (trivy):**
```bash
yay -S trivy
# or
sudo pacman -S trivy
```

**macOS (trivy):**
```bash
brew install trivy
```

Note: CVE scanning is optional. If the scanner is not installed, the audit will skip CVE scanning and continue with other checks.

## Usage on Linux and macOS

Open a terminal and execute the following:

```bash
git clone https://github.com/wearetechnative/honeybadger
cd honeybadger
sudo ./RUNME.sh audit
```

**Note:** The audit requires root privileges to perform a complete system security scan. The script will not run without sudo.

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
