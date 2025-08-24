#!/bin/bash

# OthCloud Quick Installer
# Usage: curl -sSL https://raw.githubusercontent.com/your-username/othcloud/main/install.sh | bash
# Or: wget -qO- https://raw.githubusercontent.com/your-username/othcloud/main/install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - Update these with your actual repo details
REPO_URL="${REPO_URL:-https://github.com/your-username/othcloud.git}"
INSTALL_DIR="${INSTALL_DIR:-othcloud}"

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════╗"
    echo "║       🚀 OthCloud Installer          ║"
    echo "║    One-command setup & deployment    ║"
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

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        log "Installing git..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y git
        elif command -v brew &> /dev/null; then
            brew install git
        else
            error "Could not install git automatically. Please install git manually and try again."
        fi
    fi
}

# Clone repository
clone_repo() {
    log "Cloning OthCloud repository..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        warn "Directory $INSTALL_DIR already exists. Updating..."
        cd "$INSTALL_DIR"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "Could not update repository"
    else
        git clone "$REPO_URL" "$INSTALL_DIR"
        cd "$INSTALL_DIR"
    fi
}

# Make scripts executable
setup_permissions() {
    log "Setting up permissions..."
    chmod +x start.sh 2>/dev/null || warn "Could not make start.sh executable"
    if [[ -f install.sh ]]; then
        chmod +x install.sh
    fi
}

# Start the application
start_app() {
    log "Starting OthCloud..."
    echo ""
    echo -e "${YELLOW}Choose installation mode:${NC}"
    echo "1) Development (recommended for testing and development)"
    echo "2) Production (optimized build for deployment)"
    echo "3) Setup only (install dependencies without starting)"
    echo ""
    
    read -p "Enter choice [1-3] (default: 1): " choice
    choice=${choice:-1}
    
    case $choice in
        1)
            log "Starting in development mode..."
            if command -v make &> /dev/null; then
                make dev
            else
                ./start.sh --dev
            fi
            ;;
        2)
            log "Starting in production mode..."
            if command -v make &> /dev/null; then
                make prod
            else
                ./start.sh --prod
            fi
            ;;
        3)
            log "Setting up dependencies only..."
            ./start.sh --setup
            show_completion_setup_only
            return
            ;;
        *)
            log "Invalid choice. Starting in development mode..."
            ./start.sh --dev
            ;;
    esac
}

# Show completion message for setup only
show_completion_setup_only() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║       ✅ Setup Complete!             ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Dependencies installed! Next steps:${NC}"
    echo ""
    echo -e "${YELLOW}Start your application:${NC}"
    echo "  make dev       # Development mode"
    echo "  make prod      # Production mode"
    echo "  ./start.sh --dev   # Alternative"
    echo ""
    echo -e "${YELLOW}Other useful commands:${NC}"
    echo "  make help      # Show all commands"
    echo "  make status    # Check service status"
    echo "  make logs      # View logs"
}

# Show completion message
show_completion() {
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         🎉 Installation Complete!    ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Your OthCloud is now running!${NC}"
    echo ""
    echo -e "${YELLOW}Access your application:${NC}"
    echo "  🌐 Main App: http://localhost:3000"
    echo "  📊 Traefik Dashboard: http://localhost:8080"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  make dev       # Start development mode"
    echo "  make prod      # Start production mode"
    echo "  make stop      # Stop all services"
    echo "  make logs      # View logs"
    echo "  make status    # Check service status"
    echo "  make help      # Show all available commands"
    echo ""
    echo -e "${BLUE}For more info, see the README.md file${NC}"
    echo ""
    echo -e "${GREEN}Happy coding! 🚀${NC}"
}

# Main installation
main() {
    print_banner
    
    log "Starting OthCloud installation..."
    echo ""
    
    check_git
    clone_repo
    setup_permissions
    start_app
    
    if [[ "$choice" != "3" ]]; then
        show_completion
    fi
}

# Handle Ctrl+C
trap 'echo -e "\n${RED}Installation cancelled.${NC}"; exit 1' INT

# Check if we're being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Run main function if executed directly
    main "$@"
fi
