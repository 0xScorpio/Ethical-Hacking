# =============== DESCRIPTION ===============
#
# This script runs a simple and quick page source check/scan.
# Specifically, it runs through the page source for the following:
#
# - Embedded external links
#
# - robots.txt and sitemap.xml default directories
#
# - Output (with -o flag) of the page source
#
# ~ 0xScorpio

import sys
import requests
import re
import argparse
from urllib.parse import urljoin
from bs4 import BeautifulSoup

def fetch_page_source(url):
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.text
    except requests.RequestException as e:
        print(f"Error fetching {url}: {e}")
        return None

def extract_external_links(page_source, base_url):
    soup = BeautifulSoup(page_source, 'html.parser')
    external_links = set()
    
    for tag in soup.find_all(['link', 'script', 'a']):
        if tag.name == 'link' and tag.get('href'):
            external_links.add(urljoin(base_url, tag['href']))
        elif tag.name == 'script' and tag.get('src'):
            external_links.add(urljoin(base_url, tag['src']))
        elif tag.name == 'a' and tag.get('href'):
            external_links.add(urljoin(base_url, tag['href']))
    
    return external_links

def search_sensitive_words(content, url):
    sensitive_patterns = [r'password', r'pass', r'pwd', r'cred']
    for pattern in sensitive_patterns:
        if re.search(pattern, content, re.IGNORECASE):
            print(f"Potential sensitive info found in {url} with keyword: {pattern}")

def check_common_files(base_url):
    common_files = ['robots.txt', 'sitemap.xml']
    for file in common_files:
        file_url = urljoin(base_url, file)
        try:
            response = requests.get(file_url, timeout=10)
            if response.status_code == 200:
                print(f"Found {file} at: {file_url}")
                search_sensitive_words(response.text, file_url)
        except requests.RequestException:
            pass

def main():
    parser = argparse.ArgumentParser(description="Scan a web page for external links and common files.")
    parser.add_argument("url", help="Target URL to scan (e.g. http://192.1.1.1)")
    parser.add_argument("-o", "--output", help="Save main page source to file named <output>.html")

    args = parser.parse_args()
    target_url = args.url

    print(f"Scanning: {target_url}\n")

    # Fetch main page source
    page_source = fetch_page_source(target_url)
    if not page_source:
        return

    # Save page source if output filename is given
    if args.output:
        output_file = f"{args.output}.html"
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(page_source)
        print(f"\nSaved page source to: {output_file}\n")

    # Extract and print external links
    external_links = extract_external_links(page_source, target_url)
    print("Found external links:")
    for link in external_links:
        print(link)

    # Search for sensitive words in the main page
    search_sensitive_words(page_source, target_url)

    # Scan external resources for sensitive content
    for link in external_links:
        ext_content = fetch_page_source(link)
        if ext_content:
            search_sensitive_words(ext_content, link)

    # Check for common files
    check_common_files(target_url)

if __name__ == "__main__":
    main()
