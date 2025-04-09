#!/bin/bash

# Change to the parent directory
cd ..
echo "Changed to $(pwd)"

# Stop any existing containers
docker-compose down 2>/dev/null
docker rm -f $(docker ps -a -q) 2>/dev/null || true

# Create a docker-compose file that will work
cat > docker-compose.working.yml << 'EOL'
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
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - Gateway=http://api-gateway:80
      - Microservices__Snake=http://snake:80
      - Microservices__Pong=http://pong:80
      - Microservices__Tetris=http://tetris:80
    restart: unless-stopped

  api-gateway:
    image: bucstop-gateway:latest
    container_name: api-gateway
    ports:
      - "8081:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - MicroserviceUrls__Snake=http://snake:80
      - MicroserviceUrls__Pong=http://pong:80
      - MicroserviceUrls__Tetris=http://tetris:80
    depends_on:
      - snake
      - pong
      - tetris
    restart: unless-stopped

  snake:
    image: bucstop-snake:latest
    container_name: snake
    ports:
      - "8082:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
    restart: unless-stopped

  pong:
    image: bucstop-pong:latest
    container_name: pong
    ports:
      - "8083:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
    restart: unless-stopped

  tetris:
    image: bucstop-tetris:latest
    container_name: tetris
    ports:
      - "8084:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
    restart: unless-stopped

networks:
  bucstop-network:
    driver: bridge
EOL

# Start the containers
echo "Starting containers with working configuration..."
docker-compose -f docker-compose.working.yml up -d

# Check the status
echo "Checking container status..."
sleep 5
docker ps

echo "Waiting for services to initialize..."
sleep 10
echo "Container logs:"
docker logs --tail 10 bucstop
docker logs --tail 10 api-gateway
