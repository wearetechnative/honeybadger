# Honeybadger Uitbreidingen - Aanbevelingen

**Datum**: 4 februari 2026
**Doorlooptijd**: 1 week werk, 2 weken doorlooptijd
**Doel**: Aanpassing Information Security Policy naleving (7.1 en 8.1)

## Samenvatting

Deze aanbevelingen dekken drie hoofdgebieden:
1. **Antivirus software detectie** (Policy 7.1) - Wekelijkse controle
2. **CVE-based patchbeleid** (Policy 8.1) - Self-hosted software vulnerability scanning
3. **Automatische scheduling** - Wekelijkse uitvoering

## Huidige Situatie

### Wat Honeybadger al doet:
- ✅ Lynis security audit (uitgebreide systeemhardening checks)
- ✅ Windows Defender status (alleen Windows via windows-lynis-report-parser.ps1)
- ✅ Update suggestions van Lynis (basis patch monitoring)
- ✅ Geïnstalleerde packages inventarisatie
- ✅ Screen lock configuratie monitoring
- ✅ System info en block device encryption checks

### Wat ontbreekt:
- ❌ Linux/macOS antivirus software detectie
- ❌ CVE vulnerability database checking
- ❌ Self-hosted software identificatie en tracking
- ❌ Wekelijkse automatische scheduling
- ❌ Gestructureerde compliance rapportage per policy sectie

---

## Aanbeveling 1: Antivirus Software Detectie (Policy 7.1)

### Doel
Detecteer welke antivirus software daadwerkelijk is geïnstalleerd en actief op het systeem.

### Implementatie

#### Linux Antivirus Detection
Voeg detectie toe voor:
- **ClamAV**: `clamscan --version`, daemon status, signature updates
- **ESET NOD32**: Process check, versie info
- **Sophos**: `savdstatus`, service status
- **Bitdefender**: Process en service check
- **Comodo**: Installation en service status
- **F-Prot**: Installation check

#### macOS Antivirus Detection
Voeg detectie toe voor:
- **macOS XProtect**: Built-in malware protection status
- **ClamAV**: Als geïnstalleerd via Homebrew
- **Sophos Home**: Application en process check
- **Avast**: Application check
- **AVG**: Application check
- **Bitdefender**: Application check
- **Malwarebytes**: Application check

#### Windows (uitbreiding bestaande code)
De huidige Windows Defender detectie is goed, maar voeg toe:
- **Third-party AV detection**: Norton, McAfee, Kaspersky, etc.
- **Windows Security Center** query voor alle geregistreerde AV producten

### Implementatie Details

```bash
# Nieuw bestand: RUNME.sh functie uitbreiding
function checkAntivirusStatus {
  echo "=== ANTIVIRUS SOFTWARE DETECTION ===" > $output/antivirus-info.txt

  if [[ ${osType} == "linux" ]]; then
    # Check ClamAV
    if command -v clamscan >/dev/null 2>&1; then
      echo "FOUND: ClamAV" >> $output/antivirus-info.txt
      clamscan --version >> $output/antivirus-info.txt 2>&1

      # Check daemon status
      if systemctl is-active --quiet clamav-daemon 2>/dev/null; then
        echo "ClamAV Daemon: ACTIVE" >> $output/antivirus-info.txt
      else
        echo "ClamAV Daemon: INACTIVE" >> $output/antivirus-info.txt
      fi

      # Check signature freshness
      if [ -f /var/lib/clamav/daily.cvd ] || [ -f /var/lib/clamav/daily.cld ]; then
        find /var/lib/clamav -name "*.c?d" -printf "Last update: %TY-%Tm-%Td %TH:%TM\n" | head -1 >> $output/antivirus-info.txt
      fi
    fi

    # Check for other AV software processes
    for av_proc in savd sophossps bdagentd; do
      if pgrep -x "$av_proc" >/dev/null 2>&1; then
        echo "FOUND: AV process $av_proc running" >> $output/antivirus-info.txt
      fi
    done

  elif [[ ${osType} == "macos" ]]; then
    # Check macOS XProtect
    echo "Checking macOS XProtect..." >> $output/antivirus-info.txt
    if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ]; then
      echo "FOUND: macOS XProtect (built-in)" >> $output/antivirus-info.txt
      defaults read /Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>&1 >> $output/antivirus-info.txt || echo "Version: Unknown"
    fi

    # Check for third-party AV
    av_apps=("ClamAV" "Sophos Anti-Virus" "Avast" "AVG AntiVirus" "Bitdefender" "Malwarebytes")
    for app in "${av_apps[@]}"; do
      if [ -d "/Applications/$app.app" ]; then
        echo "FOUND: $app" >> $output/antivirus-info.txt
      fi
    done
  fi

  # Compliance check
  echo "" >> $output/antivirus-info.txt
  echo "=== COMPLIANCE STATUS ===" >> $output/antivirus-info.txt
  if grep -q "FOUND:" $output/antivirus-info.txt; then
    echo "STATUS: COMPLIANT - Antivirus software detected" >> $output/antivirus-info.txt
  else
    echo "STATUS: NON-COMPLIANT - No antivirus software detected" >> $output/antivirus-info.txt
  fi
}
```

