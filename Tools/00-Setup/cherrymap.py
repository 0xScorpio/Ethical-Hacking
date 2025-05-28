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

parser.add_argument("file",
                    help="Nmap XML file to parse (relative path to current directory)")
args = parser.parse_args()

# =============== STATIC DESTINATION FILE PATH ===============
dest_file = "/home/scorpio/Cybersecurity/Tools/00-Setup/Penetration-Tests.ctd"
filename = os.path.abspath(args.file)
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

# =============== PORTS TO FORMAT WITH SCRIPT OUTPUT ===============
special_ports = [21, 22, 25, 53, 79, 88, 135, 139, 143, 161, 389, 445, 2049, 3306, 3389, 80, 443]

# =============== ADD HOST/SERVICE INFORMATION INTO NEWLY CREATED NODE ===============
for _host in rep.hosts:
    if _host.is_up() and len(_host.services) > 0:
        for _service in _host.services:
            if _service.open():
                port_number = _service.port
                service_name = _service.service.lower()

                # Create subnode for each open port
                service_node = ET.SubElement(node, "node", foreground="", is_bold="False", name=f"{port_number}/{_service.protocol} open {_service.service}", prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
                uid += 1

                # Add port/service info line with newline after
                ET.SubElement(service_node, "rich_text").text = f"{port_number}/{_service.protocol} open {_service.service}\n"

                # Add banner if available
                if _service.banner:
                    ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "\n|_Banner:"
                    ET.SubElement(service_node, "rich_text").text = f"{_service.banner}\n"

                # Add script results for special ports
                if _service.scripts_results and port_number in special_ports:
                    ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "\n|_Scripts:"
                    for script in _service.scripts_results:
                        ET.SubElement(service_node, "rich_text", weight="heavy").text = f"|_{script['id']}:\n"
                        ET.SubElement(service_node, "rich_text").text = f"{script['output']}\n"

                # Additional parsing for HTTP services on port 80
                if _service.protocol == "tcp" and port_number == 80:
                    for http_tag in _service.scripts_results:
                        if 'http-title' in http_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_http-title:"
                            ET.SubElement(service_node, "rich_text").text = f"{http_tag['output']}\n"

                # SSL details for port 443
                if _service.protocol == "tcp" and port_number == 443:
                    for ssl_tag in _service.scripts_results:
                        if 'ssl-cert' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_ssl-cert:"
                            ET.SubElement(service_node, "rich_text").text = f"{ssl_tag['output']}\n"
                        if 'ssl-date' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_ssl-date:"
                            ET.SubElement(service_node, "rich_text").text = f"{ssl_tag['output']}\n"
                        if 'tls-alpn' in ssl_tag['id']:
                            ET.SubElement(service_node, "rich_text", style="italic", weight="heavy").text = "|_tls-alpn:"
                            ET.SubElement(service_node, "rich_text").text = f"{ssl_tag['output']}\n"

                # Add enum subnode named enum-<port>
                enum_node = ET.SubElement(service_node, "node", foreground="", is_bold="False", name=f"enum-{port_number}", prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
                uid += 1

                # If HTTP is identified in the service name, create landing-page > directories
                if "http" in service_name:
                    landing_node = ET.SubElement(service_node, "node", foreground="", is_bold="False", name="landing-page", prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
                    uid += 1
                    directories_node = ET.SubElement(landing_node, "node", foreground="", is_bold="False", name="directories", prog_lang="custom-colors", readonly="False", tags="", unique_id=str(uid))
                    uid += 1

# =============== WRITE OUTPUT INTO .CTD FILE ===============
try:
    with open(dest_file, 'wb') as f:
        dest_tree.write(f, encoding="UTF-8", pretty_print=True)
except Exception as e:
    print(f"Error writing to {dest_file}: {e}")
