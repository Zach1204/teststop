#!/bin/bash

# Go to the project root directory
cd ..

# Stop and remove all containers
echo "Stopping and removing containers..."
docker-compose down
docker rm -f $(docker ps -a -q) 2>/dev/null || true

# Create environment override settings for HTTP only
cat > webapp-environment-override.json << 'EOL'
{
  "Gateway": "http://api-gateway:80",
  "Microservices": {
    "Snake": "http://snake:80",
    "Pong": "http://pong:80",
    "Tetris": "http://tetris:80"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:80"
      }
    }
  }
}
EOL

cat > gateway-environment-override.json << 'EOL'
{
  "MicroserviceUrls": {
    "Snake": "http://snake:80",
    "Pong": "http://pong:80",
    "Tetris": "http://tetris:80"
  },
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:80"
      }
    }
  }
}
EOL

cat > service-environment-override.json << 'EOL'
{
  "Kestrel": {
    "Endpoints": {
      "Http": {
        "Url": "http://0.0.0.0:80"
      }
    }
  }
}
EOL

# Check actual paths
echo "Verifying paths..."
ls -la

# Create updated docker-compose.yml with absolute paths
cat > docker-compose.yml << EOL
version: '3.4'
services:
  bucstop:
    build:
      context: $(pwd)/Bucstop\ WebApp/BucStop
      dockerfile: Dockerfile
    container_name: bucstop
    ports:
      - "8080:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - DOTNET_USE_POLLING_FILE_WATCHER=1
      - ASPNETCORE_HTTPS_PORT=
    volumes:
      - $(pwd)/webapp-environment-override.json:/app/appsettings.Production.json
    depends_on:
      - api-gateway
    restart: on-failure:3

  api-gateway:
    build:
      context: $(pwd)/Team-3-BucStop_APIGateway/APIGateway
      dockerfile: Dockerfile
    container_name: api-gateway
    ports:
      - "8081:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
    volumes:
      - $(pwd)/gateway-environment-override.json:/app/appsettings.Production.json
    depends_on:
      - snake
      - pong
      - tetris
    restart: on-failure:3

  snake:
    build:
      context: $(pwd)/Team-3-BucStop_Snake/Snake
      dockerfile: Dockerfile
    container_name: game-snake
    ports:
      - "8082:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
    volumes:
      - $(pwd)/service-environment-override.json:/app/appsettings.Production.json
    restart: on-failure:3

  pong:
    build:
      context: $(pwd)/Team-3-BucStop_Pong/Pong
      dockerfile: Dockerfile
    container_name: game-pong
    ports:
      - "8083:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
    volumes:
      - $(pwd)/service-environment-override.json:/app/appsettings.Production.json
    restart: on-failure:3

  tetris:
    build:
      context: $(pwd)/Team-3-BucStop_Tetris/Tetris
      dockerfile: Dockerfile
    container_name: game-tetris
    ports:
      - "8084:80"
    networks:
      - bucstop-network
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://+:80
      - ASPNETCORE_HTTPS_PORT=
    volumes:
      - $(pwd)/service-environment-override.json:/app/appsettings.Production.json
    restart: on-failure:3

networks:
  bucstop-network:
    driver: bridge
EOL

# Build and start containers
echo "Building and starting containers..."
docker-compose build --no-cache
docker-compose up -d

echo "Checking container status..."
sleep 5
docker ps
