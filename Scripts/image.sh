#!/bin/bash

# Change to the parent directory (teststop root)
cd ..
echo "Changed to $(pwd)"

# Stop and remove all containers
echo "Stopping and removing containers..."
docker-compose down
docker rm -f $(docker ps -a -q) 2>/dev/null || true

# Create a working docker-compose file
cat > docker-compose.simple.yml << 'EOL'
version: '3.4'
services:
  bucstop:
    image: bucstop-webapp:latest
    container_name: bucstop
    ports:
      - "8080:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    restart: on-failure:3

  api-gateway:
    image: bucstop-gateway:latest
    container_name: api-gateway
    ports:
      - "8081:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    depends_on:
      - snake
      - pong
      - tetris
    restart: on-failure:3

  snake:
    image: bucstop-snake:latest
    container_name: game-snake
    ports:
      - "8082:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    restart: on-failure:3

  pong:
    image: bucstop-pong:latest
    container_name: game-pong
    ports:
      - "8083:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    restart: on-failure:3

  tetris:
    image: bucstop-tetris:latest
    container_name: game-tetris
    ports:
      - "8084:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
    restart: on-failure:3

networks:
  bucstop-network:
    driver: bridge
EOL

# Try to run with existing images (without building)
echo "Starting containers with existing images..."
docker-compose -f docker-compose.simple.yml up -d

echo "Checking container status..."
sleep 5
docker ps -a
