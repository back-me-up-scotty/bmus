#!/bin/bash

# =========================================================================
# BmuS - Dependency Installer & Security Setup
# Installs packages and sets correct permissions
# This installation script is only required if 
# you are installing BmuS natively on a Linux or Pi system. 
# Do not use for Docker installation.
# =========================================================================

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}   BmuS - Setup & Installation   ${NC}"
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

# 3. Define packages (incl. gnupg for encryption)
PACKAGES=(
    "rsync"
    "curl"
    "cifs-utils"
    "nfs-common"
    "bc"
    "mariadb-client"
    "gnupg"
    "gocryptfs"
    "msmtp"
    "msmtp-mta"
    "bsd-mailx"
)

# 4. Install packages
echo -e "\n${YELLOW}[INFO] Installing dependencies...${NC}"
for pkg in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q -w "$pkg"; then
        echo -e "[OK] $pkg is already installed."
    else
        echo -e "${YELLOW}[INSTALL] Installing $pkg...${NC}"
        apt-get install -y "$pkg"
    fi
done

# 5. Set permissions (Security Update)
echo -e "\n${YELLOW}[INFO] Setting file permissions...${NC}"

# a) Make scripts executable (for all .sh files in folder)
chmod +x *.sh 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SECURE] All .sh scripts are now executable.${NC}"
else
    echo -e "${RED}[WARN] No .sh files found.${NC}"
fi

# b) Secure configuration files (chmod 600 - Read/Write for owner only)
# We check if files exist first to avoid errors
if [ -f "bmus.conf" ]; then
    chmod 600 bmus.conf
    chown $SUDO_USER:$SUDO_USER bmus.conf 2>/dev/null # Return ownership to normal user if necessary
    echo -e "${GREEN}[SECURE] bmus.conf set to 600 (Owner read/write only).${NC}"
fi

if [ -f ".bmus_credentials" ]; then
    chmod 600 .bmus_credentials
    chown $SUDO_USER:$SUDO_USER .bmus_credentials 2>/dev/null
    echo -e "${GREEN}[SECURE] .bmus_credentials set to 600.${NC}"
fi

# 6. Conclusion
echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}   Installation & Security Check complete!${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Start a test run now with: ${YELLOW}./bmus.sh${NC}"
echo ""