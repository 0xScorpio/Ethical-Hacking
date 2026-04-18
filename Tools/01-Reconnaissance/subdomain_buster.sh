#!/bin/bash

# ================================================================
#  SUBDOMAIN / VHOST BUSTER
# ================================================================
#
#  Runs a comprehensive set of subdomain and virtual host enumeration
#  tools against a target domain. Designed for OSCP-style engagements
#  where hidden vhosts are common and DNS records may not exist.
#
#  TOOL LAYOUT (3 terminal panes via xdotool):
#  ┌──────────────────────┬──────────────────────┐
#  │                      │                      │
#  │  [1] FFUF            │  [2] Gobuster VHOST  │
#  │  Vhost discovery     │  Vhost discovery     │
#  │  (namelist.txt)      │  (subdomains-top1m)  │
#  │                      ├──────────────────────┤
#  │                      │                      │
#  │                      │  [3] Gobuster DNS    │
#  │                      │  DNS brute-force     │
#  │                      │  (bitquark-top100k)  │
#  └──────────────────────┴──────────────────────┘
#
#  WHY THIS ORDER:
#    Vhost checks run first because any discovered vhosts must be
#    manually added to /etc/hosts before DNS-based enum is useful.
#
#  WORDLIST STRATEGY:
#    Each tool uses a DIFFERENT wordlist to maximize coverage.
#    If the primary lists come up empty, fallback lists are printed
#    at the end for manual follow-up.
#
#  FLEXIBLE INPUT:
#    ./subdomain_buster.sh test.local
#    ./subdomain_buster.sh http://test.local
#    ./subdomain_buster.sh https://test.local:8443/path
#
#  ~ 0xScorpio
# ================================================================

set -euo pipefail

# ----------------------------------------------------------------
#  INPUT VALIDATION
# ----------------------------------------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <domain>"
    echo ""
    echo "Examples:"
    echo "  $0 test.local"
    echo "  $0 http://test.local"
    echo "  $0 https://test.local:8443"
    exit 1
fi

RAW="$1"

# Normalize: strip scheme, path, trailing slashes, port
RAW="${RAW#http://}"
RAW="${RAW#https://}"
RAW="${RAW%%/*}"
TARGET="${RAW%%:*}"

if [ -z "$TARGET" ]; then
    echo "[!] Could not parse a domain from the input."
    exit 1
fi

