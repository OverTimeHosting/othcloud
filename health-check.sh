#!/bin/bash

# OthCloud Health Check Script
# Verifies that all services and dependencies are working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║       🔍 OthCloud Health Check       ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

check_item() {
    local name="$1"
    local command="$2"
    local expected="$3"
    local optional="$4"
    
    echo -n "Checking $name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        if [[ "$optional" == "optional" ]]; then
            echo -e "${YELLOW}⚠ (optional)${NC}"
            return 0
        else
            echo -e "${RED}✗${NC}"
            return 1
        fi
    fi
}

check_port() {
    local port="$1"
    local service="$2"
    
    echo -n "Checking port $port ($service)... "
    
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ (in use)${NC}"
    else
        echo -e "${YELLOW}○ (free)${NC}"
    fi
}

check_service() {
    local service="$1"
    echo -n "Checking Docker service $service... "
    
    if docker compose ps --format json 2>/dev/null | grep -q "\"Service\":\"$service\"" || docker compose ps | grep -q "$service"; then
        echo -e "${GREEN}✓ (running)${NC}"
    else
        echo -e "${RED}✗ (not running)${NC}"
    fi
}

main() {
    print_header
    echo "Checking system requirements and service status..."
    echo ""
    
    # System Requirements
    echo -e "${BLUE}System Requirements:${NC}"
    check_item "Docker" "docker --version"
    check_item "Docker Compose" "docker compose version"
    check_item "Node.js" "node --version"
    check_item "pnpm" "pnpm --version"
    check_item "Git" "git --version"
    check_item "Make" "make --version" "" "optional"
    echo ""
    
    # Port Status
    echo -e "${BLUE}Port Status:${NC}"
    check_port 3000 "OthCloud App"
    check_port 5432 "PostgreSQL"
    check_port 6379 "Redis"
    check_port 80 "HTTP"
    check_port 443 "HTTPS"
    check_port 8080 "Traefik Dashboard"
    echo ""
    
    # Docker Services
    echo -e "${BLUE}Docker Services:${NC}"
    if docker compose ps &>/dev/null; then
        check_service "postgres"
        check_service "redis"
        check_service "traefik"
    else
        echo "Docker Compose services not running or not found"
    fi
    echo ""
    
    # File Structure
    echo -e "${BLUE}Project Structure:${NC}"
    check_item "package.json" "test -f package.json"
    check_item "docker-compose.yml" "test -f docker-compose.yml"
    check_item "start.sh" "test -f start.sh"
    check_item "Makefile" "test -f Makefile"
    check_item ".env file" "test -f apps/dokploy/.env"
    check_item "data directory" "test -d data"
    echo ""
    
    # Network Connectivity
    echo -e "${BLUE}Network Tests:${NC}"
    check_item "Internet connectivity" "curl -s --connect-timeout 5 https://google.com > /dev/null"
    check_item "Docker Hub access" "docker pull hello-world:latest > /dev/null 2>&1 && docker rmi hello-world:latest > /dev/null 2>&1"
    echo ""
    
    # Application Tests (if running)
    echo -e "${BLUE}Application Tests:${NC}"
    if check_item "App responding" "curl -s --connect-timeout 5 http://localhost:3000 > /dev/null" "" "optional"; then
        check_item "App health" "curl -s http://localhost:3000/api/health | grep -q 'ok'" "" "optional"
    fi
    
    if check_item "Traefik responding" "curl -s --connect-timeout 5 http://localhost:8080 > /dev/null" "" "optional"; then
        echo "Traefik dashboard is accessible"
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}Quick Commands:${NC}"
    echo "  make dev      - Start development mode"
    echo "  make status   - Show service status"  
    echo "  make logs     - Show service logs"
    echo "  make stop     - Stop all services"
    echo "  make help     - Show all commands"
    echo ""
    
    echo -e "${GREEN}Health check complete!${NC}"
    echo "If you see any issues above, try:"
    echo "  make clean && make dev  # Reset and restart"
    echo "  make logs              # Check error messages"
}

main "$@"
