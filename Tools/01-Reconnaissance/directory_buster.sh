#!/bin/bash

# =============== DESCRIPTION ===============
#
# This script runs the basic set of directory fuzzing on a given URL.
# Specifically, it runs feroxbuster, gobuster, ffuf and dirsearch.
# To cover as many bases possible, I have set the following wordlists and checks:
#
# feroxbuster ---> directory-list-lowercase-2.3-big.txt
#
# gobuster ------> raft-large-directories.txt
#
# ffuf ----------> raft-large-directories.txt with common extensions
#
# dirsearch -----> common.txt with common extensions
#
# ~ 0xScorpio

# Ensure exactly one argument is provided
if [ "$#" -ne 1 ]; then
	echo "Usage: $0 http(s)://<IP:PORT>"
  exit 1
fi

TARGET="$1"

# Commands for directory brute-forcing
FEROX_CMD="feroxbuster --url $TARGET --depth 3 --wordlist /usr/share/wordlists/seclists/Discovery/Web-Content/raft-large-directories-lowercase.txt --filter-status 400,402,403,404,501,502,503,504,505 --extract-links --quiet --insecure"
GOBUSTER_CMD="gobuster dir --url $TARGET --wordlist /usr/share/wordlists/seclists/Discovery/Web-Content/big.txt --threads 10 --status-codes-blacklist 400,402,403,404,501,502,503,504,505 --quiet --no-tls-validation --follow-redirect"
FFUF_CMD="ffuf -u $TARGET/FUZZ -w /usr/share/wordlists/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-lowercase-2.3-big.txt -e .php,.html,.asp,.aspx,.bak,.old,.orig,.tmp,.txt,.log,.env,.xml,.json,.yml,.conf,.ini,.zip,.tar,.gz,.rar,.md,.jsp,.sqp,.swo -r -t 100 -mc 200,301,302 -c"
DIRSEARCH_CMD="dirsearch --url $TARGET --wordlists /usr/share/wordlists/seclists/Discovery/Web-Content/common.txt --threads 50 --extensions php,html,asp,aspx,bak,old,orig,tmp,txt,log,env,xml,json,yml,conf,ini,zip,tar,gz,rar,md,jsp,sqp,swo --recursive --max-recursion-depth 3 --exclude-status 400,402,403,404,501,502,503,504,505 --quiet-mode"

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
}

# Start the workflow
run_in_tab