if [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "[!] IP address supplied. Subdomain enumeration requires a domain name."
    exit 1
fi

# ----------------------------------------------------------------
#  DEPENDENCY CHECKS
# ----------------------------------------------------------------

MISSING=()
for bin in gobuster ffuf dig xdotool; do
    command -v "$bin" >/dev/null 2>&1 || MISSING+=("$bin")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "[!] Missing dependencies: ${MISSING[*]}"
    echo "    Install with: sudo apt install ${MISSING[*]}"
    exit 1
fi

# ----------------------------------------------------------------
#  DNS RESOLUTION
# ----------------------------------------------------------------

IP="$(dig +short A "$TARGET" | grep -E '^[0-9]+\.' | head -n 1)"

if [ -z "$IP" ]; then
    echo "[!] Failed to resolve A record for $TARGET"
    echo "[*] Tip: Is $TARGET in /etc/hosts or resolvable via DNS?"
    exit 1
fi

# Extract short hostname for output file naming (e.g. "test" from "test.local")
HOSTNAME="$(echo "$TARGET" | awk -F. '{print $(NF-1)}')"

echo "========================================="
echo "  Target domain : $TARGET"
echo "  Resolved IP   : $IP"
echo "  Output prefix : ${HOSTNAME}_*"
echo "========================================="

# ----------------------------------------------------------------
#  WORDLISTS
# ----------------------------------------------------------------
#  Primary lists — each tool gets a unique wordlist for max coverage.
#  Fallback lists are suggested at the end if primaries find nothing.

# FFUF vhost — small/fast for quick wins
FFUF_WL="/usr/share/wordlists/seclists/Discovery/DNS/namelist.txt"

# Gobuster vhost — larger coverage with the top 110k subdomains
GOBUSTER_VHOST_WL="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt"

# Gobuster DNS — different list to avoid overlap with vhost scan
GOBUSTER_DNS_WL="/usr/share/wordlists/seclists/Discovery/DNS/bitquark-subdomains-top100000.txt"

for wl in "$FFUF_WL" "$GOBUSTER_VHOST_WL" "$GOBUSTER_DNS_WL"; do
    if [ ! -f "$wl" ]; then
        echo "[!] Missing wordlist: $wl"
        echo "    Install: sudo apt install seclists"
        exit 1
    fi
done

# ----------------------------------------------------------------
#  OUTPUT FILES
# ----------------------------------------------------------------

FFUF_OUT="vhosts_ffuf_${HOSTNAME}.json"
GOBUSTER_VHOST_OUT="vhosts_gobuster_${HOSTNAME}.txt"
GOBUSTER_DNS_OUT="subdomains_dns_${HOSTNAME}.txt"

# ----------------------------------------------------------------
#  TOOL COMMANDS
# ----------------------------------------------------------------

# [1] FFUF — Virtual host discovery via Host header fuzzing
#     - Hits the resolved IP directly (no DNS dependency)
#     - Auto-calibration (-ac) filters false positives automatically
#     - JSON output for easy parsing
FFUF_CMD="ffuf -u http://$IP/ -w $FFUF_WL -H 'Host: FUZZ.$TARGET' -ac -mc 200,204,301,302,307,401,403 -t 50 -timeout 10 -of json -o $FFUF_OUT"

# [2] GOBUSTER VHOST — Second vhost pass with a larger wordlist
#     - Uses --append-domain to build FUZZ.domain automatically
#     - Complementary to FFUF (different wordlist, different filtering)
GOBUSTER_VHOST_CMD="gobuster vhost -u http://$IP --domain $TARGET --append-domain -w $GOBUSTER_VHOST_WL -t 50 --timeout 3s -o $GOBUSTER_VHOST_OUT"

# [3] GOBUSTER DNS — Traditional DNS subdomain brute-force
#     - Requires the target to have a real DNS server
#     - Wildcard detection prevents false positive floods
GOBUSTER_DNS_CMD="gobuster dns --domain $TARGET -w $GOBUSTER_DNS_WL -t 40 --timeout 3s --wildcard -o $GOBUSTER_DNS_OUT"

# ----------------------------------------------------------------
#  EXECUTION (xdotool terminal splitting)
# ----------------------------------------------------------------

run_in_tab() {
    # [1] FFUF vhost — main pane (priority: results needed for /etc/hosts)
    xdotool type -- "$FFUF_CMD"
    xdotool key Return
    sleep 2

    # [2] Split RIGHT → Gobuster VHOST (second vhost pass, larger wordlist)
    xdotool key ctrl+shift+r
    sleep 1
    xdotool type -- "$GOBUSTER_VHOST_CMD"
    xdotool key Return
    sleep 2

    # [3] Split DOWN → Gobuster DNS (traditional DNS brute-force)
    xdotool key ctrl+shift+d
    sleep 1
    xdotool type -- "$GOBUSTER_DNS_CMD"
    xdotool key Return
}

run_in_tab

# ----------------------------------------------------------------
#  POST-RUN GUIDANCE
# ----------------------------------------------------------------

echo ""
echo "[*] All tools launched. Output files:"
echo "      FFUF vhosts     : $FFUF_OUT"
echo "      Gobuster vhosts : $GOBUSTER_VHOST_OUT"
echo "      Gobuster DNS    : $GOBUSTER_DNS_OUT"
echo ""
echo "[*] NEXT STEPS:"
echo "    1. Check FFUF/Gobuster vhost results for discovered subdomains"
echo "    2. Add confirmed vhosts to /etc/hosts:"
echo "         echo '$IP found.subdomain.$TARGET' | sudo tee -a /etc/hosts"
echo "    3. Re-run directory_buster.sh against each new vhost"
echo ""
echo "[*] FALLBACK WORDLISTS (if primary scans find nothing):"
echo "    /usr/share/wordlists/seclists/Discovery/DNS/dns-Jhaddix.txt"
echo "    /usr/share/wordlists/seclists/Discovery/DNS/fierce-hostlist.txt"
echo "    /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt  (quick recheck)"
