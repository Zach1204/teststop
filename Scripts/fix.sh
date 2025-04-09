#!/bin/bash

# Change to the parent directory
cd ..
echo "Changed to $(pwd)"

# Create an updated docker-compose file
cat > docker-compose.fixed.yml << 'EOL'
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
      - Microservices__Snake=http://game-snake:80
      - Microservices__Pong=http://game-pong:80
      - Microservices__Tetris=http://game-tetris:80
    restart: on-failure:3

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
      - MicroserviceUrls__Snake=http://game-snake:80
      - MicroserviceUrls__Pong=http://game-pong:80
      - MicroserviceUrls__Tetris=http://game-tetris:80
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
      - ASPNETCORE_ENVIRONMENT=Production
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
      - ASPNETCORE_ENVIRONMENT=Production
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
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
    restart: on-failure:3

networks:
  bucstop-network:
    driver: bridge
EOL

# Stop and restart with the new configuration
echo "Restarting with updated configuration..."
docker-compose down
docker-compose -f docker-compose.fixed.yml up -d

echo "Checking container status..."
sleep 5
docker ps

