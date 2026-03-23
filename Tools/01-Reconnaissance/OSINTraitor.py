#!/usr/bin/env python3
"""
OSINTraitor — All-in-one OSINT reconnaissance tool.

Usage:
  python3 OSINTraitor.py --domain example.com
  python3 OSINTraitor.py --people "John Doe"
  python3 OSINTraitor.py --phone +14155551234
  python3 OSINTraitor.py --email target@example.com
  python3 OSINTraitor.py -o ./custom_folder --domain example.com --email admin@example.com --people "John Doe" --phone +14155551234

Each flag is optional. Only the modules you specify will run.
"""

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import urllib.parse
import urllib.request
import ssl

# ═══════════════════════════════════════════════════════════
#  COLORS
# ═══════════════════════════════════════════════════════════

BLUE    = "\033[94m"
GREEN   = "\033[92m"
YELLOW  = "\033[93m"
CYAN    = "\033[96m"
RED     = "\033[91m"
MAGENTA = "\033[95m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
RESET   = "\033[0m"

# ═══════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════

GOOGLE = "https://www.google.com/search?q="


def google_url(query: str) -> str:
    return GOOGLE + urllib.parse.quote_plus(query)


def banner() -> None:
    print(f"""
{RED}{BOLD}   ██████╗ ███████╗██╗███╗   ██╗████████╗██████╗  █████╗ ██╗████████╗ ██████╗ ██████╗
  ██╔═══██╗██╔════╝██║████╗  ██║╚══██╔══╝██╔══██╗██╔══██╗██║╚══██╔══╝██╔═══██╗██╔══██╗
  ██║   ██║███████╗██║██╔██╗ ██║   ██║   ██████╔╝███████║██║   ██║   ██║   ██║██████╔╝
  ██║   ██║╚════██║██║██║╚██╗██║   ██║   ██╔══██╗██╔══██║██║   ██║   ██║   ██║██╔══██╗
  ╚██████╔╝███████║██║██║ ╚████║   ██║   ██║  ██║██║  ██║██║   ██║   ╚██████╔╝██║  ██║
   ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝{RESET}
  {DIM}All-in-one OSINT Reconnaissance Tool // by 0xScorpio{RESET}
""")


def section(title: str) -> None:
    print(f"\n{BOLD}{MAGENTA}{'═' * 60}{RESET}")
    print(f"{BOLD}{MAGENTA}  {title}{RESET}")
    print(f"{BOLD}{MAGENTA}{'═' * 60}{RESET}")


def info(msg: str) -> None:
    print(f"  {GREEN}[+]{RESET} {msg}")


def warn(msg: str) -> None:
    print(f"  {YELLOW}[-]{RESET} {msg}")


def err(msg: str) -> None:
    print(f"  {RED}[!]{RESET} {msg}")


def has_tool(name: str) -> bool:
    return shutil.which(name) is not None


