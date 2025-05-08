#!/usr/bin/env python3

import os
import argparse
from lxml import etree as ET
from libnmap.parser import NmapParser

CHERRYTREE_PATH = "/home/scorpio/PenetrationTests/Penetration-Tests.ctd"

parser = argparse.ArgumentParser(description="Convert Nmap XML to CherryTree node and merge into master .ctd")
parser.add_argument("xmlfile", help="Nmap XML file to parse")
parser.add_argument("-ah", "--allhosts", action="store_true", help="Include hosts even with no open ports")
parser.add_argument("-ap", "--allports", action="store_true", help="Include closed/filtered ports")
parser.add_argument("-a", "--all", action="store_true", help="Same as --allhosts and --allports")
args = parser.parse_args()

# Absolute input path
nmap_xml = os.path.abspath(args.xmlfile)
if not os.path.isfile(nmap_xml):
    print(f"[!] Input file not found: {nmap_xml}")
    exit(1)

# Parse Nmap XML
try:
    report = NmapParser.parse_fromfile(nmap_xml)
except Exception as e:
    print(f"[!] Failed to parse Nmap XML: {e}")
    exit(1)

# Parse destination CTD file
try:
    dest_tree = ET.parse(CHERRYTREE_PATH)
    root = dest_tree.getroot()
except Exception as e:
    print(f"[!] Failed to open CherryTree file: {e}")
    exit(1)

# Find max UID
max_uid = 0
for elem in root.iter():
    if "unique_id" in elem.attrib:
        try:
            max_uid = max(max_uid, int(elem.attrib["unique_id"]))
        except ValueError:
            pass
uid = max_uid + 1

# Create new parent node
basename = os.path.splitext(os.path.basename(nmap_xml))[0]
parent_node = ET.SubElement(root, "node", name=basename, unique_id=str(uid),
                            prog_lang="custom-colors", is_bold="False",
                            readonly="False", tags="", custom_icon_id="0", foreground="")
uid += 1

# Loop through hosts/services
for host in report.hosts:
    if host.is_up() and (host.services or args.allhosts or args.all):
        for svc in host.services:
            if svc.open() or args.allports or args.all:
                node_name = f"{svc.port}/{svc.protocol} open {svc.service}"
                service_node = ET.SubElement(parent_node, "node", name=node_name, unique_id=str(uid),
                                             prog_lang="custom-colors", is_bold="False", readonly="False",
                                             tags="", foreground="")
                uid += 1

                # Basic service line
                ET.SubElement(service_node, "rich_text").text = f"{svc.port}/{svc.protocol} open {svc.service}"

                # Banner
                if svc.banner:
                    ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_Banner:"
                    ET.SubElement(service_node, "rich_text").text = svc.banner

                # Scripts
                if svc.scripts_results:
                    for s in svc.scripts_results:
                        ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = f"|_{s['id']}:"
                        ET.SubElement(service_node, "rich_text").text = s['output']

# Write back to CTD
try:
    with open(CHERRYTREE_PATH, 'wb') as f:
        dest_tree.write(f, encoding="UTF-8", pretty_print=True)
    print(f"[+] Successfully inserted into CherryTree: {CHERRYTREE_PATH}")
except Exception as e:
    print(f"[!] Failed to write updated CTD: {e}")
    exit(1)

