## Overview
Despite IPv6 adoption increasing on the internet, most company networks do not configure their internal dedicated DNS servers to handle IPv6 requests and queries. In fact, even from my experience, most companies are unaware about the vulnerable default configurations that are set by enabling IPv6 and under-utilizing it.

IPv6 Poisoning abuses this 'misconfiguration', and unawareness, through spoofing DNS replies by creating a rogue, malicious DNS server to redirect traffic to an attacker specified endpoint. 

MITM6 is the main tool that will be used - it exploits the default configuration of Windows to take over the default DNS server. It does this by replying to DHCPv6 messages, providing victims with a link-local IPv6 address and setting the attackers host as the default DNS server. As the DNS server, mitm6 will selectively reply to DNS queries of the attackers choosing and redirect the victims traffic to the attacker machine instead of the legitimate server. It is designed to work together with ntlmrelayx from Impacket for WPAD spoofing and credential relaying.

## Exploitation [EASY]
First, let's set up a fake relay server:
```bash
ntlmrelayx.py -6 -t ldaps://TARGET-IP -wh fakewap.domain.local -l FOLDER-TO-DUMP
```
*There have been instances where if there is a problem with the issuing of certificates, either due to the lack of a proper PKI environment or misconfigured certificate placements from the CA, LDAPS may not work. In this case, run the NTLM relay via LDAP instead.*

Once the relay server is set up, we'll want to finally run MITM6:
```bash
sudo mitm6 -d DOMAIN.local
```
> [!NOTE]
*Of course, this attack must be run on the internal network. From my experience as a penetration tester, if you started the pen-test externally, then using eth0 (or whatever you local network interface is) will be fine. However, if you've been given a VPN to start you pen-test directly from an internal instance, then make sure to switch the interface flag to your VPN interface: ` -i tun0 `, for example.*

And that's literally it!
For the most part, we're waiting for an event to occur. Events could be a user or admin logging into their device, rebooting their machine, accessing a file share, etc. Any network event that occurs will allow us to grab the NTLM hash and relay it over.

> [!NOTE]
Make sure to run this in small sprints of 5-10 minutes - else it could case network outages. Remember, we're impersonating the DNS server, so there's a chance that we can break the synchronization between our rogue DNS and the actual dedicated DNS server within the client environment... unless for some reason your end-goal is denial-of-service.*

## Results
Let's create a scenario of an administrator logging into their laptop within the network.

![image](https://github.com/0xScorpio/Ethical-Hacking/assets/140411254/cf1bfecb-6d85-49f6-bae0-5b766c0a0ccc)

As you can see, a user is created and instantly added into the ENTERPRISE ADMINS group! 

The username and password is printed out for us as well for local authentication, say on the domain controller (because why not?). 

> [!WARNING]
This is quite severe because now we've opened the doors to post-compromise attacks like a possible a Kerberos Golden Ticket attack (although stick with Silver Tickets for stealthy operations... shhh) as well as the infamous DCSync attacks (this attack is easily performed assuming you have the credentials of a Domain Admin or Enterprise Admin account) - which is the ideal attack for most corporate environments that have multiple clustered domain controllers for basic load-balancing.
