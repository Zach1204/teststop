#!/bin/bash
export ASPNETCORE_ENVIRONMENT=Production
# ------------------------------------------------------
#  Config / Constants
# ------------------------------------------------------

# Prod IP - Update this with your EC2 instance public IP
PUBLIC_IP="54.145.129.101"

# Required CLI tools
REQUIRED_CMDS=("git" "docker" "docker-compose" "dotnet")

# List of services for uncontainerized mode
SERVICES=(
    "Team-3-BucStop_APIGateway/APIGateway|API Gateway|8081"
    "Team-3-BucStop_Snake/Snake|Snake|8082"
    "Team-3-BucStop_Pong/Pong|Pong|8083"
    "Team-3-BucStop_Tetris/Tetris|Tetris|8084"
    "Bucstop WebApp/BucStop|BucStop WebApp|8080"
)

# ------------------------------------------------------
#  Check for required tools
# ------------------------------------------------------
check_requirements() {
    echo "Checking for required tools..."
    missing_tools=0
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "ERROR: Missing required command: $cmd"
            missing_tools=1
        else
            echo "Found required command: $cmd"
        fi
    done
    
    if [ $missing_tools -eq 1 ]; then
        echo "ERROR: Please install missing tools and try again."
        exit 1
    fi
    
    # Check for Docker service
    if ! docker info >/dev/null 2>&1; then
        echo "ERROR: Docker service is not running. Please start Docker and try again."
        exit 1
    fi
    
    echo "All required tools are available."
}

# Run the requirements check
check_requirements

# ------------------------------------------------------
#  Select Deployment Mode (Menu)
# ------------------------------------------------------
echo ""
echo "Select Deployment Mode:"
echo "   [1] Containerized (Docker)"
echo "   [2] Uncontainerized (Local dotnet run)"
echo -n "Enter choice (1 or 2): "
read -r choice

case $choice in
    1) DEPLOY_MODE="containerized";;
    2) DEPLOY_MODE="uncontainerized";;
    *) echo "ERROR: Invalid choice! Please enter 1 or 2."; exit 1;;
esac

# Array to store background process PIDs
declare -a SERVICE_PIDS

# ------------------------------------------------------
#  Cleanup function
# Stops Docker containers or local processes based on deployment mode.
# ------------------------------------------------------
cleanup() {
    echo ""
    echo "Cleaning up processes..."

    if [[ "$DEPLOY_MODE" == "containerized" ]]; then
        if [ -n "$BUILD_PID" ]; then
            kill "$BUILD_PID" 2>/dev/null
        fi

        echo "Stopping Docker containers..."
        docker-compose down || echo "Warning: Issue stopping containers, continuing cleanup..."

        echo "Pruning unused Docker resources..."
        docker system prune -af --volumes || echo "Warning: Issue pruning Docker resources, continuing cleanup..."

    else
        echo "Stopping local dotnet services..."

        PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

        pgrep -f "dotnet run" | while read -r pid; do
            proc_dir=$(readlink -f /proc/$pid/cwd 2>/dev/null)

            if [[ "$proc_dir" == "$PROJECT_ROOT"* ]]; then
                echo "Stopping dotnet process $pid from $proc_dir..."
                kill "$pid" 2>/dev/null
            fi
        done
    fi
}

# Bind cleanup to Ctrl+C and termination signals
trap cleanup SIGINT SIGTERM

# ------------------------------------------------------
#  Timer display during builds for feedback
# ------------------------------------------------------
timer() {
    local start_time=$(date +%s)
    local pid=$1

    echo -n "Building services... Elapsed time: 00:00"

    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        printf "\rBuilding services... Elapsed time: %02d:%02d" "$minutes" "$seconds"
    done

    echo ""
    echo "Services built in $minutes minutes and $seconds seconds."
}

# ------------------------------------------------------
#  Function to build and run services without containers
# ------------------------------------------------------
build_uncontainerized() {
    echo ""
    echo "Building services locally..."

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    build_and_run_service() {
        local service_path=$1
        local service_name=$2
        local port=$3

        echo ""
        echo "Building $service_name..."
        cd "$PROJECT_ROOT/$service_path" || {
            echo "ERROR: Failed to change to directory: $service_path"
            return 1
        }

        if ! dotnet build; then
            echo "ERROR: Failed to build $service_name"
            return 1
        fi

        echo "Starting $service_name on port $port..."
        ASPNETCORE_URLS="http://0.0.0.0:$port" \
        ASPNETCORE_ENVIRONMENT="Production" \
        dotnet run --no-launch-profile &
        local pid=$!
        SERVICE_PIDS+=($pid)

        sleep 2
        if ! kill -0 $pid 2>/dev/null; then
            echo "ERROR: Failed to start $service_name"
            return 1
        fi

        echo "$service_name started successfully (PID: $pid)"
        cd - > /dev/null || exit 1
    }

    for service in "${SERVICES[@]}"; do
        IFS="|" read -r path name port <<< "$service"
        if ! build_and_run_service "$path" "$name" "$port"; then
            echo "ERROR: Deployment failed. Cleaning up..."
            cleanup
            exit 1
        fi
    done

    echo ""
    echo "All services built and started successfully!"
    echo "Services are running on:"
    for service in "${SERVICES[@]}"; do
        IFS="|" read -r path name port <<< "$service"
        echo "   - $name: http://$PUBLIC_IP:$port"
    done
    echo ""
}

