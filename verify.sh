#!/bin/bash

# OthCloud Directory Verification Script
# Helps diagnose setup issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_item() {
    local name="$1"
    local path="$2"
    
    echo -n "Checking $name... "
    
    if [[ -e "$path" ]]; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC} (missing: $path)"
        return 1
    fi
}

main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║      🔍 OthCloud Verification        ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    log "Checking directory structure..."
    echo ""
    
    # Show current directory
    log "Current directory: $(pwd)"
    log "Directory name: $(basename $(pwd))"
    echo ""
    
    # Check critical files
    echo -e "${BLUE}Core Files:${NC}"
    check_item "package.json" "package.json"
    check_item "start.sh" "start.sh"
    check_item "docker-compose.yml" "docker-compose.yml"
    check_item "Makefile" "Makefile"
    echo ""
    
    # Check app structure
    echo -e "${BLUE}App Structure:${NC}"
    check_item "apps directory" "apps"
    check_item "apps/dokploy" "apps/dokploy"
    check_item "apps/dokploy/package.json" "apps/dokploy/package.json"
    
    # Check .env files
    if [[ -f "apps/dokploy/.env.example" ]]; then
        check_item ".env.example" "apps/dokploy/.env.example"
    else
        warn "apps/dokploy/.env.example missing - will create default .env"
    fi
    
    if [[ -f "apps/dokploy/.env" ]]; then
        check_item ".env file" "apps/dokploy/.env"
    else
        warn "apps/dokploy/.env missing - will be created automatically"
    fi
    echo ""
    
    # Show directory contents
    echo -e "${BLUE}Directory Contents:${NC}"
    ls -la | head -10
    echo ""
    
    # Check if we're in othcloud directory
    if [[ "$(basename $(pwd))" == "othcloud" ]]; then
        log "✓ You're in the othcloud directory"
    else
        warn "You might not be in the othcloud directory"
        log "Expected directory name: othcloud"
        log "Current directory name: $(basename $(pwd))"
    fi
    echo ""
    
    # Final assessment
    if [[ -f "package.json" && -f "start.sh" && -d "apps/dokploy" ]]; then
        echo -e "${GREEN}"
        echo "╔══════════════════════════════════════╗"
        echo "║        ✅ Verification Passed!       ║"
        echo "╚══════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        log "Your OthCloud directory looks good!"
        log "You can now run: sudo make dev"
    else
        echo -e "${RED}"
        echo "╔══════════════════════════════════════╗"
        echo "║        ❌ Verification Failed!       ║"
        echo "╚══════════════════════════════════════╝"
        echo -e "${NC}"
        echo ""
        error "Directory structure is incomplete or corrupted"
        echo ""
        echo -e "${YELLOW}Possible fixes:${NC}"
        echo "1. Make sure you cloned the repository correctly:"
        echo "   git clone https://github.com/OverTimeHosting/othcloud.git"
        echo ""
        echo "2. Make sure you're in the othcloud directory:"
        echo "   cd othcloud"
        echo ""
        echo "3. Try cloning to a fresh directory:"
        echo "   cd .. && rm -rf othcloud"
        echo "   git clone https://github.com/OverTimeHosting/othcloud.git"
        echo "   cd othcloud"
    fi
}

main "$@"
