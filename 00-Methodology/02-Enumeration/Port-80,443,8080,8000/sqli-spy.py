#!/usr/bin/env python3

import requests
import sys
import time
from urllib.parse import urlparse, urlencode, parse_qs

# Terminal colors
R = '\033[91m'
G = '\033[92m'
Y = '\033[93m'
B = '\033[94m'
W = '\033[0m'

def usage():
    print(f"{Y}Usage: {W}{sys.argv[0]} <payloads.txt> <URL>")
    print(f"{Y}Example: {W}{sys.argv[0]} payloads.txt http://10.10.10.10/login.php")
    print(f"{Y}Example: {W}{sys.argv[0]} payloads.txt 'http://10.10.10.10/index.php?user=FUZZ'")
    sys.exit(1)

# Ensure correct argument order
if len(sys.argv) != 3:
    usage()

payload_file = sys.argv[1]
url = sys.argv[2]

# Read payloads
try:
    with open(payload_file, 'r') as f:
        payloads = [line.strip() for line in f.readlines() if line.strip()]
except Exception as e:
    print(f"{R}[!] Error reading payloads: {e}{W}")
    sys.exit(1)

def inject_payload(url, payload):
    """Inject the payload into the URL appropriately"""
    if 'FUZZ' in url:
        return url.replace('FUZZ', payload)
    
    parsed = urlparse(url)
    if parsed.query:
        query = parse_qs(parsed.query)
        injected_query = {k: payload for k in query}
        return parsed._replace(query=urlencode(injected_query, doseq=True)).geturl()
    else:
        return url  # No place to inject, send raw

# Baseline response
try:
    baseline = requests.get(url, timeout=10)
    base_length = len(baseline.text)
    base_status = baseline.status_code
except Exception as e:
    print(f"{R}[!] Cannot connect to URL: {e}{W}")
    sys.exit(1)

print(f"{B}[*] Starting SQLi detection on: {url}{W}\n")

# Main payload loop
for payload in payloads:
    test_url = inject_payload(url, payload)
    try:
        start = time.time()
        resp = requests.get(test_url, timeout=10)
        end = time.time()
    except Exception as e:
        print(f"{R}[!] Error with payload {payload}: {e}{W}")
        continue

    duration = end - start
    diff = abs(len(resp.text) - base_length)

    if resp.status_code != base_status or diff > 20 or duration > 5:
        print(f"{G}[+] Potential SQLi detected with payload: {payload}{W}")
        print(f"    Status: {resp.status_code} | Resp Size Diff: {diff} | Time: {duration:.2f}s\n")
    else:
        print(f"{Y}[-] No anomaly with: {payload}{W}")

print(f"{B}[*] Detection finished.{W}")