# ------------------------------------------------------
#  Validate Docker Images Function
# ------------------------------------------------------
validate_docker_images() {
    echo "Validating Docker images..."
    local images=("bucstop-webapp" "bucstop-gateway" "bucstop-snake" "bucstop-pong" "bucstop-tetris")
    local missing_images=0
    
    for img in "${images[@]}"; do
        if docker images -q $img | grep -q .; then
            echo "Found Docker image: $img"
        else
            echo "Missing Docker image: $img"
            missing_images=1
        fi
    done
    
    if [ $missing_images -eq 1 ]; then
        echo "Some Docker images are missing. Do you want to build them now? (y/n)"
        read -r build_choice
        if [[ "$build_choice" == "y" ]]; then
            build_images
        else
            echo "ERROR: Deployment aborted due to missing images."
            exit 1
        fi
    else
        echo "All Docker images are available"
    fi
}

# ------------------------------------------------------
#  Build Docker Images Function
# ------------------------------------------------------
build_images() {
    echo "Building Docker images..."
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    build_image() {
        local path=$1
        local image_name=$2
        
        echo "Building image $image_name from $path"
        cd "$PROJECT_ROOT/$path" || {
            echo "ERROR: Failed to change to directory: $path"
            return 1
        }
        
        if ! docker build -t $image_name .; then
            echo "ERROR: Failed to build image: $image_name"
            return 1
        }
        
        echo "Successfully built image: $image_name"
        cd - > /dev/null || exit 1
    }
    
    # Build all required images
    build_image "Bucstop WebApp/BucStop" "bucstop-webapp" || return 1
    build_image "Team-3-BucStop_APIGateway/APIGateway" "bucstop-gateway" || return 1
    build_image "Team-3-BucStop_Snake/Snake" "bucstop-snake" || return 1
    build_image "Team-3-BucStop_Pong/Pong" "bucstop-pong" || return 1
    build_image "Team-3-BucStop_Tetris/Tetris" "bucstop-tetris" || return 1
    
    echo "All Docker images built successfully"
}

# ------------------------------------------------------
#  Check Docker Compose File Exists
# ------------------------------------------------------
check_docker_compose_file() {
    echo "Checking for docker-compose.yml file..."
    
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    COMPOSE_FILE="$PROJECT_ROOT/Bucstop WebApp/scripts/docker-compose.yml"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "ERROR: docker-compose.yml file not found at $COMPOSE_FILE"
        echo "Please ensure the file exists and try again"
        exit 1
    else
        echo "docker-compose.yml file found"
        # Create a symlink in the current directory for docker-compose to use
        ln -sf "$COMPOSE_FILE" ./docker-compose.yml
    fi
}

# ------------------------------------------------------
#  Deployment Starts Here
# ------------------------------------------------------
echo "Starting deployment process..."

# Pull latest repo updates
echo "Checking repository status..."
pull_output=$(git pull)
if [[ "$pull_output" == "Already up to date." ]]; then
    echo "Repo is already up to date."
else
    echo "$pull_output"
fi

if [[ "$DEPLOY_MODE" == "containerized" ]]; then
    # Clean up Docker resources
    cleanup
    
    # Additional checks for containerized mode
    check_docker_compose_file
    validate_docker_images
    
    echo ""
    echo "Launching microservices..."
    (docker-compose up -d) &
    BUILD_PID=$!
    timer $BUILD_PID
    
    # Verify services are running
    echo "Verifying services are running..."
    sleep 5
    if docker-compose ps | grep -q "Exit"; then
        echo "ERROR: Some services failed to start. Check logs with 'docker-compose logs'"
        exit 1
    else
        echo "All containerized services started successfully!"
    fi
else
    build_uncontainerized
fi

echo "Deployment completed successfully! Services are now accessible at http://$PUBLIC_IP"
