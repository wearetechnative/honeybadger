#!/usr/bin/env bash
#
# generate-final-report.sh - Generate consolidated final audit report
#
# This script reads Honeybadger audit output files and generates a
# consolidated final-report.md with all key information in structured format.
#
# Usage: generate-final-report.sh <output-directory>
#

set -euo pipefail

# Function to display usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") <output-directory>

Generate a consolidated final audit report from Honeybadger audit output.

Arguments:
    <output-directory>    Path to the audit output directory containing audit files

Example:
    $(basename "$0") output-hostname-user-17-03-2026

EOF
    exit 1
}

# Check if output directory argument is provided
if [ $# -eq 0 ]; then
    echo "Error: No output directory specified" >&2
    usage
fi

OUTPUT_DIR="$1"

# Validate output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Error: Output directory does not exist: $OUTPUT_DIR" >&2
    exit 1
fi

# Check for required files (at least lynis-report.json should exist)
if [ ! -f "$OUTPUT_DIR/lynis-report.json" ]; then
    echo "Error: Required file not found: $OUTPUT_DIR/lynis-report.json" >&2
    echo "This does not appear to be a valid Honeybadger audit output directory" >&2
    exit 1
fi

#==============================================================================
# DATA EXTRACTION FUNCTIONS - ASSET IDENTIFICATION
#==============================================================================

# Extract serial number from asset-inventory.txt or return "Not available"
extract_serial_number() {
    local serial="Not available"

    if [ -f "$OUTPUT_DIR/asset-inventory.txt" ]; then
        # Extract from "Serial Number / Model" line
        serial=$(grep -E "^Serial Number / Model" "$OUTPUT_DIR/asset-inventory.txt" 2>/dev/null | cut -d'|' -f2 | xargs)
    fi

    echo "${serial:-Not available}"
}

# Extract hostname from lynis-report.json
extract_hostname() {
    local hostname="Unknown"

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        hostname=$(jq -r '.hostname // "Unknown"' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
    fi

    echo "${hostname:-Unknown}"
}

# Extract hardware model from asset-inventory.txt or neofetch.json
extract_hardware_model() {
    local model="Not available"

    # Try asset-inventory.txt first
    if [ -f "$OUTPUT_DIR/asset-inventory.txt" ]; then
        # Extract from "Serial Number / Model" line (model is usually after serial)
        local line=$(grep -E "^Serial Number / Model" "$OUTPUT_DIR/asset-inventory.txt" 2>/dev/null | cut -d'|' -f2 | xargs)
        # Model is typically at the end
        model=$(echo "$line" | awk '{print $NF}')
    fi

    # Fallback to neofetch if available
    if [ "$model" = "Not available" ] && [ -f "$OUTPUT_DIR/neofetch.json" ]; then
        model=$(jq -r '.Model // "Not available"' "$OUTPUT_DIR/neofetch.json" 2>/dev/null)
    fi

    echo "${model:-Not available}"
}

# Detect current user (non-root) from SUDO_USER or directory name
extract_current_user() {
    local user="Unknown"

    # Try SUDO_USER environment variable first
    if [ -n "${SUDO_USER:-}" ]; then
        user="$SUDO_USER"
    else
        # Parse from directory name: output-<hostname>-<user>-<date>
        local dirname=$(basename "$OUTPUT_DIR")
        # Extract user (second field after splitting by -)
        if [[ "$dirname" =~ ^output-[^-]+-([^-]+)- ]]; then
            user="${BASH_REMATCH[1]}"
        fi
    fi

    echo "${user:-Unknown}"
}

# Extract NixOS metadata from nixos-system-info.txt if available
extract_nixos_metadata() {
    local metadata=""

    if [ -f "$OUTPUT_DIR/nixos-system-info.txt" ]; then
        # Read relevant lines from nixos-system-info.txt
        metadata=$(grep -E "^(Nixpkgs|System Generation|Last Rebuild)" "$OUTPUT_DIR/nixos-system-info.txt" 2>/dev/null || echo "")
    fi

    echo "$metadata"
}

# Extract audit date from directory name or file timestamp
extract_audit_date() {
    local audit_date=""

    # Parse from directory name: output-<hostname>-<user>-<date>
    local dirname=$(basename "$OUTPUT_DIR")
    if [[ "$dirname" =~ ([0-9]{2}-[0-9]{2}-[0-9]{4})$ ]]; then
        audit_date="${BASH_REMATCH[1]}"
    else
        # Fallback to lynis-report.json modification time
        if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
            audit_date=$(date -r "$OUTPUT_DIR/lynis-report.json" '+%d-%m-%Y' 2>/dev/null || echo "Unknown")
        fi
    fi

    echo "${audit_date:-Unknown}"
}

#==============================================================================
# DATA EXTRACTION FUNCTIONS - OS AND KERNEL STATUS
#==============================================================================

# Extract OS type, version, and architecture from lynis-report.json
extract_os_info() {
    local os_type="Unknown"
    local os_version="Unknown"
    local architecture="Unknown"

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        os_type=$(jq -r '.os // "Unknown"' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        os_version=$(jq -r '.os_version // "Unknown"' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)

        # Try to get architecture (may not be in all reports)
        architecture=$(jq -r '.os_kernel_version_full // ""' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null | grep -o 'x86_64\|aarch64\|arm64' || echo "x86_64")
    fi

    echo "$os_type|$os_version|$architecture"
}

# Extract kernel version from lynis-report.json
extract_kernel_version() {
    local kernel="Unknown"

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        kernel=$(jq -r '.os_kernel_version // "Unknown"' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
    fi

    echo "${kernel:-Unknown}"
}

# Parse os-kernel-status.txt for EOL status
# Returns: "SUPPORTED", "EOL", or "UNKNOWN"
parse_kernel_eol_status() {
    local status="UNKNOWN"

    if [ -f "$OUTPUT_DIR/os-kernel-status.txt" ]; then
        # Check for key indicators in the file
        if grep -qi "FULLY SUPPORTED\|ACTIVELY MAINTAINED\|CURRENT" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
            status="SUPPORTED"
        elif grep -qi "EOL\|End of Life\|DEPRECATED" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
            status="EOL"
        fi
    fi

    echo "$status"
}

# Determine kernel support status with visual indicator
determine_kernel_support_status() {
    local eol_status=$(parse_kernel_eol_status)

    case "$eol_status" in
        SUPPORTED)
            echo "✅ Supported"
            ;;
        EOL)
            echo "❌ End of Life"
            ;;
        *)
            echo "⚠️ Unknown"
            ;;
    esac
}

# Determine OS update stream status
# Returns status with visual indicator
determine_update_stream_status() {
    local status="⚠️ Unknown"

    if [ -f "$OUTPUT_DIR/os-kernel-status.txt" ]; then
        # Check for active update stream indicators
        if grep -qi "Update Stream: ACTIVE\|CURRENT STABLE RELEASE" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
            # Check if LTS
            if grep -qi "LTS" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
                status="✅ Active (LTS)"
            else
                status="✅ Active"
            fi
        elif grep -qi "Extended Support" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
            status="⚠️ Extended Support"
        elif grep -qi "Inactive\|EOL\|End of Life" "$OUTPUT_DIR/os-kernel-status.txt" 2>/dev/null; then
            status="❌ Inactive (EOL)"
        fi
    fi

    echo "$status"
}


#==============================================================================
# DATA EXTRACTION FUNCTIONS - SECURITY CONTROLS
#==============================================================================

# Parse blockdevices.txt for disk encryption status
# Returns: "ENABLED" or "DISABLED"
parse_disk_encryption() {
    local status="DISABLED"

    if [ -f "$OUTPUT_DIR/blockdevices.txt" ]; then
        # Check for crypto_LUKS or dm-crypt in blockdevices
        if grep -qi "crypto_LUKS\|dm-crypt" "$OUTPUT_DIR/blockdevices.txt" 2>/dev/null; then
            status="ENABLED"
        fi
    fi

    echo "$status"
}

# Get disk encryption status with visual indicator
get_disk_encryption_status() {
    local encryption=$(parse_disk_encryption)

    if [ "$encryption" = "ENABLED" ]; then
        echo "✅ Enabled"
    else
        echo "❌ Disabled"
    fi
}

# Parse screenlock-info.txt for auto-lock configuration
# Returns timeout in minutes or "DISABLED"
parse_screen_lock() {
    local timeout="DISABLED"

    if [ -f "$OUTPUT_DIR/screenlock-info.txt" ]; then
        # Check for AUTO-LOCK-STATUS
        if grep -qi "AUTO-LOCK-STATUS: ENABLED" "$OUTPUT_DIR/screenlock-info.txt" 2>/dev/null; then
            # Extract timeout in seconds and convert to minutes
            local seconds=$(grep -i "Total time until auto-lock:" "$OUTPUT_DIR/screenlock-info.txt" 2>/dev/null | grep -o '[0-9]\+' | head -1)
            if [ -n "$seconds" ]; then
                timeout=$((seconds / 60))
            fi
        fi
    fi

    echo "$timeout"
}

# Determine screen lock compliance status
determine_screen_lock_status() {
    local timeout=$(parse_screen_lock)

    if [ "$timeout" = "DISABLED" ]; then
        echo "❌ Not configured"
    elif [ "$timeout" -le 15 ]; then
        echo "✅ Enabled ($timeout minutes)"
    else
        echo "⚠️ Timeout too long ($timeout minutes)"
    fi
}

# Extract last update date from os-update-history.txt or asset-inventory
extract_last_update_date() {
    local update_date="Unknown"

    # Try asset-inventory.txt first
    if [ -f "$OUTPUT_DIR/asset-inventory.txt" ]; then
        local status=$(grep -E "^OS Up-to-date" "$OUTPUT_DIR/asset-inventory.txt" 2>/dev/null | cut -d'|' -f2 | xargs)
        if [[ "$status" =~ Current|Yes ]]; then
            update_date="Current"
        fi
    fi

    # TODO: Could parse os-update-history.txt for actual date if needed

    echo "$update_date"
}

# Extract firewall status from lynis-report.json or asset-inventory.txt
extract_firewall_status() {
    local status="Unknown"

    if [ -f "$OUTPUT_DIR/asset-inventory.txt" ]; then
        status=$(grep -E "^Firewall Active" "$OUTPUT_DIR/asset-inventory.txt" 2>/dev/null | cut -d'|' -f2 | xargs)
    fi

    # Convert to status with indicator
    case "$status" in
        Yes)
            echo "✅ Active"
            ;;
        No)
            echo "❌ Inactive"
            ;;
        *)
            echo "⚠️ Unknown"
            ;;
    esac
}

