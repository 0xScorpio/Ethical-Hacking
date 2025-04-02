#!/bin/bash

# Check if at least one IP is provided, but not more than 4
if [ $# -lt 1 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 <IP1> [IP2] [IP3] [IP4]"
  exit 1
fi

COMMANDS=("recon") # Base commands

# Function to execute commands in a split terminal dynamically
run_in_splits() {
  local base_cmd="$1"
  shift  # Remove the first argument (base_cmd), leaving only IPs
  local ips=("$@")

  xdotool type "$base_cmd ${ips[0]}" && xdotool key Return && sleep 2

  for ((i = 1; i < ${#ips[@]}; i++)); do
    if ((i == 1)); then
      xdotool key ctrl+shift+r  # First split (Right)
    else
      xdotool key ctrl+shift+d  # Subsequent splits (Down)
    fi
    sleep 0.5
    xdotool type "$base_cmd ${ips[i]}" && xdotool key Return && sleep 2
  done
}

# Run recon command in separate tabs
for cmd in "${COMMANDS[@]}"; do
  run_in_splits "$cmd" "$@"
  xdotool key ctrl+shift+t  # Open a new tab
  sleep 2
done

# Run nmap separately for each IP in its own tab
for ip in "$@"; do
  nmap_cmd="nmap -p- -sC -sV -O -v -oX ${ip}.xml $ip"
  xdotool key ctrl+shift+t  # Open a new tab
  sleep 2
  xdotool type "$nmap_cmd" && xdotool key Return && sleep 2
done
