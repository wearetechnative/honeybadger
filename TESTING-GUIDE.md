# Testing Guide - ISO27001 Compliance Reporting Features

This guide covers testing for the new features added in v0.6.0.

## Prerequisites

Before testing:
- ✅ Code changes implemented
- ✅ Documentation updated (README, CHANGELOG)
- ✅ Error handling verified
- ✅ Backward compatibility confirmed

## Group 8: Testing Checklist

### 8.1 Test on Arch Linux
```bash
sudo ./RUNME.sh audit
```
**Verify:**
- [ ] Serial number collected (check `hardware-serial.txt`)
- [ ] OS update history generated (`os-update-history.txt`)
- [ ] Lynis hardening score shown in `asset-inventory.txt`
- [ ] Score has compliance indicator (✅/❌)
- [ ] HTML report has severity-categorized findings

### 8.2 Test on Ubuntu
```bash
sudo ./RUNME.sh audit
```
**Verify:**
- [ ] All features work on Debian-based system
- [ ] Update history shows apt information
- [ ] dmidecode works (or gracefully fails on VM)

### 8.3 Test on NixOS
```bash
sudo ./RUNME.sh audit
```
**Verify:**
- [ ] NixOS metadata collected (`nixos-system-info.txt`)
- [ ] Commit hash extracted and shown in asset inventory
- [ ] System generation number displayed
- [ ] Update history shows NixOS channel info

### 8.4 Test on VM (Serial Number Fallback)
```bash
sudo ./RUNME.sh audit
```
**Verify:**
- [ ] Audit completes without errors
- [ ] Serial number shows "Not available"
- [ ] No error messages about missing dmidecode

### 8.5 Test with Low Hardening Score
**Simulate a system with score <65:**
- Find system with low Lynis score, or
- Manually edit `lynis-report.json` to set `hardening_index: 58`
- Run `./RUNME.sh check-output output-dir/`

**Verify:**
- [ ] Score shows ❌ NON-COMPLIANT indicator
- [ ] Message: "required: ≥65"
- [ ] Status shows as "Fair" or "Poor"

### 8.6 Test without dmidecode
```bash
# Temporarily rename dmidecode
sudo mv /usr/bin/dmidecode /usr/bin/dmidecode.bak

sudo ./RUNME.sh audit

# Restore dmidecode
sudo mv /usr/bin/dmidecode.bak /usr/bin/dmidecode
```
**Verify:**
- [ ] Audit completes successfully
- [ ] Serial number field shows "Not available"
- [ ] No errors in output

### 8.7 Verify All New Output Files
After audit, check that these files exist and contain data:
```bash
ls -lh output-*/
```
**Expected files:**
- [ ] `hardware-serial.txt` - Contains serial number or "Not available"
- [ ] `os-update-history.txt` - Update status and last update date
- [ ] `asset-inventory.txt` - Includes new fields (serial, score, NixOS if applicable)
- [ ] `lynis-report-warnings_fails.html` - Severity-grouped findings

### 8.8 Verify Asset Inventory Fields
```bash
cat output-*/asset-inventory.txt
```
**Check for these fields:**
- [ ] Serial Number (separate from Model)
- [ ] Model
- [ ] Lynis Hardening Score (with status and compliance)
- [ ] NixOS Commit Hash (NixOS only)
- [ ] NixOS Generation (NixOS only)

### 8.9 Verify HTML Severity Categorization
Open in browser:
```bash
firefox output-*/lynis-report-warnings_fails.html
```
**Verify:**
- [ ] Summary shows counts: "X critical, Y high, Z medium findings"
- [ ] Findings grouped into sections: Critical, High, Medium, Low, Other
- [ ] Color coding works: 🔴 red, 🟠 orange, 🟡 yellow, 🔵 blue, ⚪ gray
- [ ] Severity badges on each finding
- [ ] Critical section at top (if any critical findings)

## Group 10.5-10.6: Final Steps

### 10.5 Multi-Distribution Testing
Run audit on:
- [ ] Arch Linux (or Manjaro)
- [ ] Ubuntu/Debian
- [ ] NixOS
- [ ] VM environment
- [ ] macOS (if available)

Compare outputs - all should work correctly.

### 10.6 Git Commit Preparation

**Follow project git commit guidelines:**
- Do NOT mention "Claude" or AI assistance in commits
- Write as human developer
- Focus on what changed and why

**Suggested commit structure:**
```bash
git add lib/_library RUNME.sh
git commit -m "Add ISO27001 compliance tracking features

Implement hardware serial number collection, OS update history tracking,
Lynis hardening score display with threshold validation (≥65), NixOS
metadata collection, and severity-based categorization of security findings.

- Collect device serial numbers via dmidecode
- Integrate check-os-updates.sh for update tracking
- Display and validate Lynis hardening scores
- Add NixOS commit hash and generation tracking
- Categorize Lynis findings by severity (Critical/High/Medium/Low)
- Update HTML reports with color-coded severity sections
"

git add README.md CHANGELOG.md
git commit -m "Update documentation for v0.6.0 compliance features

Document new ISO27001 compliance requirements, output files, and
hardening score threshold. Add dmidecode to dependencies."
```

## Success Criteria

All tests pass when:
- ✅ Audit runs successfully on all tested distributions
- ✅ All new output files are generated
- ✅ Serial numbers collected (or gracefully degraded)
- ✅ Hardening scores shown with compliance indicators
- ✅ NixOS metadata collected on NixOS systems
- ✅ HTML report shows severity-categorized findings
- ✅ No errors or warnings during audit
- ✅ Backward compatibility maintained

## Troubleshooting

**If dmidecode fails:**
- Normal on VMs - should show "Not available"
- Check dmidecode is installed: `which dmidecode`
- Try manually: `sudo dmidecode -s system-serial-number`

**If NixOS metadata missing:**
- Check if really on NixOS: `cat /etc/os-release`
- Verify nixos-version command: `nixos-version`
- Check file exists: `cat /run/current-system/nixos-version`

**If severity categorization not working:**
- Check jq is installed: `which jq`
- Verify lynis-report.json exists and is valid JSON
- Check for temp file cleanup in /tmp/

**If hardening score not shown:**
- Verify `.hardening_index` in lynis-report.json: `jq -r '.hardening_index' output-*/lynis-report.json`
- Should be a number 0-100

## Reporting Issues

If you find bugs during testing:
1. Note which distribution/environment
2. Include error messages
3. Check relevant output files
4. Provide steps to reproduce
