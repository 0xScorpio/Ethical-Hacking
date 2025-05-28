#!/usr/bin/env python3

# =============== DESCRIPTION ===============
#
# This tool takes in an XML formatted file and parses the information into a specific .CTD formatted output.
# Specifically, I created this tool to take in NMAP-generated XML output (-oX) and organize it accordingly
# with its own subnodes, directly into a static, configurable path for my CherryTree notes.
#
# ~ 0xScorpio

# =============== IMPORT LIBRARIES ===============
from lxml import etree as ET
from libnmap.parser import NmapParser
import os
import argparse

# =============== PARSER CONFIGURATIONS ===============
parser = argparse.ArgumentParser()

parser.add_argument("-m", "--merge", action="store", required=True,
                    help="Merge the content into an existing CherryTree file (must be closed).")
parser.add_argument("file",
                    help="Nmap XML file to parse (relative path to current directory)")
args = parser.parse_args()

# =============== ABSOLUTE FILE PATH ===============
filename = os.path.abspath(args.file)
dest_file = args.merge
uid = 1

# =============== EXTRACT BASENAME OF XML FILE (without extension) ===============
base_name = os.path.splitext(os.path.basename(filename))[0]

# =============== PARSING XML FILE ===============
try:
    rep = NmapParser.parse_fromfile(filename)
except Exception as e:
    print(f"Error while parsing file {filename}: {e}")
    exit(1)

# =============== OPEN EXISTING .CTD FILE FOR MERGING ===============
try:
    dest_tree = ET.parse(dest_file)
    dest_tree_root = dest_tree.getroot()
except Exception as e:
    print(f"Error while parsing destination file {dest_file}: {e}")
    exit(1)

# =============== ENSURE PROPER ASSIGNMENT ===============
biggest_UID = 0
for elem in dest_tree_root.iter():
    if "unique_id" in elem.attrib:
        try:
            biggest_UID = max(biggest_UID, int(elem.attrib["unique_id"]))
        except ValueError:
            pass

uid = biggest_UID + 1

# =============== NODE CREATION BASED ON BASENAME ===============
node = ET.SubElement(dest_tree_root, "node", custom_icon_id="0", foreground="", is_bold="False", name=base_name, prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
uid += 1

# =============== ADD HOST/SERVICE INFORMATION INTO NEWLY CREATED NODE ===============
for _host in rep.hosts:
    if _host.is_up() and len(_host.services) > 0 or args.allhosts or args.all:
        for _service in _host.services:
            if _service.open() or args.allports or args.all:
                port_name = f"port{_service.port}"

                # Create subnode for each open port
                service_node = ET.SubElement(node, "node", foreground="", is_bold="False", name=f"{_service.port}/{_service.protocol} open {_service.service}", prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
                uid += 1

                # Adding service details
                ET.SubElement(service_node, "rich_text").text = f"{_service.port}/{_service.protocol} open {_service.service}"

                # Add banner if available
                if _service.banner:
                    ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_Banner:"
                    ET.SubElement(service_node, "rich_text").text = f"{_service.banner}\n"

                # Add scripts results if available
                if _service.scripts_results:
                    ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_Scripts:"
                    for script in _service.scripts_results:
                        ET.SubElement(service_node, "rich_text", weight="heavy").text = f"|_{script['id']}:\n"
                        ET.SubElement(service_node, "rich_text").text = f"|_{script['output']}\n"

                # Add HTTP title for port 80
                if _service.protocol == "tcp" and _service.port == 80:
                    for http_tag in _service.scripts_results:
                        if 'http-title' in http_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_http-title:"
                            ET.SubElement(service_node, "rich_text").text = f"|_{http_tag['output']}\n"

                # Add SSL cert and SSL date for port 443
                if _service.protocol == "tcp" and _service.port == 443:
                    for ssl_tag in _service.scripts_results:
                        if 'ssl-cert' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_ssl-cert:"
                            ET.SubElement(service_node, "rich_text").text = f"|_{ssl_tag['output']}\n"
                        if 'ssl-date' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_ssl-date:"
                            ET.SubElement(service_node, "rich_text").text = f"|_{ssl_tag['output']}\n"
                        if 'tls-alpn' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_tls-alpn:"
                            ET.SubElement(service_node, "rich_text").text = f"|_{ssl_tag['output']}\n"

# =============== WRITE OUTPUT INTO .CTD FILE ===============
try:
    with open(dest_file, 'wb') as f:
        dest_tree.write(f, encoding="UTF-8", pretty_print=True)
except Exception as e:
    print(f"Error writing to {dest_file}: {e}")
