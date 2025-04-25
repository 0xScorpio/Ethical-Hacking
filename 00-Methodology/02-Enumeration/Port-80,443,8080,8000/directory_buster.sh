#!/bin/bash

# Ensure at least one and at most four arguments are provided
if [ $# -lt 1 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <IP:PORT> [IP:PORT] [IP:PORT] [IP:PORT]"
  exit 1
fi

# Commands for directory brute-forcing
FEROX_CMD="feroxbuster -u http://"
FEROX_ARGS="-w /usr/share/wordlists/seclists/Discovery/Web-Content/directory-list-lowercase-2.3-big.txt --filter-status 400,402,403,404,501,502,503,504,505"

GOBUSTER_CMD="gobuster dir -u http://"
GOBUSTER_ARGS="-w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -t 5 -b 200,301,302"

FFUF_CMD="ffuf -u http://"
FFUF_FUZZ="/FUZZ"
FFUF_ARGS="-w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -e .php,.html,.asp,.aspx,.bak,.old,.orig,.tmp,.txt,.log,.env,.xml,.json,.yml,.conf,.ini,.zip,.tar,.gz,.rar,.md,.jsp,.sqp,.swo -r -t 100 -mc 200,301,302 -c"

DIRSEARCH_CMD="dirsearch -u http://"
DIRSEARCH_ARGS="-w /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt -t 50 --exclude-status 400,401,403,404,503"

PAGECHECK_CMD="pgcheck http://"

# Function to open a new tab, split it, and run commands
run_in_tab() {
  local target="$1"

  # Run Feroxbuster in the first split (default terminal)
  xdotool type "$FEROX_CMD$target $FEROX_ARGS" && xdotool key Return
  sleep 2
  
  # Split terminal (RIGHT) and run GoBuster
  xdotool key ctrl+shift+r
  xdotool type "$GOBUSTER_CMD$target $GOBUSTER_ARGS" && xdotool key Return
  sleep 2

  # Split terminal (DOWN) and run FFUF
  xdotool key ctrl+shift+d
  xdotool type "$FFUF_CMD$target$FFUF_FUZZ $FFUF_ARGS" && xdotool key Return
  sleep 2
  
  # Split terminal (DOWN) and run Dirsearch
  xdotool key ctrl+shift+d
  sleep 2
  xdotool type "$DIRSEARCH_CMD$target $DIRSEARCH_ARGS" && xdotool key Return
  
  # Split terminal (DOWN) and run pgcheck
  xdotool key ctrl+shift+d
  sleep 2
  xdotool type "$PAGECHECK_CMD$target" && xdotool key Return
}

# Loop through each argument and create a new tab for each
for site in "$@"; do
  run_in_tab "$site"
done

