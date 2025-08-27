#!/bin/bash

# OTHcloud Installation Script
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

# Check system compatibility
check_system() {
    if [ "$(uname)" = "Darwin" ]; then
        log_error "This script must be run on Linux"
        exit 1
    fi

    if [ -f /.dockerenv ]; then
        log_error "This script cannot be run inside a Docker container"
        exit 1
    fi
}

# Check port availability (warn but don't fail)
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
        log_warning "Port 3000 conflict detected. Services may not start properly."
        log_info "You can stop conflicting services with: systemctl stop nginx apache2"
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
        openssl

    log_success "System dependencies installed"
}

# Install Docker
install_docker() {
    if command_exists docker; then
        log_info "Docker already installed"
        # Ensure Docker is running
        systemctl start docker >/dev/null 2>&1 || true
        systemctl enable docker >/dev/null 2>&1 || true
        return
    fi

    log_info "Installing Docker..."
    
    # Use the official Docker install script
    curl -fsSL https://get.docker.com | sh

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    log_success "Docker installed successfully"
}

# Install Node.js
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
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs

    log_success "Node.js installed successfully"
}

# Install PNPM
install_pnpm() {
    if command_exists pnpm; then
        log_info "PNPM already installed"
        return
    fi

    log_info "Installing PNPM..."
    
    # Enable corepack and install pnpm
    corepack enable 2>/dev/null || npm install -g pnpm

    log_success "PNPM installed successfully"
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

# Setup Docker Swarm
setup_docker_swarm() {
    log_info "Setting up Docker Swarm..."
    
    # Leave any existing swarm (ignore errors)
    docker swarm leave --force 2>/dev/null || true
    
    local advertise_addr="${ADVERTISE_ADDR:-$(get_server_ip)}"
    log_info "Using advertise address: $advertise_addr"
    
    # Check if running in Proxmox LXC container
    if is_proxmox_lxc; then
        log_warning "Detected Proxmox LXC container environment!"
        log_info "This may affect Docker Swarm networking"
        sleep 3
    fi
    
    # Initialize swarm
    if ! docker swarm init --advertise-addr "$advertise_addr" 2>/dev/null; then
        log_warning "Docker Swarm initialization failed, trying without advertise address..."
        if ! docker swarm init 2>/dev/null; then
            log_warning "Docker Swarm not available, using standalone Docker mode"
            return 1
        fi
    fi
    
    log_success "Docker Swarm initialized"
    
    # Create overlay network (ignore if exists)
    docker network rm othcloud-network 2>/dev/null || true
    if ! docker network create --driver overlay --attachable othcloud-network 2>/dev/null; then
        log_warning "Failed to create overlay network, creating bridge network"
        docker network create othcloud-network 2>/dev/null || true
    fi
    
    log_success "Docker network created"
    return 0
}

# Clone repository and prepare environment
clone_repository() {
    log_info "Cloning OTHcloud repository..."
    
    # Remove existing directory if it exists
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Clone the repository
    if ! git clone -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
        log_error "Failed to clone repository"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # Create necessary directories
    mkdir -p /etc/othcloud
    chmod 755 /etc/othcloud
    
    # Generate secure passwords and secrets
    local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local jwt_secret=$(openssl rand -base64 32)
    local ssh_encryption_key=$(openssl rand -base64 32)
    
    # Create .env.production file
    log_info "Creating production environment configuration..."
    cat > .env.production << EOF
# Database
DATABASE_URL="postgresql://othcloud:${postgres_password}@othcloud-postgres:5432/othcloud"

# Security
JWT_SECRET="${jwt_secret}"
SSH_ENCRYPTION_KEY="${ssh_encryption_key}"

# Redis
REDIS_URL="redis://othcloud-redis:6379"

# Cloudflare (optional - configure after installation)
CLOUDFLARE_API_TOKEN=""
CLOUDFLARE_ZONE_ID=""
BASE_DOMAIN=""

# Timeouts
SSH_TIMEOUT=30000
DOCKER_TIMEOUT=30000

# Environment
NODE_ENV=production
NEXTAUTH_URL="http://localhost:3000"
EOF
    
    # Save credentials for later use
    cat > /etc/othcloud/db-credentials << EOF
POSTGRES_USER=othcloud
POSTGRES_DB=othcloud
POSTGRES_PASSWORD=${postgres_password}
DATABASE_URL=postgresql://othcloud:${postgres_password}@othcloud-postgres:5432/othcloud
EOF
    chmod 600 /etc/othcloud/db-credentials
    
    cat > /etc/othcloud/app-secrets << EOF
JWT_SECRET=${jwt_secret}
SSH_ENCRYPTION_KEY=${ssh_encryption_key}
REDIS_URL=redis://othcloud-redis:6379
EOF
    chmod 600 /etc/othcloud/app-secrets
    
    log_success "Repository cloned and configured successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building OTHcloud Docker image..."
    
    cd "$INSTALL_DIR"
    
    # Build the Docker image with retry logic
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Build attempt $attempt of $max_attempts..."
        
        if docker build -t "$DOCKER_IMAGE_NAME:latest" .; then
            log_success "Docker image built successfully"
            return 0
        else
            log_warning "Build attempt $attempt failed"
            if [ $attempt -eq $max_attempts ]; then
                log_error "Failed to build Docker image after $max_attempts attempts"
                log_info "You can try running the build manually with: docker build -t $DOCKER_IMAGE_NAME:latest ."
                exit 1
            fi
            attempt=$((attempt + 1))
            sleep 5
        fi
    done
}

# Setup database
setup_database() {
    log_info "Setting up PostgreSQL database..."
    
    # Source credentials
    source /etc/othcloud/db-credentials
    
    # Create PostgreSQL service (swarm or standalone)
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        # Use Docker Swarm
        docker service create \
            --name othcloud-postgres \
            --constraint 'node.role==manager' \
            --network othcloud-network \
            --env POSTGRES_USER=othcloud \
            --env POSTGRES_DB=othcloud \
            --env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
            --mount type=volume,source=othcloud-postgres-data,target=/var/lib/postgresql/data \
            postgres:16 2>/dev/null || {
                log_warning "Swarm service creation failed, using docker run..."
                docker run -d \
                    --name othcloud-postgres \
                    --network othcloud-network \
                    --env POSTGRES_USER=othcloud \
                    --env POSTGRES_DB=othcloud \
                    --env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
                    -v othcloud-postgres-data:/var/lib/postgresql/data \
                    --restart unless-stopped \
                    postgres:16
            }
    else
        # Use standalone Docker
        docker run -d \
            --name othcloud-postgres \
            --network othcloud-network \
            --env POSTGRES_USER=othcloud \
            --env POSTGRES_DB=othcloud \
            --env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
            -v othcloud-postgres-data:/var/lib/postgresql/data \
            --restart unless-stopped \
            postgres:16 2>/dev/null || {
                # Remove existing container if it exists
                docker rm -f othcloud-postgres 2>/dev/null || true
                docker run -d \
                    --name othcloud-postgres \
                    --network othcloud-network \
                    --env POSTGRES_USER=othcloud \
                    --env POSTGRES_DB=othcloud \
                    --env POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
                    -v othcloud-postgres-data:/var/lib/postgresql/data \
                    --restart unless-stopped \
                    postgres:16
            }
    fi
    
    log_success "PostgreSQL database setup completed"
}

# Setup Redis
setup_redis() {
    log_info "Setting up Redis cache..."
    
    # Create Redis service (swarm or standalone)
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        # Use Docker Swarm
        docker service create \
            --name othcloud-redis \
            --constraint 'node.role==manager' \
            --network othcloud-network \
            --mount type=volume,source=othcloud-redis-data,target=/data \
            redis:7-alpine 2>/dev/null || {
                log_warning "Swarm service creation failed, using docker run..."
                docker run -d \
                    --name othcloud-redis \
                    --network othcloud-network \
                    -v othcloud-redis-data:/data \
                    --restart unless-stopped \
                    redis:7-alpine
            }
    else
        # Use standalone Docker
        docker run -d \
            --name othcloud-redis \
            --network othcloud-network \
            -v othcloud-redis-data:/data \
            --restart unless-stopped \
            redis:7-alpine 2>/dev/null || {
                # Remove existing container if it exists
                docker rm -f othcloud-redis 2>/dev/null || true
                docker run -d \
                    --name othcloud-redis \
                    --network othcloud-network \
                    -v othcloud-redis-data:/data \
                    --restart unless-stopped \
                    redis:7-alpine
            }
    fi
    
    log_success "Redis cache setup completed"
}

# Deploy OTHcloud application
deploy_application() {
    log_info "Deploying OTHcloud application..."
    
    # Source credentials
    source /etc/othcloud/db-credentials
    source /etc/othcloud/app-secrets
    
    # Check if running in Proxmox LXC container
    local endpoint_mode=""
    if is_proxmox_lxc; then
        endpoint_mode="--endpoint-mode dnsrr"
    fi
    
    # Deploy application (swarm or standalone)
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        # Use Docker Swarm
        docker service create \
            --name othcloud-app \
            --replicas 1 \
            --network othcloud-network \
            --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
            --mount type=bind,source=/etc/othcloud,target=/etc/othcloud \
            --mount type=volume,source=othcloud-data,target=/app/data \
            --publish published=3000,target=3000,mode=host \
            --update-parallelism 1 \
            --update-order stop-first \
            --constraint 'node.role == manager' \
            --env NODE_ENV=production \
            --env DATABASE_URL="$DATABASE_URL" \
            --env JWT_SECRET="$JWT_SECRET" \
            --env SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
            --env REDIS_URL="$REDIS_URL" \
            --env CLOUDFLARE_API_TOKEN="" \
            --env CLOUDFLARE_ZONE_ID="" \
            --env BASE_DOMAIN="" \
            --env SSH_TIMEOUT=30000 \
            --env DOCKER_TIMEOUT=30000 \
            $endpoint_mode \
            "$DOCKER_IMAGE_NAME:latest" 2>/dev/null || {
                log_warning "Swarm service creation failed, using docker run..."
                docker run -d \
                    --name othcloud-app \
                    --network othcloud-network \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v /etc/othcloud:/etc/othcloud \
                    -v othcloud-data:/app/data \
                    -p 3000:3000 \
                    --restart unless-stopped \
                    --env NODE_ENV=production \
                    --env DATABASE_URL="$DATABASE_URL" \
                    --env JWT_SECRET="$JWT_SECRET" \
                    --env SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
                    --env REDIS_URL="$REDIS_URL" \
                    --env CLOUDFLARE_API_TOKEN="" \
                    --env CLOUDFLARE_ZONE_ID="" \
                    --env BASE_DOMAIN="" \
                    --env SSH_TIMEOUT=30000 \
                    --env DOCKER_TIMEOUT=30000 \
                    "$DOCKER_IMAGE_NAME:latest"
            }
    else
        # Use standalone Docker
        docker run -d \
            --name othcloud-app \
            --network othcloud-network \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v /etc/othcloud:/etc/othcloud \
            -v othcloud-data:/app/data \
            -p 3000:3000 \
            --restart unless-stopped \
            --env NODE_ENV=production \
            --env DATABASE_URL="$DATABASE_URL" \
            --env JWT_SECRET="$JWT_SECRET" \
            --env SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
            --env REDIS_URL="$REDIS_URL" \
            --env CLOUDFLARE_API_TOKEN="" \
            --env CLOUDFLARE_ZONE_ID="" \
            --env BASE_DOMAIN="" \
            --env SSH_TIMEOUT=30000 \
            --env DOCKER_TIMEOUT=30000 \
            "$DOCKER_IMAGE_NAME:latest" 2>/dev/null || {
                # Remove existing container if it exists
                docker rm -f othcloud-app 2>/dev/null || true
                docker run -d \
                    --name othcloud-app \
                    --network othcloud-network \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v /etc/othcloud:/etc/othcloud \
                    -v othcloud-data:/app/data \
                    -p 3000:3000 \
                    --restart unless-stopped \
                    --env NODE_ENV=production \
                    --env DATABASE_URL="$DATABASE_URL" \
                    --env JWT_SECRET="$JWT_SECRET" \
                    --env SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
                    --env REDIS_URL="$REDIS_URL" \
                    --env CLOUDFLARE_API_TOKEN="" \
                    --env CLOUDFLARE_ZONE_ID="" \
                    --env BASE_DOMAIN="" \
                    --env SSH_TIMEOUT=30000 \
                    --env DOCKER_TIMEOUT=30000 \
                    "$DOCKER_IMAGE_NAME:latest"
            }
    fi
    
    log_success "OTHcloud application deployed successfully"
}

# Setup Traefik reverse proxy (optional)
setup_traefik() {
    log_info "Setting up Traefik reverse proxy..."
    
    # Create Traefik configuration directory
    mkdir -p /etc/othcloud/traefik/dynamic
    
    # Create basic Traefik configuration
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

    # Deploy Traefik (skip if ports are occupied)
    if ! ss -tulnp | grep -E ":80|:443" >/dev/null; then
        docker run -d \
            --name othcloud-traefik \
            --restart unless-stopped \
            -v /etc/othcloud/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
            -v /var/run/docker.sock:/var/run/docker.sock:ro \
            -p 80:80/tcp \
            -p 443:443/tcp \
            -p 8080:8080/tcp \
            traefik:v3.1.2 2>/dev/null || {
                log_warning "Traefik deployment failed - ports may be in use"
            }
        
        # Connect to network if successful
        docker network connect othcloud-network othcloud-traefik 2>/dev/null || true
        
        log_success "Traefik reverse proxy setup completed"
    else
        log_warning "Ports 80/443 are in use, skipping Traefik setup"
    fi
}

# Wait for services
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    local retries=30
    local wait_time=10
    
    # Wait for database to be ready
    for i in $(seq 1 10); do
        if docker logs othcloud-postgres 2>&1 | grep -q "database system is ready"; then
            break
        fi
        log_info "Waiting for database... ($i/10)"
        sleep 5
    done
    
    # Wait for application to be ready
    for i in $(seq 1 $retries); do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            log_success "OTHcloud is ready!"
            return 0
        fi
        
        log_info "Waiting for application... ($i/$retries)"
        sleep $wait_time
    done
    
    log_warning "Application may still be starting up. Check logs with: docker logs othcloud-app"
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/othcloud.service << EOF
[Unit]
Description=OTHcloud Application Services
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/bash -c 'docker start othcloud-postgres othcloud-redis othcloud-app 2>/dev/null || true'
ExecStop=/bin/bash -c 'docker stop othcloud-app othcloud-redis othcloud-postgres 2>/dev/null || true'
TimeoutStartSec=120
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable othcloud.service >/dev/null 2>&1 || true
    
    log_success "Systemd service created"
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
    install_pnpm
    
    # Setup Docker Swarm (optional)
    setup_docker_swarm || log_warning "Using standalone Docker mode"
    
    clone_repository
    build_docker_image
    
    setup_database
    setup_redis
    deploy_application
    setup_traefik
    
    create_systemd_service
    wait_for_services
    
    # Get server IP for final message
    local server_ip=$(get_server_ip)
    local formatted_addr
    if echo "$server_ip" | grep -q ':'; then
        formatted_addr="[$server_ip]"
    else
        formatted_addr="$server_ip"
    fi
    
    echo ""
    log_success "🎉 OTHcloud installation completed!"
    echo ""
    log_info "📋 Installation Summary:"
    echo "   • Application URL: http://${formatted_addr}:3000"
    echo "   • Installation Directory: $INSTALL_DIR"
    echo "   • Configuration: /etc/othcloud/"
    echo ""
    log_info "🔧 Useful Commands:"
    echo "   • View logs: docker logs othcloud-app"
    echo "   • Restart services: systemctl restart othcloud"
    echo "   • Update: $INSTALL_DIR/install.sh update"
    echo ""
    log_warning "⚠️  Default admin credentials:"
    echo "   • Email: damo@damo.com"
    echo "   • Password: admin"
    echo "   • Please change these after first login!"
    echo ""
    log_info "🔗 Access your dashboard at: http://${formatted_addr}:3000"
}

