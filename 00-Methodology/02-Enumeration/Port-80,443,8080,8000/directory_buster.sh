#!/bin/bash

# Ensure exactly one argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <IP:PORT>"
  exit 1
fi

TARGET="$1"

# Commands for directory brute-forcing
FEROX_CMD="feroxbuster -u http://$TARGET -w /usr/share/wordlists/seclists/Discovery/Web-Content/directory-list-lowercase-2.3-big.txt --filter-status 400,402,403,404,501,502,503,504,505"
GOBUSTER_CMD="gobuster dir -u http://$TARGET -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -t 5 -b 404,501,502,503,504,505"
FFUF_CMD="ffuf -u http://$TARGET/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories.txt -e .php,.html,.asp,.aspx,.bak,.old,.orig,.tmp,.txt,.log,.env,.xml,.json,.yml,.conf,.ini,.zip,.tar,.gz,.rar,.md,.jsp,.sqp,.swo -r -t 100 -mc 200,301,302 -c"
DIRSEARCH_CMD="dirsearch -u http://$TARGET -w /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt -t 50 --exclude-status 400,401,403,404,503"
PAGECHECK_CMD="pgcheck http://$TARGET"

# Function to open new tab, split, and run commands
run_in_tab() {
  # Run Feroxbuster
  xdotool type "$FEROX_CMD" && xdotool key Return
  sleep 2
  
  # Split terminal (RIGHT) and run GoBuster
  xdotool key ctrl+shift+r
  xdotool type "$GOBUSTER_CMD" && xdotool key Return
  sleep 2

  # Split terminal (DOWN) and run FFUF
  xdotool key ctrl+shift+d
  xdotool type "$FFUF_CMD" && xdotool key Return
  sleep 2
  
  # Split terminal (DOWN) and run Dirsearch
  xdotool key ctrl+shift+d
  sleep 2
  xdotool type "$DIRSEARCH_CMD" && xdotool key Return
  
  # Split terminal (DOWN) and run pgcheck
  xdotool key ctrl+shift+d
  sleep 2
  xdotool type "$PAGECHECK_CMD" && xdotool key Return
}

# Start the workflow
run_in_tab
