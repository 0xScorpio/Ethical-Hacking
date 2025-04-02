import sys
import requests
import re
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
        response = requests.get(file_url, timeout=10)
        if response.status_code == 200:
            print(f"Found {file} at: {file_url}")
            search_sensitive_words(response.text, file_url)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 pgcheck.py <target-url>")
        sys.exit(1)
    
    target_url = sys.argv[1]
    print(f"Scanning: {target_url}\n")
    
    # Fetch main page source
    page_source = fetch_page_source(target_url)
    if not page_source:
        return
    
    # Extract external links
    external_links = extract_external_links(page_source, target_url)
    print("Found external links:")
    for link in external_links:
        print(link)
    
    # Search for sensitive words in the main page
    search_sensitive_words(page_source, target_url)
    
    # Fetch and scan external resources
    for link in external_links:
        ext_content = fetch_page_source(link)
        if ext_content:
            search_sensitive_words(ext_content, link)
    
    # Check for common files like robots.txt and sitemap.xml
    check_common_files(target_url)
    
if __name__ == "__main__":
    main()
