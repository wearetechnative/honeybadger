#!/usr/bin/env bash
#
# fetch-os-releases.sh - Fetch latest OS and kernel release information
#
# This script fetches current release information from various sources and
# caches it for use by check-os-status.sh
#
# Usage: ./fetch-os-releases.sh [output-dir]
#

CACHE_DIR="${1:-.cache}"
CACHE_TTL=86400  # 24 hours

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Function to check if cache is still valid
is_cache_valid() {
    local cache_file="$1"
    local ttl="$2"

    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi

    local now=$(date +%s)
    local mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    local age=$((now - mtime))

    if [[ $age -lt $ttl ]]; then
        return 0
    else
        return 1
    fi
}

# Fetch data with curl
fetch_url() {
    local url="$1"
    local output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -s -f "$url" > "$output" 2>/dev/null
        return $?
    else
        echo "ERROR: curl not found" >&2
        return 1
    fi
}

echo "Fetching latest OS and kernel release information..."
echo "Cache directory: $CACHE_DIR"
echo ""

# Fetch NixOS releases
if ! is_cache_valid "$CACHE_DIR/nixos-releases.json" "$CACHE_TTL"; then
    echo "Fetching NixOS releases from endoflife.date..."
    if fetch_url "https://endoflife.date/api/nixos.json" "$CACHE_DIR/nixos-releases.json"; then
        echo "  ✓ NixOS releases cached"
    else
        echo "  ✗ Failed to fetch NixOS releases"
    fi
else
    echo "  → NixOS releases cache is still valid"
fi

# Fetch Ubuntu releases
if ! is_cache_valid "$CACHE_DIR/ubuntu-releases.json" "$CACHE_TTL"; then
    echo "Fetching Ubuntu releases from endoflife.date..."
    if fetch_url "https://endoflife.date/api/ubuntu.json" "$CACHE_DIR/ubuntu-releases.json"; then
        echo "  ✓ Ubuntu releases cached"
    else
        echo "  ✗ Failed to fetch Ubuntu releases"
    fi
else
    echo "  → Ubuntu releases cache is still valid"
fi

# Fetch Debian releases
if ! is_cache_valid "$CACHE_DIR/debian-releases.json" "$CACHE_TTL"; then
    echo "Fetching Debian releases from endoflife.date..."
    if fetch_url "https://endoflife.date/api/debian.json" "$CACHE_DIR/debian-releases.json"; then
        echo "  ✓ Debian releases cached"
    else
        echo "  ✗ Failed to fetch Debian releases"
    fi
else
    echo "  → Debian releases cache is still valid"
fi

# Fetch Linux kernel releases
if ! is_cache_valid "$CACHE_DIR/kernel-releases.json" "$CACHE_TTL"; then
    echo "Fetching Linux kernel releases from kernel.org..."
    if fetch_url "https://www.kernel.org/releases.json" "$CACHE_DIR/kernel-releases.json"; then
        echo "  ✓ Kernel releases cached"
    else
        echo "  ✗ Failed to fetch kernel releases"
    fi
else
    echo "  → Kernel releases cache is still valid"
fi

echo ""
echo "Cache update complete!"
echo ""
echo "Cached files:"
ls -lh "$CACHE_DIR"/*.json 2>/dev/null || echo "  No cache files found"