def run_cmd(cmd: list[str], outfile: str | None = None, silent: bool = False) -> str:
    """Run a shell command, optionally saving stdout to a file. Returns stdout."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        output = result.stdout.strip()
        if outfile and output:
            with open(outfile, "w", encoding="utf-8") as f:
                f.write(output + "\n")
        if not silent and output:
            print(output)
        return output
    except FileNotFoundError:
        warn(f"{cmd[0]} not found — skipping")
        return ""
    except subprocess.TimeoutExpired:
        warn(f"{cmd[0]} timed out — skipping")
        return ""


def run_pipe(cmds: list[list[str]], outfile: str | None = None) -> str:
    """Run piped commands: cmds[0] | cmds[1] | ... Returns final stdout."""
    try:
        procs = []
        for i, cmd in enumerate(cmds):
            stdin = procs[i - 1].stdout if i > 0 else None
            p = subprocess.Popen(cmd, stdin=stdin, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if i > 0 and procs[i - 1].stdout:
                procs[i - 1].stdout.close()
            procs.append(p)
        output, _ = procs[-1].communicate(timeout=300)
        for p in procs[:-1]:
            p.wait()
        output = output.strip()
        if outfile and output:
            with open(outfile, "w", encoding="utf-8") as f:
                f.write(output + "\n")
        return output
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return ""


def api_get(url: str, headers: dict | None = None, timeout: int = 15) -> dict | str | None:
    """Simple GET request. Returns parsed JSON or raw text. No external deps."""
    try:
        req = urllib.request.Request(url, headers=headers or {"User-Agent": "OSINTraitor/1.0"})
        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            data = resp.read().decode("utf-8", errors="replace")
            try:
                return json.loads(data)
            except json.JSONDecodeError:
                return data
    except Exception:
        return None


def print_dorks(categories: dict, placeholder: str, target: str, out_dir: str, filename: str) -> int:
    """Print dork categories with clickable Google URLs. Returns total count."""
    total = 0
    lines: list[str] = []

    for cat, dorks in categories.items():
        print(f"\n  {BOLD}{YELLOW}━━━ {cat} ({len(dorks)}) ━━━{RESET}")
        lines.append(f"\n━━━ {cat} ({len(dorks)}) ━━━")

        for raw in dorks:
            query = raw.replace(f"{{{placeholder}}}", target)
            url = google_url(query)
            total += 1
            print(f"    {DIM}{total:>3}.{RESET} {CYAN}{query}{RESET}")
            print(f"         {BLUE}{url}{RESET}")
            lines.append(f"  {total}. {query}")
            lines.append(f"     {url}")

    filepath = os.path.join(out_dir, filename)
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(f"Google Dorks — {target}\n{'=' * 40}\n")
        f.write("\n".join(lines) + "\n")
    info(f"{total} dorks saved to {filepath}")
    return total


# ═══════════════════════════════════════════════════════════
#  DOMAIN DORKS
# ═══════════════════════════════════════════════════════════

DOMAIN_DORKS = {
    "Target Scoping": [
        "site:{domain}",
        "site:*.{domain}",
        "-site:{domain}",
    ],
    "File Type Discovery": [
        "site:{domain} filetype:pdf",
        "site:{domain} filetype:doc",
        "site:{domain} filetype:docx",
        "site:{domain} filetype:xls",
        "site:{domain} filetype:xlsx",
        "site:{domain} filetype:csv",
        "site:{domain} filetype:txt",
        "site:{domain} filetype:log",
        "site:{domain} filetype:conf",
        "site:{domain} filetype:cfg",
        "site:{domain} filetype:ini",
        "site:{domain} filetype:sql",
        "site:{domain} filetype:bak",
        "site:{domain} filetype:old",
        "site:{domain} filetype:zip",
        "site:{domain} filetype:rar",
        "site:{domain} filetype:7z",
        "site:{domain} filetype:tar",
        "site:{domain} filetype:gz",
        "site:{domain} filetype:json",
        "site:{domain} filetype:xml",
        "site:{domain} filetype:yml",
        "site:{domain} filetype:yaml",
        "site:{domain} filetype:pem",
        "site:{domain} filetype:key",
        "site:{domain} filetype:ovpn",
        "site:{domain} filetype:rdp",
    ],
    "URL-Based Discovery": [
        "site:{domain} inurl:admin",
        "site:{domain} inurl:login",
        "site:{domain} inurl:signin",
        "site:{domain} inurl:signup",
        "site:{domain} inurl:register",
        "site:{domain} inurl:upload",
        "site:{domain} inurl:download",
        "site:{domain} inurl:backup",
        "site:{domain} inurl:test",
        "site:{domain} inurl:dev",
        "site:{domain} inurl:staging",
        "site:{domain} inurl:old",
        "site:{domain} inurl:api",
        "site:{domain} inurl:v1",
        "site:{domain} inurl:v2",
        "site:{domain} inurl:graphql",
        "site:{domain} inurl:swagger",
        "site:{domain} inurl:api-docs",
        "site:{domain} inurl:php?id=",
        "site:{domain} inurl:cmd=",
        "site:{domain} inurl:exec=",
        "site:{domain} inurl:query=",
        "site:{domain} inurl:redirect=",
        "site:{domain} inurl:url=",
        "site:{domain} inurl:return=",
        "site:{domain} inurl:next=",
    ],
    "Page Content Discovery": [
        'site:{domain} intext:password',
        'site:{domain} intext:username',
        'site:{domain} intext:credentials',
        'site:{domain} intext:apikey',
        'site:{domain} intext:"api key"',
        'site:{domain} intext:"secret key"',
        'site:{domain} intext:"access token"',
        'site:{domain} intext:"confidential"',
        'site:{domain} intext:"internal use only"',
        'site:{domain} intext:"do not distribute"',
        'site:{domain} intext:"not for public release"',
    ],
    "Title-Based Discovery": [
        "site:{domain} intitle:admin",
        "site:{domain} intitle:login",
        "site:{domain} intitle:dashboard",
        "site:{domain} intitle:index.of",
        'site:{domain} intitle:"index of"',
        'site:{domain} intitle:"parent directory"',
        'site:{domain} intitle:"Apache Status"',
        'site:{domain} intitle:"PHP Version"',
    ],
    "Directory Listings / Misconfigurations": [
        'site:{domain} intitle:"index of" "backup"',
        'site:{domain} intitle:"index of" ".git"',
        'site:{domain} intitle:"index of" ".env"',
        'site:{domain} intitle:"index of" ".ssh"',
        'site:{domain} intitle:"index of" "config"',
        'site:{domain} intitle:"index of" "database"',
        'site:{domain} intitle:"index of" "wp-content/uploads"',
    ],
    "Technology Fingerprinting": [
        "site:{domain} inurl:wp-admin",
        "site:{domain} inurl:wp-content",
        "site:{domain} inurl:wp-includes",
        "site:{domain} inurl:phpmyadmin",
        "site:{domain} intitle:phpMyAdmin",
        "site:{domain} inurl:jira",
        "site:{domain} inurl:confluence",
        "site:{domain} inurl:jenkins",
        "site:{domain} inurl:grafana",
        "site:{domain} inurl:kibana",
        "site:{domain} inurl:gitlab",
        "site:{domain} inurl:sonarqube",
    ],
    "Credentials & Secrets Leakage": [
        'site:{domain} filetype:env "DB_PASSWORD"',
        'site:{domain} filetype:env "AWS_SECRET"',
        'site:{domain} filetype:env "API_KEY"',
        'site:{domain} filetype:env "SMTP_PASSWORD"',
        'site:{domain} filetype:json "access_token"',
        'site:{domain} filetype:yaml "password:"',
        'site:{domain} filetype:properties "jdbc:"',
        'site:{domain} filetype:xml "connectionString"',
        'site:{domain} intext:"BEGIN RSA PRIVATE KEY"',
        'site:{domain} intext:"BEGIN OPENSSH PRIVATE KEY"',
        'site:{domain} intext:"BEGIN PGP PRIVATE KEY"',
        'site:{domain} filetype:ppk "PuTTY-User-Key-File"',
    ],
    "Cloud & DevOps Artifacts": [
        'site:{domain} filetype:tf "aws_"',
        "site:{domain} filetype:tfvars",
        "site:{domain} filetype:dockerfile",
        "site:{domain} filetype:docker-compose",
        "site:{domain} filetype:helm",
        "site:{domain} filetype:kubeconfig",
        'site:{domain} filetype:yaml "apiVersion" "kind"',
        "site:s3.amazonaws.com {domain}",
        "site:blob.core.windows.net {domain}",
        "site:storage.googleapis.com {domain}",
    ],
    "Error & Debug Exposure": [
        'site:{domain} intext:"stack trace"',
        'site:{domain} intext:"exception"',
        'site:{domain} intext:"fatal error"',
        'site:{domain} intext:"debug=true"',
        'site:{domain} intext:"syntax error" filetype:log',
        'intext:"Warning: mysql" site:{domain}',
    ],
    "User-Generated Content / Leaks": [
        "site:pastebin.com {domain}",
        "site:github.com {domain}",
        "site:gitlab.com {domain}",
        "site:bitbucket.org {domain}",
        'site:stackoverflow.com "{domain}"',
        "site:trello.com {domain}",
        "site:notion.site {domain}",
        "site:docs.google.com {domain}",
    ],
    "Authentication & Access Control": [
        "site:{domain} inurl:reset",
        "site:{domain} inurl:forgot",
        "site:{domain} inurl:password",
        'site:{domain} intitle:"two-factor"',
        'site:{domain} intitle:"2fa"',
        "site:{domain} inurl:sso",
        "site:{domain} inurl:oauth",
        "site:{domain} inurl:saml",
    ],
    "Historical / Cached Data": [
        "cache:{domain}",
        "site:web.archive.org {domain}",
    ],
    "High-Value Combined Patterns": [
        "site:{domain} (filetype:env OR filetype:conf)",
        "(inurl:admin OR inurl:login) site:{domain}",
        'intitle:"index of" (backup OR db OR sql) site:{domain}',
        "site:{domain} intext:password filetype:log",
        "site:{domain} (filetype:sql OR filetype:bak OR filetype:old)",
        "site:{domain} inurl:api (intext:key OR intext:token)",
        "site:{domain} ext:php inurl:config",
    ],
}

# ═══════════════════════════════════════════════════════════
#  PERSON DORKS
# ═══════════════════════════════════════════════════════════

PERSON_DORKS = {
    "General Identity Search": [
        '"{person}"',
        '"{person}" resume OR CV',
        '"{person}" bio OR biography OR about',
        '"{person}" portfolio OR "personal site"',
        '"{person}" contact OR email OR phone',
        '"{person}" address OR location OR city',
    ],
    "Social Media Profiles": [
        'site:linkedin.com/in "{person}"',
        'site:linkedin.com/pub "{person}"',
        'site:twitter.com "{person}"',
        'site:x.com "{person}"',
        'site:facebook.com "{person}"',
        'site:instagram.com "{person}"',
        'site:tiktok.com "{person}"',
        'site:reddit.com/user "{person}"',
        'site:reddit.com "{person}"',
        'site:youtube.com "{person}"',
        'site:github.com "{person}"',
        'site:gitlab.com "{person}"',
        'site:bitbucket.org "{person}"',
        'site:keybase.io "{person}"',
        'site:medium.com "{person}"',
        'site:dev.to "{person}"',
        'site:t.me "{person}"',
        'site:mastodon.social "{person}"',
        'site:bsky.app "{person}"',
    ],
    "Professional & Work History": [
        '"{person}" site:linkedin.com "experience"',
        '"{person}" site:linkedin.com "education"',
        '"{person}" site:glassdoor.com',
        '"{person}" site:crunchbase.com',
        '"{person}" site:zoominfo.com',
        '"{person}" site:rocketreach.co',
        '"{person}" "works at" OR "employed at" OR "working at"',
        '"{person}" "CEO" OR "CTO" OR "CFO" OR "CISO"',
        '"{person}" "engineer" OR "developer" OR "analyst"',
        '"{person}" "manager" OR "director" OR "VP"',
    ],
    "Email Discovery": [
        '"{person}" "@gmail.com"',
        '"{person}" "@yahoo.com"',
        '"{person}" "@hotmail.com"',
        '"{person}" "@outlook.com"',
        '"{person}" "@protonmail.com"',
        '"{person}" email OR "e-mail" OR "contact me"',
        '"{person}" intext:@',
        'site:hunter.io "{person}"',
    ],
    "Phone & Address Lookup": [
        '"{person}" phone OR telephone OR cell OR mobile',
        '"{person}" address OR "street" OR "apt"',
        'site:whitepages.com "{person}"',
        'site:truepeoplesearch.com "{person}"',
        'site:fastpeoplesearch.com "{person}"',
        'site:fastbackgroundcheck.com "{person}"',
        'site:spokeo.com "{person}"',
        'site:411.com "{person}"',
        'site:thatsthem.com "{person}"',
        'site:peekyou.com "{person}"',
        'site:webmii.com "{person}"',
        'site:beenverified.com "{person}"',
    ],
    "Public Records & Legal": [
        'site:judyrecords.com "{person}"',
        'site:unicourt.com "{person}"',
        'site:publicrecords.com "{person}"',
        '"{person}" court OR lawsuit OR arrest OR case',
        '"{person}" bankruptcy OR lien OR judgment',
        '"{person}" site:voterrecords.com',
        '"{person}" site:opengovus.com',
        '"{person}" "property records" OR "deed"',
        '"{person}" marriage OR divorce OR "vital records"',
    ],
    "Breach & Credential Exposure": [
        'site:haveibeenpwned.com "{person}"',
        '"{person}" "password" OR "credential" OR "leak"',
        '"{person}" site:pastebin.com',
        '"{person}" site:ghostbin.com',
        '"{person}" site:rentry.co',
        '"{person}" "database" "dump" OR "breach"',
    ],
    "Documents & Files": [
        '"{person}" filetype:pdf',
        '"{person}" filetype:doc OR filetype:docx',
        '"{person}" filetype:xls OR filetype:xlsx',
        '"{person}" filetype:ppt OR filetype:pptx',
        '"{person}" filetype:txt',
        '"{person}" filetype:csv',
    ],
    "Forum & Community Posts": [
        'site:stackoverflow.com "{person}"',
        'site:quora.com "{person}"',
        'site:news.ycombinator.com "{person}"',
        'site:discord.com "{person}"',
        '"{person}" forum OR board OR community',
    ],
    "News & Media Mentions": [
        '"{person}" site:news.google.com',
        '"{person}" inurl:news OR inurl:press OR inurl:article',
        '"{person}" interview OR podcast OR "quoted" OR "said"',
        '"{person}" award OR recognition OR "featured in"',
    ],
    "Images & Geolocation": [
        '"{person}" inurl:flickr.com',
        '"{person}" inurl:imgur.com',
        '"{person}" inurl:500px.com',
        '"{person}" "tagged photo" OR "photo of"',
        '"{person}" geolocation OR "checked in" OR GPS',
    ],
    "Academic & Research": [
        'site:scholar.google.com "{person}"',
        'site:researchgate.net "{person}"',
        'site:academia.edu "{person}"',
        'site:orcid.org "{person}"',
        '"{person}" thesis OR dissertation OR "published in"',
        '"{person}" "PhD" OR "professor" OR "researcher"',
    ],
    "Code & Technical Footprint": [
        'site:github.com "{person}" email',
        '"{person}" "ssh-rsa" OR "ssh-ed25519"',
        '"{person}" "gpg" OR "pgp" OR "public key"',
        'site:npmjs.com "{person}"',
        'site:pypi.org "{person}"',
        'site:hub.docker.com "{person}"',
        '"{person}" "API key" OR "token" OR "secret"',
    ],
    "Dating & Personal Interests": [
        '"{person}" site:meetup.com',
        '"{person}" wishlist OR "amazon.com/hz/wishlist"',
        '"{person}" "strava.com" OR "garmin.com"',
        '"{person}" "goodreads.com"',
        '"{person}" "letterboxd.com"',
        '"{person}" "last.fm" OR "spotify"',
    ],
}

# ═══════════════════════════════════════════════════════════
#  EMAIL DORKS
# ═══════════════════════════════════════════════════════════

EMAIL_DORKS = {
    "Direct Email Search": [
        '"{email}"',
        'intext:"{email}"',
        '"{email}" password OR credential OR login',
        '"{email}" site:pastebin.com',
        '"{email}" site:ghostbin.com',
        '"{email}" site:rentry.co',
    ],
    "Breach & Leak Exposure": [
        '"{email}" leak OR breach OR dump OR database',
        '"{email}" filetype:txt',
        '"{email}" filetype:csv',
        '"{email}" filetype:sql',
        '"{email}" filetype:log',
    ],
    "Social & Professional Accounts": [
        'site:linkedin.com "{email}"',
        'site:twitter.com "{email}"',
        'site:facebook.com "{email}"',
        'site:github.com "{email}"',
        'site:gitlab.com "{email}"',
        'site:stackoverflow.com "{email}"',
        'site:keybase.io "{email}"',
        'site:gravatar.com "{email}"',
    ],
    "Documents Containing Email": [
        '"{email}" filetype:pdf',
        '"{email}" filetype:doc OR filetype:docx',
        '"{email}" filetype:xls OR filetype:xlsx',
        '"{email}" filetype:ppt',
    ],
    "Code Repositories": [
        'site:github.com "{email}"',
        '"{email}" filetype:env',
        '"{email}" filetype:yml OR filetype:yaml',
        '"{email}" filetype:json',
        '"{email}" filetype:conf OR filetype:cfg',
        '"{email}" "smtp" OR "mail" OR "sendgrid" OR "mailgun"',
    ],
    "Forum & Community Registrations": [
        '"{email}" site:reddit.com',
        '"{email}" site:quora.com',
        '"{email}" site:medium.com',
        '"{email}" forum OR register OR signup OR subscribe',
    ],
}

# ═══════════════════════════════════════════════════════════
#  MODULE: DOMAIN RECON
# ═══════════════════════════════════════════════════════════

def module_domain(domain: str, out_dir: str) -> None:
    section(f"DOMAIN RECON — {domain}")

    # ── DNS basics ───────────────────────────────────────
    info("Resolving DNS...")
    try:
        ips = socket.getaddrinfo(domain, None, socket.AF_UNSPEC, socket.SOCK_STREAM)
        seen = set()
        for family, _, _, _, addr in ips:
            ip = addr[0]
            if ip not in seen:
                seen.add(ip)
                fam = "IPv6" if family == socket.AF_INET6 else "IPv4"
                print(f"    {fam}: {ip}")
        with open(os.path.join(out_dir, "dns.txt"), "w") as f:
            for ip in seen:
                f.write(ip + "\n")
    except socket.gaierror:
        warn(f"Could not resolve {domain}")

    # ── Whois ────────────────────────────────────────────
    if has_tool("whois"):
        info("Running whois...")
        run_cmd(["whois", domain], outfile=os.path.join(out_dir, "whois.txt"), silent=True)
    else:
        warn("whois not installed — skipping")

    # ── crt.sh — free certificate transparency API ──────
    info("Querying crt.sh for subdomains (free API)...")
    crt_data = api_get(f"https://crt.sh/?q=%25.{urllib.parse.quote(domain, safe='')}&output=json")
    crt_subs: set[str] = set()
    if isinstance(crt_data, list):
        for entry in crt_data:
            name = entry.get("name_value", "")
            for sub in name.split("\n"):
                sub = sub.strip().lower()
                if sub and sub.endswith(domain) and "*" not in sub:
                    crt_subs.add(sub)
        info(f"crt.sh found {len(crt_subs)} subdomains")
    else:
        warn("crt.sh returned no data")

    # ── HackerTarget free API ────────────────────────────
    info("Querying HackerTarget (free API)...")
    ht_data = api_get(f"https://api.hackertarget.com/hostsearch/?q={urllib.parse.quote(domain, safe='')}")
    ht_subs: set[str] = set()
    if isinstance(ht_data, str) and "error" not in ht_data.lower():
        for line in ht_data.strip().split("\n"):
            host = line.split(",")[0].strip().lower()
            if host and host.endswith(domain):
                ht_subs.add(host)
        info(f"HackerTarget found {len(ht_subs)} subdomains")

    # ── AlienVault OTX free API ──────────────────────────
    info("Querying AlienVault OTX (free API)...")
    otx_data = api_get(f"https://otx.alienvault.com/api/v1/indicators/domain/{urllib.parse.quote(domain, safe='')}/passive_dns")
    otx_subs: set[str] = set()
    if isinstance(otx_data, dict):
        for record in otx_data.get("passive_dns", []):
            hostname = record.get("hostname", "").strip().lower()
            if hostname and hostname.endswith(domain):
                otx_subs.add(hostname)
        info(f"AlienVault OTX found {len(otx_subs)} subdomains")

    # ── CLI tools: assetfinder, subfinder, amass ─────────
    cli_subs: set[str] = set()
    for tool, cmd_fn in [
        ("assetfinder", lambda: ["assetfinder", "--subs-only", domain]),
        ("subfinder",   lambda: ["subfinder", "-d", domain, "-silent"]),
    ]:
        if has_tool(tool):
            info(f"Running {tool}...")
            out = run_cmd(cmd_fn(), silent=True)
            for line in out.split("\n"):
                h = line.strip().lower()
                if h and h.endswith(domain):
                    cli_subs.add(h)

    # Merge all subdomains
    all_subs = sorted(crt_subs | ht_subs | otx_subs | cli_subs | {domain})
    sub_file = os.path.join(out_dir, "subdomains.txt")
    with open(sub_file, "w") as f:
        f.write("\n".join(all_subs) + "\n")
    info(f"Total unique subdomains: {len(all_subs)}")

    # ── Probe alive ──────────────────────────────────────
    alive_file = os.path.join(out_dir, "alive.txt")
    if has_tool("httprobe"):
        info("Probing alive hosts with httprobe...")
        result = subprocess.run(
            ["httprobe", "-prefer-https"],
            input="\n".join(all_subs), capture_output=True, text=True, timeout=120
        )
        alive = sorted(set(
            line.strip().lower().replace("https://", "").replace("http://", "").rstrip("/")
            for line in result.stdout.strip().split("\n") if line.strip()
        ))
        with open(alive_file, "w") as f:
            f.write("\n".join(alive) + "\n")
        info(f"Alive hosts: {len(alive)}")
    else:
        warn("httprobe not installed — writing subdomains as alive list")
        with open(alive_file, "w") as f:
            f.write("\n".join(all_subs) + "\n")
        alive = all_subs

    # ── Subdomain takeover ───────────────────────────────
    if has_tool("subjack"):
        info("Checking for subdomain takeover with subjack...")
        fingerprints = ""
        for path in [
            os.path.expanduser("~/go/src/github.com/haccer/subjack/fingerprints.json"),
            "/usr/share/subjack/fingerprints.json",
        ]:
            if os.path.isfile(path):
                fingerprints = path
                break
        if not fingerprints:
            subjack_bin = shutil.which("subjack")
            if subjack_bin:
                candidate = os.path.join(os.path.dirname(subjack_bin), "fingerprints.json")
                if os.path.isfile(candidate):
                    fingerprints = candidate
        if fingerprints:
            run_cmd([
                "subjack", "-w", sub_file, "-t", "100", "-timeout", "30",
                "-ssl", "-c", fingerprints, "-v", "3",
                "-o", os.path.join(out_dir, "takeovers.txt")
            ], silent=True)
        else:
            warn("subjack fingerprints.json not found — skipping")

    # ── Port scan ────────────────────────────────────────
    if has_tool("nmap"):
        info("Scanning ports with nmap...")
        run_cmd([
            "nmap", "-iL", alive_file, "-T4", "-Pn",
            "-oA", os.path.join(out_dir, "nmap_scan")
        ], silent=True)

    # ── Wayback Machine ──────────────────────────────────
    if has_tool("waybackurls"):
        info("Scraping Wayback Machine...")
        result = subprocess.run(
            ["waybackurls"],
            input="\n".join(all_subs), capture_output=True, text=True, timeout=120
        )
        wb_urls = sorted(set(line.strip() for line in result.stdout.split("\n") if line.strip()))
        wb_file = os.path.join(out_dir, "wayback_urls.txt")
        with open(wb_file, "w") as f:
            f.write("\n".join(wb_urls) + "\n")
        info(f"Wayback URLs: {len(wb_urls)}")

        # Params
        params = sorted(set(
            u.split("=")[0] for u in wb_urls if "?" in u and "=" in u
        ))
        if params:
            with open(os.path.join(out_dir, "wayback_params.txt"), "w") as f:
                f.write("\n".join(p + "=" for p in params) + "\n")

        # Extensions
        for ext in ("js", "jsp", "json", "php", "aspx"):
            matches = [u for u in wb_urls if u.lower().endswith(f".{ext}")]
            if matches:
                with open(os.path.join(out_dir, f"wayback_{ext}.txt"), "w") as f:
                    f.write("\n".join(matches) + "\n")

    # ── Wayback Machine free API ─────────────────────────
    info("Querying web.archive.org CDX API...")
    cdx_data = api_get(
        f"https://web.archive.org/cdx/search/cdx?url=*.{urllib.parse.quote(domain, safe='')}&output=json&fl=original&collapse=urlkey&limit=500"
    )
    if isinstance(cdx_data, list) and len(cdx_data) > 1:
        urls = sorted(set(row[0] for row in cdx_data[1:]))
        cdx_file = os.path.join(out_dir, "wayback_cdx.txt")
        with open(cdx_file, "w") as f:
            f.write("\n".join(urls) + "\n")
        info(f"CDX API returned {len(urls)} unique URLs")

    # ── Google Dorks ─────────────────────────────────────
    info("Generating domain Google dorks...")
    print_dorks(DOMAIN_DORKS, "domain", domain, out_dir, "dorks_domain.txt")


# ═══════════════════════════════════════════════════════════
#  MODULE: PEOPLE OSINT
# ═══════════════════════════════════════════════════════════

def module_people(person: str, out_dir: str) -> None:
    section(f"PEOPLE OSINT — {person}")

    # ── Username enumeration with sherlock ────────────────
    if has_tool("sherlock"):
        info(f"Running sherlock on '{person}'...")
        sherlock_out = os.path.join(out_dir, "sherlock.txt")
        run_cmd(["sherlock", person, "--print-found", "--output", sherlock_out], silent=True)

    # ── Maigret ──────────────────────────────────────────
    if has_tool("maigret"):
        info(f"Running maigret on '{person}'...")
        run_cmd([
            "maigret", person, "--top-sites", "500",
            "--pdf", os.path.join(out_dir, "maigret_report.pdf")
        ], silent=True)

    # ── Social Analyzer ──────────────────────────────────
    if has_tool("social-analyzer"):
        info(f"Running social-analyzer on '{person}'...")
        run_cmd([
            "social-analyzer", "--username", person,
            "--metadata", "--extract", "--trim"
        ], silent=True)

    # ── GitHub user search (free API, no key) ────────────
    info(f"Searching GitHub users API for '{person}'...")
    gh_data = api_get(f"https://api.github.com/search/users?q={urllib.parse.quote(person, safe='')}&per_page=10")
    if isinstance(gh_data, dict) and gh_data.get("items"):
        results = []
        for u in gh_data["items"][:10]:
            results.append(f"  {u['login']} — {u['html_url']}")
        if results:
            info(f"GitHub matches ({len(results)}):")
            for r in results:
                print(f"    {CYAN}{r}{RESET}")
            with open(os.path.join(out_dir, "github_users.txt"), "w") as f:
                f.write("\n".join(results) + "\n")

    # ── Reddit user check (free, no key) ─────────────────
    username = person.replace(" ", "")
    info(f"Checking Reddit for u/{username}...")
    reddit_data = api_get(f"https://www.reddit.com/user/{urllib.parse.quote(username, safe='')}/about.json")
    if isinstance(reddit_data, dict) and reddit_data.get("data", {}).get("name"):
        rd = reddit_data["data"]
        print(f"    {CYAN}Found: u/{rd['name']} (karma: {rd.get('total_karma', '?')}){RESET}")
        with open(os.path.join(out_dir, "reddit.txt"), "w") as f:
            f.write(f"u/{rd['name']}\nKarma: {rd.get('total_karma','?')}\n")

    # ── Google Dorks ─────────────────────────────────────
    info("Generating people Google dorks...")
    print_dorks(PERSON_DORKS, "person", person, out_dir, "dorks_people.txt")


# ═══════════════════════════════════════════════════════════
#  MODULE: PHONE OSINT
# ═══════════════════════════════════════════════════════════

PHONE_DORKS = {
    "Direct Phone Search": [
        '"{phone}"',
        'intext:"{phone}"',
        '"{phone}" site:whitepages.com',
        '"{phone}" site:truepeoplesearch.com',
        '"{phone}" site:fastpeoplesearch.com',
        '"{phone}" site:spokeo.com',
        '"{phone}" site:411.com',
        '"{phone}" site:thatsthem.com',
        '"{phone}" site:beenverified.com',
        '"{phone}" site:calleridtest.com',
    ],
    "Phone Context Search": [
        '"{phone}" name OR owner OR registered',
        '"{phone}" address OR location OR city',
        '"{phone}" spam OR scam OR fraud OR robocall',
        '"{phone}" business OR company OR LLC',
        '"{phone}" linkedin OR facebook OR instagram',
    ],
    "Leak & Breach Search": [
        '"{phone}" site:pastebin.com',
        '"{phone}" filetype:txt',
        '"{phone}" filetype:csv',
        '"{phone}" filetype:sql',
        '"{phone}" leak OR breach OR dump',
    ],
}


def module_phone(phone: str, out_dir: str) -> None:
    section(f"PHONE OSINT — {phone}")

    # ── phoneinfoga ──────────────────────────────────────
    if has_tool("phoneinfoga"):
        info(f"Running phoneinfoga scan on {phone}...")
        result = run_cmd(["phoneinfoga", "scan", "-n", phone], silent=True)
        if result:
            outfile = os.path.join(out_dir, "phoneinfoga.txt")
            with open(outfile, "w") as f:
                f.write(result + "\n")
            info(f"phoneinfoga output saved to {outfile}")
            print(result)
    else:
        warn("phoneinfoga not installed — skipping scan")
        warn("Install: https://github.com/sundowndev/phoneinfoga")

    # ── NumVerify free API (100 req/month free) ──────────
    info("Querying NumVerify API (free tier)...")
    clean_num = phone.replace("+", "").replace("-", "").replace(" ", "").replace("(", "").replace(")", "")
    nv_data = api_get(f"http://apilayer.net/api/validate?access_key=&number={clean_num}")
    if isinstance(nv_data, dict) and nv_data.get("valid") is not None:
        if nv_data.get("valid"):
            print(f"    {CYAN}Valid:        {nv_data.get('valid')}{RESET}")
            print(f"    {CYAN}Country:      {nv_data.get('country_name', '?')}{RESET}")
            print(f"    {CYAN}Location:     {nv_data.get('location', '?')}{RESET}")
            print(f"    {CYAN}Carrier:      {nv_data.get('carrier', '?')}{RESET}")
            print(f"    {CYAN}Line type:    {nv_data.get('line_type', '?')}{RESET}")
            with open(os.path.join(out_dir, "numverify.txt"), "w") as f:
                json.dump(nv_data, f, indent=2)
        else:
            warn("NumVerify: number appears invalid")
    else:
        warn("NumVerify API unavailable (set API key for full results)")

    # ── Google Dorks ─────────────────────────────────────
    info("Generating phone Google dorks...")
    # Also search stripped/formatted variants
    variants = {phone}
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) >= 10:
        variants.add(digits)
        variants.add(f"+{digits}")
        if len(digits) == 11:
            local = digits[1:]
            variants.add(f"({local[:3]}) {local[3:6]}-{local[6:]}")
            variants.add(f"{local[:3]}-{local[3:6]}-{local[6:]}")

    print_dorks(PHONE_DORKS, "phone", phone, out_dir, "dorks_phone.txt")

    if len(variants) > 1:
        info("Additional format variants to search manually:")
        for v in sorted(variants):
            if v != phone:
                print(f"    {CYAN}{v}{RESET}")


# ═══════════════════════════════════════════════════════════
#  MODULE: EMAIL OSINT
# ═══════════════════════════════════════════════════════════

def module_email(email: str, out_dir: str) -> None:
    section(f"EMAIL OSINT — {email}")

    # ── Have I Been Pwned (free, no key for breach list) ─
    info("Querying Have I Been Pwned (breach names)...")
    hibp_data = api_get(
        f"https://haveibeenpwned.com/api/v3/breachedaccount/{urllib.parse.quote(email, safe='')}?truncateResponse=true",
        headers={"User-Agent": "OSINTraitor/1.0", "hibp-api-key": ""}
    )
    if isinstance(hibp_data, list):
        breaches = [b.get("Name", "?") for b in hibp_data]
        info(f"Found in {len(breaches)} breaches:")
        for b in breaches:
            print(f"    {RED}• {b}{RESET}")
        with open(os.path.join(out_dir, "hibp_breaches.txt"), "w") as f:
            f.write("\n".join(breaches) + "\n")
    else:
        warn("HIBP: no breaches found or API key required for lookups")
        info("Check manually: https://haveibeenpwned.com/")

    # ── EmailRep.io (free, no key needed for basic) ──────
    info("Querying EmailRep.io (free API)...")
    emailrep = api_get(
        f"https://emailrep.io/{urllib.parse.quote(email, safe='')}",
        headers={"User-Agent": "OSINTraitor/1.0", "Accept": "application/json"}
    )
    if isinstance(emailrep, dict) and emailrep.get("email"):
        rep = emailrep
        print(f"    {CYAN}Reputation:   {rep.get('reputation', '?')}{RESET}")
        print(f"    {CYAN}Suspicious:   {rep.get('suspicious', '?')}{RESET}")
        print(f"    {CYAN}Malicious:    {rep.get('details', {}).get('malicious_activity', '?')}{RESET}")
        print(f"    {CYAN}Spam:         {rep.get('details', {}).get('spam', '?')}{RESET}")
        print(f"    {CYAN}Breached:     {rep.get('details', {}).get('data_breach', '?')}{RESET}")
        print(f"    {CYAN}Profiles:     {', '.join(rep.get('details', {}).get('profiles', [])) or 'none'}{RESET}")
        print(f"    {CYAN}Last seen:    {rep.get('details', {}).get('last_seen', '?')}{RESET}")
        with open(os.path.join(out_dir, "emailrep.json"), "w") as f:
            json.dump(rep, f, indent=2)
    else:
        warn("EmailRep.io returned no data")

    # ── Disify (free disposable email check) ─────────────
    info("Checking if email is disposable (Disify API)...")
    disify = api_get(f"https://disify.com/api/email/{urllib.parse.quote(email, safe='')}")
    if isinstance(disify, dict):
        is_disp = disify.get("disposable", False)
        is_valid_fmt = disify.get("format", True)
        print(f"    {CYAN}Format valid: {is_valid_fmt}{RESET}")
        print(f"    {CYAN}Disposable:   {is_disp}{RESET}")
        if disify.get("dns"):
            print(f"    {CYAN}DNS valid:    {disify['dns']}{RESET}")

    # ── h8mail (CLI breach searcher) ─────────────────────
    if has_tool("h8mail"):
        info(f"Running h8mail on {email}...")
        run_cmd(["h8mail", "-t", email], silent=False)
    else:
        warn("h8mail not installed — skipping CLI breach search")

    # ── holehe (account existence checker) ───────────────
    if has_tool("holehe"):
        info(f"Running holehe (email→accounts)...")
        holehe_out = os.path.join(out_dir, "holehe.txt")
        result = run_cmd(["holehe", email], silent=True)
        if result:
            with open(holehe_out, "w") as f:
                f.write(result + "\n")
            # Count positives
            positives = [l for l in result.split("\n") if "[+]" in l]
            info(f"holehe found {len(positives)} accounts — saved to holehe.txt")
            for p in positives:
                print(f"    {CYAN}{p.strip()}{RESET}")

    # ── MX record check ─────────────────────────────────
    email_domain = email.split("@")[1] if "@" in email else ""
    if email_domain:
        info(f"Resolving MX records for {email_domain}...")
        if has_tool("dig"):
            mx_out = run_cmd(["dig", "+short", "MX", email_domain], silent=True)
            if mx_out:
                print(f"    {CYAN}{mx_out.replace(chr(10), chr(10) + '    ')}{RESET}")
                with open(os.path.join(out_dir, "mx_records.txt"), "w") as f:
                    f.write(mx_out + "\n")
        elif has_tool("nslookup"):
            mx_out = run_cmd(["nslookup", "-type=mx", email_domain], silent=True)
            if mx_out:
                with open(os.path.join(out_dir, "mx_records.txt"), "w") as f:
                    f.write(mx_out + "\n")

    # ── Google Dorks ─────────────────────────────────────
    info("Generating email Google dorks...")
    print_dorks(EMAIL_DORKS, "email", email, out_dir, "dorks_email.txt")


# ═══════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════

def main() -> None:
    parser = argparse.ArgumentParser(
        description="OSINTraitor — All-in-one OSINT reconnaissance tool.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 OSINTraitor.py --domain example.com
  python3 OSINTraitor.py --people "John Doe"
  python3 OSINTraitor.py --phone +14155551234
  python3 OSINTraitor.py --email target@example.com
  python3 OSINTraitor.py -o ./custom_folder --domain example.com --people "John Doe"
        """,
    )
    parser.add_argument("--domain", "-d", help="Target domain for full recon")
    parser.add_argument("--people", "-p", help="Target person name or username")
    parser.add_argument("--phone", "-t", help="Target phone number with country code (e.g. +14155551234)")
    parser.add_argument("--email", "-e", help="Target email address")
    parser.add_argument("--output", "-o", default="traitors", help="Output directory (default: traitors)")

    args = parser.parse_args()

    if not any([args.domain, args.people, args.phone, args.email]):
        parser.print_help()
        sys.exit(1)

    banner()

    out_dir = args.output
    os.makedirs(out_dir, exist_ok=True)
    info(f"Output directory: {os.path.abspath(out_dir)}\n")

    modules_ran = 0

    if args.domain:
        module_domain(args.domain, out_dir)
        modules_ran += 1

    if args.people:
        module_people(args.people, out_dir)
        modules_ran += 1

    if args.phone:
        module_phone(args.phone, out_dir)
        modules_ran += 1

    if args.email:
        module_email(args.email, out_dir)
        modules_ran += 1

    # ── Final summary ────────────────────────────────────
    section("SUMMARY")
    info(f"{modules_ran} module(s) completed")
    info(f"All output saved to: {os.path.abspath(out_dir)}")
    files = sorted(os.listdir(out_dir))
    if files:
        print(f"\n  {BOLD}Files generated:{RESET}")
        for f in files:
            size = os.path.getsize(os.path.join(out_dir, f))
            print(f"    {DIM}•{RESET} {f} {DIM}({size:,} bytes){RESET}")
    print()


if __name__ == "__main__":
    main()
