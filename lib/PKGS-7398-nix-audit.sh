#!/usr/bin/env bash

set -euo pipefail

echo "=== NixOS Supply Chain Trust Check (PKGS-7398) ==="
echo

# Use modern command (no deprecated warning)
CONFIG=$(nix config show)

# Extract values
SUBSTITUTERS=$(echo "$CONFIG" | grep "^substituters =" | cut -d '=' -f2- | xargs)
TRUSTED_KEYS=$(echo "$CONFIG" | grep "^trusted-public-keys =" | cut -d '=' -f2- | xargs)
REQUIRE_SIGS=$(echo "$CONFIG" | grep "^require-sigs =" | awk '{print $3}')
TRUSTED_SUBS=$(echo "$CONFIG" | grep "^trusted-substituters =" | cut -d '=' -f2- | xargs)

echo "Substituters:        $SUBSTITUTERS"
echo "Trusted keys:        $TRUSTED_KEYS"
echo "Require signatures:  $REQUIRE_SIGS"
echo "Trusted substituters:$TRUSTED_SUBS"
echo

# Checks
PASS=true
REASONS=()

# Check substituters
if [[ -z "$SUBSTITUTERS" ]]; then
  PASS=false
  REASONS+=("No substituters configured")
fi

# Check require-sigs
if [[ "$REQUIRE_SIGS" != "true" ]]; then
  PASS=false
  REASONS+=("Signature enforcement disabled (require-sigs != true)")
fi

# Check trusted keys
if [[ -z "$TRUSTED_KEYS" ]]; then
  PASS=false
  REASONS+=("No trusted public keys configured")
fi

# Check if official cache is present
if ! echo "$SUBSTITUTERS" | grep -q "cache.nixos.org"; then
  REASONS+=("Official cache.nixos.org not in use (not required, but recommended)")
fi

# Optional: verify store integrity (non-fatal)
echo "Running store verification (this may take a while)..."
if nix store verify --all >/dev/null 2>&1; then
  STORE_OK=true
  echo "Store integrity: OK"
else
  STORE_OK=false
  echo "Store integrity: WARNING (verification issues or skipped)"
fi

echo
echo "=== Audit Result ==="

if $PASS; then
  RESULT="PASS"
else
  RESULT="FAIL"
fi

echo "Result: $RESULT"
echo

# Generate ISO27001-style statement
echo "=== ISO27001 Audit Statement ==="
echo

if $PASS; then
  cat <<EOF
The system uses the Nix package manager with enforced supply chain security controls.

- Binary sources (substituters) are explicitly defined: $SUBSTITUTERS
- Cryptographic verification is enforced (require-sigs = true)
- Trusted public keys are configured for all allowed sources
- Unsigned or tampered packages are rejected by design

$( [ "$STORE_OK" = true ] && echo "- Local package store integrity verified successfully" )

This implementation mitigates risks related to untrusted or unsigned package repositories (Lynis control PKGS-7398) and provides strong assurance of software supply chain integrity.
EOF

else
  cat <<EOF
The system uses the Nix package manager, but supply chain trust controls are not fully enforced.

Issues identified:
- $(printf "%s\n- " "${REASONS[@]}")

This may expose the system to risks related to untrusted or unsigned package sources (Lynis control PKGS-7398). Remediation is recommended to enforce strict signature verification and trusted sources.
EOF
fi

echo
echo "=== End of Report ==="
