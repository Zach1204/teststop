#!/bin/bash

# Stop and remove all existing containers
echo "Stopping all existing containers..."
docker-compose down -v

# Clean up any dangling resources
echo "Cleaning up Docker resources..."
docker system prune -f

# Pull latest images if needed
echo "Pulling latest images..."
docker-compose pull

# Build images with no cache to ensure clean build
echo "Building fresh containers..."
docker-compose build --no-cache

# Start the containers in detached mode
echo "Starting containers..."
docker-compose up -d

# Check if containers are running
echo "Checking container status..."
docker-compose ps

echo "Deployment complete. Watching logs..."
docker-compose logs -f
