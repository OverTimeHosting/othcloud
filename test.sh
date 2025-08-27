#!/bin/bash

# OTHcloud Installation Test Script
# Tests the installation to ensure everything is working correctly

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🧪 OTHcloud Installation Test"
echo "==============================="
echo ""

# Test Docker
echo -n "Testing Docker... "
if docker --version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${RED}❌ FAILED${NC}"
    echo "Docker is not installed or not running"
fi

# Test containers
echo -n "Testing containers... "
if docker ps | grep -q othcloud; then
    echo -e "${GREEN}✅ OK${NC}"
    running_containers=$(docker ps | grep othcloud | wc -l)
    echo "   Found $running_containers OTHcloud containers running"
else
    echo -e "${RED}❌ FAILED${NC}"
    echo "No OTHcloud containers are running"
fi

# Test network
echo -n "Testing network... "
if docker network ls | grep -q othcloud-network; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "OTHcloud network not found"
fi

# Test volumes
echo -n "Testing volumes... "
volume_count=$(docker volume ls | grep othcloud | wc -l)
if [ "$volume_count" -gt 0 ]; then
    echo -e "${GREEN}✅ OK${NC}"
    echo "   Found $volume_count OTHcloud volumes"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "No OTHcloud volumes found"
fi

# Test web service
echo -n "Testing web service... "
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OK${NC}"
    echo "   Application is responding on port 3000"
else
    echo -e "${RED}❌ FAILED${NC}"
    echo "Application is not responding on port 3000"
fi

# Test database connection
echo -n "Testing database... "
if docker logs othcloud-postgres 2>&1 | grep -q "database system is ready"; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "Database may still be starting"
fi

# Test Redis
echo -n "Testing Redis... "
if docker exec othcloud-redis redis-cli ping 2>/dev/null | grep -q PONG; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "Redis connection test failed"
fi

# Test configuration files
echo -n "Testing configuration... "
if [ -f "/etc/othcloud/db-credentials" ] && [ -f "/etc/othcloud/app-secrets" ]; then
    echo -e "${GREEN}✅ OK${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "Some configuration files are missing"
fi

echo ""
echo "📊 Test Summary:"
echo "=================="

# Overall health check
healthy_services=0
total_services=7

# Count healthy services
docker --version >/dev/null 2>&1 && healthy_services=$((healthy_services + 1))
docker ps | grep -q othcloud && healthy_services=$((healthy_services + 1))
docker network ls | grep -q othcloud-network && healthy_services=$((healthy_services + 1))
[ "$(docker volume ls | grep othcloud | wc -l)" -gt 0 ] && healthy_services=$((healthy_services + 1))
curl -s http://localhost:3000 >/dev/null 2>&1 && healthy_services=$((healthy_services + 1))
docker logs othcloud-postgres 2>&1 | grep -q "database system is ready" && healthy_services=$((healthy_services + 1))
[ -f "/etc/othcloud/db-credentials" ] && [ -f "/etc/othcloud/app-secrets" ] && healthy_services=$((healthy_services + 1))

echo "Healthy services: $healthy_services/$total_services"

if [ $healthy_services -eq $total_services ]; then
    echo -e "${GREEN}🎉 All tests passed! OTHcloud is running properly.${NC}"
    exit 0
elif [ $healthy_services -gt 4 ]; then
    echo -e "${YELLOW}⚠️  Most services are working, but some issues were detected.${NC}"
    exit 1
else
    echo -e "${RED}❌ Multiple issues detected. OTHcloud may not be working properly.${NC}"
    echo ""
    echo "Try running:"
    echo "  sudo ./install.sh restart-services"
    echo "  docker logs othcloud-app"
    exit 2
fi