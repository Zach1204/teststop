#!/bin/bash

# ─────────────────────────────────────────────────────────────
#  AWS EC2 Setup Script for BucStop Application
#  This script installs all required dependencies and prepares
#  the environment for deployment on a fresh AWS EC2 instance
# ─────────────────────────────────────────────────────────────

# Exit on error
set -e

# Text colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] ${GREEN}$1${NC}"
}

# Error function
error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    error "Please run this script as root or with sudo"
fi

# Update package list
log "Updating package list..."
apt-get update || error "Failed to update package list"

# Install prerequisites
log "Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common || error "Failed to install prerequisites"

# ─────────────────────────────────────────────────────────────
#  Install Docker
# ─────────────────────────────────────────────────────────────
log "Installing Docker..."

# Remove old versions if they exist
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || error "Failed to add Docker GPG key"

# Set up stable repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null || error "Failed to add Docker repository"

# Update apt package index
apt-get update || error "Failed to update package list after adding Docker repository"

# Install Docker CE
apt-get install -y docker-ce docker-ce-cli containerd.io || error "Failed to install Docker"

# Start Docker service
systemctl start docker || error "Failed to start Docker service"
systemctl enable docker || error "Failed to enable Docker service"

# Verify Docker installation
docker --version || error "Docker installation verification failed"
log "Docker installed successfully"

# ─────────────────────────────────────────────────────────────
#  Install Docker Compose
# ─────────────────────────────────────────────────────────────
log "Installing Docker Compose..."

# Download Docker Compose binary
DOCKER_COMPOSE_VERSION="v2.20.3"
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose || error "Failed to download Docker Compose"

# Apply executable permissions to the binary
chmod +x /usr/local/bin/docker-compose || error "Failed to apply executable permissions to Docker Compose"

# Create symbolic link
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || true

# Verify Docker Compose installation
docker-compose --version || error "Docker Compose installation verification failed"
log "Docker Compose installed successfully"

# ─────────────────────────────────────────────────────────────
#  Install .NET SDK
# ─────────────────────────────────────────────────────────────
log "Installing .NET SDK..."

# Add Microsoft package repository
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb || error "Failed to download Microsoft package repository"
dpkg -i packages-microsoft-prod.deb || error "Failed to install Microsoft package repository"
rm packages-microsoft-prod.deb

# Install .NET SDK
apt-get update || error "Failed to update package list after adding Microsoft repository"
apt-get install -y dotnet-sdk-6.0 || error "Failed to install .NET SDK"

# Verify .NET installation
dotnet --version || error ".NET SDK installation verification failed"
log ".NET SDK installed successfully"

# ─────────────────────────────────────────────────────────────
#  Install Git
# ─────────────────────────────────────────────────────────────
log "Installing Git..."
apt-get install -y git || error "Failed to install Git"

# Verify Git installation
git --version || error "Git installation verification failed"
log "Git installed successfully"

# ─────────────────────────────────────────────────────────────
#  Set up project
# ─────────────────────────────────────────────────────────────
log "Setting up project environment..."

# Create project directory if it doesn't exist
PROJECT_DIR="/opt/bucstop"
mkdir -p $PROJECT_DIR || error "Failed to create project directory"

# Set proper permissions for the ec2-user or ubuntu user
DEFAULT_USER=$(who am i | awk '{print $1}')
if [ "$DEFAULT_USER" = "root" ]; then
    # Try to determine the default user for the system
    if getent passwd ubuntu > /dev/null; then
        DEFAULT_USER="ubuntu"
    elif getent passwd ec2-user > /dev/null; then
        DEFAULT_USER="ec2-user"
    else
        DEFAULT_USER=$(find /home -type d -name "*" -maxdepth 1 | head -n1 | cut -d'/' -f3)
    fi
fi

if [ -n "$DEFAULT_USER" ] && [ "$DEFAULT_USER" != "root" ]; then
    chown -R $DEFAULT_USER:$DEFAULT_USER $PROJECT_DIR || error "Failed to set permissions for project directory"
    log "Set ownership of $PROJECT_DIR to $DEFAULT_USER"
fi

# Add the current user to the docker group to run docker without sudo
if [ -n "$DEFAULT_USER" ] && [ "$DEFAULT_USER" != "root" ]; then
    usermod -aG docker $DEFAULT_USER || error "Failed to add $DEFAULT_USER to docker group"
    log "Added $DEFAULT_USER to docker group"
fi

# ─────────────────────────────────────────────────────────────
#  Configure firewall (if UFW is installed)
# ─────────────────────────────────────────────────────────────
if command -v ufw > /dev/null; then
    log "Configuring firewall..."
    
    # Allow SSH
    ufw allow 22/tcp || error "Failed to allow SSH port"
    
    # Allow application ports
    ufw allow 80/tcp || error "Failed to allow HTTP port"
    ufw allow 443/tcp || error "Failed to allow HTTPS port"
    ufw allow 8080/tcp || error "Failed to allow WebApp port"
    ufw allow 8081/tcp || error "Failed to allow Gateway port"
    ufw allow 8082/tcp || error "Failed to allow Snake port"
    ufw allow 8083/tcp || error "Failed to allow Pong port"
    ufw allow 8084/tcp || error "Failed to allow Tetris port"
    
    # Enable firewall if it's not already enabled
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable || error "Failed to enable firewall"
    fi
    
    ufw status || error "Failed to get firewall status"
    log "Firewall configured successfully"
fi

# ─────────────────────────────────────────────────────────────
#  Installation completed
# ─────────────────────────────────────────────────────────────
log "Installation completed successfully!"
log "To deploy the application:"
echo -e "${GREEN}1. Clone your repository:${NC}"
echo -e "   git clone https://github.com/yourusername/BucStop-Goofin-dev.git"
echo -e "${GREEN}2. Navigate to the Scripts directory:${NC}"
echo -e "   cd BucStop-Goofin-dev/Scripts"
echo -e "${GREEN}3. Run the deployment script:${NC}"
echo -e "   bash deploy.sh"
echo -e "${YELLOW}Note: You may need to log out and log back in for the Docker group permissions to take effect.${NC}" 