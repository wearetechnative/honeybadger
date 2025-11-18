#!/bin/bash

# Script to parse Lynis report JSON and extract key security information
# Usage: ./lynis-report-parser.sh /path/to/lynis-report.json

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/lynis-report.json"
    exit 1
fi

REPORT_FILE="$1"

if [ ! -f "$REPORT_FILE" ]; then
    echo "Error: Report file not found: $REPORT_FILE"
    exit 1
fi

# Function to extract JSON values safely
get_json_value() {
    local key="$1"
    local default="$2"
    
    value=$(jq -r ".$key // \"$default\"" "$REPORT_FILE")
    
    if [ "$value" = "null" ] || [ "$value" = "NA" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Function to extract array values
get_json_array() {
    local key="$1"
    local default="$2"
    
    values=$(jq -r ".$key[]? // \"$default\"" "$REPORT_FILE")
    
    if [ -z "$values" ] || [ "$values" = "null" ] || [ "$values" = "NA" ]; then
        echo "$default"
    else
        echo "$values"
    fi
}

echo "===== SYSTEM INFORMATION ====="
echo "OS Name:           $(get_json_value "os_name" "Unknown")"
echo "OS Full Name:      $(get_json_value "os_fullname" "Unknown")"
echo "OS Version:        $(get_json_value "os_version" "Unknown")"
echo

echo "===== KERNEL INFORMATION ====="
echo "Kernel Version:    $(get_json_value "linux_kernel_version" "Unknown")"
echo "Kernel Release:    $(get_json_value "linux_kernel_release" "Unknown")"
echo "Kernel Full:       $(get_json_value "os_kernel_version_full" "Unknown")"
echo "Kernel Type:       $(get_json_value "linux_kernel_type" "Unknown")"
echo

echo "===== BOOT SECURITY ====="
echo "Boot Loader:       $(get_json_value "boot_loader" "Unknown")"
echo "UEFI Boot:         $(get_json_value "boot_uefi_booted" "Unknown")"
echo "Secure Boot:       $(get_json_value "boot_uefi_booted_secure" "Unknown (0=disabled, 1=enabled)")"
echo

echo "===== PASSWORD SETTINGS ====="
echo "Min Password Age:  $(get_json_value "password_min_days" "Not set")"
echo "Max Password Age:  $(get_json_value "password_max_days" "Not set")"
echo

echo "===== FIREWALL STATUS ====="
echo "Firewall Installed: $(get_json_value "firewall_installed" "Unknown (0=no, 1=yes)")"
echo "Firewall Active:    $(get_json_value "firewall_active" "Unknown (0=no, 1=yes)")"
echo "Firewall Software:  $(get_json_array "firewall_software[]" "None detected")"
echo "Empty Ruleset:      $(get_json_value "firewall_empty_ruleset" "Unknown (0=no, 1=yes)")"
echo

echo "===== ENCRYPTION ====="
echo "Encryption Methods:"
encryption_data=$(get_json_array "encryption[]" "None detected")
if [ "$encryption_data" != "None detected" ]; then
    echo "$encryption_data" | while read -r line; do
        echo "- $line"
    done
else
    echo "- None detected"
fi

echo "Encrypted Swap:"
encrypted_swap=$(get_json_array "encrypted_swap[]" "None detected")
if [ "$encrypted_swap" != "None detected" ]; then
    echo "$encrypted_swap" | while read -r line; do
        echo "- $line"
    done
else
    echo "- None detected"
fi
echo

echo "===== SYSTEM UPDATES ====="
echo "Package Audit Tool: $(get_json_value "package_audit_tool_found" "Unknown (0=no, 1=yes)")"
echo "Vulnerable Packages Found: $(get_json_value "vulnerable_packages_found" "Unknown (0=no, 1=yes)")"
echo

echo "===== SYSTEM HARDENING ====="
echo "Hardening Index: $(get_json_value "hardening_index" "Unknown")/100"
echo

echo "Report generated on: $(date)"
