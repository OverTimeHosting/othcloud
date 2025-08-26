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

# Check port availability
check_ports() {
    local ports=("80" "443" "3000")
    
    for port in "${ports[@]}"; do
        if ss -tulnp | grep ":${port} " >/dev/null; then
            log_warning "Port ${port} is already in use"
            if [ "$port" = "3000" ]; then
                log_error "Port 3000 is required for OTHcloud. Please free this port and try again."
                exit 1
            fi
        fi
    done
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
        software-properties-common

    log_success "System dependencies installed"
}

# Install Docker
install_docker() {
    if command_exists docker; then
        log_info "Docker already installed"
        return
    fi

    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update and install Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
        if [ "$major_version" -ge "20" ]; then
            log_info "Node.js $node_version is already installed"
            return
        fi
    fi

    log_info "Installing Node.js 20..."
    
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
    
    # Enable corepack
    corepack enable
    corepack prepare pnpm@9.12.0 --activate

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
    
    # Leave any existing swarm
    docker swarm leave --force 2>/dev/null || true
    
    local advertise_addr="${ADVERTISE_ADDR:-$(get_server_ip)}"
    log_info "Using advertise address: $advertise_addr"
    
    # Check if running in Proxmox LXC container
    local endpoint_mode=""
    if is_proxmox_lxc; then
        log_warning "Detected Proxmox LXC container environment!"
        log_info "Adding --endpoint-mode dnsrr for LXC compatibility"
        endpoint_mode="--endpoint-mode dnsrr"
        sleep 3
    fi
    
    # Initialize swarm
    docker swarm init --advertise-addr "$advertise_addr"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to initialize Docker Swarm"
        exit 1
    fi
    
    log_success "Docker Swarm initialized"
    
    # Create overlay network
    docker network rm -f othcloud-network 2>/dev/null || true
    docker network create --driver overlay --attachable othcloud-network
    
    log_success "Docker network created"
}

# Clone repository
clone_repository() {
    log_info "Cloning OTHcloud repository..."
    
    # Remove existing directory if it exists
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    
    # Clone the repository
    git clone -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to clone repository"
        exit 1
    fi
    
    cd "$INSTALL_DIR"
    log_success "Repository cloned successfully"
}

# Build Docker image
build_docker_image() {
    log_info "Building OTHcloud Docker image..."
    
    cd "$INSTALL_DIR"
    
    # Build the Docker image
    docker build -t "$DOCKER_IMAGE_NAME:latest" .
    
    if [ $? -ne 0 ]; then
        log_error "Failed to build Docker image"
        exit 1
    fi
    
    log_success "Docker image built successfully"
}

# Setup database
setup_database() {
    log_info "Setting up PostgreSQL database..."
    
    # Generate secure password
    local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    
    # Create PostgreSQL service
    docker service create \
        --name othcloud-postgres \
        --constraint 'node.role==manager' \
        --network othcloud-network \
        --env POSTGRES_USER=othcloud \
        --env POSTGRES_DB=othcloud \
        --env POSTGRES_PASSWORD="$postgres_password" \
        --mount type=volume,source=othcloud-postgres-data,target=/var/lib/postgresql/data \
        postgres:16
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create PostgreSQL service"
        exit 1
    fi
    
    # Save database credentials
    mkdir -p /etc/othcloud
    cat > /etc/othcloud/db-credentials << EOF
POSTGRES_USER=othcloud
POSTGRES_DB=othcloud
POSTGRES_PASSWORD=$postgres_password
DATABASE_URL=postgresql://othcloud:$postgres_password@othcloud-postgres:5432/othcloud
EOF
    chmod 600 /etc/othcloud/db-credentials
    
    log_success "PostgreSQL database setup completed"
}

# Setup Redis
setup_redis() {
    log_info "Setting up Redis cache..."
    
    docker service create \
        --name othcloud-redis \
        --constraint 'node.role==manager' \
        --network othcloud-network \
        --mount type=volume,source=othcloud-redis-data,target=/data \
        redis:7-alpine
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create Redis service"
        exit 1
    fi
    
    log_success "Redis cache setup completed"
}

