#!/bin/bash
# Simple deployment script for BucStop

# Set production environment
export ASPNETCORE_ENVIRONMENT=Production

# Public IP
PUBLIC_IP="54.145.129.101"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker is not running. Please start Docker and try again."
  exit 1
fi

# Check for docker-compose
if ! command -v docker-compose > /dev/null 2>&1; then
  echo "ERROR: docker-compose not found. Please install it and try again."
  exit 1
fi

echo "Starting deployment process..."

# Find docker-compose file
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/Bucstop WebApp/scripts/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "ERROR: docker-compose.yml not found at $COMPOSE_FILE"
  exit 1
fi

# Create symlink to docker-compose file
echo "Creating symlink to docker-compose.yml..."
ln -sf "$COMPOSE_FILE" ./docker-compose.yml

# Stop any running containers
echo "Stopping any running containers..."
docker-compose down

# Build images if they don't exist
echo "Checking for Docker images..."
IMAGES=("bucstop-webapp" "bucstop-gateway" "bucstop-snake" "bucstop-pong" "bucstop-tetris")
BUILD_NEEDED=false

for IMG in "${IMAGES[@]}"; do
  if [[ "$(docker images -q $IMG 2> /dev/null)" == "" ]]; then
    echo "Image $IMG not found, build needed."
    BUILD_NEEDED=true
    break
  fi
done

if $BUILD_NEEDED; then
  echo "Building Docker images..."
  
  # Build each image
  cd "$PROJECT_ROOT/Bucstop WebApp/BucStop" && docker build -t bucstop-webapp . && cd - || exit 1
  cd "$PROJECT_ROOT/Team-3-BucStop_APIGateway/APIGateway" && docker build -t bucstop-gateway . && cd - || exit 1
  cd "$PROJECT_ROOT/Team-3-BucStop_Snake/Snake" && docker build -t bucstop-snake . && cd - || exit 1
  cd "$PROJECT_ROOT/Team-3-BucStop_Pong/Pong" && docker build -t bucstop-pong . && cd - || exit 1
  cd "$PROJECT_ROOT/Team-3-BucStop_Tetris/Tetris" && docker build -t bucstop-tetris . && cd - || exit 1
fi

# Start services
echo "Starting services..."
docker-compose up -d

# Check if services are running
echo "Verifying services..."
sleep 5
if docker-compose ps | grep -q "Exit"; then
  echo "ERROR: Some services failed to start. Check logs with 'docker-compose logs'"
  exit 1
else
  echo "All services started successfully!"
  echo "Application is now accessible at http://$PUBLIC_IP:8080"
fi