### Integratie in RUNME.sh
Voeg aan de `audit()` functie toe (rond regel 101):
```bash
checkAntivirusStatus
```

**Workload**: 4 uur (implementatie + testing op Linux/macOS)

---

## Aanbeveling 2: CVE Database Checking voor Self-Hosted Software (Policy 8.1)

### Doel
Controleer self-hosted software op bekende CVE vulnerabilities via geautomatiseerde database queries.

### Implementatie Opties

#### Optie A: Grype (Aanbevolen) ⭐
**Voordeel**: Gratis, open-source, offline database, snelle scans

```bash
function checkCVEVulnerabilities {
  echo "=== CVE VULNERABILITY SCAN ===" > $output/cve-vulnerabilities.json

  # Install grype if not present (one-time)
  if ! command -v grype >/dev/null 2>&1; then
    echo "Installing Grype vulnerability scanner..."
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
  fi

  # Scan installed packages
  echo "Scanning system packages for CVE vulnerabilities..."
  grype dir:/ --scope all-layers -o json > $output/cve-vulnerabilities.json 2>&1

  # Generate summary
  critical_count=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' $output/cve-vulnerabilities.json)
  high_count=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' $output/cve-vulnerabilities.json)

  echo "=== CVE SCAN SUMMARY ===" > $output/cve-summary.txt
  echo "Critical vulnerabilities: $critical_count" >> $output/cve-summary.txt
  echo "High vulnerabilities: $high_count" >> $output/cve-summary.txt

  if [ "$critical_count" -gt 0 ] || [ "$high_count" -gt 0 ]; then
    echo "STATUS: ACTION REQUIRED - Critical/High CVEs found" >> $output/cve-summary.txt
  else
    echo "STATUS: OK - No critical vulnerabilities detected" >> $output/cve-summary.txt
  fi
}
```

**Dependencies**:
- Grype: https://github.com/anchore/grype
- jq (already used in project)

**Workload**: 6 uur (implementatie, testing, documentatie)

#### Optie B: Trivy (Alternatief)
Vergelijkbaar met Grype, ook uitstekende CVE database coverage.

```bash
# Similar implementation with trivy
trivy rootfs --format json --output $output/cve-vulnerabilities.json /
```

#### Optie C: OWASP Dependency-Check
Meer gericht op application dependencies (Java, .NET, Python, etc.)

### Docker Container Scanning (Bonus)
Voeg ook Docker container vulnerability scanning toe:

```bash
# Scan all running containers
docker ps --format "{{.Names}}" | while read container; do
  echo "Scanning container: $container"
  grype docker:$container -o json > $output/cve-docker-$container.json
done
```

**Workload**: +2 uur extra

---

## Aanbeveling 3: Wekelijkse Automatische Scheduling

### Doel
Automatiseer wekelijkse Honeybadger audits conform policy vereisten.

### Implementatie Opties

#### Optie A: Systemd Timer (Linux) - Aanbevolen ⭐

Create `/etc/systemd/system/honeybadger-audit.service`:
```ini
[Unit]
Description=Honeybadger Weekly Security Audit
After=network-online.target docker.service

[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/honeybadger
ExecStart=/opt/honeybadger/RUNME.sh audit
StandardOutput=journal
StandardError=journal
```

Create `/etc/systemd/system/honeybadger-audit.timer`:
```ini
[Unit]
Description=Run Honeybadger audit weekly
Requires=honeybadger-audit.service

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```

Install script:
```bash
#!/bin/bash
# install-scheduler.sh

# Copy honeybadger to /opt
sudo cp -r . /opt/honeybadger

# Install systemd units
sudo cp systemd/honeybadger-audit.service /etc/systemd/system/
sudo cp systemd/honeybadger-audit.timer /etc/systemd/system/

# Enable and start timer
sudo systemctl daemon-reload
sudo systemctl enable honeybadger-audit.timer
sudo systemctl start honeybadger-audit.timer

# Show status
sudo systemctl status honeybadger-audit.timer
```

**Workload**: 3 uur

#### Optie B: Cron (Cross-platform)

```bash
# Install via cron
# Runs every Monday at 9:00 AM
0 9 * * 1 cd /opt/honeybadger && ./RUNME.sh audit
```

