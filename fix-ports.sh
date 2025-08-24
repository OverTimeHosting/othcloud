#!/bin/bash

# Port Conflict Resolver Script
# Helps resolve port conflicts automatically

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

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║      🔧 Port Conflict Resolver       ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
}

check_port_usage() {
    local port=$1
    local service_name=""
    
    if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        service_name=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f2 | head -1)
        echo "in_use:$service_name"
    else
        echo "free"
    fi
}

main() {
    print_banner
    log "Checking for port conflicts..."
    echo ""
    
    # Check critical ports
    local ports=(80 443 3000 5432 6379 8080)
    local conflicts=()
    
    for port in "${ports[@]}"; do
        local status=$(check_port_usage $port)
        echo -n "Port $port: "
        
        if [[ $status == "free" ]]; then
            echo -e "${GREEN}✓ Available${NC}"
        else
            local service=$(echo $status | cut -d':' -f2)
            echo -e "${RED}✗ Used by $service${NC}"
            conflicts+=("$port:$service")
        fi
    done
    
    echo ""
    
    if [[ ${#conflicts[@]} -eq 0 ]]; then
        echo -e "${GREEN}"
        echo "╔══════════════════════════════════════╗"
        echo "║        ✅ No Conflicts Found!        ║"
        echo "╚══════════════════════════════════════╝"
        echo -e "${NC}"
        log "All ports are available. You can run: sudo make dev"
        exit 0
    fi
    
    echo -e "${YELLOW}"
    echo "╔══════════════════════════════════════╗"
    echo "║       ⚠️ Port Conflicts Detected      ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    
    # Provide solutions for each conflict
    for conflict in "${conflicts[@]}"; do
        local port=$(echo $conflict | cut -d':' -f1)
        local service=$(echo $conflict | cut -d':' -f2)
        
        echo -e "${BLUE}Port $port (used by $service):${NC}"
        
        case $port in
            80|443)
                echo "  Impact: Traefik will fail to start, but main app will work on port 3000"
                case $service in
                    nginx)
                        echo "  Solution: sudo systemctl stop nginx"
                        echo "  Restart later: sudo systemctl start nginx"
                        ;;
                    apache2|httpd)
                        echo "  Solution: sudo systemctl stop apache2 # or httpd"
                        echo "  Restart later: sudo systemctl start apache2"
                        ;;
                    *)
                        echo "  Solution: Stop the service using port $port"
                        echo "  Find process: sudo lsof -i :$port"
                        echo "  Kill process: sudo kill \\$(sudo lsof -t -i :$port)"
                        ;;
                esac
                ;;
            3000)
                echo "  Impact: ❌ CRITICAL - Main application cannot start"
                echo "  Solution: MUST stop the service using port 3000"
                echo "  Find process: sudo lsof -i :3000"
                echo "  Kill process: sudo kill \\$(sudo lsof -t -i :3000)"
                ;;
            5432)
                echo "  Impact: Database conflicts - may cause issues"
                echo "  Solution: Stop other PostgreSQL instances"
                echo "  Command: sudo systemctl stop postgresql"
                ;;
            6379)
                echo "  Impact: Redis conflicts - may cause issues"
                echo "  Solution: Stop other Redis instances"
                echo "  Command: sudo systemctl stop redis-server"
                ;;
            8080)
                echo "  Impact: Traefik dashboard won't be accessible"
                echo "  Solution: Stop service using port 8080 or ignore"
                ;;
        esac
        echo ""
    done
    
    # Quick fix options
    echo -e "${BLUE}Quick Fix Options:${NC}"
    echo ""
    echo "1. Auto-stop common web servers:"
    echo "   sudo systemctl stop nginx apache2 httpd"
    echo ""
    echo "2. Continue anyway (main app will still work on port 3000):"
    echo "   sudo make dev"
    echo ""
    echo "3. Use alternative ports for Traefik:"
    echo "   Edit docker-compose.yml to use ports 8080:80 and 8443:443"
    echo ""
    
    # Offer to auto-fix
    echo -n "Auto-stop nginx/apache to free ports 80/443? [y/N]: "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log "Stopping common web servers..."
        sudo systemctl stop nginx 2>/dev/null || true
        sudo systemctl stop apache2 2>/dev/null || true  
        sudo systemctl stop httpd 2>/dev/null || true
        
        # Re-check ports 80 and 443
        local port80=$(check_port_usage 80)
        local port443=$(check_port_usage 443)
        
        if [[ $port80 == "free" && $port443 == "free" ]]; then
            log "✅ Ports 80 and 443 are now available!"
            log "You can now run: sudo make dev"
        else
            warn "Some ports are still in use. Check manually with: sudo lsof -i :80 -i :443"
        fi
    fi
    
    echo ""
    log "💡 Tip: Even with port conflicts, your app should work on http://localhost:3000"
    log "Only Traefik features (routing, SSL) will be affected by port 80/443 conflicts"
}

main "$@"
