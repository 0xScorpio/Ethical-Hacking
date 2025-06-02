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

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 http(s)://<domain or IP>"
    exit 1
fi

TARGET="$1"

# Determine if IP or domain
if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    IP="$TARGET"
    HOSTNAME="target"
else
    IP=$(dig +short "$TARGET" | head -n 1)
    if [ -z "$IP" ]; then
        echo "[!] Could not resolve IP for $TARGET."
        exit 1
    fi
    HOSTNAME=$(echo "$TARGET" | awk -F. '{print $(NF-2)}')
fi

# Wordlists for enumeration
SUBDOMAIN_WL="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt"
VHOST_WL="/usr/share/wordlists/seclists/Discovery/DNS/namelist.txt"
SUBLIST3R_WL="/usr/share/wordlists/seclists/Discovery/DNS/active-subdomains.txt"

# Output files
SUBDOMAIN_OUT="subdomains_${HOSTNAME}.txt"
VHOST_OUT="vhosts_${HOSTNAME}_raw.json"
SUBLIST3R_OUT="sublist3r_${HOSTNAME}_subdomains.txt"

# Commands for subdomain enumeration
GOBUSTER_CMD="gobuster dns -d $TARGET -w $SUBDOMAIN_WL -t 50 -o $SUBDOMAIN_OUT"
FFUF_CMD="ffuf -u http://$IP/ -w $VHOST_WL -H \"Host: FUZZ.$TARGET\" -ac -mc 200,301,302 -timeout 10 -o $VHOST_OUT -of json"
SUBLIST3R_CMD="sublist3r -d $TARGET -o $SUBLIST3R_OUT"

# Function to open new tab, split, and run commands
run_in_tab() {
  # Run Gobuster (subdomain enumeration)
  xdotool type "$GOBUSTER_CMD" && xdotool key Return
  sleep 2
  
  # Split terminal (RIGHT) and run FFUF (VHost fuzzing)
  xdotool key ctrl+shift+r
  xdotool type "$FFUF_CMD" && xdotool key Return
  sleep 2

  # Split terminal (DOWN) and run Sublist3r (subdomain enumeration)
  xdotool key ctrl+shift+d
  xdotool type "$SUBLIST3R_CMD" && xdotool key Return
}

# Start the workflow
run_in_tab
