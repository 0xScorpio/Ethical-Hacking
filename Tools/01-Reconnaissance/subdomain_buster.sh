#!/bin/bash

# =============== DESCRIPTION ===============
#
# This script runs a set of subdomain enumeration tools on a given domain.
# Specifically, it runs FFUF, Gobuster, and Sublist3r to cover as many bases as possible.
#
# ffuf ----------> Virtual host discovery using namelist.txt (run FIRST — found
#                  vhosts need to be added to /etc/hosts before further enum)
#
# gobuster ------> Subdomain brute-forcing using subdomains-top1million-110000.txt
#
# sublist3r -----> Passive subdomain enumeration
#
# Accepts flexible input:
#   ./subdomain_buster.sh test.local
#   ./subdomain_buster.sh http://test.local
#   ./subdomain_buster.sh https://test.local:8443/path
#
# ~ 0xScorpio

set -euo pipefail

### -------------------------------
### Input validation
### -------------------------------

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

# Strip scheme
RAW="${RAW#http://}"
RAW="${RAW#https://}"
# Strip path / trailing slashes
RAW="${RAW%%/*}"
# Strip port
TARGET="${RAW%%:*}"

# Reject empty input
if [ -z "$TARGET" ]; then
    echo "[!] Could not parse a domain from the input."
    exit 1
fi

# Reject bare IPs (DNS enumeration does not apply)
if [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "[!] IP address supplied. DNS-based subdomain enumeration requires a domain."
    exit 1
fi

echo "[*] Target domain: $TARGET"

### -------------------------------
### Dependency checks
### -------------------------------

for bin in gobuster ffuf sublist3r dig xdotool; do
    command -v "$bin" >/dev/null 2>&1 || {
        echo "[!] Missing dependency: $bin"
        exit 1
    }
done

### -------------------------------
### DNS resolution
### -------------------------------

IP="$(dig +short A "$TARGET" | grep -E '^[0-9]+\.' | head -n 1)"
if [ -z "$IP" ]; then
    echo "[!] Failed to resolve A record for $TARGET"
    exit 1
fi

echo "[*] Resolved $TARGET -> $IP"

HOSTNAME="$(echo "$TARGET" | awk -F. '{print $(NF-1)}')"

### -------------------------------
### Wordlists
### -------------------------------

SUBDOMAIN_WL="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt"
VHOST_WL="/usr/share/wordlists/seclists/Discovery/DNS/namelist.txt"

for wl in "$SUBDOMAIN_WL" "$VHOST_WL"; do
    [ -f "$wl" ] || { echo "[!] Missing wordlist: $wl"; exit 1; }
done

### -------------------------------
### Output files
### -------------------------------

SUBDOMAIN_OUT="subdomains_${HOSTNAME}.txt"
VHOST_OUT="vhosts_${HOSTNAME}.json"
SUBLIST3R_OUT="sublist3r_${HOSTNAME}.txt"

### -------------------------------
### Tool commands
### -------------------------------

# FFUF virtual host discovery (FIRST — results need /etc/hosts entries)
# - Host header fuzzing against resolved IP
# - Auto-calibration filters false positives
FFUF_CMD="ffuf -u http://$IP/ -w $VHOST_WL -H 'Host: FUZZ.$TARGET' -ac -mc 200,204,301,302,307,401,403 -timeout 10 -of json -o $VHOST_OUT"

# Gobuster DNS mode — subdomain brute-force with wildcard detection
GOBUSTER_CMD="gobuster dns --domain $TARGET -w $SUBDOMAIN_WL -t 40 --timeout 3s --wildcard -o $SUBDOMAIN_OUT"

# Sublist3r — passive enum only
SUBLIST3R_CMD="sublist3r -d $TARGET -o $SUBLIST3R_OUT"

### -------------------------------
### Execution (xdotool window splitting)
### -------------------------------

run_in_tab() {
    # FFUF vhost discovery (priority — need results for /etc/hosts)
    xdotool type -- "$FFUF_CMD"
    xdotool key Return
    sleep 2

    # Split RIGHT → Gobuster DNS
    xdotool key ctrl+shift+r
    sleep 1
    xdotool type -- "$GOBUSTER_CMD"
    xdotool key Return
    sleep 2

    # Split DOWN → Sublist3r
    xdotool key ctrl+shift+d
    sleep 1
    xdotool type -- "$SUBLIST3R_CMD"
    xdotool key Return
}

run_in_tab