# Update function
update_othcloud() {
    log_info "🔄 Updating OTHcloud..."
    
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "OTHcloud installation directory not found. Please reinstall."
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    
    # Pull latest changes
    git pull origin "$REPO_BRANCH"
    
    # Rebuild image
    docker build -t "$DOCKER_IMAGE_NAME:latest" .
    
    # Update services
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        docker service update --image "$DOCKER_IMAGE_NAME:latest" othcloud-app
    else
        docker stop othcloud-app
        docker rm othcloud-app
        # Re-source credentials and redeploy
        source /etc/othcloud/db-credentials
        source /etc/othcloud/app-secrets
        
        docker run -d \
            --name othcloud-app \
            --network othcloud-network \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v /etc/othcloud:/etc/othcloud \
            -v othcloud-data:/app/data \
            -p 3000:3000 \
            --restart unless-stopped \
            --env NODE_ENV=production \
            --env DATABASE_URL="$DATABASE_URL" \
            --env JWT_SECRET="$JWT_SECRET" \
            --env SSH_ENCRYPTION_KEY="$SSH_ENCRYPTION_KEY" \
            --env REDIS_URL="$REDIS_URL" \
            --env CLOUDFLARE_API_TOKEN="" \
            --env CLOUDFLARE_ZONE_ID="" \
            --env BASE_DOMAIN="" \
            --env SSH_TIMEOUT=30000 \
            --env DOCKER_TIMEOUT=30000 \
            "$DOCKER_IMAGE_NAME:latest"
    fi
    
    log_success "✅ OTHcloud updated successfully!"
}

