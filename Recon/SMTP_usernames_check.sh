#!/bin/bash

# Check if the required arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IP-RANGE> <USERNAME>"
    echo "Example: $0 192.168.209.0-10 user123"
    exit 1
fi

IP_RANGE=$1
USERNAME=$2

# Function to check if an IP has port 25 open and verify username
check_ip() {
    local TARGET_IP=$1
    local USERNAME=$2

    # Check if port 25 is open using netcat
    echo "Checking $TARGET_IP for port 25..."
    nc -nv -w 1 $TARGET_IP 25 </dev/null &>/dev/null

    if [ "$?" -eq 0 ]; then
        echo "Port 25 open on $TARGET_IP. Running VRFY..."
        echo "VRFY $USERNAME" | nc -nv $TARGET_IP 25
    else
        echo "Port 25 closed on $TARGET_IP."
    fi
}

# Parse the IP range
IFS='.-' read -r IP_PART1 IP_PART2 IP_PART3 START END <<<"$IP_RANGE"

if [ -z "$END" ]; then
    echo "Invalid IP range. Please use a range like 192.168.209.0-10."
    exit 1
fi

# Loop through the IPs and check each one
for ((i=START; i<=END; i++)); do
    TARGET_IP="${IP_PART1}.${IP_PART2}.${IP_PART3}.${i}"
    check_ip "$TARGET_IP" "$USERNAME"
done
