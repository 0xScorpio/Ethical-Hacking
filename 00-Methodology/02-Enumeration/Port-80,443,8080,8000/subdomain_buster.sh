#!/bin/bash

# Ensure at least one and at most four arguments are provided
if [ $# -lt 1 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <target.local> [target.local] [target.local] [target.local]"
  exit 1
fi

# Commands for subdomain enumeration
DNS_CMD="gobuster dns -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt -t 10 -d"
VHOST_CMD="gobuster vhost --append-domain --wordlist /usr/share/wordlists/seclists/Discovery/DNS/namelist.txt -u http://"
VHOST_FILTER="| grep 'Status: 200'"

# Function to open a new tab, split it, and run commands
run_in_tab() {
  local target="$1"

  # Run Gobuster DNS in the first split (default terminal)
  xdotool type "$DNS_CMD $target" && xdotool key Return
  sleep 2

  # Split terminal (DOWN) and run Gobuster VHost
  xdotool key ctrl+shift+d
  sleep 2
  xdotool type "$VHOST_CMD$target $VHOST_FILTER" && xdotool key Return
}

# Loop through each argument and create a new tab for each
for site in "$@"; do
  run_in_tab "$site"
done

