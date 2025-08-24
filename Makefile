.PHONY: help install dev prod stop clean logs status test restart quick

# Default target
.DEFAULT_GOAL := help

# Colors
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)OthCloud - Available Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "$(GREEN)%-12s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies and setup environment
	@echo "$(YELLOW)Installing OthCloud...$(NC)"
	@chmod +x start.sh 2>/dev/null || true
	@./start.sh --setup

dev: ## Start in development mode
	@echo "$(YELLOW)Starting OthCloud in development mode...$(NC)"
	@chmod +x start.sh 2>/dev/null || true
	@./start.sh --dev

prod: ## Start in production mode
	@echo "$(YELLOW)Starting OthCloud in production mode...$(NC)"
	@chmod +x start.sh 2>/dev/null || true
	@./start.sh --prod

stop: ## Stop all services
	@echo "$(YELLOW)Stopping OthCloud services...$(NC)"
	@chmod +x start.sh 2>/dev/null || true
	@./start.sh --stop

clean: ## Clean up everything (containers, volumes, dependencies)
	@echo "$(RED)Cleaning up everything...$(NC)"
	@chmod +x start.sh 2>/dev/null || true
	@./start.sh --clean

logs: ## Show logs from all services
	@echo "$(BLUE)Showing logs...$(NC)"
	@docker compose logs -f

status: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker compose ps

restart: stop dev ## Restart services

quick: ## Quick start (skip checks, for development)
	@echo "$(YELLOW)Quick starting OthCloud...$(NC)"
	@docker compose up -d
	@sleep 5
	@pnpm run dokploy:dev

# Additional useful commands
deps: ## Update dependencies
	@echo "$(YELLOW)Updating dependencies...$(NC)"
	@pnpm update

format: ## Format code
	@echo "$(YELLOW)Formatting code...$(NC)"
	@pnpm run format-and-lint:fix

check: ## Check code quality
	@echo "$(YELLOW)Checking code quality...$(NC)"
	@pnpm run format-and-lint

build: ## Build the application
	@echo "$(YELLOW)Building application...$(NC)"
	@pnpm run dokploy:build

test: ## Run tests
	@echo "$(YELLOW)Running tests...$(NC)"
	@pnpm test

reset: ## Reset everything and start fresh
	@echo "$(RED)Resetting everything...$(NC)"
	@make clean
	@make dev

# Database commands
db-studio: ## Open database studio
	@echo "$(BLUE)Opening database studio at http://localhost:4983$(NC)"
	@pnpm run studio

reset-db: ## Reset database
	@echo "$(RED)Resetting database...$(NC)"
	@pnpm run db:clean
	@pnpm run migration:run

# Docker commands  
docker-logs: ## Show Docker container logs
	@docker compose logs -f

docker-ps: ## Show Docker container status
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Network commands
ports: ## Show port usage
	@echo "$(BLUE)Checking port usage:$(NC)"
	@netstat -tuln 2>/dev/null | grep -E ':(3000|5432|6379|80|443|8080)' || echo "No conflicts found"
