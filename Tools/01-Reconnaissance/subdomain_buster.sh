#!/bin/bash

# =============== DESCRIPTION ===============
#
# This script runs a set of subdomain enumeration tools on a given domain.
# Specifically, it runs Gobuster, FFUF, and Sublist3r to cover as many bases as possible.
#
# gobuster ------> Subdomain brute-forcing using the subdomains-top1million-110000.txt wordlist
#
# ffuf ----------> Virtual host discovery using the namelist.txt wordlist
#
# sublist3r ----- > SUBLISTER!
#
# ~ 0xScorpio

set -euo pipefail

### -------------------------------
### Input validation
### -------------------------------

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

TARGET_RAW="$1"

# Strip scheme if user passed URL
TARGET="${TARGET_RAW#http://}"
TARGET="${TARGET#https://}"
TARGET="${TARGET%%/*}"

# Reject IPs (DNS enumeration does not apply)
if [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "[!] IP address supplied. DNS-based subdomain enumeration requires a domain."
    exit 1
fi

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

IP="$(dig +short A "$TARGET" | head -n 1)"
if [ -z "$IP" ]; then
    echo "[!] Failed to resolve A record for $TARGET"
    exit 1
fi

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
### Tool commands (corrected)
### -------------------------------

# Gobuster DNS mode — domain only, sane thread count, wildcard detection
GOBUSTER_CMD=(
    gobuster dns
    --domain "$TARGET"
    -w "$SUBDOMAIN_WL"
    -t 40
    --timeout 3s
    --wildcard
    -o "$SUBDOMAIN_OUT"
)

# FFUF virtual host discovery
# - Host header fuzzing
# - Baseline filtering via auto-calibration
# - Match common web response codes
FFUF_CMD=(
    ffuf
    -u "http://$IP/"
    -w "$VHOST_WL"
    -H "Host: FUZZ.$TARGET"
    -ac
    -mc 200,204,301,302,307,401,403
    -timeout 10
    -of json
    -o "$VHOST_OUT"
)

# Sublist3r — passive enum only
SUBLIST3R_CMD=(
    sublist3r
    -d "$TARGET"
    -o "$SUBLIST3R_OUT"
)

### -------------------------------
### Execution (window logic preserved)
### -------------------------------

run_in_tab() {

    # Gobuster
    xdotool type "${GOBUSTER_CMD[*]}"
    xdotool key Return
    sleep 2

    # Split RIGHT → FFUF
    xdotool key ctrl+shift+r
    xdotool type "ffuf -u http://$IP/ -w $VHOST_WL -H 'Host: FUZZ.$TARGET' -ac -mc 200,204,301,302,307,401,403 -timeout 10 -of json -o $VHOST_OUT"
    xdotool key Return
    sleep 2

    # Split DOWN → Sublist3r
    xdotool key ctrl+shift+d
    xdotool type "${SUBLIST3R_CMD[*]}"
    xdotool key Return
}

run_in_tab

