#!/bin/bash

# ================================================================
#  SCORPIO SCAN — Initial Enumeration Suite
# ================================================================
#
#  Runs the core recon scans against one or more targets:
#  Nmap full-port TCP, AutoRecon, and Nmap UDP.
#
#  TOOL LAYOUT (3 terminal panes via xdotool):
#  ┌──────────────────────┬──────────────────────┐
#  │                      │                      │
#  │  [1] Nmap TCP        │  [2] AutoRecon       │
#  │  All ports + scripts │  Auto-enum (no UDP)  │
#  │  XML for cherrymap   ├──────────────────────┤
#  │                      │                      │
#  │                      │  [3] Nmap UDP        │
#  │                      │  Top 1000 UDP ports  │
#  └──────────────────────┴──────────────────────┘
#
#  WHY THIS ORDER:
#    Nmap TCP in the main pane — watch port discovery in real time.
#    AutoRecon runs full service enum (UDP disabled — handled by pane 3).
#    Dedicated UDP scan covers top 1000 ports vs AutoRecon's top 100.
#
#  FLEXIBLE INPUT:
#    ./scorpio_scan.sh 10.0.0.1=web
#    ./scorpio_scan.sh 10.0.0.1=web 10.0.0.2=db
#    ./scorpio_scan.sh http://10.0.0.1=web
#    ./scorpio_scan.sh https://10.0.0.1:8443=web
#
#  ~ 0xScorpio
# ================================================================

set -euo pipefail

# ----------------------------------------------------------------
#  INPUT VALIDATION
# ----------------------------------------------------------------

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <IP=HOSTNAME> [<IP=HOSTNAME> ...]"
    echo ""
    echo "Examples:"
    echo "  $0 10.0.0.1=web"
    echo "  $0 10.0.0.1=web 10.0.0.2=db"
    echo "  $0 http://10.0.0.1=web"
    echo "  $0 https://10.0.0.1:8443=web"
    exit 1
fi

# ----------------------------------------------------------------
#  DEPENDENCY CHECKS
# ----------------------------------------------------------------

MISSING=()
for bin in autorecon nmap xdotool; do
    command -v "$bin" >/dev/null 2>&1 || MISSING+=("$bin")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "[!] Missing dependencies: ${MISSING[*]}"
    exit 1
fi

# ----------------------------------------------------------------
#  TARGET PARSING HELPER
# ----------------------------------------------------------------

parse_target() {
    local raw="$1"

    # Strip scheme if present
    raw="${raw#http://}"
    raw="${raw#https://}"
    # Strip path / trailing slashes
    raw="${raw%%/*}"

    # Split on '=' → left side is IP (possibly with port), right side is hostname
    local ip_part="${raw%%=*}"
    local hostname="${raw#*=}"

    # Strip port from IP if present
    ip_part="${ip_part%%:*}"

    echo "$ip_part" "$hostname"
}

# ----------------------------------------------------------------
#  MAIN LOOP
# ----------------------------------------------------------------

ORIGINAL_WIN_ID="$(xdotool getactivewindow)"

for TARGET in "$@"; do

    # Parse and validate
    read -r IP HOSTNAME <<< "$(parse_target "$TARGET")"

    if [[ -z "$IP" || -z "$HOSTNAME" || "$IP" == "$HOSTNAME" ]]; then
        echo "[!] Invalid input: '$TARGET'"
        echo "    Expected format: <IP>=<HOSTNAME>  (e.g. 10.0.0.1=web)"
        continue
    fi

    if [[ ! "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "[!] '$IP' does not look like a valid IPv4 address."
        continue
    fi

    echo "========================================="
    echo "  Target IP   : $IP"
    echo "  Hostname    : $HOSTNAME"
    echo "  Nmap XML    : ${HOSTNAME}.xml"
    echo "========================================="

    # ----------------------------------------------------------------
    #  TOOL COMMANDS
    # ----------------------------------------------------------------

    # [1] Nmap TCP — full port scan with scripts, version, OS detection
    NMAP_TCP_CMD="sudo nmap -p- -sC -sV -O -Pn --open -v -oX ${HOSTNAME}.xml $IP"

    # [2] AutoRecon — full service enum, no brute-force, TCP only (UDP handled by pane 3)
    AUTORECON_CMD="sudo autorecon --exclude-tags brute --port-scans nmap-tcp-all $IP"

    # [3] Nmap UDP — top 1000 UDP ports with aggressive detection
    NMAP_UDP_CMD="sudo nmap -sU -A --top-ports 1000 -Pn -v $IP"

    # ----------------------------------------------------------------
    #  EXECUTION (xdotool terminal splitting)
    # ----------------------------------------------------------------

    # Re-focus the terminal
    xdotool windowactivate --sync "$ORIGINAL_WIN_ID"
    sleep 0.5

    # [1] Nmap TCP — main left pane (watch port discovery live)
    xdotool type -- "$NMAP_TCP_CMD"
    xdotool key Return
    sleep 2

    # [2] Split RIGHT → AutoRecon (top-right pane)
    xdotool key ctrl+shift+r
    sleep 1
    xdotool type -- "$AUTORECON_CMD"
    xdotool key Return
    sleep 2

    # [3] Split DOWN → Nmap UDP (bottom-right pane)
    xdotool key ctrl+shift+d
    sleep 1
    xdotool type -- "$NMAP_UDP_CMD"
    xdotool key Return

done

# ----------------------------------------------------------------
#  POST-RUN GUIDANCE
# ----------------------------------------------------------------

echo ""
echo "[*] All scans launched."
echo "[*] QUICK REFERENCE:"
echo "    - Nmap XML output → use with cherrymap or other parsers"
echo "    - UDP scan is slow → check periodically for results"
echo ""
echo "[*] NEXT STEPS:"
echo "    1. Review Nmap TCP output for open ports"
echo "    2. Run directory_buster.sh / subdomain_buster.sh as needed"
echo "    3. Check Nmap XML with: cherrymap <hostname>.xml"
