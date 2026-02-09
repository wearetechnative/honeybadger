#!/usr/bin/env bash
#
# check-os-status.sh - Check OS and Kernel status from Honeybadger output
# Extracts information from existing Honeybadger output files
#
# Usage: ./check-os-status.sh <output-directory>
# Example: ./check-os-status.sh output-wtoorren-04-02-2026
#

OUTPUT_DIR="${1:-.}"
CACHE_DIR="${2:-.cache}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if directory exists
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Directory $OUTPUT_DIR does not exist"
    exit 1
fi

# Fetch latest release info if cache doesn't exist or is old
if [[ ! -d "$CACHE_DIR" ]] || [[ ! -f "$CACHE_DIR/nixos-releases.json" ]]; then
    if [[ -f "$SCRIPT_DIR/fetch-os-releases.sh" ]]; then
        echo "Fetching latest OS release information..."
        bash "$SCRIPT_DIR/fetch-os-releases.sh" "$CACHE_DIR" >/dev/null 2>&1
    fi
fi

REPORT_FILE="$OUTPUT_DIR/os-kernel-status.txt"

# Helper functions to query release data
get_latest_nixos_release() {
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.[0].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null
    fi
}

get_nixos_eol_date() {
    local version="$1"
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r ".[] | select(.cycle == \"$version\") | .eol" "$CACHE_DIR/nixos-releases.json" 2>/dev/null
    fi
}

