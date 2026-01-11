#!/bin/bash

# =========================================================================
# BmuS - Full Dependency Installer & Security Setup V.3.0
# Installs CORE system tools and BmuS specific requirements.
# Tested on: Debian, Ubuntu, Raspberry Pi OS (Raspbian)
# =========================================================================

# Output Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}   BmuS - Back Me Up Scotty - Full Installation   ${NC}"
echo -e "${GREEN}======================================================${NC}"

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run this script with sudo.${NC}"
  echo "Command: sudo ./install_dependencies.sh"
  exit 1
fi

# 2. Update package lists
echo -e "\n${YELLOW}[INFO] Updating package lists...${NC}"
apt-get update -q || { echo -e "${RED}[ERROR] Update failed.${NC}"; exit 1; }

# 3. Define Package List
# This list combines standard system tools and BmuS specific requirements.
PACKAGES=(
    # --- System Core & Utilities ---
    "bash"              # Shell environment
    "coreutils"         # cp, mv, ls, sort, date, etc.
    "grep"              # Text filtering
    "sed"               # Stream editor (Crucial for Dashboard/Logs)
    "gawk"              # GNU awk (Text processing)
    "findutils"         # find command
    "tar"               # Archiving
    "zip"               # Archiving
    "unzip"             # Extracting
    "ca-certificates"   # SSL Certificates (for curl/wget)
    
    # --- Network & Connectivity ---
    "curl"              # For updates & checks
    "iputils-ping"      # For network checks (ping)
    "cifs-utils"        # Mount Windows Shares (SMB/CIFS)
    "nfs-common"        # Mount NFS Shares
    "net-tools"         # Network tools (ifconfig, netstat) - Critical for Docker
    "iproute2"          # Modern network tools (ip) - Critical for Docker
    
    # --- Database ---
    "mysql-client"      # Standard MySQL Client
    "mariadb-client"    # Alternative (often required on newer Raspbian versions)
    
    # --- Mail & Notifications ---
    "msmtp"             # SMTP Client
    "msmtp-mta"         # Mail Transfer Agent
    "bsd-mailx"         # 'mail' command support
    
    # --- BmuS Logic & Security ---
    "rsync"             # The heart of the backup
    "bc"                # Floating Point Math (Critical for Dashboard Speed Calc)
    "sysstat"           # System performance tools (mpstat for CPU usage)
    "gnupg"             # For DB Dump Encryption
    "gocryptfs"         # For File System Encryption
    "rclone"            # For Cloud Uploads (Dropbox, Drive, etc.)
)

# 4. Installation Loop
echo -e "\n${YELLOW}[INFO] Installing packages...${NC}"

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q -w "$pkg"; then
        echo -e "[OK] $pkg is already installed."
    else
        echo -e "${YELLOW}[INSTALL] Installing $pkg...${NC}"
        # We attempt install, but don't abort on single errors 
        # (e.g., if mysql-client is virtual/missing but mariadb-client works)
        apt-get install -y "$pkg"
    fi
done

# 5. Security & Permissions
echo -e "\n${YELLOW}[INFO] Setting file permissions...${NC}"

# a) Make all shell scripts executable
chmod +x *.sh 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SECURE] All .sh scripts are now executable.${NC}"
else
    echo -e "${RED}[WARN] No .sh files found.${NC}"
fi

# b) Secure configuration files (chmod 600)
# We check if files exist, set them to read/write for owner only, 
# and ensure they belong to the sudo user (not root).

if [ -f "bmus.conf" ]; then
    chmod 600 bmus.conf
    chown $SUDO_USER:$SUDO_USER bmus.conf 2>/dev/null 
    echo -e "${GREEN}[SECURE] bmus.conf secured (chmod 600).${NC}"
fi

if [ -f ".bmus_credentials" ]; then
    chmod 600 .bmus_credentials
    chown $SUDO_USER:$SUDO_USER .bmus_credentials 2>/dev/null
    echo -e "${GREEN}[SECURE] .bmus_credentials secured (chmod 600).${NC}"
fi

if [ -f "bmus_gocryptfs" ]; then
    chmod 600 bmus_gocryptfs
    chown $SUDO_USER:$SUDO_USER bmus_gocryptfs 2>/dev/null
    echo -e "${GREEN}[SECURE] bmus_gocryptfs secured (chmod 600).${NC}"
fi

# 6. Completion
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   Installation complete!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "You can now start BmuS with: ${YELLOW}./bmus.sh${NC}"
echo ""