# Restart services function
restart_services() {
    log_info "🔄 Restarting OTHcloud services..."
    
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        # Restart Docker services
        docker service update --force othcloud-app 2>/dev/null || true
        docker service update --force othcloud-postgres 2>/dev/null || true
        docker service update --force othcloud-redis 2>/dev/null || true
    else
        # Restart containers
        docker restart othcloud-postgres othcloud-redis othcloud-app 2>/dev/null || true
    fi
    
    docker restart othcloud-traefik 2>/dev/null || true
    
    log_success "✅ Services restarted successfully!"
}

# Uninstall function
uninstall_othcloud() {
    log_warning "🗑️  Uninstalling OTHcloud..."
    
    # Stop systemd service
    systemctl stop othcloud.service 2>/dev/null || true
    systemctl disable othcloud.service 2>/dev/null || true
    rm -f /etc/systemd/system/othcloud.service
    systemctl daemon-reload
    
    # Remove Docker services and containers
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        docker service rm othcloud-app othcloud-postgres othcloud-redis 2>/dev/null || true
    else
        docker stop othcloud-app othcloud-postgres othcloud-redis 2>/dev/null || true
        docker rm othcloud-app othcloud-postgres othcloud-redis 2>/dev/null || true
    fi
    
    docker stop othcloud-traefik 2>/dev/null || true
    docker rm othcloud-traefik 2>/dev/null || true
    
    # Remove network
    docker network rm othcloud-network 2>/dev/null || true
    
    # Remove images
    docker rmi "$DOCKER_IMAGE_NAME:latest" 2>/dev/null || true
    
    # Leave swarm
    docker swarm leave --force 2>/dev/null || true
    
    log_warning "⚠️  Data volumes preserved. To remove completely:"
    echo "   docker volume rm othcloud-postgres-data othcloud-redis-data othcloud-data"
    echo "   rm -rf $INSTALL_DIR /etc/othcloud"
    
    log_success "✅ OTHcloud uninstalled (data preserved)"
}

# Show status
show_status() {
    echo "=== OTHcloud Status ==="
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        docker service ls | grep othcloud || echo "No services running"
    else
        docker ps | grep othcloud || echo "No containers running"
    fi
    echo ""
    echo "=== Service Health ==="
    curl -s http://localhost:3000 2>/dev/null && echo "✅ Application healthy" || echo "❌ Application not responding"
}

# Show logs
show_logs() {
    if [ -n "$1" ]; then
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            docker service logs -f "othcloud-$1"
        else
            docker logs -f "othcloud-$1"
        fi
    else
        echo "Available services: app, postgres, redis"
        echo "Usage: $0 logs [app|postgres|redis]"
        echo "Showing app logs:"
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            docker service logs -f othcloud-app
        else
            docker logs -f othcloud-app
        fi
    fi
}

# Main script logic
case "$1" in
    "update")
        update_othcloud
        ;;
    "restart-services")
        restart_services
        ;;
    "uninstall")
        read -p "Are you sure you want to uninstall OTHcloud? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_othcloud
        else
            echo "Uninstall cancelled."
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