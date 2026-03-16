#!/usr/bin/env bash
#
# check-os-updates.sh - Check if OS is on current/supported update stream
# Part of Honeybadger ISO27001 Compliance Tool
#
# Checks for: NixOS, Ubuntu, Debian, Arch, Kali, Fedora, macOS
#

OUTPUT_FILE="${1:-os-update-status.txt}"

echo "=== OS UPDATE STATUS CHECK ===" > "$OUTPUT_FILE"
echo "Check Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Detect OS
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS_NAME="$NAME"
    OS_VERSION="$VERSION_ID"
    OS_PRETTY="$PRETTY_NAME"
    OS_ID="$ID"
elif [[ "$(uname)" == "Darwin" ]]; then
    OS_ID="macos"
    OS_NAME="macOS"
    OS_VERSION=$(sw_vers -productVersion)
    OS_PRETTY="macOS $OS_VERSION"
else
    echo "ERROR: Unable to detect OS" >> "$OUTPUT_FILE"
    exit 1
fi

echo "Detected OS: $OS_PRETTY" >> "$OUTPUT_FILE"
echo "OS ID: $OS_ID" >> "$OUTPUT_FILE"
echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Current date for age calculations
CURRENT_YEAR=$(date +%Y)
CURRENT_MONTH=$(date +%m)

# Function to calculate months difference
months_since() {
    local year=$1
    local month=$2
    echo $(( (CURRENT_YEAR - year) * 12 + (CURRENT_MONTH - month) ))
}

