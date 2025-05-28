#!/bin/bash
# =============== DESCRIPTION ===============
#
# Setup a basic directory environment for a new penetration test.
# Follows the following format:
#
#      ----HOSTNAME----
#      |      |       |              
#    scan    web    exploit    
#                     |       
#                   access     
#
# Good luck!
# ~ 0xScorpio

set -e

# Check dependencies
for cmd in xdotool; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] Required command '$cmd' not found. Install it first."
        exit 1
    fi
done

# Check if at least one hostname is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <HOSTNAME1> [HOSTNAME2 ...]"
    exit 1
fi

for HOST in "$@"; do
    echo "[*] Creating directory structure for '$HOST'..."

    # Absolute path
    BASE_DIR="$PWD/$HOST"

    # Create required directories
    mkdir -p "$BASE_DIR/scan" \
             "$BASE_DIR/web" \
             "$BASE_DIR/exploit/access"

    echo "[+] Structure created at: $BASE_DIR"

    # Prompt user
    read -r -p "Do you currently want to work on this machine? (y/N) " response
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "[*] Using xdotool to open tabs..."

            # Focus on terminal window
            xdotool windowfocus "$(xdotool getactivewindow)"

            sleep 0.5
            # First tab already open, use it for 'scan'
            xdotool type --delay 50 "cd '$BASE_DIR/scan'"
            xdotool key Return

            # Open new tab for 'web'
            xdotool key ctrl+shift+t
            sleep 0.3
            xdotool type --delay 50 "cd '$BASE_DIR/web'"
            xdotool key Return

            # Open new tab for 'exploit'
            xdotool key ctrl+shift+t
            sleep 0.3
            xdotool type --delay 50 "cd '$BASE_DIR/exploit'"
            xdotool key Return

            # Open new tab for 'exploit/access'
            xdotool key ctrl+shift+t
            sleep 0.3
            xdotool type --delay 50 "cd '$BASE_DIR/exploit/access'"
            xdotool key Return
            ;;
        *)
            echo "Good luck!"
            exit 0
            ;;
    esac
done
