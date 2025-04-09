#!/bin/bash
#ACTUALLY WORKS

# Change to the parent directory
cd ..
echo "Changed to $(pwd)"

# Stop any existing containers
docker-compose down 2>/dev/null
docker rm -f $(docker ps -a -q) 2>/dev/null || true

# Create a corrected docker-compose
cat > docker-compose.corrected.yml << 'EOL'
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
      - ASPNETCORE_HTTPS_PORT=
      - Kestrel__EndpointDefaults__Protocols=Http1
      - Gateway=http://api-gateway:80
      - Microservices__Snake=http://snake:80
      - Microservices__Pong=http://pong:80
      - Microservices__Tetris=http://tetris:80
      # Explicitly override any localhost references
      - ApiHeartbeat__BaseUrl=http://api-gateway:80
      - ApiHeartbeat__Host=api-gateway
      - ApiHeartbeat__Port=80
      - ApiHeartbeat__Protocol=http
    restart: unless-stopped

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
      - ASPNETCORE_HTTPS_PORT=
      - Kestrel__EndpointDefaults__Protocols=Http1
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
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
      - Kestrel__EndpointDefaults__Protocols=Http1
    restart: unless-stopped

  pong:
    image: bucstop-pong:latest
    container_name: pong
    ports:
      - "8083:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
      - Kestrel__EndpointDefaults__Protocols=Http1
    restart: unless-stopped

  tetris:
    image: bucstop-tetris:latest
    container_name: tetris
    ports:
      - "8084:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
      - Kestrel__EndpointDefaults__Protocols=Http1
    restart: unless-stopped

networks:
  bucstop-network:
    driver: bridge
EOL

# Start the containers
echo "Starting containers with corrected configuration..."
docker-compose -f docker-compose.corrected.yml up -d

# Check the status
echo "Checking container status..."
sleep 5
docker ps

echo "Container logs:"
sleep 10
docker logs bucstop 1>&1 | tail -n 20
