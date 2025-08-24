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

# Check if running as root
check_permissions() {
    if [[ $EUID -eq 0 ]]; then
        error "Please do not run this script as root"
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        warn "Docker not found. Please install Docker first:"
        echo "  curl -fsSL https://get.docker.com | sh"
        echo "  sudo usermod -aG docker \$USER"
        echo "  # Then log out and back in"
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        error "Docker Compose not found. Please install Docker Compose"
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        warn "Node.js not found. Please install Node.js $NODE_VERSION"
        echo "  # Using nvm (recommended):"
        echo "  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash"
        echo "  nvm install $NODE_VERSION && nvm use"
        exit 1
    fi
    
    # Check pnpm
    if ! command -v pnpm &> /dev/null; then
        warn "pnpm not found. Installing pnpm..."
        npm install -g pnpm
    fi
    
    # Verify Node version
    NODE_CURRENT=$(node -v | sed 's/v//')
    if ! [[ $NODE_CURRENT == $NODE_VERSION* ]]; then
        warn "Node.js version mismatch. Expected: $NODE_VERSION, Found: $NODE_CURRENT"
        warn "Consider using nvm: nvm install $NODE_VERSION && nvm use"
    fi
}

# Check if ports are available
check_ports() {
    log "Checking port availability..."
    
    for port in "${REQUIRED_PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            warn "Port $port is already in use"
            if [[ $port == 80 || $port == 443 ]]; then
                warn "Consider stopping your web server temporarily: sudo systemctl stop nginx apache2"
            fi
        fi
    done
}

# Setup environment
setup_environment() {
    log "Setting up environment..."
    
    # Create .env if it doesn't exist
    if [[ ! -f apps/dokploy/.env ]]; then
        cp apps/dokploy/.env.example apps/dokploy/.env
        log "Created environment file"
    fi
    
    # Create required directories
    mkdir -p data/traefik/dynamic
    mkdir -p data/postgres
    mkdir -p data/redis
    
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
    pnpm install --frozen-lockfile
    
    log "Running application setup..."
    pnpm run dokploy:setup
    
    log "Running server script..."
    timeout 10s pnpm run server:script || log "Server script completed (or timed out safely)"
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
    pnpm install --frozen-lockfile
    
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
