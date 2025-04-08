#!/bin/bash
export ASPNETCORE_ENVIRONMENT=Production
# ─────────────────────────────────────────────────────────────
#  Config / Constants
# ─────────────────────────────────────────────────────────────

# Prod IP, still figuring out how we want to manage dev IP not being static
PUBLIC_IP="3.232.16.65"

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

# ─────────────────────────────────────────────────────────────
#  Check for required tools
# ─────────────────────────────────────────────────────────────
check_requirements() {
    echo "🔍 Checking for required tools..."
    missing_tools=0
    for cmd in "${REQUIRED_CMDS[@]}"; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo "❌  Missing required command: $cmd"
            missing_tools=1
        else
            echo "✅  Found required command: $cmd"
        fi
    done
    
    if [ $missing_tools -eq 1 ]; then
        echo "❌  Please install missing tools and try again."
        exit 1
    fi
    
    # Check for Docker service
    if ! docker info >/dev/null 2>&1; then
        echo "❌  Docker service is not running. Please start Docker and try again."
        exit 1
    fi
    
    echo "✅  All required tools are available."
}

check_requirements

# ─────────────────────────────────────────────────────────────
#  Select Deployment Mode (Menu)
# ─────────────────────────────────────────────────────────────
while true; do
    echo -e "\n📌  Select Deployment Mode:"
    echo -e "   [1] 🐳 Containerized (Docker)"
    echo -e "   [2] 🔨 Uncontainerized (Local dotnet run)"
    echo -n "👉  Enter choice (1 or 2): "
    read -r choice

    case $choice in
        1) DEPLOY_MODE="containerized"; break;;
        2) DEPLOY_MODE="uncontainerized"; break;;
        *) echo "❌  Invalid choice! Please enter 1 or 2.";;
    esac
done

# Array to store background process PIDs
declare -a SERVICE_PIDS

# ─────────────────────────────────────────────────────────────
#  Cleanup function
# Stops Docker containers or local processes based on deployment mode.
# Always prunes Docker resources in containerized mode to save EBS space.
# EBS space costs money in AWS.
# ─────────────────────────────────────────────────────────────
cleanup() {
    echo -e "\n🚨  Cleaning up processes..."

    if [[ "$DEPLOY_MODE" == "containerized" ]]; then
        if [ -n "$BUILD_PID" ]; then
            kill "$BUILD_PID" 2>/dev/null
        fi

        echo -e "\n🧹  Stopping Docker containers..."
        docker-compose down || echo "⚠️  Warning: Issue stopping containers, continuing cleanup..."

        echo -e "\n🫼  Pruning unused Docker resources..."
        docker system prune -af --volumes | awk '
            /Deleted Images:/ { skip=1; next }
            /Deleted build cache objects:/ { skip=1; next }
            /^Total reclaimed space:/ {
                skip=0
                print "   🧽 " $0
                next
            }
            skip==0 { print }
        ' || echo "⚠️  Warning: Issue pruning Docker resources, continuing cleanup..."

    else
        echo -e "\n🛌  Stopping local dotnet services..."

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

# ─────────────────────────────────────────────────────────────
#  Timer display during builds for feedback
# ─────────────────────────────────────────────────────────────
timer() {
    local start_time=$(date +%s)
    local pid=$1

    echo -n "⏳  Building services... Elapsed time: 00:00"

    while kill -0 "$pid" 2>/dev/null; do
        sleep 1
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local minutes=$((elapsed / 60))
        local seconds=$((elapsed % 60))
        printf "\r⏳  Building services... Elapsed time: %02d:%02d" "$minutes" "$seconds"
    done

    echo -e "\r✅  Services built in $minutes minutes and $seconds seconds.    "
}

# ─────────────────────────────────────────────────────────────
#  Function to build and run services without containers
# ─────────────────────────────────────────────────────────────
build_uncontainerized() {
    echo -e "\n🔨  Building services locally..."

    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    build_and_run_service() {
        local service_path=$1
        local service_name=$2
        local port=$3

        echo -e "\n📦  Building $service_name..."
        cd "$PROJECT_ROOT/$service_path" || {
            echo "❌  Failed to change to directory: $service_path"
            return 1
        }

        if ! dotnet build; then
            echo "❌  Failed to build $service_name"
            return 1
        fi

        echo -e "🚀  Starting $service_name on port $port..."
        ASPNETCORE_URLS="http://0.0.0.0:$port" \
        # There is currently only a "development" environment variable outlined in launchSettings.json
        # and no Prod environment variable.
        ASPNETCORE_ENVIRONMENT="Production" \
        dotnet run --no-launch-profile &
        local pid=$!
        SERVICE_PIDS+=($pid)

        sleep 2
        if ! kill -0 $pid 2>/dev/null; then
            echo "❌  Failed to start $service_name"
            return 1
        fi

        echo "✅  $service_name started successfully (PID: $pid)"
        cd - > /dev/null || exit 1
    }

    for service in "${SERVICES[@]}"; do
        IFS="|" read -r path name port <<< "$service"
        if ! build_and_run_service "$path" "$name" "$port"; then
            echo "❌  Deployment failed. Cleaning up..."
            cleanup
            exit 1
        fi
    done

    echo -e "\n✅  All services built and started successfully!"
    echo -e "📜  Services are running on:"
    for service in "${SERVICES[@]}"; do
        IFS="|" read -r path name port <<< "$service"
        echo -e "   - $name: http://$PUBLIC_IP:$port"
    done
    echo
}

# ─────────────────────────────────────────────────────────────
#  Validate Docker Images Function
# ─────────────────────────────────────────────────────────────
validate_docker_images() {
    echo "🔍 Validating Docker images..."
    local images=("bucstop-webapp" "bucstop-gateway" "bucstop-snake" "bucstop-pong" "bucstop-tetris")
    local missing_images=0
    
    for img in "${images[@]}"; do
        if docker images -q $img | grep -q .; then
            echo "✅ Found Docker image: $img"
        else
            echo "❌ Missing Docker image: $img"
            missing_images=1
        fi
    done
    
    if [ $missing_images -eq 1 ]; then
        echo "⚠️ Some Docker images are missing. Do you want to build them now? (y/n)"
        read -r build_choice
        if [[ "$build_choice" == "y" ]]; then
            build_images
        else
            echo "❌ Deployment aborted due to missing images."
            exit 1
        fi
    else
        echo "✅ All Docker images are available"
    fi
}

# ─────────────────────────────────────────────────────────────
#  Build Docker Images Function
# ─────────────────────────────────────────────────────────────
build_images() {
    echo "🔨 Building Docker images..."
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    build_image() {
        local path=$1
        local image_name=$2
        
        echo "🔨 Building image $image_name from $path"
        cd "$PROJECT_ROOT/$path" || {
            echo "❌ Failed to change to directory: $path"
            return 1
        }
        
        if ! docker build -t $image_name .; then
            echo "❌ Failed to build image: $image_name"
            return 1
        }
        
        echo "✅ Successfully built image: $image_name"
        cd - > /dev/null || exit 1
    }
    
    # Build all required images
    build_image "Bucstop WebApp/BucStop" "bucstop-webapp" || return 1
    build_image "Team-3-BucStop_APIGateway/APIGateway" "bucstop-gateway" || return 1
    build_image "Team-3-BucStop_Snake/Snake" "bucstop-snake" || return 1
    build_image "Team-3-BucStop_Pong/Pong" "bucstop-pong" || return 1
    build_image "Team-3-BucStop_Tetris/Tetris" "bucstop-tetris" || return 1
    
    echo "✅ All Docker images built successfully"
}

