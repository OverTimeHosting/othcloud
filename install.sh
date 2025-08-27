#!/bin/bash

# OTHcloud Installation Script with Memory Optimization
# One-line install: curl -sSL https://raw.githubusercontent.com/OverTimeHosting/othcloud/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/OverTimeHosting/othcloud.git"
REPO_BRANCH="main"
PROJECT_NAME="othcloud"
INSTALL_DIR="/opt/othcloud"
DOCKER_IMAGE_NAME="othcloud/othcloud"

# Logging functions
log_info() {
    printf "${BLUE}ℹ️  %s${NC}\n" "$1"
}

log_success() {
    printf "${GREEN}✅ %s${NC}\n" "$1"
}

log_warning() {
    printf "${YELLOW}⚠️  %s${NC}\n" "$1"
}

log_error() {
    printf "${RED}❌ %s${NC}\n" "$1"
}

# Function to detect if running in Proxmox LXC container
is_proxmox_lxc() {
    if [ -n "$container" ] && [ "$container" = "lxc" ]; then
        return 0
    fi
    
    if grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        return 0
    fi
    
    return 1
}

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

# Check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Check system requirements
check_system() {
    if [ "$(uname)" = "Darwin" ]; then
        log_error "This script must be run on Linux"
        exit 1
    fi

    if [ -f /.dockerenv ]; then
        log_error "This script cannot be run inside a Docker container"
        exit 1
    fi
    
    # Check memory
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    
    log_info "System memory: ${total_mem}MB total, ${available_mem}MB available"
    
    if [ "$total_mem" -lt 2000 ]; then
        log_error "Insufficient memory. Minimum 2GB RAM required (4GB+ recommended)"
        exit 1
    elif [ "$total_mem" -lt 4000 ]; then
        log_warning "Low memory detected. 4GB+ RAM recommended for optimal performance"
    fi
    
    # Check disk space
    local available_disk=$(df / | awk 'NR==2{printf "%.0f", $4/1024}')
    if [ "$available_disk" -lt 5000 ]; then
        log_error "Insufficient disk space. Minimum 5GB free space required"
        exit 1
    fi
    
    log_info "System checks passed"
}

# Check port availability
check_ports() {
    local ports=("80" "443" "3000")
    local conflicts=0
    
    for port in "${ports[@]}"; do
        if ss -tulnp | grep ":${port} " >/dev/null; then
            log_warning "Port ${port} is already in use"
            if [ "$port" = "3000" ]; then
                conflicts=1
            fi
        fi
    done
    
    if [ $conflicts -eq 1 ]; then
        log_warning "Port 3000 conflict detected. You may need to stop other services."
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package lists
    apt-get update -y
    
    # Install required packages
    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        ca-certificates \
        gnupg \
        lsb-release \
        apt-transport-https \
        software-properties-common \
        openssl \
        htop \
        net-tools

    log_success "System dependencies installed"
}

# Install Docker with optimal settings
install_docker() {
    if command_exists docker; then
        log_info "Docker already installed"
        systemctl start docker >/dev/null 2>&1 || true
        systemctl enable docker >/dev/null 2>&1 || true
        return
    fi

    log_info "Installing Docker..."
    
    # Use official Docker install script
    curl -fsSL https://get.docker.com | sh

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Optimize Docker for build performance
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "experimental": false
}
EOF
    
    systemctl restart docker
    sleep 3

    log_success "Docker installed and optimized"
}

# Install Node.js (for potential local builds)
install_nodejs() {
    if command_exists node; then
        local node_version=$(node -v | sed 's/v//')
        local major_version=$(echo $node_version | cut -d. -f1)
        if [ "$major_version" -ge "18" ]; then
            log_info "Node.js $node_version is already installed"
            return
        fi
    fi

    log_info "Installing Node.js..."
    
    # Install NodeSource repository for Node 20
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs

    log_success "Node.js installed successfully"
}

