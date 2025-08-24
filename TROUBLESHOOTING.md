# 🚨 OthCloud Troubleshooting Guide

Common issues and how to fix them quickly.

## 🚀 Quick Fixes

### Issue: `cannot stat 'apps/dokploy/.env.example': No such file or directory`

**Cause:** You're not in the correct directory or the clone is incomplete.

**Fix:**
```bash
# Step 1: Verify your setup
make verify

# Step 2: Check directory
pwd                    # Should end with: /othcloud
ls package.json        # Should exist

# Step 3: If files missing, re-clone
cd ..
rm -rf othcloud
git clone https://github.com/OverTimeHosting/othcloud.git
cd othcloud
sudo make dev
```

### Issue: `Docker Compose not found`

**Cause:** Auto-installation failed or incomplete.

**Fix:**
```bash
# Manual Docker Compose install
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker compose version

# Try again
sudo make dev
```

### Issue: `Permission denied` errors

**Cause:** Incorrect file permissions or not using sudo.

**Fix:**
```bash
# Fix script permissions
chmod +x *.sh

# Use sudo for system-level operations
sudo make dev

# Fix file ownership (if needed)
sudo chown -R $USER:$USER .
```

### Issue: `Port already in use`

**Cause:** Another service is using required ports.

**Fix:**
```bash
# Check what's using ports
sudo netstat -tlnp | grep -E ':(80|443|3000|5432|6379)'

# Stop common conflicting services
sudo systemctl stop nginx apache2

# Or use different ports by editing docker-compose.yml
```

## 📋 Systematic Diagnosis

### Step 1: Verify Directory Structure
```bash
make verify
# or
./verify.sh
```

### Step 2: Check System Requirements
```bash
./health-check.sh
```

### Step 3: Check Services
```bash
make status
docker compose ps
```

### Step 4: View Logs
```bash
make logs
# or
docker compose logs
```

## 🔧 Common Issues & Solutions

### Node.js Version Mismatch
```
[WARN] Node.js version mismatch. Expected: 20.16.0, Found: 20.19.4
```

**Solution:** This is usually fine. The app should work with newer Node.js versions. If you encounter issues:
```bash
# Install specific version with nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 20.16.0
nvm use 20.16.0
```

### Docker Permission Issues
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Or restart session
# logout and login again
```

### Database Connection Failed
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```

**Solution:**
```bash
# Check if PostgreSQL container is running
docker compose ps

# Restart database service
docker compose restart postgres

# Check database logs
docker compose logs postgres
```

### Missing Dependencies During Install
```bash
# Update package lists
sudo apt update

# Install essential build tools
sudo apt install -y build-essential curl wget git

# For RHEL/CentOS/Fedora
sudo yum groupinstall -y "Development Tools"
sudo yum install -y curl wget git
```

## 🧪 Reset & Recovery

### Complete Reset
```bash
# Stop everything
make clean

# Remove all data
sudo rm -rf data/
sudo rm -rf node_modules/
sudo rm apps/dokploy/.env

# Start fresh
make dev
```

### Docker Reset
```bash
# Stop all containers
docker compose down

# Remove all containers and volumes
docker compose down -v --remove-orphans

# Clean Docker system
docker system prune -af

# Restart
make dev
```

### Nuclear Option (Fresh Start)
```bash
# Remove everything
cd ..
sudo rm -rf othcloud

# Clone fresh
git clone https://github.com/OverTimeHosting/othcloud.git
cd othcloud

# Start clean
sudo make dev
```

## 📊 Health Check Commands

| Command | Purpose |
|---------|---------|
| `make verify` | Check directory structure |
| `./health-check.sh` | System health check |
| `make status` | Service status |
| `make logs` | View all logs |
| `make ports` | Check port conflicts |
| `docker compose ps` | Container status |
| `curl localhost:3000` | Test app response |

## 🔍 Debug Information

### Gather Debug Info
```bash
echo "=== System Info ==="
uname -a
echo ""

echo "=== Docker Info ==="
docker --version
docker compose version
echo ""

echo "=== Node Info ==="
node --version
npm --version
pnpm --version
echo ""

echo "=== Directory Info ==="
pwd
ls -la
echo ""

echo "=== Service Status ==="
docker compose ps
echo ""

echo "=== Recent Logs ==="
docker compose logs --tail=20
```

## 🆘 Getting Help

If none of these solutions work:

1. **Run diagnostics:**
   ```bash
   make verify
   ./health-check.sh
   ```

2. **Gather information:**
   ```bash
   # Save debug info to file
   make verify > debug.txt
   ./health-check.sh >> debug.txt
   docker compose logs >> debug.txt
   ```

3. **Create an issue** with the debug information on GitHub

4. **Check documentation** for more specific scenarios

## ✅ Success Indicators

You'll know everything is working when you see:

```bash
✅ Docker installed successfully
✅ Docker Compose installed successfully  
✅ Node.js installed successfully
✅ All system requirements are satisfied!
✅ Services are ready!
🌐 Application will be available at:
   - Main App: http://localhost:3000
   - Traefik Dashboard: http://localhost:8080
```

And you can access `http://localhost:3000` without errors.