check_nixos_is_current() {
    local version="$1"
    if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        local latest=$(jq -r '.[0].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
        if [[ "$version" == "$latest" ]]; then
            echo "current"
        else
            local second_latest=$(jq -r '.[1].cycle' "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
            if [[ "$version" == "$second_latest" ]]; then
                echo "previous"
            else
                # Check if EOL has passed
                local eol=$(jq -r ".[] | select(.cycle == \"$version\") | .eol" "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
                if [[ -n "$eol" ]]; then
                    local eol_ts=$(date -d "$eol" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$eol" +%s 2>/dev/null)
                    local now_ts=$(date +%s)
                    if [[ $now_ts -gt $eol_ts ]]; then
                        echo "eol"
                    else
                        echo "supported"
                    fi
                else
                    echo "unknown"
                fi
            fi
        fi
    fi
}

get_latest_ubuntu_lts() {
    if [[ -f "$CACHE_DIR/ubuntu-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.[] | select(.lts == true) | .cycle' "$CACHE_DIR/ubuntu-releases.json" 2>/dev/null | head -1
    fi
}

check_ubuntu_is_current() {
    local version="$1"
    if [[ -f "$CACHE_DIR/ubuntu-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        local is_eol=$(jq -r ".[] | select(.cycle == \"$version\") | .eol" "$CACHE_DIR/ubuntu-releases.json" 2>/dev/null)
        if [[ -n "$is_eol" ]]; then
            local eol_ts=$(date -d "$is_eol" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$is_eol" +%s 2>/dev/null)
            local now_ts=$(date +%s)
            if [[ $now_ts -gt $eol_ts ]]; then
                echo "eol"
            else
                local latest=$(jq -r '.[] | select(.lts == true) | .cycle' "$CACHE_DIR/ubuntu-releases.json" 2>/dev/null | head -1)
                if [[ "$version" == "$latest" ]]; then
                    echo "current"
                else
                    echo "supported"
                fi
            fi
        else
            echo "unknown"
        fi
    fi
}

get_kernel_info() {
    local kernel_version="$1"
    if [[ -f "$CACHE_DIR/kernel-releases.json" ]] && command -v jq >/dev/null 2>&1; then
        jq -r ".releases[] | select(.version | startswith(\"$kernel_version\")) | {version: .version, moniker: .moniker, iseol: .iseol}" "$CACHE_DIR/kernel-releases.json" 2>/dev/null | head -1
    fi
}

echo "=====================================" > "$REPORT_FILE"
echo "  OS & KERNEL STATUS ANALYSIS" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "Analysis Date: $(date)" >> "$REPORT_FILE"
echo "Source: $OUTPUT_DIR" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Extract OS information from available files
OS_NAME=""
OS_VERSION=""
OS_CODENAME=""
KERNEL_VERSION=""

# Try to get info from lynis-report.json (most reliable)
if [[ -f "$OUTPUT_DIR/lynis-report.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
        OS_NAME=$(jq -r '.os_name // empty' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        OS_VERSION=$(jq -r '.os_version // empty' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        OS_FULLNAME=$(jq -r '.os_fullname // empty' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        KERNEL_RAW=$(jq -r '.linux_kernel_version // empty' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
    fi
fi

# Fallback to neofetch.txt or fastfetch.txt
FETCH_FILE=""
if [[ -f "$OUTPUT_DIR/neofetch.txt" ]]; then
    FETCH_FILE="$OUTPUT_DIR/neofetch.txt"
elif [[ -f "$OUTPUT_DIR/fastfetch.txt" ]]; then
    FETCH_FILE="$OUTPUT_DIR/fastfetch.txt"
fi

if [[ -n "$FETCH_FILE" ]]; then
    # Get OS info if not already set
    if [[ -z "$OS_NAME" ]]; then
        OS_LINE=$(grep "^OS:" "$FETCH_FILE" | head -1)
        if [[ -n "$OS_LINE" ]]; then
            # Parse: "OS: NixOS 25.11.20260103.30a3c51 (Xantusia) x86_64"
            # or: "OS: Kali GNU/Linux Rolling x86_64"
            OS_FULLNAME=$(echo "$OS_LINE" | sed 's/^OS: //')

            # Handle different formats
            if [[ "$OS_FULLNAME" =~ "Kali" ]]; then
                OS_NAME="Kali"
                OS_VERSION=$(echo "$OS_FULLNAME" | grep -oP 'Rolling|\d+\.\d+' | head -1)
            else
                OS_NAME=$(echo "$OS_FULLNAME" | awk '{print $1}')
                OS_VERSION=$(echo "$OS_FULLNAME" | awk '{print $2}' | cut -d. -f1-2)
            fi
            OS_CODENAME=$(echo "$OS_FULLNAME" | grep -oP '\(\K[^)]+' || echo "")
        fi
    fi

    # Always try to get kernel from fetch file (more reliable than lynis)
    if [[ -z "$KERNEL_VERSION" ]]; then
        # Try both formats: "Kernel: 6.12.63" and "Kernel: Linux 6.12.25-amd64"
        KERNEL_LINE=$(grep "^Kernel:" "$FETCH_FILE" | head -1)
        if [[ -n "$KERNEL_LINE" ]]; then
            # Extract version number (handles both "6.12.63" and "Linux 6.12.25-amd64")
            KERNEL_VERSION=$(echo "$KERNEL_LINE" | grep -oP '\d+\.\d+\.\d+' | head -1)
        fi
    fi
fi

# Fallback to lsb_release.txt
if [[ -z "$OS_NAME" && -f "$OUTPUT_DIR/lsb_release.txt" ]]; then
    OS_NAME=$(grep "^Distributor ID:" "$OUTPUT_DIR/lsb_release.txt" | cut -d: -f2- | xargs)
    OS_VERSION=$(grep "^Release:" "$OUTPUT_DIR/lsb_release.txt" | cut -d: -f2- | xargs)
    OS_CODENAME=$(grep "^Codename:" "$OUTPUT_DIR/lsb_release.txt" | cut -d: -f2- | xargs)
fi

# If still no data, error out
if [[ -z "$OS_NAME" ]]; then
    echo "ERROR: Unable to extract OS information from output files" >> "$REPORT_FILE"
    cat "$REPORT_FILE"
    exit 1
fi

echo "====================================="  >> "$REPORT_FILE"
echo "SECTION 1: OPERATING SYSTEM STATUS" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo "Detected OS: $OS_NAME" >> "$REPORT_FILE"
echo "Version: $OS_VERSION" >> "$REPORT_FILE"
[[ -n "$OS_CODENAME" ]] && echo "Codename: $OS_CODENAME" >> "$REPORT_FILE"
[[ -n "$OS_FULLNAME" ]] && echo "Full Name: $OS_FULLNAME" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Analyze OS version and update stream
case "$OS_NAME" in
    NixOS)
        echo "Distribution: NixOS (Rolling/Stable)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        # Get dynamic release info from cache
        NIXOS_STATUS=$(check_nixos_is_current "$OS_VERSION")
        NIXOS_EOL=$(get_nixos_eol_date "$OS_VERSION")
        LATEST_NIXOS=$(get_latest_nixos_release)

        # Get release details from cache
        if [[ -f "$CACHE_DIR/nixos-releases.json" ]] && command -v jq >/dev/null 2>&1; then
            NIXOS_RELEASE_DATE=$(jq -r ".[] | select(.cycle == \"$OS_VERSION\") | .releaseDate" "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
            NIXOS_CODENAME=$(jq -r ".[] | select(.cycle == \"$OS_VERSION\") | .codename" "$CACHE_DIR/nixos-releases.json" 2>/dev/null)
        fi

        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"

        if [[ "$NIXOS_STATUS" == "current" ]]; then
            echo "Status: YES - CURRENT STABLE RELEASE" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            [[ -n "$NIXOS_CODENAME" ]] && echo "Codename: $NIXOS_CODENAME" >> "$REPORT_FILE"
            [[ -n "$NIXOS_RELEASE_DATE" ]] && echo "Release Date: $NIXOS_RELEASE_DATE" >> "$REPORT_FILE"
            [[ -n "$NIXOS_EOL" ]] && echo "EOL Date: $NIXOS_EOL" >> "$REPORT_FILE"
            echo "Support Status: FULLY SUPPORTED" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "NixOS Release Cycle:" >> "$REPORT_FILE"
            echo "  - New stable release every 6 months (May and November)" >> "$REPORT_FILE"
            echo "  - Each release supported until next stable release" >> "$REPORT_FILE"
            echo "  - Continuous updates via channels" >> "$REPORT_FILE"

        elif [[ "$NIXOS_STATUS" == "previous" ]]; then
            echo "Status: YES - PREVIOUS STABLE (still supported)" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (but upgrade recommended)" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            [[ -n "$NIXOS_CODENAME" ]] && echo "Codename: $NIXOS_CODENAME" >> "$REPORT_FILE"
            [[ -n "$NIXOS_RELEASE_DATE" ]] && echo "Release Date: $NIXOS_RELEASE_DATE" >> "$REPORT_FILE"
            [[ -n "$NIXOS_EOL" ]] && echo "EOL Date: $NIXOS_EOL" >> "$REPORT_FILE"
            echo "Support Status: ACTIVE but near EOL" >> "$REPORT_FILE"
            [[ -n "$LATEST_NIXOS" ]] && echo "Recommendation: Upgrade to $LATEST_NIXOS" >> "$REPORT_FILE"

        elif [[ "$NIXOS_STATUS" == "eol" ]]; then
            echo "Status: NO - EOL REACHED" >> "$REPORT_FILE"
            echo "Update Stream: EOL (End of Life)" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            [[ -n "$NIXOS_CODENAME" ]] && echo "Codename: $NIXOS_CODENAME" >> "$REPORT_FILE"
            [[ -n "$NIXOS_RELEASE_DATE" ]] && echo "Release Date: $NIXOS_RELEASE_DATE" >> "$REPORT_FILE"
            [[ -n "$NIXOS_EOL" ]] && echo "EOL Date: $NIXOS_EOL (already passed)" >> "$REPORT_FILE"
            echo "Support Status: NO LONGER SUPPORTED" >> "$REPORT_FILE"
            [[ -n "$LATEST_NIXOS" ]] && echo "CRITICAL: Upgrade to NixOS $LATEST_NIXOS immediately" >> "$REPORT_FILE"

        else
            # Fallback to manual detection if cache not available
            MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
            MINOR=$(echo "$OS_VERSION" | cut -d. -f2 | cut -d' ' -f1)

            echo "Status: UNKNOWN VERSION (using fallback detection)" >> "$REPORT_FILE"
            echo "Update Stream: UNABLE TO DETERMINE" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Version: $OS_VERSION" >> "$REPORT_FILE"
            echo "Note: Unable to fetch release data. Please verify manually at https://nixos.org" >> "$REPORT_FILE"
            echo "Recommendation: Update release cache with ./fetch-os-releases.sh" >> "$REPORT_FILE"
        fi
        ;;

    Ubuntu)
        echo "Distribution: Ubuntu Linux" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"

        case "$OS_VERSION" in
            24.04)
                echo "Status: YES - CURRENT LTS" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
                echo "Type: Long Term Support (LTS)" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: April 2024" >> "$REPORT_FILE"
                echo "EOL Date: April 2029 (5 years standard support)" >> "$REPORT_FILE"
                echo "Extended Security Maintenance: Until April 2034" >> "$REPORT_FILE"
                echo "Support Status: FULLY SUPPORTED" >> "$REPORT_FILE"
                ;;
            22.04)
                echo "Status: YES - LTS (Previous)" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
                echo "Type: Long Term Support (LTS)" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: April 2022" >> "$REPORT_FILE"
                echo "EOL Date: April 2027 (5 years standard support)" >> "$REPORT_FILE"
                echo "Extended Security Maintenance: Until April 2032" >> "$REPORT_FILE"
                echo "Support Status: FULLY SUPPORTED" >> "$REPORT_FILE"
                ;;
            20.04)
                echo "Status: NEAR EOL - LTS" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE (limited time)" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: April 2020" >> "$REPORT_FILE"
                echo "EOL Date: April 2025 (standard support ending soon)" >> "$REPORT_FILE"
                echo "Extended Security Maintenance: Until April 2030" >> "$REPORT_FILE"
                echo "Support Status: NEAR EOL - UPGRADE RECOMMENDED" >> "$REPORT_FILE"
                ;;
            18.04)
                echo "Status: NO - EOL REACHED" >> "$REPORT_FILE"
                echo "Update Stream: INACTIVE" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: April 2018" >> "$REPORT_FILE"
                echo "EOL Date: April 2023" >> "$REPORT_FILE"
                echo "Support Status: NO LONGER SUPPORTED" >> "$REPORT_FILE"
                echo "CRITICAL: Upgrade to Ubuntu 24.04 LTS immediately" >> "$REPORT_FILE"
                ;;
            *)
                echo "Status: UNKNOWN VERSION" >> "$REPORT_FILE"
                echo "Update Stream: UNABLE TO DETERMINE" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Ubuntu version: $OS_VERSION" >> "$REPORT_FILE"
                echo "Please check https://wiki.ubuntu.com/Releases for details" >> "$REPORT_FILE"
                ;;
        esac
        ;;

    Debian)
        echo "Distribution: Debian GNU/Linux" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"

        case "$OS_VERSION" in
            12)
                echo "Status: YES - CURRENT STABLE" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
                echo "Codename: Bookworm" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: June 10, 2023" >> "$REPORT_FILE"
                echo "Estimated EOL: ~2028 (5 years support)" >> "$REPORT_FILE"
                echo "Support Status: FULLY SUPPORTED" >> "$REPORT_FILE"
                ;;
            11)
                echo "Status: YES - OLDSTABLE" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE (limited support)" >> "$REPORT_FILE"
                echo "Codename: Bullseye" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Release Date: August 14, 2021" >> "$REPORT_FILE"
                echo "EOL Date: ~2026" >> "$REPORT_FILE"
                echo "Support Status: OLDSTABLE (upgrade recommended)" >> "$REPORT_FILE"
                ;;
            *)
                echo "Status: UNKNOWN or OLD VERSION" >> "$REPORT_FILE"
                echo "Please check https://www.debian.org/releases/" >> "$REPORT_FILE"
                ;;
        esac
        ;;

    Arch|"Arch Linux")
        echo "Distribution: Arch Linux (Rolling Release)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"
        echo "Status: YES - ALWAYS CURRENT (if regularly updated)" >> "$REPORT_FILE"
        echo "Update Stream: ROLLING RELEASE (no versions)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"
        echo "Release Model: Rolling Release (continuous updates)" >> "$REPORT_FILE"
        echo "EOL: N/A (no fixed versions)" >> "$REPORT_FILE"
        echo "Support Status: ACTIVE (requires regular updates)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "IMPORTANT: Arch Linux must be updated regularly (weekly recommended)" >> "$REPORT_FILE"
        echo "   Run: sudo pacman -Syu" >> "$REPORT_FILE"
        ;;

    Kali|"Kali Linux")
        echo "Distribution: Kali Linux (Debian-based, Rolling)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        # Try to detect Kali release based on kernel version and scan date
        KALI_RELEASE="Unknown"
        if [[ -n "$KERNEL_VERSION" ]]; then
            # Parse kernel version to extract major.minor
            K_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
            K_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)

            # Estimate Kali release based on kernel version
            # Kali quarterly releases: 2024.1 (Feb), 2024.2 (May), 2024.3 (Aug), 2024.4 (Nov)
            # Kali 2025.1 (Feb), etc.
            case "$K_MAJOR.$K_MINOR" in
                6.12|6.13)
                    KALI_RELEASE="2024.4 or 2025.1 (kernel $KERNEL_VERSION)"
                    ;;
                6.11)
                    KALI_RELEASE="2024.3 (kernel $KERNEL_VERSION)"
                    ;;
                6.10)
                    KALI_RELEASE="2024.2 (kernel $KERNEL_VERSION)"
                    ;;
                6.8|6.9)
                    KALI_RELEASE="2024.1 (kernel $KERNEL_VERSION)"
                    ;;
                6.6|6.7)
                    KALI_RELEASE="2023.4 (kernel $KERNEL_VERSION)"
                    ;;
                6.1|6.5)
                    KALI_RELEASE="2023.3 or older (kernel $KERNEL_VERSION)"
                    ;;
                *)
                    KALI_RELEASE="Unable to determine (kernel $KERNEL_VERSION)"
                    ;;
            esac
        fi

        echo "Estimated Release: $KALI_RELEASE" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"

        # Kali uses rolling release model
        if [[ "$OS_VERSION" =~ "Rolling" || "$OS_VERSION" =~ ^202[4-6] ]]; then
            echo "Status: YES - ROLLING RELEASE" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
            echo "Type: Rolling Release (Debian-based)" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Release Model: Rolling (continuous updates)" >> "$REPORT_FILE"
            echo "Quarterly Releases: 2024.1 (Feb), 2024.2 (May), 2024.3 (Aug), 2024.4 (Nov)" >> "$REPORT_FILE"
            echo "Latest: 2025.1 (Feb 2026), 2025.2 (May 2026), etc." >> "$REPORT_FILE"
            echo "EOL: N/A (rolling release, no fixed EOL)" >> "$REPORT_FILE"
            echo "Support Status: ACTIVE" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "IMPORTANT: Kali Linux must be updated regularly (weekly recommended)" >> "$REPORT_FILE"
            echo "   Run: sudo apt update && sudo apt full-upgrade" >> "$REPORT_FILE"
        else
            echo "Status: OLD RELEASE" >> "$REPORT_FILE"
            echo "Update Stream: UPDATE REQUIRED" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Release: $OS_VERSION" >> "$REPORT_FILE"
            echo "Recommendation: Update to latest Kali release" >> "$REPORT_FILE"
            echo "Command: sudo apt update && sudo apt full-upgrade" >> "$REPORT_FILE"
        fi
        ;;

    *)
        echo "Distribution: $OS_NAME (Unknown/Unsupported)" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "1. IS CURRENT OS VERSION AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"
        echo "Status: UNABLE TO DETERMINE" >> "$REPORT_FILE"
        echo "Reason: Distribution '$OS_NAME' not in database" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"

        echo "2. OS VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
        echo "---------------------------------------------------" >> "$REPORT_FILE"
        echo "Version: $OS_VERSION" >> "$REPORT_FILE"
        echo "Manual verification required" >> "$REPORT_FILE"
        ;;
