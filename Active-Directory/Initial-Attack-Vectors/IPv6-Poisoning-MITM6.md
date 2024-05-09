## Overview
Despite IPv6 adoption increasing on the internet, most company networks do not configure their internal dedicated DNS servers to handle IPv6 requests and queries. In fact, even from my experience, most companies are unaware about the vulnerable default configurations that are set by enabling IPv6 and under-utilizing it.

IPv6 Poisoning abuses this 'misconfiguration', and unawareness, by spoofing DNS replies by creating a rogue, malicious DNS server to redirect traffic to an attacker specified endpoint.
