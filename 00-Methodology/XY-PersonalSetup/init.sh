#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Catch failures in pipes

echo "Starting system initialization..."

# Ensure full update and upgrade
echo "[+] Updating and upgrading the system..."
sudo apt-get update -y && sudo apt-get dist-upgrade -y

# Reformat directories
read -p "Are you sure you want to delete existing directories? (y/N) " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "[+] Removing old directories..."
    rm -rf ~/Documents ~/Music ~/Pictures ~/Public ~/Templates ~/Videos
fi

echo "[+] Creating new directories..."
mkdir -p ~/Cybersecurity/{Exams,Github,HackTheBox,OSINT,TryHackMe}
mkdir -p ~/Cybersecurity/HackTheBox/{Connect,Rooms}
mkdir -p ~/Cybersecurity/TryHackMe/{Connect,Rooms}
mkdir -p ~/Cybersecurity/Exams/OSCP/{ADLabs,ChallengeLabs,Connect,Training,ProvingGrounds}
mkdir -p ~/Media/{bg,docs,images}

# Download official Kali background
echo "[+] Downloading Kali background..."
wget -q -P ~/Media/bg/ https://raw.githubusercontent.com/dorianpro/kaliwallpapers/master/kali-linux-wallpaper-v7.png

# Install Sublime Text
echo "[+] Installing Sublime Text..."
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt-get update -y && sudo apt-get install -y sublime-text
sudo ln -sf /opt/sublime_text/sublime_text /usr/local/bin/sublime

# Install essential tools
echo "[+] Installing essential tools..."
sudo apt-get install -y ghidra xdotool fcrackzip chisel gnumeric libreoffice jd-gui subjack assetfinder ssh-audit jq rlwrap \
    sshuttle linux-exploit-suggester poppler-utils dirsearch libimage-exiftool-perl steghide mitm6 httprobe \
    golang seclists curl dnsrecon enum4linux feroxbuster gobuster impacket-scripts nbtscan nikto nmap onesixtyone \
    oscanner redis-tools smbclient smbmap snmp sslscan sipvicious tnscmd10g whatweb wkhtmltopdf python3 python3-pip

# Install AutoRecon
echo "[+] Install AutoRecon manually please..."
#sudo apt-get install -y python3 python3-pip pipx
#pipx ensurepath
#source ~/.zshrc
#pipx install git+https://github.com/Tib3rius/AutoRecon.git

# Install additional tools via Pipx
#echo "[+] Install Pipx tools manually..."
#pipx install git-dumper hash-id linuxprivchecker visidata openpyxl xlsx2csv xlrd bloodyad

# Install Docker
echo "[+] Installing Docker..."
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-compose
sudo docker run hello-world || echo "[!] Docker test failed!"

# Install Obsidian
echo "[+] Installing Obsidian..."
OBSIDIAN_VERSION="1.7.7"
wget -q -O ~/Downloads/obsidian.deb "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb"
sudo dpkg -i ~/Downloads/obsidian.deb && rm ~/Downloads/obsidian.deb

# Update database for 'locate'
echo "[+] Updating locate database..."
sudo updatedb

# Install Flameshot
echo "[+] Installing Flameshot..."
sudo apt-get install -y flameshot

# Extract rockyou.txt
echo "[+] Extracting rockyou.txt..."
sudo gzip -d /usr/share/wordlists/rockyou.txt.gz || echo "[!] rockyou.txt already extracted."

# Install GitLeaks
echo "[+] Installing GitLeaks..."
git clone --depth=1 https://github.com/gitleaks/gitleaks.git ~/gitleaks
cd ~/gitleaks
make build || echo "[!] GitLeaks build failed!"
cd ~

# Install WordPress scanner
echo "[+] Installing WPScan..."
sudo docker pull wpscanteam/wpscan

# Install VM tools (optional)
# echo "[+] Installing VM tools..."
# sudo apt-get install -y --reinstall open-vm-tools-desktop fuse

echo "[✓] Initialization complete!"