Install script:
```bash
#!/bin/bash
# install-cron.sh
(crontab -l 2>/dev/null; echo "0 9 * * 1 cd /opt/honeybadger && ./RUNME.sh audit") | crontab -
```

**Workload**: 1.5 uur

#### Optie C: macOS LaunchAgent

Create `~/Library/LaunchAgents/com.technative.honeybadger.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.technative.honeybadger</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/honeybadger/RUNME.sh</string>
        <string>audit</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>1</integer>
        <key>Hour</key>
        <integer>9</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/tmp/honeybadger.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/honeybadger.error.log</string>
</dict>
</plist>
```

**Workload**: 2 uur

### Report Delivery
Voeg automatische report delivery toe via email of centraal logging:

```bash
# Add to end of audit() function
function sendReport {
  if command -v mail >/dev/null 2>&1; then
    echo "Honeybadger audit completed. See attached report." | \
      mail -s "Honeybadger Audit - $(hostname) - $(date +%Y-%m-%d)" \
      -a $tarball \
      security@company.com
  fi
}
```

**Workload**: +1 uur

---

## Aanbeveling 4: Compliance Reporting Dashboard

### Doel
Genereer gestructureerde compliance rapportage die direct aansluit bij policy secties.

### Implementatie

Create nieuw script: `generate-compliance-report.sh`
```bash
#!/bin/bash
# Generates compliance summary from audit results

OUTPUT_DIR=$1
REPORT="$OUTPUT_DIR/compliance-report.txt"

echo "========================================" > $REPORT
echo "  HONEYBADGER COMPLIANCE REPORT" >> $REPORT
echo "  Date: $(date)" >> $REPORT
echo "  Hostname: $(hostname)" >> $REPORT
echo "========================================" >> $REPORT
echo "" >> $REPORT

# Section 7.1: Antivirus Software
echo "7.1 ANTIVIRUS SOFTWARE PROTECTION" >> $REPORT
echo "-----------------------------------" >> $REPORT
if [ -f "$OUTPUT_DIR/antivirus-info.txt" ]; then
  grep "STATUS:" "$OUTPUT_DIR/antivirus-info.txt" >> $REPORT
  grep "FOUND:" "$OUTPUT_DIR/antivirus-info.txt" | head -5 >> $REPORT
else
  echo "STATUS: NOT CHECKED" >> $REPORT
fi
echo "" >> $REPORT

# Section 8.1: Patch Management (CVE)
echo "8.1 PATCH MANAGEMENT - CVE VULNERABILITIES" >> $REPORT
echo "-------------------------------------------" >> $REPORT
if [ -f "$OUTPUT_DIR/cve-summary.txt" ]; then
  cat "$OUTPUT_DIR/cve-summary.txt" >> $REPORT
else
  echo "STATUS: NOT CHECKED" >> $REPORT
fi
echo "" >> $REPORT

# Lynis hardening score
echo "SYSTEM HARDENING SCORE" >> $REPORT
echo "----------------------" >> $REPORT
if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
  jq -r '.lynis_summary.hardening_index' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null >> $REPORT || echo "Unable to parse"
fi
echo "" >> $REPORT

# Critical findings summary
echo "CRITICAL FINDINGS SUMMARY" >> $REPORT
echo "-------------------------" >> $REPORT
if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
  jq -r '.warning[] | .description' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null | head -10 >> $REPORT || echo "No warnings found"
fi
```

Voeg aan `audit()` toe:
```bash
# Generate compliance report
bash generate-compliance-report.sh $output
```

**Workload**: 4 uur

---

## Aanbeveling 5: Elastiscan Integratie (Optioneel)

### Context
Genoemd in requirements: "Elastiscan: 2 wkn met doorlooptijd 4 wkn"

### Vraag aan Product Owner
Verduidelijk Elastiscan requirements:
- Is dit een bestaande tool van Technative?
- Moet Honeybadger data naar Elastiscan sturen?
- Wat is het data format/protocol?
- REST API? File export? Database insert?

**Workload**: TBD (afhankelijk van Elastiscan specificaties)

---

## Totale Workload Overzicht

| Component | Workload | Prioriteit |
|-----------|----------|------------|
| 1. Antivirus detectie (Linux/macOS) | 4 uur | Hoog |
| 2. CVE vulnerability scanning (Grype) | 6 uur | Hoog |
| 2a. Docker container scanning | 2 uur | Medium |
| 3. Wekelijkse scheduling (systemd) | 3 uur | Hoog |
| 3a. Report delivery (email) | 1 uur | Medium |
| 4. Compliance reporting dashboard | 4 uur | Hoog |
| 5. Testing & documentatie | 4 uur | Hoog |
| 6. README updates | 1 uur | Medium |
| **TOTAAL CORE** | **22 uur** | **~3 dagen** |
| **TOTAAL MET OPTIES** | **27 uur** | **~3.5 dagen** |

