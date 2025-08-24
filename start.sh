#!/bin/bash

# OthCloud - One-command startup script
# Usage: ./start.sh [--dev|--prod|--stop|--clean|--setup]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="othcloud"
NODE_VERSION="20.16.0"
REQUIRED_PORTS=(3000 5432 6379 80 443 8080)

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║          🚀 OthCloud Setup           ║"
    echo "║     One-command deployment tool      ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root and handle appropriately
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root detected. This is allowed but not recommended for development."
        warn "Consider creating a non-root user for better security."
        
        # Set appropriate environment for root
        export DOCKER_BUILDKIT=1
        export COMPOSE_DOCKER_CLI_BUILD=1
        
        # Ensure proper ownership of files
        if [[ -n "$SUDO_USER" ]]; then
            log "Will set file ownership to user: $SUDO_USER"
            ORIGINAL_USER="$SUDO_USER"
        else
            ORIGINAL_USER="root"
        fi
        
        sleep 2
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        warn "Docker not found. Installing Docker..."
        if [[ "$(uname)" == "Linux" ]]; then
            # Install Docker on Linux
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            rm get-docker.sh
            
            # Add user to docker group if not root
            if [[ $EUID -ne 0 && -n "$SUDO_USER" ]]; then
                usermod -aG docker "$SUDO_USER"
                log "Added $SUDO_USER to docker group. You may need to log out and back in."
            elif [[ $EUID -ne 0 ]]; then
                usermod -aG docker "$(whoami)"
                log "Added $(whoami) to docker group. You may need to log out and back in."
            fi
            
            # Start Docker service
            systemctl enable docker
            systemctl start docker
            
            log "Docker installed successfully"
        else
            error "Please install Docker manually for your system and try again"
        fi
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        warn "Docker Compose not found. Installing Docker Compose..."
        
        if [[ "$(uname)" == "Linux" ]]; then
            # Get latest version
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
            
            # Download and install
            curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            
            # Create symlink for 'docker compose' command
            mkdir -p /usr/local/lib/docker/cli-plugins
            ln -sf /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
            
            log "Docker Compose installed successfully"
        else
            error "Please install Docker Compose manually for your system and try again"
        fi
    fi
    
    # Verify Docker is running
    if ! docker info &> /dev/null; then
        warn "Docker is not running. Starting Docker..."
        systemctl start docker || service docker start || error "Failed to start Docker service"
        sleep 3
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        warn "Node.js not found. Installing Node.js $NODE_VERSION..."
        if [[ "$(uname)" == "Linux" ]]; then
            # Install Node.js via NodeSource repository
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
            
            # Alternative for RPM-based systems
            if ! command -v node &> /dev/null; then
                curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
                yum install -y nodejs || dnf install -y nodejs
            fi
            
            log "Node.js installed successfully"
        else
            error "Please install Node.js $NODE_VERSION manually and try again"
        fi
    fi
    
    # Check pnpm
    if ! command -v pnpm &> /dev/null; then
        warn "pnpm not found. Installing pnpm..."
        if [[ $EUID -eq 0 ]]; then
            # Install pnpm globally for root
            npm install -g pnpm --unsafe-perm
        else
            npm install -g pnpm
        fi
        log "pnpm installed successfully"
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        warn "Git not found. Installing Git..."
        if [[ "$(uname)" == "Linux" ]]; then
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y git
            elif command -v yum &> /dev/null; then
                yum install -y git
            elif command -v dnf &> /dev/null; then
                dnf install -y git
            else
                error "Could not install git. Please install manually."
            fi
            log "Git installed successfully"
        else
            error "Please install Git manually for your system and try again"
        fi
    fi
    
    # Check curl (needed for installations)
    if ! command -v curl &> /dev/null; then
        warn "curl not found. Installing curl..."
        if [[ "$(uname)" == "Linux" ]]; then
            if command -v apt-get &> /dev/null; then
                apt-get update && apt-get install -y curl
            elif command -v yum &> /dev/null; then
                yum install -y curl
            elif command -v dnf &> /dev/null; then
                dnf install -y curl
            fi
        fi
    fi
    
    # Verify Node version
    NODE_CURRENT=$(node -v | sed 's/v//')
    if ! [[ $NODE_CURRENT == $NODE_VERSION* ]]; then
        warn "Node.js version mismatch. Expected: $NODE_VERSION, Found: $NODE_CURRENT"
        warn "The application should still work, but consider updating if you encounter issues."
    fi
    
    log "All system requirements are satisfied!"
}