# Get server IP
get_server_ip() {
    local ip=""
    
    # Try multiple services to get public IP
    ip=$(curl -4s --connect-timeout 5 https://ifconfig.io 2>/dev/null) || \
    ip=$(curl -4s --connect-timeout 5 https://icanhazip.com 2>/dev/null) || \
    ip=$(curl -4s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null)

    # Try IPv6 if IPv4 fails
    if [ -z "$ip" ]; then
        ip=$(curl -6s --connect-timeout 5 https://ifconfig.io 2>/dev/null) || \
        ip=$(curl -6s --connect-timeout 5 https://icanhazip.com 2>/dev/null)
    fi

    # Fallback to private IP
    if [ -z "$ip" ]; then
        ip=$(ip addr show | grep -E "inet (192\.168\.|10\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.)" | head -n1 | awk '{print $2}' | cut -d/ -f1)
    fi

    if [ -z "$ip" ]; then
        log_error "Could not determine server IP address"
        exit 1
    fi

    echo "$ip"
}

# Setup Docker network
setup_docker_network() {
    log_info "Setting up Docker networking..."
    
    # Create network (remove if exists)
    docker network rm othcloud-network 2>/dev/null || true
    docker network create othcloud-network 2>/dev/null || true
    
    log_success "Docker network created"
}

# Clone and prepare repository
prepare_repository() {
    log_info "Preparing OTHcloud repository..."
    
    # Remove existing directory
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Clone repository
    if ! git clone -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
        log_error "Failed to clone repository"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # Create configuration directories
    mkdir -p /etc/othcloud
    chmod 755 /etc/othcloud
    
    # Generate secure credentials
    local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local jwt_secret=$(openssl rand -base64 32)
    local ssh_encryption_key=$(openssl rand -base64 32)
    
    # Create production environment
    log_info "Creating production environment configuration..."
    cat > .env.production << EOF
# Database
DATABASE_URL="postgresql://othcloud:${postgres_password}@othcloud-postgres:5432/othcloud"

# Security
JWT_SECRET="${jwt_secret}"
SSH_ENCRYPTION_KEY="${ssh_encryption_key}"

# Redis
REDIS_URL="redis://othcloud-redis:6379"

# Environment
NODE_ENV=production
NEXTAUTH_URL="http://localhost:3000"

# Optional: Configure after installation
CLOUDFLARE_API_TOKEN=""
CLOUDFLARE_ZONE_ID=""
BASE_DOMAIN=""

# Timeouts
SSH_TIMEOUT=30000
DOCKER_TIMEOUT=30000
EOF
    
    # Save credentials for services
    cat > /etc/othcloud/credentials << EOF
POSTGRES_USER=othcloud
POSTGRES_DB=othcloud
POSTGRES_PASSWORD=${postgres_password}
DATABASE_URL=postgresql://othcloud:${postgres_password}@othcloud-postgres:5432/othcloud
JWT_SECRET=${jwt_secret}
SSH_ENCRYPTION_KEY=${ssh_encryption_key}
REDIS_URL=redis://othcloud-redis:6379
EOF
    chmod 600 /etc/othcloud/credentials
    
    log_success "Repository cloned and configured successfully"
}

# Build Docker image with memory optimization
build_docker_image() {
    log_info "Building OTHcloud Docker image..."
    
    cd "$INSTALL_DIR"
    
    # Check system resources
    local available_mem=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local available_disk=$(df / | awk 'NR==2{printf "%.0f", $4/1024}')
    
    log_info "Available resources: ${available_mem}MB RAM, ${available_disk}MB disk"
    
    # Optimize build parameters based on available memory
    local build_memory="2g"
    local node_memory="4096"
    
    if [ "$total_mem" -lt 4000 ]; then
        build_memory="1g"
        node_memory="2048"
        log_warning "Using reduced memory settings for build"
    fi
    
    # Set Node.js memory limits
    export NODE_OPTIONS="--max_old_space_size=${node_memory} --max-semi-space-size=128"
    
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Build attempt $attempt of $max_attempts..."
        
        # Clean up before retry attempts
        if [ $attempt -gt 1 ]; then
            log_info "Cleaning up Docker system..."
            docker system prune -f --volumes 2>/dev/null || true
            # Force garbage collection
            sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
        fi
        
        # Try building with optimized settings
        local build_success=false
        
        if timeout 1800 docker build \
            --build-arg NODE_OPTIONS="--max_old_space_size=${node_memory} --max-semi-space-size=128" \
            --build-arg NODE_ENV=production \
            --memory="${build_memory}" \
            --memory-swap="${build_memory}" \
            --shm-size=256m \
            --no-cache \
            -t "${DOCKER_IMAGE_NAME}:latest" . 2>&1 | tee /tmp/docker-build.log; then
            
            log_success "Docker image built successfully on attempt $attempt"
            rm -f /tmp/docker-build.log
            return 0
        else
            log_warning "Build attempt $attempt failed"
            
            # Check for specific error types
            if grep -q "JavaScript heap out of memory" /tmp/docker-build.log 2>/dev/null; then
                log_warning "Memory exhaustion detected"
                if [ "$node_memory" -gt 1024 ]; then
                    node_memory=$((node_memory - 512))
                    log_info "Reducing Node.js memory limit to ${node_memory}MB"
                fi
            fi
        fi
        
        attempt=$((attempt + 1))
        [ $attempt -le $max_attempts ] && sleep 10
    done
    
    # Build failed, try fallback strategies
    log_error "Docker build failed after $max_attempts attempts"
    log_info "Trying fallback strategies..."
    
    # Fallback 1: Use pre-built image
    log_info "Attempting to use pre-built dokploy image..."
    if docker pull dokploy/dokploy:latest 2>/dev/null; then
        docker tag dokploy/dokploy:latest "${DOCKER_IMAGE_NAME}:latest"
        log_success "Using pre-built image as fallback"
        return 0
    fi
    
    # Fallback 2: Try pulling from Docker Hub if available
    log_info "Attempting to pull from registry..."
    if docker pull "${DOCKER_IMAGE_NAME}:latest" 2>/dev/null; then
        log_success "Pulled image from registry"
        return 0
    fi
    
    # All attempts failed
    log_error "All build strategies failed!"
    log_error "Build log (last 20 lines):"
    tail -20 /tmp/docker-build.log 2>/dev/null || true
    log_error ""
    log_error "System requirements not met. Please ensure:"
    log_error "  • RAM: 4GB+ total memory (you have: ${total_mem}MB)"
    log_error "  • Disk: 10GB+ free space (you have: ${available_disk}MB)"
    log_error "  • CPU: 2+ cores recommended"
    log_error ""
    log_error "Troubleshooting steps:"
    log_error "  1. Free up memory: 'free -h && docker system prune -a'"
    log_error "  2. Increase swap: 'sudo fallocate -l 2G /swapfile && sudo swapon /swapfile'"
    log_error "  3. Use a more powerful server"
    log_error "  4. Try manual installation: 'git clone && docker-compose up'"
    
    exit 1
}

# Setup PostgreSQL database
setup_database() {
    log_info "Setting up PostgreSQL database..."
    
    source /etc/othcloud/credentials
    
    # Remove existing container
    docker rm -f othcloud-postgres 2>/dev/null || true
    
    # Create PostgreSQL container
    docker run -d \
        --name othcloud-postgres \
        --network othcloud-network \
        --restart unless-stopped \
        -e POSTGRES_USER="$POSTGRES_USER" \
        -e POSTGRES_DB="$POSTGRES_DB" \
        -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
        -v othcloud-postgres-data:/var/lib/postgresql/data \
        postgres:16-alpine
    
    # Wait for database to be ready
    log_info "Waiting for database to initialize..."
    for i in {1..30}; do
        if docker exec othcloud-postgres pg_isready -U "$POSTGRES_USER" >/dev/null 2>&1; then
            log_success "Database is ready"
            break
        fi
        sleep 2
    done
    
    log_success "PostgreSQL database setup completed"
}

# Setup Redis cache
setup_redis() {
    log_info "Setting up Redis cache..."
    
    # Remove existing container
    docker rm -f othcloud-redis 2>/dev/null || true
    
    # Create Redis container
    docker run -d \
        --name othcloud-redis \
        --network othcloud-network \
        --restart unless-stopped \
        -v othcloud-redis-data:/data \
        redis:7-alpine redis-server --appendonly yes
    
    log_success "Redis cache setup completed"
}

# Deploy main application
deploy_application() {
    log_info "Deploying OTHcloud application..."
    
    source /etc/othcloud/credentials
    
    # Remove existing container
    docker rm -f othcloud-app 2>/dev/null || true
    
    # Deploy application container
    docker run -d \
        --name othcloud-app \
        --network othcloud-network \
        --restart unless-stopped \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v /etc/othcloud:/etc/othcloud \
        -v othcloud-data:/app/data \
        -p 3000:3000 \
        -e NODE_ENV=production \
        -e DATABASE_URL="$DATABASE_URL" \
        -e JWT_SECRET="$JWT_SECRET" \
        -e SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
        -e REDIS_URL="$REDIS_URL" \
        -e SSH_TIMEOUT=30000 \
        -e DOCKER_TIMEOUT=30000 \
        "${DOCKER_IMAGE_NAME}:latest"
    
    log_success "Application deployed successfully"
}

# Setup reverse proxy
setup_traefik() {
    # Skip if ports are in use
    if ss -tulnp | grep -E ":80|:443" >/dev/null; then
        log_warning "Ports 80/443 in use, skipping Traefik setup"
        return
    fi
    
    log_info "Setting up Traefik reverse proxy..."
    
    mkdir -p /etc/othcloud/traefik
    
    # Basic Traefik configuration
    cat > /etc/othcloud/traefik/traefik.yml << 'EOF'
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

log:
  level: INFO
EOF
    
    # Deploy Traefik
    docker run -d \
        --name othcloud-traefik \
        --network othcloud-network \
        --restart unless-stopped \
        -v /etc/othcloud/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p 80:80 \
        -p 443:443 \
        -p 8080:8080 \
        traefik:v3.1.2
    
    log_success "Traefik reverse proxy deployed"
}

# Wait for services to be healthy
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    local max_wait=120
    local waited=0
    
    while [ $waited -lt $max_wait ]; do
        if curl -sf http://localhost:3000 >/dev/null 2>&1; then
            log_success "OTHcloud is ready!"
            return 0
        fi
        
        sleep 5
        waited=$((waited + 5))
        
        if [ $((waited % 30)) -eq 0 ]; then
            log_info "Still waiting... (${waited}s)"
        fi
    done
    
    log_warning "Service health check timeout. Check logs with: docker logs othcloud-app"
}

# Create systemd service for auto-start
create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/othcloud.service << 'EOF'
[Unit]
Description=OTHcloud Container Management Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/bash -c 'docker start othcloud-postgres othcloud-redis othcloud-app othcloud-traefik 2>/dev/null || true'
ExecStop=/bin/bash -c 'docker stop othcloud-app othcloud-traefik othcloud-redis othcloud-postgres 2>/dev/null || true'
TimeoutStartSec=120
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable othcloud.service >/dev/null 2>&1 || true
    
    log_success "Systemd service created and enabled"
}

# Main installation function
install_othcloud() {
    log_info "🚀 Starting OTHcloud installation..."
    
    check_root
    check_system
    check_ports
    
    install_dependencies
    install_docker
    install_nodejs
    
    setup_docker_network
    prepare_repository
    build_docker_image
    
    setup_database
    setup_redis
    deploy_application
    setup_traefik
    
    create_systemd_service
    wait_for_services
    
    # Installation complete
    local server_ip=$(get_server_ip)
    local formatted_addr
    if echo "$server_ip" | grep -q ':'; then
        formatted_addr="[$server_ip]"
    else
        formatted_addr="$server_ip"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    log_success "🎉 OTHcloud installation completed successfully!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    log_info "📋 Access Information:"
    echo "   🌐 Application URL: http://${formatted_addr}:3000"
    echo "   🔧 Traefik Dashboard: http://${formatted_addr}:8080 (if enabled)"
    echo ""
    log_info "🔑 Default Login Credentials:"
    echo "   📧 Email: damo@damo.com"
    echo "   🔒 Password: admin"
    echo "   ⚠️  CHANGE THESE IMMEDIATELY AFTER LOGIN!"
    echo ""
    log_info "📁 Installation Locations:"
    echo "   📂 Application: $INSTALL_DIR"
    echo "   ⚙️  Configuration: /etc/othcloud/"
    echo ""
    log_info "🛠️  Useful Commands:"
    echo "   📊 Check status: docker ps | grep othcloud"
    echo "   📋 View logs: docker logs othcloud-app"
    echo "   🔄 Restart: systemctl restart othcloud"
    echo "   🆙 Update: $0 update"
    echo "   🗑️  Uninstall: $0 uninstall"
    echo ""
    log_info "🔗 Ready to use! Visit: http://${formatted_addr}:3000"
    echo "════════════════════════════════════════════════════════════════"
}

# Update function
update_othcloud() {
    log_info "🔄 Updating OTHcloud..."
    
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation directory not found. Run installation first."
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    git pull origin "$REPO_BRANCH"
    
    # Rebuild and restart
    docker build -t "${DOCKER_IMAGE_NAME}:latest" .
    docker restart othcloud-app
    
    log_success "✅ Update completed!"
}

# Uninstall function
uninstall_othcloud() {
    log_warning "🗑️  Uninstalling OTHcloud..."
    
    # Stop and remove containers
    docker stop othcloud-app othcloud-traefik othcloud-redis othcloud-postgres 2>/dev/null || true
    docker rm othcloud-app othcloud-traefik othcloud-redis othcloud-postgres 2>/dev/null || true
    
    # Remove network
    docker network rm othcloud-network 2>/dev/null || true
    
    # Remove systemd service
    systemctl disable othcloud.service 2>/dev/null || true
    rm -f /etc/systemd/system/othcloud.service
    systemctl daemon-reload
    
    log_success "✅ Uninstalled (data volumes preserved)"
    log_info "To remove data: docker volume rm othcloud-postgres-data othcloud-redis-data othcloud-data"
}

# Show status
show_status() {
    echo "=== OTHcloud Status ==="
    docker ps --filter name=othcloud --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    curl -sf http://localhost:3000 >/dev/null && echo "✅ Application: Healthy" || echo "❌ Application: Not responding"
}

# Show logs
show_logs() {
    local service=${1:-app}
    docker logs -f "othcloud-$service" 2>/dev/null || {
        echo "Available services: app, postgres, redis, traefik"
        echo "Usage: $0 logs [service]"
    }
}

# Main script logic
case "$1" in
    "update")
        update_othcloud
        ;;
    "uninstall")
        read -p "Are you sure you want to uninstall OTHcloud? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_othcloud
        fi
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    *)
        install_othcloud
        ;;
esac