esac

echo "" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "SECTION 2: KERNEL VERSION STATUS" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [[ -z "$KERNEL_VERSION" ]]; then
    echo "ERROR: Unable to extract kernel version from output files" >> "$REPORT_FILE"
else
    echo "Detected Kernel: $KERNEL_VERSION" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    # Parse kernel version (format: X.Y.Z)
    KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
    KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)
    KERNEL_PATCH=$(echo "$KERNEL_VERSION" | cut -d. -f3 | grep -oP '^\d+')

    echo "Kernel Version: $KERNEL_MAJOR.$KERNEL_MINOR.$KERNEL_PATCH" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    echo "1. IS CURRENT KERNEL AN ACTIVE UPDATE STREAM?" >> "$REPORT_FILE"
    echo "---------------------------------------------------" >> "$REPORT_FILE"

    # Kernel version database (as of February 2026)
    # Source: https://kernel.org
    case "$KERNEL_MAJOR.$KERNEL_MINOR" in
        6.12)
            echo "Status: YES - STABLE KERNEL SERIES" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE" >> "$REPORT_FILE"
            echo "Type: Stable" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: December 2024" >> "$REPORT_FILE"
            echo "Latest in series: 6.12.x (regularly updated)" >> "$REPORT_FILE"
            echo "Estimated EOL: ~6-12 months from release" >> "$REPORT_FILE"
            echo "Support Status: ACTIVELY MAINTAINED" >> "$REPORT_FILE"
            ;;
        6.11)
            echo "Status: NEAR EOL - STABLE" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (limited time)" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: September 2024" >> "$REPORT_FILE"
            echo "Estimated EOL: Early 2026" >> "$REPORT_FILE"
            echo "Support Status: NEAR EOL - UPGRADE RECOMMENDED" >> "$REPORT_FILE"
            echo "Recommended: Upgrade to 6.12+ kernel" >> "$REPORT_FILE"
            ;;
        6.10|6.9|6.8|6.7|6.6)
            if [[ "$KERNEL_MINOR" == "6" ]]; then
                echo "Status: YES - LTS KERNEL" >> "$REPORT_FILE"
                echo "Update Stream: ACTIVE (Long Term Support)" >> "$REPORT_FILE"
                echo "Type: LTS (Long Term Support)" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Series Release: December 2023" >> "$REPORT_FILE"
                echo "EOL Date: December 2026 (projected)" >> "$REPORT_FILE"
                echo "Support Status: LTS - FULLY SUPPORTED" >> "$REPORT_FILE"
            else
                echo "Status: OLD STABLE (likely EOL)" >> "$REPORT_FILE"
                echo "Update Stream: INACTIVE or near EOL" >> "$REPORT_FILE"
                echo "" >> "$REPORT_FILE"

                echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
                echo "---------------------------------------------------" >> "$REPORT_FILE"
                echo "Series Release: 2024" >> "$REPORT_FILE"
                echo "Support Status: EOL or near EOL" >> "$REPORT_FILE"
                echo "Recommendation: Update to kernel 6.12+ or 6.6 LTS" >> "$REPORT_FILE"
            fi
            ;;
        6.1)
            echo "Status: YES - LTS KERNEL" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (Long Term Support)" >> "$REPORT_FILE"
            echo "Type: LTS" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: December 2022" >> "$REPORT_FILE"
            echo "EOL Date: December 2026" >> "$REPORT_FILE"
            echo "Support Status: LTS - FULLY SUPPORTED" >> "$REPORT_FILE"
            ;;
        5.15)
            echo "Status: YES - LTS KERNEL" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (Long Term Support)" >> "$REPORT_FILE"
            echo "Type: LTS" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: October 2021" >> "$REPORT_FILE"
            echo "EOL Date: October 2026" >> "$REPORT_FILE"
            echo "Support Status: LTS - FULLY SUPPORTED" >> "$REPORT_FILE"
            ;;
        5.10)
            echo "Status: YES - LTS KERNEL" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (Long Term Support)" >> "$REPORT_FILE"
            echo "Type: LTS" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: December 2020" >> "$REPORT_FILE"
            echo "EOL Date: December 2026" >> "$REPORT_FILE"
            echo "Support Status: LTS - FULLY SUPPORTED" >> "$REPORT_FILE"
            ;;
        5.4)
            echo "Status: YES - LTS (near EOL)" >> "$REPORT_FILE"
            echo "Update Stream: ACTIVE (limited time)" >> "$REPORT_FILE"
            echo "Type: LTS" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Series Release: November 2019" >> "$REPORT_FILE"
            echo "EOL Date: December 2025" >> "$REPORT_FILE"
            echo "Support Status: LTS - NEAR EOL" >> "$REPORT_FILE"
            echo "Recommendation: Plan upgrade to newer LTS kernel" >> "$REPORT_FILE"
            ;;
        *)
            echo "Status: UNKNOWN or VERY OLD" >> "$REPORT_FILE"
            echo "Update Stream: UNABLE TO DETERMINE" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"

            echo "2. KERNEL VERSION RELEASE & EOL DATES" >> "$REPORT_FILE"
            echo "---------------------------------------------------" >> "$REPORT_FILE"
            echo "Kernel: $KERNEL_MAJOR.$KERNEL_MINOR.$KERNEL_PATCH" >> "$REPORT_FILE"
            echo "Please check https://kernel.org for current status" >> "$REPORT_FILE"

            if [[ "$KERNEL_MAJOR" -lt 5 ]]; then
                echo "" >> "$REPORT_FILE"
                echo "WARNING: Kernel version is very old (< 5.x)" >> "$REPORT_FILE"
                echo "   This kernel is likely EOL and unsupported" >> "$REPORT_FILE"
                echo "   CRITICAL: Upgrade immediately for security updates" >> "$REPORT_FILE"
            fi
            ;;
    esac

    echo "" >> "$REPORT_FILE"
    echo "3. ADDITIONAL KERNEL INFORMATION" >> "$REPORT_FILE"
    echo "---------------------------------------------------" >> "$REPORT_FILE"
    echo "Current LTS Kernels (as of Feb 2026):" >> "$REPORT_FILE"
    echo "  - 6.6 LTS (EOL: Dec 2026)" >> "$REPORT_FILE"
    echo "  - 6.1 LTS (EOL: Dec 2026)" >> "$REPORT_FILE"
    echo "  - 5.15 LTS (EOL: Oct 2026)" >> "$REPORT_FILE"
    echo "  - 5.10 LTS (EOL: Dec 2026)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Latest Stable Kernel: 6.12.x" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Note: Kernel support depends on distribution." >> "$REPORT_FILE"
    echo "      Distribution kernels may have extended support." >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "SUMMARY & RECOMMENDATIONS" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Generate summary