# Check OS-specific update status
case "$OS_ID" in
    nixos)
        echo "=== NixOS UPDATE STATUS ===" >> "$OUTPUT_FILE"

        # Parse version (format: YY.MM)
        MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
        MINOR=$(echo "$OS_VERSION" | cut -d. -f2 | cut -d' ' -f1)

        # NixOS releases every 6 months (May and November)
        # Current stable: 25.11 (November 2025)
        # Next expected: 26.05 (May 2026)

        if [[ "$MAJOR" == "25" && "$MINOR" == "11" ]]; then
            echo "Status: ✅ CURRENT STABLE RELEASE" >> "$OUTPUT_FILE"
            echo "Release: November 2025" >> "$OUTPUT_FILE"
            echo "Support: Until approximately May 2026 (next release)" >> "$OUTPUT_FILE"
            echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
        elif [[ "$MAJOR" == "25" && "$MINOR" == "05" ]]; then
            echo "Status: ⚠️ PREVIOUS STABLE (still supported)" >> "$OUTPUT_FILE"
            echo "Release: May 2025" >> "$OUTPUT_FILE"
            echo "Support: Until approximately November 2025" >> "$OUTPUT_FILE"
            echo "Compliance: COMPLIANT (but upgrade recommended)" >> "$OUTPUT_FILE"
        elif [[ "$MAJOR" == "24" ]]; then
            echo "Status: ❌ OLD RELEASE (upgrade required)" >> "$OUTPUT_FILE"
            echo "Release: 2024" >> "$OUTPUT_FILE"
            echo "Support: Likely EOL" >> "$OUTPUT_FILE"
            echo "Compliance: NON-COMPLIANT" >> "$OUTPUT_FILE"
        else
            echo "Status: ⚠️ UNKNOWN VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: NEEDS VERIFICATION" >> "$OUTPUT_FILE"
        fi

        echo "" >> "$OUTPUT_FILE"
        echo "Channel Info:" >> "$OUTPUT_FILE"
        if command -v nix-channel >/dev/null 2>&1; then
            nix-channel --list >> "$OUTPUT_FILE" 2>&1 || echo "Unable to query channels" >> "$OUTPUT_FILE"
        fi
        ;;

    ubuntu)
        echo "=== UBUNTU UPDATE STATUS ===" >> "$OUTPUT_FILE"

        # Ubuntu LTS versions and their EOL dates
        case "$OS_VERSION" in
            24.04)
                echo "Status: ✅ CURRENT LTS (Noble Numbat)" >> "$OUTPUT_FILE"
                echo "Release: April 2024" >> "$OUTPUT_FILE"
                echo "Standard Support: Until April 2029" >> "$OUTPUT_FILE"
                echo "ESM Support: Until April 2034" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
                ;;
            24.10)
                echo "Status: ✅ CURRENT RELEASE (Oracular Oriole)" >> "$OUTPUT_FILE"
                echo "Release: October 2024" >> "$OUTPUT_FILE"
                echo "Support: Until July 2025" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT (but upgrade to LTS recommended)" >> "$OUTPUT_FILE"
                ;;
            23.10)
                months=$(months_since 2023 10)
                if [[ $months -gt 9 ]]; then
                    echo "Status: ❌ EOL (End of Life)" >> "$OUTPUT_FILE"
                    echo "Release: October 2023" >> "$OUTPUT_FILE"
                    echo "Support: Ended July 2024" >> "$OUTPUT_FILE"
                    echo "Compliance: NON-COMPLIANT - UPGRADE REQUIRED" >> "$OUTPUT_FILE"
                else
                    echo "Status: ⚠️ SHORT-TERM RELEASE" >> "$OUTPUT_FILE"
                    echo "Release: October 2023" >> "$OUTPUT_FILE"
                    echo "Support: Until July 2024" >> "$OUTPUT_FILE"
                    echo "Compliance: UPGRADE TO LTS RECOMMENDED" >> "$OUTPUT_FILE"
                fi
                ;;
            22.04)
                echo "Status: ✅ LTS (Jammy Jellyfish)" >> "$OUTPUT_FILE"
                echo "Release: April 2022" >> "$OUTPUT_FILE"
                echo "Standard Support: Until April 2027" >> "$OUTPUT_FILE"
                echo "ESM Support: Until April 2032" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
                ;;
            20.04)
                months=$(months_since 2020 4)
                if [[ $months -gt 60 ]]; then
                    echo "Status: ❌ STANDARD SUPPORT ENDED" >> "$OUTPUT_FILE"
                    echo "Release: April 2020" >> "$OUTPUT_FILE"
                    echo "Standard Support: Ended April 2025" >> "$OUTPUT_FILE"
                    echo "ESM Available: Until April 2030" >> "$OUTPUT_FILE"
                    echo "Compliance: NON-COMPLIANT - UPGRADE REQUIRED" >> "$OUTPUT_FILE"
                else
                    echo "Status: ⚠️ LTS (Focal Fossa) - NEAR EOL" >> "$OUTPUT_FILE"
                    echo "Release: April 2020" >> "$OUTPUT_FILE"
                    echo "Standard Support: Until April 2025" >> "$OUTPUT_FILE"
                    echo "Compliance: UPGRADE RECOMMENDED SOON" >> "$OUTPUT_FILE"
                fi
                ;;
            18.04)
                echo "Status: ❌ EOL" >> "$OUTPUT_FILE"
                echo "Release: April 2018" >> "$OUTPUT_FILE"
                echo "Standard Support: Ended April 2023" >> "$OUTPUT_FILE"
                echo "Compliance: NON-COMPLIANT - CRITICAL UPGRADE REQUIRED" >> "$OUTPUT_FILE"
                ;;
            *)
                echo "Status: ⚠️ UNKNOWN UBUNTU VERSION" >> "$OUTPUT_FILE"
                echo "Compliance: NEEDS MANUAL VERIFICATION" >> "$OUTPUT_FILE"
                ;;
        esac

        echo "" >> "$OUTPUT_FILE"
        echo "Update Check:" >> "$OUTPUT_FILE"
        if command -v apt >/dev/null 2>&1; then
            apt list --upgradable 2>/dev/null | wc -l | xargs echo "Available updates:" >> "$OUTPUT_FILE"
        fi
        ;;

    debian)
        echo "=== DEBIAN UPDATE STATUS ===" >> "$OUTPUT_FILE"

        case "$OS_VERSION" in
            12)
                echo "Status: ✅ CURRENT STABLE (Bookworm)" >> "$OUTPUT_FILE"
                echo "Release: June 2023" >> "$OUTPUT_FILE"
                echo "Support: ~5 years (until ~2028)" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
                ;;
            11)
                echo "Status: ⚠️ OLDSTABLE (Bullseye)" >> "$OUTPUT_FILE"
                echo "Release: August 2021" >> "$OUTPUT_FILE"
                echo "Support: Until ~2026" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT (but upgrade to 12 recommended)" >> "$OUTPUT_FILE"
                ;;
            10)
                echo "Status: ❌ OLDOLDSTABLE (Buster) - EOL SOON" >> "$OUTPUT_FILE"
                echo "Release: July 2019" >> "$OUTPUT_FILE"
                echo "Support: Extended LTS only" >> "$OUTPUT_FILE"
                echo "Compliance: UPGRADE REQUIRED" >> "$OUTPUT_FILE"
                ;;
            *)
                echo "Status: ⚠️ UNKNOWN DEBIAN VERSION" >> "$OUTPUT_FILE"
                echo "Compliance: NEEDS VERIFICATION" >> "$OUTPUT_FILE"
                ;;
        esac
        ;;

    arch)
        echo "=== ARCH LINUX UPDATE STATUS ===" >> "$OUTPUT_FILE"
        echo "Status: ✅ ROLLING RELEASE (always current if updated)" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"

        # Check last update
        if [[ -f /var/log/pacman.log ]]; then
            LAST_UPDATE=$(grep -E "upgraded|installed" /var/log/pacman.log | tail -1 | awk '{print $1, $2}')
            echo "Last package activity: $LAST_UPDATE" >> "$OUTPUT_FILE"

            # Check if last update was more than 14 days ago
            LAST_UPDATE_DATE=$(grep -E "upgraded|installed" /var/log/pacman.log | tail -1 | awk '{print $1}' | tr -d '[]')
            if [[ -n "$LAST_UPDATE_DATE" ]]; then
                DAYS_SINCE=$(( ($(date +%s) - $(date -d "$LAST_UPDATE_DATE" +%s)) / 86400 ))
                echo "Days since last update: $DAYS_SINCE" >> "$OUTPUT_FILE"

                if [[ $DAYS_SINCE -gt 30 ]]; then
                    echo "Compliance: ⚠️ UPDATE REQUIRED (>30 days since last update)" >> "$OUTPUT_FILE"
                elif [[ $DAYS_SINCE -gt 14 ]]; then
                    echo "Compliance: ⚠️ UPDATE RECOMMENDED (>14 days since last update)" >> "$OUTPUT_FILE"
                else
                    echo "Compliance: ✅ COMPLIANT (recently updated)" >> "$OUTPUT_FILE"
                fi
            fi
        fi

        echo "" >> "$OUTPUT_FILE"
        echo "Available Updates:" >> "$OUTPUT_FILE"
        if command -v pacman >/dev/null 2>&1; then
            # Note: requires sudo for -Sy, so just check local db
            pacman -Qu 2>/dev/null | wc -l | xargs echo "Pending updates:" >> "$OUTPUT_FILE" || echo "Unable to check (run: sudo pacman -Sy)" >> "$OUTPUT_FILE"
        fi

        echo "" >> "$OUTPUT_FILE"
        echo "Recommendation: Run 'sudo pacman -Syu' weekly" >> "$OUTPUT_FILE"
        ;;

    kali)
        echo "=== KALI LINUX UPDATE STATUS ===" >> "$OUTPUT_FILE"
        echo "Type: Rolling Release (Debian-based)" >> "$OUTPUT_FILE"

        # Kali version format: YYYY.N
        if [[ "$OS_VERSION" =~ ^202[4-6] ]]; then
            echo "Status: ✅ CURRENT RELEASE" >> "$OUTPUT_FILE"
            echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Support: Rolling release, continuously updated" >> "$OUTPUT_FILE"
            echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
        elif [[ "$OS_VERSION" =~ ^2023 ]]; then
            echo "Status: ⚠️ OLD RELEASE" >> "$OUTPUT_FILE"
            echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: UPDATE RECOMMENDED" >> "$OUTPUT_FILE"
        else
            echo "Status: ❌ VERY OLD RELEASE" >> "$OUTPUT_FILE"
            echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: CRITICAL UPDATE REQUIRED" >> "$OUTPUT_FILE"
        fi

        echo "" >> "$OUTPUT_FILE"
        echo "Update Status:" >> "$OUTPUT_FILE"
        if command -v apt >/dev/null 2>&1; then
            apt list --upgradable 2>/dev/null | wc -l | xargs echo "Available updates:" >> "$OUTPUT_FILE"
        fi

        echo "" >> "$OUTPUT_FILE"
        echo "Recommendation: Run 'sudo apt update && sudo apt full-upgrade' weekly" >> "$OUTPUT_FILE"
        ;;

    fedora)
        echo "=== FEDORA UPDATE STATUS ===" >> "$OUTPUT_FILE"

        # Fedora versions released ~every 6 months
        # Support for ~13 months
        if [[ "$OS_VERSION" -ge 41 ]]; then
            echo "Status: ✅ CURRENT RELEASE" >> "$OUTPUT_FILE"
            echo "Version: Fedora $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Support: ~13 months from release" >> "$OUTPUT_FILE"
            echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
        elif [[ "$OS_VERSION" -eq 40 ]]; then
            echo "Status: ⚠️ PREVIOUS RELEASE (still supported)" >> "$OUTPUT_FILE"
            echo "Version: Fedora $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: COMPLIANT (upgrade recommended)" >> "$OUTPUT_FILE"
        elif [[ "$OS_VERSION" -ge 38 ]]; then
            echo "Status: ⚠️ OLD RELEASE (near EOL)" >> "$OUTPUT_FILE"
            echo "Version: Fedora $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: UPGRADE RECOMMENDED" >> "$OUTPUT_FILE"
        else
            echo "Status: ❌ EOL RELEASE" >> "$OUTPUT_FILE"
            echo "Version: Fedora $OS_VERSION" >> "$OUTPUT_FILE"
            echo "Compliance: NON-COMPLIANT - UPGRADE REQUIRED" >> "$OUTPUT_FILE"
        fi
        ;;

    macos)
        echo "=== macOS UPDATE STATUS ===" >> "$OUTPUT_FILE"

        # Parse major version
        MACOS_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)

        case "$MACOS_MAJOR" in
            15)
                echo "Status: ✅ CURRENT (macOS Sequoia)" >> "$OUTPUT_FILE"
                echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                echo "Release: 2024" >> "$OUTPUT_FILE"
                echo "Support: Full support" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
                ;;
            14)
                echo "Status: ✅ SUPPORTED (macOS Sonoma)" >> "$OUTPUT_FILE"
                echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                echo "Release: 2023" >> "$OUTPUT_FILE"
                echo "Support: Full support (security updates)" >> "$OUTPUT_FILE"
                echo "Compliance: COMPLIANT" >> "$OUTPUT_FILE"
                ;;
            13)
                echo "Status: ⚠️ LIMITED SUPPORT (macOS Ventura)" >> "$OUTPUT_FILE"
                echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                echo "Release: 2022" >> "$OUTPUT_FILE"
                echo "Support: Security updates only" >> "$OUTPUT_FILE"
                echo "Compliance: UPGRADE RECOMMENDED" >> "$OUTPUT_FILE"
                ;;
            12)
                echo "Status: ⚠️ NEAR EOL (macOS Monterey)" >> "$OUTPUT_FILE"
                echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                echo "Release: 2021" >> "$OUTPUT_FILE"
                echo "Support: Limited security updates" >> "$OUTPUT_FILE"
                echo "Compliance: UPGRADE REQUIRED SOON" >> "$OUTPUT_FILE"
                ;;
            *)
                if [[ "$MACOS_MAJOR" -lt 12 ]]; then
                    echo "Status: ❌ NO LONGER SUPPORTED" >> "$OUTPUT_FILE"
                    echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                    echo "Compliance: NON-COMPLIANT - UPGRADE REQUIRED" >> "$OUTPUT_FILE"
                else
                    echo "Status: ⚠️ UNKNOWN macOS VERSION" >> "$OUTPUT_FILE"
                    echo "Version: $OS_VERSION" >> "$OUTPUT_FILE"
                    echo "Compliance: NEEDS VERIFICATION" >> "$OUTPUT_FILE"
                fi
                ;;
        esac

        echo "" >> "$OUTPUT_FILE"
        echo "Update Check:" >> "$OUTPUT_FILE"
        softwareupdate -l 2>&1 | head -10 >> "$OUTPUT_FILE"
        ;;

    *)
        echo "Status: ⚠️ UNSUPPORTED OS TYPE: $OS_ID" >> "$OUTPUT_FILE"
        echo "Compliance: MANUAL VERIFICATION REQUIRED" >> "$OUTPUT_FILE"
        ;;