# Deploy OTHcloud application
deploy_application() {
    log_info "Deploying OTHcloud application..."
    
    # Source database credentials
    source /etc/othcloud/db-credentials
    
    # Generate additional secrets
    local jwt_secret=$(openssl rand -base64 32)
    local ssh_encryption_key=$(openssl rand -base64 32)
    
    # Check if running in Proxmox LXC container
    local endpoint_mode=""
    if is_proxmox_lxc; then
        endpoint_mode="--endpoint-mode dnsrr"
    fi
    
    # Create the main application service
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
        --env JWT_SECRET="$jwt_secret" \
        --env SSH_ENCRYPTION_KEY="$ssh_encryption_key" \
        --env REDIS_URL="redis://othcloud-redis:6379" \
        --env CLOUDFLARE_API_TOKEN="" \
        --env CLOUDFLARE_ZONE_ID="" \
        --env BASE_DOMAIN="" \
        --env SSH_TIMEOUT=30000 \
        --env DOCKER_TIMEOUT=30000 \
        $endpoint_mode \
        "$DOCKER_IMAGE_NAME:latest"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to deploy OTHcloud application"
        exit 1
    fi
    
    # Save application secrets
    cat > /etc/othcloud/app-secrets << EOF
JWT_SECRET=$jwt_secret
SSH_ENCRYPTION_KEY=$ssh_encryption_key
REDIS_URL=redis://othcloud-redis:6379
EOF
    chmod 600 /etc/othcloud/app-secrets
    
    log_success "OTHcloud application deployed successfully"
}

# Setup Traefik reverse proxy
setup_traefik() {
    log_info "Setting up Traefik reverse proxy..."
    
    # Create Traefik configuration directory
    mkdir -p /etc/othcloud/traefik/dynamic
    
    # Create Traefik configuration
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
  file:
    directory: /etc/traefik/dynamic
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /etc/traefik/acme.json
      httpChallenge:
        entryPoint: web

log:
  level: INFO
EOF

    # Create dynamic configuration
    cat > /etc/othcloud/traefik/dynamic/othcloud.yml << 'EOF'
http:
  routers:
    othcloud:
      rule: "PathPrefix(`/`)"
      service: othcloud
      entryPoints:
        - web

  services:
    othcloud:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:3000"
EOF

    # Deploy Traefik
    docker run -d \
        --name othcloud-traefik \
        --restart unless-stopped \
        -v /etc/othcloud/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
        -v /etc/othcloud/traefik/dynamic:/etc/traefik/dynamic:ro \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -p 80:80/tcp \
        -p 443:443/tcp \
        -p 443:443/udp \
        traefik:v3.1.2
    
    # Connect to network
    docker network connect othcloud-network othcloud-traefik
    
    log_success "Traefik reverse proxy setup completed"
}

# Wait for services
wait_for_services() {
    log_info "Waiting for services to be ready..."
    
    local retries=30
    local wait_time=10
    
    for i in $(seq 1 $retries); do
        if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
            log_success "OTHcloud is ready!"
            return 0
        fi
        
        log_info "Waiting for services... ($i/$retries)"
        sleep $wait_time
    done
    
    log_warning "Services may still be starting up. Please check logs if needed."
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
ExecStart=/bin/bash -c 'docker service ls | grep othcloud || (docker swarm init --advertise-addr \$(curl -s ifconfig.io) && /opt/othcloud/install.sh restart-services)'
ExecStop=/bin/bash -c 'docker service rm othcloud-app othcloud-postgres othcloud-redis; docker stop othcloud-traefik; docker rm othcloud-traefik'
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable othcloud.service
    
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
    
    setup_docker_swarm
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
    echo "   • Traefik Dashboard: http://${formatted_addr}:8080"
    echo "   • Installation Directory: $INSTALL_DIR"
    echo "   • Configuration: /etc/othcloud/"
    echo ""
    log_info "🔧 Useful Commands:"
    echo "   • View logs: docker service logs -f othcloud-app"
    echo "   • Restart services: systemctl restart othcloud"
    echo "   • Update: $INSTALL_DIR/install.sh update"
    echo ""
    log_warning "⚠️  Default admin credentials:"
    echo "   • Email: damo@damo.com"
    echo "   • Password: admin"
    echo "   • Please change these after first login!"
    echo ""
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
    
    # Update service
    docker service update --image "$DOCKER_IMAGE_NAME:latest" othcloud-app
    
    log_success "✅ OTHcloud updated successfully!"
}

# Restart services function
restart_services() {
    log_info "🔄 Restarting OTHcloud services..."
    
    # Restart Docker services
    docker service update --force othcloud-app
    docker service update --force othcloud-postgres
    docker service update --force othcloud-redis
    docker restart othcloud-traefik
    
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
    docker service rm othcloud-app othcloud-postgres othcloud-redis 2>/dev/null || true
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
    docker service ls | grep othcloud || echo "No services running"
    echo ""
    docker ps | grep othcloud || echo "No containers running"
    echo ""
    echo "=== Service Health ==="
    curl -s http://localhost:3000/api/health 2>/dev/null && echo "✅ Application healthy" || echo "❌ Application not responding"
}

# Show logs
show_logs() {
    if [ -n "$1" ]; then
        docker service logs -f "othcloud-$1"
    else
        echo "Available services: app, postgres, redis"
        echo "Usage: $0 logs [app|postgres|redis]"
        echo "Showing app logs:"
        docker service logs -f othcloud-app
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