OS_STATUS="UNKNOWN"
KERNEL_STATUS="UNKNOWN"
OS_RECOMMENDATION=""
KERNEL_RECOMMENDATION=""

# Check OS status - look for patterns in Section 1 (within first 30 lines of section)
OS_SECTION=$(grep -A 50 "SECTION 1: OPERATING SYSTEM STATUS" "$REPORT_FILE" | head -50)

if echo "$OS_SECTION" | grep -q "Status: YES - CURRENT\|Status: YES - ALWAYS CURRENT\|Status: YES - ROLLING RELEASE"; then
    OS_STATUS="CURRENT"
elif echo "$OS_SECTION" | grep -q "Status: YES - PREVIOUS STABLE"; then
    OS_STATUS="NEAR_EOL"
    # Extract the recommendation
    OS_RECOMMENDATION=$(echo "$OS_SECTION" | grep "Recommendation:" | sed 's/^Recommendation: //')
elif echo "$OS_SECTION" | grep -q "Status: .*EOL\|Status: YES - OLDSTABLE\|Status: NEAR EOL"; then
    OS_STATUS="NEAR_EOL"
    OS_RECOMMENDATION=$(echo "$OS_SECTION" | grep "Recommendation:\|Recommended:" | head -1 | sed 's/^Recommendation: //;s/^Recommended: //')