# ─────────────────────────────────────────────────────────────
#  Check Docker Compose File Exists
# ─────────────────────────────────────────────────────────────
check_docker_compose_file() {
    echo "🔍 Checking for docker-compose.yml file..."
    
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    COMPOSE_FILE="$PROJECT_ROOT/Bucstop WebApp/scripts/docker-compose.yml"
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ docker-compose.yml file not found at $COMPOSE_FILE"
        echo "Please ensure the file exists and try again"
        exit 1
    else
        echo "✅ docker-compose.yml file found"
        # Create a symlink in the current directory for docker-compose to use
        ln -sf "$COMPOSE_FILE" ./docker-compose.yml
    fi
}

# ─────────────────────────────────────────────────────────────
#  Deployment Magic Starts Here
# ─────────────────────────────────────────────────────────────
echo "🚀  Starting deployment process..."

# Pull latest repo updates
echo "🔄  Checking repository status..."
pull_output=$(git pull)
if [[ "$pull_output" == "Already up to date." ]]; then
    echo "✅  Repo is already up to date."
else
    echo "$pull_output"
fi

if [[ "$DEPLOY_MODE" == "containerized" ]]; then
    # Clean up Docker resources
    cleanup
    
    # Additional checks for containerized mode
    check_docker_compose_file
    validate_docker_images
    
    echo -e "\n🐳  Launching microservices..."
    (docker-compose up -d) &
    BUILD_PID=$!
    timer $BUILD_PID
    
    # Verify services are running
    echo "🔍 Verifying services are running..."
    sleep 5
    if docker-compose ps | grep -q "Exit"; then
        echo "❌ Some services failed to start. Check logs with 'docker-compose logs'"
        exit 1
    else
        echo -e "✅  All containerized services started successfully!\n"
    fi
else
    build_uncontainerized
fi

echo "🎉 Deployment completed successfully! Services are now accessible at http://$PUBLIC_IP"

# Notes: 
# I am not 100% certain I am in love with the cleanup mechanism.
# Consider revisiting cleanup for containers both before and after deployment actions.
# Consider using 'killall dotnet' as blunt force to kill dotnet services instead.
# Consider altering `docker system prune` based on our approach to data persistence.