# Check if ports are available
check_ports() {
    log "Checking port availability..."
    
    local ports_in_use=()
    local critical_conflict=false
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            ports_in_use+=("$port")
            
            # Check what's using the port
            local service=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f2 | head -1)
            warn "Port $port is in use by: ${service:-unknown}"
            
            if [[ $port == 80 || $port == 443 ]]; then
                warn "Port $port (HTTP/HTTPS) conflict detected"
                warn "This will cause Traefik to fail, but the main app will still work on port 3000"
                
                if [[ "$service" == "nginx" || "$service" == "apache2" || "$service" == "httpd" ]]; then
                    warn "To fix this, you can temporarily stop $service:"
                    warn "  sudo systemctl stop $service"
                fi
            elif [[ $port == 3000 ]]; then
                error "Port 3000 (main application) is already in use. Cannot continue."
                critical_conflict=true
            fi
        fi
    done
    
    if [[ $critical_conflict == true ]]; then
        error "Critical port conflict detected. Please stop the service using port 3000 and try again."
    fi
    
    if [[ ${#ports_in_use[@]} -gt 0 ]]; then
        warn "Port conflicts detected: ${ports_in_use[*]}"
        warn "The application will attempt to continue, but some services may fail."
        warn "Main application should still be accessible on port 3000."
        
        echo -n "Continue anyway? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log "Setup cancelled. Please resolve port conflicts and try again."
            exit 1
        fi
    fi
}

# Fix file ownership if running as root via sudo
fix_ownership() {
    if [[ $EUID -eq 0 && -n "$SUDO_USER" ]]; then
        log "Fixing file ownership for user: $SUDO_USER"
        
        # Get the original user's UID and GID
        SUDO_UID=$(id -u "$SUDO_USER")
        SUDO_GID=$(id -g "$SUDO_USER")
        
        # Fix ownership of key directories and files
        chown -R "$SUDO_UID:$SUDO_GID" . 2>/dev/null || true
        chown -R "$SUDO_UID:$SUDO_GID" ~/.docker 2>/dev/null || true
        chown -R "$SUDO_UID:$SUDO_GID" ~/.npm 2>/dev/null || true
        chown -R "$SUDO_UID:$SUDO_GID" ~/.pnpm 2>/dev/null || true
    fi
}

# Setup environment
setup_environment() {
    log "Setting up environment..."
    
    # Check if we're in the right directory
    if [[ ! -f "package.json" ]]; then
        error "package.json not found. Make sure you're in the othcloud directory."
    fi
    
    # Create .env if it doesn't exist
    if [[ ! -f apps/dokploy/.env ]]; then
        if [[ -f apps/dokploy/.env.example ]]; then
            cp apps/dokploy/.env.example apps/dokploy/.env
            log "Created environment file from .env.example"
        else
            # Create a default .env file if example doesn't exist
            log "Creating default environment file..."
            mkdir -p apps/dokploy
            cat > apps/dokploy/.env << 'EOF'
DATABASE_URL="postgres://dokploy:amukds4wi9001583845717ad2@localhost:5432/dokploy"
PORT=3000
NODE_ENV=development
EOF
            log "Created default environment file"
        fi
    else
        log "Environment file already exists"
    fi
    
    # Create required directories
    mkdir -p data/traefik/dynamic
    mkdir -p data/postgres
    mkdir -p data/redis
    
    # Fix ownership after creating directories
    fix_ownership
    
    # Create basic Traefik config if it doesn't exist
    if [[ ! -f data/traefik/traefik.yml ]]; then
        cat > data/traefik/traefik.yml << 'EOF'
api:
  dashboard: true
  insecure: true

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
  file:
    directory: /etc/traefik/dynamic
    watch: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

log:
  level: INFO
EOF
        log "Created Traefik configuration"
    fi
    
    # Create .gitkeep for data directory
    touch data/.gitkeep
    
    # Final ownership fix
    fix_ownership
}

# Start services
start_services() {
    log "Starting Docker services..."
    
    # Initialize Docker Swarm if not already initialized
    if ! docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q active; then
        log "Initializing Docker Swarm..."
        ADVERTISE_ADDR=$(hostname -I | awk '{print $1}' || echo "127.0.0.1")
        docker swarm init --advertise-addr $ADVERTISE_ADDR 2>/dev/null || true
    fi
    
    # Start Docker Compose services
    docker compose up -d
    
    # Wait for services to be healthy
    log "Waiting for services to be ready..."
    sleep 10
    
    # Check service health
    for i in {1..60}; do
        if docker compose ps --format json 2>/dev/null | grep -q '"Health":"healthy"' || docker compose ps | grep -q "Up"; then
            log "Services are ready!"
            break
        fi
        if [[ $i -eq 60 ]]; then
            warn "Services may not be fully ready yet, but continuing..."
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
}

# Install dependencies and setup
setup_application() {
    log "Installing dependencies..."
    
    # Handle pnpm for root
    if [[ $EUID -eq 0 ]]; then
        # Use --unsafe-perm for root to avoid permission issues
        pnpm install --frozen-lockfile --unsafe-perm || pnpm install --frozen-lockfile
    else
        pnpm install --frozen-lockfile
    fi
    
    # Fix ownership after installing dependencies
    fix_ownership
    
    log "Running application setup..."
    
    # Run setup with error handling for port conflicts
    if ! pnpm run dokploy:setup; then
        warn "Application setup encountered errors (likely port conflicts)"
        warn "This is usually caused by port 80/443 being in use"
        warn "The application should still work on port 3000"
        
        # Check if the error was due to port conflicts
        if docker compose ps postgres redis &>/dev/null; then
            log "Core services (database, redis) are running - continuing..."
        else
            error "Core services failed to start. Please check logs with: make logs"
        fi
    else
        log "Application setup completed successfully"
    fi
    
    log "Running server script..."
    timeout 10s pnpm run server:script || log "Server script completed (or timed out safely)"
    
    # Final ownership fix
    fix_ownership
}

# Start development server
start_dev() {
    log "Starting development server..."
    log "🌐 Application will be available at:"
    log "   - Main App: http://localhost:3000"
    log "   - Traefik Dashboard: http://localhost:8080"
    log ""
    log "Press Ctrl+C to stop the server"
    
    # Start with turbopack for faster builds
    pnpm run dokploy:dev:turbopack
}

# Start production server
start_prod() {
    log "Building and starting production server..."
    pnpm run dokploy:build
    
    log "🌐 Application will be available at:"
    log "   - Main App: http://localhost:3000"
    log "   - Traefik Dashboard: http://localhost:8080"
    
    pnpm run dokploy:start
}

# Setup only (for quick install)
setup_only() {
    log "Setting up OthCloud (dependencies and environment only)..."
    check_permissions
    check_requirements
    setup_environment
    
    log "Installing dependencies..."
    
    # Handle pnpm for root
    if [[ $EUID -eq 0 ]]; then
        pnpm install --frozen-lockfile --unsafe-perm || pnpm install --frozen-lockfile
    else
        pnpm install --frozen-lockfile
    fi
    
    # Fix ownership after setup
    fix_ownership
    
    log "Setup complete! Run './start.sh --dev' to start services"
}

# Stop all services
stop_services() {
    log "Stopping all services..."
    docker compose down || true
    
    # Stop any running Node processes
    pkill -f "node.*dokploy" 2>/dev/null || true
    pkill -f "tsx.*dokploy" 2>/dev/null || true
    
    log "All services stopped"
}

# Clean everything
clean_all() {
    log "Cleaning up everything..."
    docker compose down -v --remove-orphans || true
    docker system prune -f || true
    
    # Clean node modules
    rm -rf node_modules 2>/dev/null || true
    rm -rf apps/*/node_modules 2>/dev/null || true
    rm -rf packages/*/node_modules 2>/dev/null || true
    
    # Clean data directories
    rm -rf data 2>/dev/null || true
    
    log "Cleanup complete"
}

# Show help
show_help() {
    echo "OthCloud Startup Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --dev         Start in development mode (default)"
    echo "  --prod        Start in production mode"
    echo "  --stop        Stop all services"
    echo "  --clean       Clean up everything (containers, volumes, node_modules)"
    echo "  --setup       Install dependencies and setup environment only"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Start in development mode"
    echo "  $0 --dev          # Start in development mode"
    echo "  $0 --prod         # Start in production mode"
    echo "  $0 --stop         # Stop all services"
    echo "  $0 --clean        # Clean up everything"
    echo "  $0 --setup        # Setup dependencies only"
}

# Main execution
main() {
    print_banner
    
    # Show current directory for debugging
    log "Current directory: $(pwd)"
    log "Directory contents: $(ls -la | head -5 | tail -4 | tr '\n' ' ')"
    
    case "${1:---dev}" in
        --dev)
            check_permissions
            check_requirements
            check_ports
            setup_environment
            start_services
            setup_application
            start_dev
            ;;
        --prod)
            check_permissions
            check_requirements
            check_ports
            setup_environment
            start_services
            setup_application
            start_prod
            ;;
        --stop)
            stop_services
            ;;
        --clean)
            clean_all
            ;;
        --setup)
            setup_only
            ;;
        --help)
            show_help
            ;;
        *)
            error "Unknown option: $1. Use --help for usage information."
            ;;
    esac
}

# Handle Ctrl+C gracefully
trap 'echo -e "\n${YELLOW}Shutting down...${NC}"; stop_services; exit 0' INT

# Run main function with all arguments
main "$@"
