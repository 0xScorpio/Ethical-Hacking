#!/bin/bash

# Exit on error
set -e

# Usage check
if [ $# -lt 1 ]; then
  echo "Usage: $0 <IP=HOSTNAME> [<IP=HOSTNAME> ...]"
  echo "Example: $0 10.0.0.1=web 10.0.0.2=db"
  exit 1
fi

# Define base commands to be customized per target
BASE_COMMANDS=(
  "recon"                                        # Command 1
  "nmap -p- -sC -sV -O -v -oX"                   # Command 2, needs hostname + IP
  "scan -a"                                      # Command 3
)

# Get the original terminal window ID
ORIGINAL_WIN_ID=$(xdotool getactivewindow)

# Loop through all IP=HOSTNAME pairs
for TARGET in "$@"; do
  # Split input into IP and HOSTNAME
  IFS='=' read -r IP HOSTNAME <<< "$TARGET"

  if [[ -z "$IP" || -z "$HOSTNAME" ]]; then
    echo "Invalid input: '$TARGET'. Expected format: <IP>=<HOSTNAME>"
    continue
  fi

  # Open a new tab for this target
  xdotool key --window "$ORIGINAL_WIN_ID" ctrl+shift+t
  sleep 1

  # Re-focus the terminal (safety)
  xdotool windowactivate --sync "$ORIGINAL_WIN_ID"
  sleep 0.5

  # Define full commands to run
  COMMANDS=(
    "${BASE_COMMANDS[0]} $IP"
    "${BASE_COMMANDS[1]} ${HOSTNAME}.xml $IP"
    "${BASE_COMMANDS[2]} $IP"
  )

  # Run the first command in the default pane
  xdotool type --window "$ORIGINAL_WIN_ID" "${COMMANDS[0]}"
  xdotool key --window "$ORIGINAL_WIN_ID" Return
  sleep 1

  # Run remaining commands in split panes
  for ((i = 1; i < ${#COMMANDS[@]}; i++)); do
    # Split the pane (Ctrl+Shift+D)
    xdotool key --window "$ORIGINAL_WIN_ID" ctrl+shift+r
    sleep 1
    xdotool windowactivate --sync "$ORIGINAL_WIN_ID"
    sleep 0.5
    xdotool type --window "$ORIGINAL_WIN_ID" "${COMMANDS[$i]}"
    xdotool key --window "$ORIGINAL_WIN_ID" Return
    sleep 0.5
  done
done