esac

echo "" >> "$OUTPUT_FILE"
echo "=== RECOMMENDATION ===" >> "$OUTPUT_FILE"

# Extract compliance status
if grep -q "NON-COMPLIANT" "$OUTPUT_FILE"; then
    echo "⚠️ CRITICAL: This system is running an unsupported OS version." >> "$OUTPUT_FILE"
    echo "Action: Upgrade to a current, supported version immediately." >> "$OUTPUT_FILE"
    echo "Risk: Security vulnerabilities, no patches, policy violation." >> "$OUTPUT_FILE"
    EXIT_CODE=2
elif grep -q "UPGRADE REQUIRED" "$OUTPUT_FILE"; then
    echo "⚠️ WARNING: This system needs upgrading soon." >> "$OUTPUT_FILE"
    echo "Action: Plan upgrade within 30 days." >> "$OUTPUT_FILE"
    EXIT_CODE=1
elif grep -q "UPGRADE RECOMMENDED" "$OUTPUT_FILE"; then
    echo "ℹ️ INFO: Upgrade recommended but not critical." >> "$OUTPUT_FILE"
    echo "Action: Plan upgrade at next maintenance window." >> "$OUTPUT_FILE"
    EXIT_CODE=0
elif grep -q "COMPLIANT" "$OUTPUT_FILE"; then
    echo "✅ PASS: System is running a current, supported OS version." >> "$OUTPUT_FILE"
    echo "Action: Continue regular updates." >> "$OUTPUT_FILE"
    EXIT_CODE=0
else
    echo "⚠️ UNKNOWN: Unable to determine compliance status." >> "$OUTPUT_FILE"
    echo "Action: Manual review required." >> "$OUTPUT_FILE"
    EXIT_CODE=3
fi

echo "" >> "$OUTPUT_FILE"
echo "=== END OF OS UPDATE STATUS CHECK ===" >> "$OUTPUT_FILE"

# Print to stdout as well
cat "$OUTPUT_FILE"

exit $EXIT_CODE