elif echo "$OS_SECTION" | grep -q "Status: NO -"; then
    OS_STATUS="EOL"
    OS_RECOMMENDATION=$(echo "$OS_SECTION" | grep "CRITICAL:" | sed 's/^.*CRITICAL: //')
fi

# Check kernel status in Section 2 (look in the actual kernel section)
KERNEL_SECTION=$(grep -A 50 "SECTION 2: KERNEL VERSION STATUS" "$REPORT_FILE" | head -50)

if echo "$KERNEL_SECTION" | grep -q "Status: YES - STABLE KERNEL\|Status: YES - LTS"; then
    KERNEL_STATUS="CURRENT"
elif echo "$KERNEL_SECTION" | grep -q "Status: NEAR EOL\|Status: OLD STABLE\|Status: UNKNOWN"; then
    KERNEL_STATUS="WARNING"
    KERNEL_RECOMMENDATION=$(echo "$KERNEL_SECTION" | grep "Recommendation:" | head -1 | sed 's/^Recommendation: //')
elif echo "$KERNEL_SECTION" | grep -q "Status: NO -"; then
    KERNEL_STATUS="EOL"
    KERNEL_RECOMMENDATION=$(echo "$KERNEL_SECTION" | grep "CRITICAL:" | sed 's/^.*CRITICAL: //')
