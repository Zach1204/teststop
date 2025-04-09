#!/bin/bash

# This script updates the IP address in all relevant configuration files to the new EC2 instance IP

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  $0 <new-ip-address> [old-ip-address]"
    echo -e "${YELLOW}Example:${NC}"
    echo -e "  $0 54.145.129.101"
    echo -e "  $0 54.145.129.101 3.232.16.65"
    exit 1
}

# Check if IP address is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: New IP address not provided${NC}"
    show_usage
fi

NEW_IP="$1"
OLD_IP="${2:-3.232.16.65}"  # Default old IP if not provided

echo -e "${BLUE}=== BucStop IP Address Update Script ===${NC}"
echo -e "${GREEN}Replacing IP address ${YELLOW}$OLD_IP${GREEN} with ${YELLOW}$NEW_IP${GREEN} in configuration files...${NC}"

# Navigate to project root (assuming script is in the Scripts directory)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT" || { echo -e "${RED}Error: Could not navigate to project root${NC}"; exit 1; }

# Update appsettings.Production.json files
find . -name "appsettings.Production.json" -type f | while read -r file; do
    echo -e "${GREEN}Updating file: ${YELLOW}$file${NC}"
    # Use sed to replace all occurrences of the old IP with the new IP
    sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
done

# Update deploy.sh script
DEPLOY_SCRIPT="./Scripts/deploy.sh"
if [ -f "$DEPLOY_SCRIPT" ]; then
    echo -e "${GREEN}Updating file: ${YELLOW}$DEPLOY_SCRIPT${NC}"
    sed -i "s/PUBLIC_IP=\"$OLD_IP\"/PUBLIC_IP=\"$NEW_IP\"/g" "$DEPLOY_SCRIPT"
fi

# Update docker-compose.yml if needed (for external references)
DOCKER_COMPOSE="./Bucstop WebApp/scripts/docker-compose.yml"
if [ -f "$DOCKER_COMPOSE" ]; then
    echo -e "${GREEN}Checking file: ${YELLOW}$DOCKER_COMPOSE${NC}"
    if grep -q "$OLD_IP" "$DOCKER_COMPOSE"; then
        echo -e "${GREEN}Updating file: ${YELLOW}$DOCKER_COMPOSE${NC}"
        sed -i "s/$OLD_IP/$NEW_IP/g" "$DOCKER_COMPOSE"
    else
        echo -e "${GREEN}No changes needed in: ${YELLOW}$DOCKER_COMPOSE${NC}"
    fi
fi

echo -e "${BLUE}=== IP Address Update Complete ===${NC}"
echo -e "${GREEN}Successfully updated IP address in all configuration files.${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Commit and push these changes to your repository"
echo -e "2. Deploy the application using the updated deploy.sh script"
echo -e "   cd $PROJECT_ROOT/Scripts && bash deploy.sh"
echo -e "${BLUE}=== Done ===${NC}" 