**Doorlooptijd**: 2 weken (inclusief review, testing op verschillende platforms, documentatie)

---

## Implementatie Roadmap

### Week 1: Core Features
**Dagen 1-2**:
- Implementeer antivirus detectie (Linux/macOS/Windows uitbreiding)
- Test op meerdere platformen

**Dagen 3-4**:
- Implementeer CVE vulnerability scanning met Grype
- Integreer in RUNME.sh audit flow
- Test CVE rapportage

**Dag 5**:
- Implementeer wekelijkse scheduling (systemd + cron + LaunchAgent)
- Compliance report generator

### Week 2: Testing & Refinement
**Dagen 6-7**:
- Cross-platform testing
- Bug fixes
- Performance optimalisatie

**Dagen 8-9**:
- Documentatie updates (README, project.md)
- User guide voor nieuwe features
- Admin guide voor scheduling setup

**Dag 10**:
- Code review
- Security review nieuwe functionaliteit
- Release preparation

---

## Aanvullende Aanbevelingen

### 1. Centralized Reporting (Toekomstig)
Overweeg centrale rapportage server waar alle Honeybadger clients hun reports naartoe sturen:
- Centraal dashboard voor compliance status gehele organisatie
- Alerting bij non-compliance
- Trend analysis over tijd

### 2. Policy-as-Code
Definieer compliance policies in code (JSON/YAML):
```yaml
policies:
  - id: "7.1"
    name: "Antivirus Protection"
    required: true
    checks:
      - antivirus_installed: true
      - antivirus_active: true
      - signatures_updated_days: 7

  - id: "8.1"
    name: "Patch Management"
    required: true
    checks:
      - critical_cve_count: 0
      - high_cve_count: 5  # max 5 high CVEs allowed
```

### 3. Auto-remediation (Advanced)
Voor bepaalde findings automatische remediation:
- Update antivirus signatures
- Install security patches (met approval)
- Enable missing security features

---

## Dependencies & Prerequisites

### Nieuwe Dependencies
- **grype**: CVE vulnerability scanner
  - Install: `curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh`
- **jq**: JSON parsing (al in gebruik)

### Optionele Dependencies
- **mail/sendmail**: Email report delivery
- **systemd**: Linux scheduling (meeste moderne distros)

### Platform Support
- ✅ Linux: Debian, Ubuntu, Fedora, Arch, NixOS
- ✅ macOS: 10.15+
- ✅ Windows: Bestaande Windows support blijft werken

---

## Risico's & Mitigaties

| Risico | Impact | Mitigatie |
|--------|--------|-----------|
| Grype performance bij grote systemen | Medium | Implementeer timeout en scope limiting |
| False positives in CVE scanning | Medium | Manual review proces, whitelist functionaliteit |
| Scheduling permissions (requires root) | Low | Duidelijke documentatie, install script |
| Platform verschillen AV software | Low | Uitgebreide testing, graceful fallbacks |

---

## Deliverables

1. ✅ Antivirus detection module (Linux/macOS/Windows)
2. ✅ CVE vulnerability scanning integration
3. ✅ Wekelijkse scheduling scripts (systemd/cron/LaunchAgent)
4. ✅ Compliance reporting generator
5. ✅ Bijgewerkte documentatie
6. ✅ Installation guide voor scheduling
7. ✅ Test reports op 3+ platformen

---

## Vragen voor Product Owner / CISO

1. **Elastiscan**: Wat zijn de exacte requirements voor Elastiscan integratie?
2. **Report Delivery**: Waar moeten wekelijkse reports naartoe? Email? Central server? SharePoint?
3. **CVE Thresholds**: Wat zijn acceptabele limieten voor CVE counts? (bijv. 0 critical, max 5 high?)
4. **Remediation**: Moet Honeybadger ook auto-remediation kunnen of alleen rapportage?
5. **Central Dashboard**: Is er interesse in een centrale compliance dashboard voor hele organisatie?
6. **Policy Sections**: Zijn er nog andere policy secties die gemonitord moeten worden?

---

## Conclusie

Met deze uitbreidingen wordt Honeybadger een complete ISO27001 compliance monitoring tool die:
- ✅ **Policy 7.1**: Antivirus software detecteert en monitort
- ✅ **Policy 8.1**: CVE vulnerabilities tracked via database
- ✅ **Wekelijks**: Automatisch draait en rapporteert
- ✅ **Compliance**: Duidelijke compliance status per policy sectie rapporteert

De implementatie is goed te doen binnen 1 week development + 1 week testing/documentatie, en voldoet aan alle genoemde requirements.