elif grep -q "ERROR: Unable to extract kernel version" "$REPORT_FILE"; then
    KERNEL_STATUS="UNKNOWN"
fi

echo "Overall System Status:" >> "$REPORT_FILE"
echo "  Operating System: $OS_STATUS" >> "$REPORT_FILE"
echo "  Kernel: $KERNEL_STATUS" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [[ "$OS_STATUS" == "CURRENT" && "$KERNEL_STATUS" == "CURRENT" ]]; then
    echo "PASS: System is running current, supported software" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Actions:" >> "$REPORT_FILE"
    echo "  - Continue regular updates" >> "$REPORT_FILE"
    echo "  - Monitor for new releases" >> "$REPORT_FILE"
    EXIT_CODE=0
elif [[ "$OS_STATUS" == "EOL" || "$KERNEL_STATUS" == "EOL" ]]; then
    echo "FAIL: System has EOL components" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "CRITICAL Actions Required:" >> "$REPORT_FILE"
    if [[ "$OS_STATUS" == "EOL" && -n "$OS_RECOMMENDATION" ]]; then
        echo "  - OS: $OS_RECOMMENDATION" >> "$REPORT_FILE"
    elif [[ "$OS_STATUS" == "EOL" ]]; then
        echo "  - Upgrade operating system immediately" >> "$REPORT_FILE"
    fi
    if [[ "$KERNEL_STATUS" == "EOL" && -n "$KERNEL_RECOMMENDATION" ]]; then
        echo "  - Kernel: $KERNEL_RECOMMENDATION" >> "$REPORT_FILE"
    elif [[ "$KERNEL_STATUS" == "EOL" ]]; then
        echo "  - Update to supported kernel version" >> "$REPORT_FILE"
    fi
    echo "  - Security vulnerabilities are not being patched" >> "$REPORT_FILE"
    EXIT_CODE=2
else
    echo "WARNING: System needs attention" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Actions Recommended:" >> "$REPORT_FILE"
    if [[ "$OS_STATUS" == "NEAR_EOL" && -n "$OS_RECOMMENDATION" ]]; then
        echo "  - OS: $OS_RECOMMENDATION" >> "$REPORT_FILE"
    elif [[ "$OS_STATUS" == "NEAR_EOL" ]]; then
        echo "  - Plan OS upgrade in next maintenance window" >> "$REPORT_FILE"
    fi
    if [[ "$KERNEL_STATUS" == "WARNING" && -n "$KERNEL_RECOMMENDATION" ]]; then
        echo "  - Kernel: $KERNEL_RECOMMENDATION" >> "$REPORT_FILE"
    elif [[ "$KERNEL_STATUS" == "WARNING" ]]; then
        echo "  - Consider kernel update" >> "$REPORT_FILE"
    fi
    EXIT_CODE=1
fi

echo "" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"
echo "END OF REPORT" >> "$REPORT_FILE"
echo "=====================================" >> "$REPORT_FILE"

# Print report to stdout
cat "$REPORT_FILE"

exit $EXIT_CODE
