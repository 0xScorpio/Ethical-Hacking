#!/bin/bash

# Ensure exactly one argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <target.local>"
  exit 1
fi

TARGET="$1"

# Extract main domain part (e.g., oscptarget from internal.oscptarget.local)
MAIN_DOMAIN=$(echo "$TARGET" | awk -F. '{print $(NF-2)}')

# Wordlists
SUBDOMAIN_WL="/usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt"
VHOST_WL="/usr/share/wordlists/seclists/Discovery/DNS/namelist.txt"

# Output filenames
SUBDOMAIN_OUTPUT="subdomains_${MAIN_DOMAIN}.txt"
VHOST_RAW_OUTPUT="vhosts_${MAIN_DOMAIN}_raw.json"

# Core commands
DNS_CMD="gobuster dns -w $SUBDOMAIN_WL -t 50 -d $TARGET -o $SUBDOMAIN_OUTPUT"
VHOST_CMD_TEMPLATE="ffuf -u http://IP_TARGET/ -w $VHOST_WL -H \"Host: FUZZ.${TARGET}\" -ac -mc 200,301,302 -timeout 10 -o $VHOST_RAW_OUTPUT -of json"

# Function to type a command and run it
type_and_run() {
  local cmd="$1"
  sleep 1
  xdotool type --delay 1 --clearmodifiers "$cmd"
  xdotool key Return
}

# Start
echo "[*] Resolving IP address for $TARGET..."
IP=$(dig +short "$TARGET" | head -n 1)

if [ -z "$IP" ]; then
  echo "[!] Could not resolve IP for $TARGET."
  exit 1
fi

# Replace IP placeholder in VHOST_CMD
VHOST_CMD=$(echo "$VHOST_CMD_TEMPLATE" | sed "s/IP_TARGET/$IP/")

# --- Run DNS enumeration in the current terminal pane ---
echo "[*] Running subdomain enumeration in current pane..."
type_and_run "$DNS_CMD"

# --- Split RIGHT and run VHOST fuzzing ---
sleep 2
echo "[*] Splitting RIGHT and running VHOST fuzzing..."
xdotool key ctrl+shift+r
sleep 2
type_and_run "$VHOST_CMD"

# Done
echo "[*] Enumeration setup completed."
