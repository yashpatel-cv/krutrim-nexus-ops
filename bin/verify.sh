#!/usr/bin/env bash
# verify.sh - Validates the server state

set -Eeuo pipefail

pass() { echo -e "\e[32m[PASS]\e[0m $*"; }
fail() { echo -e "\e[31m[FAIL]\e[0m $*"; exit 1; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; }

echo "Running Verification..."

# 1. Check Firewall
if nft list ruleset | grep -q "chain input"; then
    pass "nftables is active and has rules."
else
    fail "nftables ruleset is empty or not loaded."
fi

# 2. Check DNS
if grep -q "127.0.0.1" /etc/resolv.conf; then
    pass "resolv.conf points to localhost."
else
    fail "resolv.conf does NOT point to localhost."
fi

if systemctl is-active --quiet unbound; then
    pass "Unbound service is running."
else
    fail "Unbound service is NOT running."
fi

# 3. Check Privacy
if systemctl is-active --quiet tor; then
    pass "Tor is running."
else
    warn "Tor is not running (might be disabled by default)."
fi

# 4. Check Swap
if [ -f /swapfile ]; then
    pass "Swap file exists."
else
    warn "Swap file does not exist."
fi

# 5. Check Web
if systemctl is-active --quiet caddy; then
    pass "Caddy is running."
else
    warn "Caddy is not running."
fi

echo "Verification Complete."
