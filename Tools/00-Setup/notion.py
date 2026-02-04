#!/home/scorpio/venvs/notion/bin/python

import sys
import time
import hashlib
from lxml import etree
from notion_client import Client

# =========================
# CONFIG
# =========================

NOTION_TOKEN = "############################################"
PARENT_PAGE_ID = "##########################################"  
RATE_LIMIT_DELAY = 0.35  # seconds

# =========================
# UTILS
# =========================

def sha256(text):
    return hashlib.sha256(text.encode()).hexdigest()

def clean(text):
    return text.strip() if text else ""

# =========================
# XML PARSER
# =========================

def parse_nmap_xml(xml_file):
    tree = etree.parse(xml_file)
    root = tree.getroot()

    host = root.find("host")
    addr = host.find("address").get("addr")

    ports_data = []

    for port in host.findall(".//port"):
        state = port.find("state").get("state")
        if state != "open":
            continue

        proto = port.get("protocol")
        portid = port.get("portid")

        service = port.find("service")
        svc_name = service.get("name", "")
        svc_version = " ".join(filter(None, [
            service.get("product"),
            service.get("version"),
            service.get("extrainfo")
        ]))

        scripts = []
        for script in port.findall("script"):
            scripts.append(f"[{script.get('id')}]\n{script.get('output')}")

        ports_data.append({
            "host": addr,
            "port": portid,
            "protocol": proto,
            "service": svc_name,
            "version": svc_version,
            "scripts": "\n\n".join(scripts)
        })

    return ports_data

# =========================
# NOTION INGEST
# =========================

def create_port_page(notion, port):
    title = f"{port['protocol'].upper()}/{port['port']} – {port['service']}"
    fingerprint = sha256(f"{port['host']}-{port['protocol']}-{port['port']}")

    blocks = []

    def heading(text):
        return {
            "object": "block",
            "type": "heading_2",
            "heading_2": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }

    def paragraph(text):
        return {
            "object": "block",
            "type": "paragraph",
            "paragraph": {
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }

    def code(text):
        return {
            "object": "block",
            "type": "code",
            "code": {
                "language": "bash",
                "rich_text": [{"type": "text", "text": {"content": text}}]
            }
        }

    blocks.extend([
        heading("Service & Version"),
        paragraph(f"{port['service']} --- {port['version']}"),
        heading("State"),
        paragraph("open"),
        heading("Script Output"),
        code(port["scripts"] or "EMPTY!"),
        heading("Enumeration Notes"),
        paragraph("")
    ])

    notion.pages.create(
        parent={"page_id": PARENT_PAGE_ID},
        properties={
            "title": {
                "title": [
                    {"type": "text", "text": {"content": title}}
                ]
            }
        },
        children=blocks
    )

# =========================
# MAIN
# =========================

def main():
    if len(sys.argv) != 2:
        print("Usage: notion.py [XML].xml")
        sys.exit(1)

    notion = Client(auth=NOTION_TOKEN)
    ports = parse_nmap_xml(sys.argv[1])

    for port in ports:
        create_port_page(notion, port)
        time.sleep(RATE_LIMIT_DELAY)

if __name__ == "__main__":
    main()