#==============================================================================
# DATA EXTRACTION FUNCTIONS - COMPLIANCE METRICS
#==============================================================================

# Extract Lynis hardening score from lynis-report.json
extract_lynis_score() {
    local score="0"

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        score=$(jq -r '.hardening_index // "0"' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
    fi

    echo "$score"
}

# Determine score compliance status (≥65 = compliant)
determine_score_compliance() {
    local score=$(extract_lynis_score)

    if [ "$score" -ge 65 ]; then
        echo "✅ $score/100"
    else
        echo "❌ $score/100"
    fi
}

# Extract and count findings by severity from lynis-report.json
# Lynis uses warning[] for warnings, but doesn't have explicit severity levels
# We'll parse the warnings and categorize based on patterns
extract_critical_findings() {
    local count=0

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        # Count warnings array items - these are typically higher severity
        count=$(jq -r '.["warning[]"] | length // 0' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
    fi

    echo "$count"
}

# Extract high severity findings
# Since Lynis doesn't explicitly categorize, we'll use suggestion count as proxy
extract_high_findings() {
    local count=0

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        # Use first few suggestions as "high" priority items
        local total=$(jq -r '.["suggestion[]"] | length // 0' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        # Consider up to 5 suggestions as "high" if there are warnings
        local warnings=$(extract_critical_findings)
        if [ "$warnings" -gt 0 ] && [ "$total" -gt 0 ]; then
            count=$(( total < 5 ? total : 5 ))
        fi
    fi

    echo "$count"
}

# Format critical and high findings for display
format_findings() {
    local critical=$(extract_critical_findings)
    local high=$(extract_high_findings)

    if [ "$critical" -eq 0 ] && [ "$high" -eq 0 ]; then
        echo "✅ 0 Critical, 0 High"
    elif [ "$critical" -eq 0 ]; then
        echo "⚠️ 0 Critical, $high High"
    else
        echo "❌ $critical Critical, $high High"
    fi
}

# Get detailed findings list (warnings from Lynis)
get_detailed_findings() {
    local findings=""

    if [ -f "$OUTPUT_DIR/lynis-report.json" ]; then
        # Extract warnings as they are the most critical
        local warnings=$(jq -r '.["warning[]"] | @json' "$OUTPUT_DIR/lynis-report.json" 2>/dev/null)
        if [ "$warnings" != "null" ] && [ -n "$warnings" ]; then
            findings=$(echo "$warnings" | jq -r '.[] | select(. != "-")' 2>/dev/null | head -10)
        fi
    fi

    echo "$findings"
}

#==============================================================================
# REPORT TEMPLATE AND GENERATION
#==============================================================================

# Generate markdown report header with audit metadata
generate_report_header() {
    local audit_date=$(extract_audit_date)
    local hostname=$(extract_hostname)

    cat <<HEADER
# Honeybadger Security Audit Report

**Audit Date:** $audit_date  
**System:** $hostname

---

HEADER
}

# Generate Asset Identification section
generate_asset_section() {
    local serial=$(extract_serial_number)
    local hostname=$(extract_hostname)
    local model=$(extract_hardware_model)
    local user=$(extract_current_user)
    local nixos_meta=$(extract_nixos_metadata)

    cat <<ASSET
## 📋 Asset Identification

| Field | Value |
|-------|-------|
| Serial Number | $serial |
| Hostname | $hostname |
| Hardware Model | $model |
| Current User | $user |

ASSET

    # Add NixOS metadata if available
    if [ -n "$nixos_meta" ]; then
        cat <<NIXOS

### NixOS Metadata
\`\`\`
$nixos_meta
\`\`\`

NIXOS
    fi
}

# Generate Operating System section
generate_os_section() {
    local os_info=$(extract_os_info)
    local os_type=$(echo "$os_info" | cut -d'|' -f1)
    local os_version=$(echo "$os_info" | cut -d'|' -f2)
    local architecture=$(echo "$os_info" | cut -d'|' -f3)
    local kernel=$(extract_kernel_version)
    local kernel_status=$(determine_kernel_support_status)
    local update_stream=$(determine_update_stream_status)

    cat <<OS
## 💻 Operating System

| Field | Value |
|-------|-------|
| OS Type | $os_type |
| OS Version | $os_version |
| Kernel Version | $kernel |
| Architecture | $architecture |
| Kernel Support Status | $kernel_status |
| Update Stream Status | $update_stream |

OS
}

# Generate Security Controls section
generate_security_section() {
    local disk_encryption=$(get_disk_encryption_status)
    local screen_lock=$(determine_screen_lock_status)
    local last_update=$(extract_last_update_date)
    local firewall=$(extract_firewall_status)

    cat <<SECURITY
## 🔒 Security Controls

| Control | Status |
|---------|--------|
| Disk Encryption | $disk_encryption |
| Screen Lock | $screen_lock |
| OS Updates | $last_update |
| Firewall | $firewall |

SECURITY
}

# Generate Compliance Metrics section
generate_compliance_section() {
    local score_status=$(determine_score_compliance)
    local findings=$(format_findings)
    local detailed=$(get_detailed_findings)

    cat <<COMPLIANCE
## 📊 Compliance Metrics

| Metric | Value |
|--------|-------|
| Lynis Hardening Score | $score_status |
| Security Findings | $findings |

COMPLIANCE

    # Add detailed findings if any exist
    if [ -n "$detailed" ]; then
        cat <<FINDINGS

### Key Findings
\`\`\`
$detailed
\`\`\`

FINDINGS
    fi
}

# Main function to generate the complete report
generate_final_report() {
    local output_file="$OUTPUT_DIR/final-report.md"

    {
        generate_report_header
        generate_asset_section
        generate_os_section
        generate_security_section
        generate_compliance_section

        cat <<FOOTER

---

**Report generated by Honeybadger** | $(date '+%Y-%m-%d %H:%M:%S')

FOOTER
    } > "$output_file"

    # Set appropriate permissions
    chmod 644 "$output_file"

    echo "✅ Final report generated: $output_file"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

# Main entry point
main() {
    # All validation already done at script start

    # Generate the report (error handling built into functions with fallbacks)
    generate_final_report

    exit 0
}

# Run main function
main
