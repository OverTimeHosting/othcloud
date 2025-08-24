# 🚀 Auto-Installation Guide

Your OthCloud now automatically installs all required dependencies! Here's how it works:

## ✅ What Gets Auto-Installed

### System Dependencies
- ✅ **Docker** - Container platform
- ✅ **Docker Compose** - Multi-container orchestration  
- ✅ **Node.js v20.16.0** - JavaScript runtime
- ✅ **pnpm** - Fast package manager
- ✅ **Git** - Version control
- ✅ **curl** - HTTP client for downloads

### Services Setup
- ✅ **PostgreSQL** - Database (via Docker)
- ✅ **Redis** - Cache/queue system (via Docker)
- ✅ **Traefik** - Reverse proxy (via Docker)

## 🎯 Usage Methods

### Method 1: Direct Clone & Start (Recommended)
```bash
# As root (servers/VPS)
sudo git clone https://github.com/OverTimeHosting/othcloud.git
cd othcloud
sudo make dev

# The script will automatically:
# 1. Install Docker & Docker Compose
# 2. Install Node.js & pnpm
# 3. Setup all services
# 4. Start your application
```

### Method 2: One-Line Installer
```bash
# Auto-installs everything and starts
curl -sSL https://raw.githubusercontent.com/OverTimeHosting/othcloud/main/install.sh | sudo bash
```

### Method 3: Manual Steps
```bash
git clone https://github.com/OverTimeHosting/othcloud.git
cd othcloud
sudo ./start.sh --dev
```

## 🔧 What Happens During Auto-Install

### 1. **Docker Installation**
```bash
# Downloads and runs Docker's official install script
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker
```

### 2. **Docker Compose Installation**
```bash
# Gets latest version from GitHub
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### 3. **Node.js Installation**
```bash
# Installs via NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Or for RHEL/CentOS/Fedora
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs
```

### 4. **pnpm Installation**
```bash
# Installs globally via npm
npm install -g pnpm --unsafe-perm
```

## 🌍 Supported Operating Systems

### ✅ Fully Supported
- **Ubuntu** (18.04, 20.04, 22.04, 24.04)
- **Debian** (9, 10, 11, 12)
- **CentOS** (7, 8)
- **RHEL** (7, 8, 9)
- **Fedora** (35+)
- **Amazon Linux 2**

### ⚠️ Partial Support
- **Alpine Linux** (manual Docker install may be needed)
- **Arch Linux** (uses different package manager)

## 🔒 Permission Requirements

### Root Access Required For:
- Installing system packages (Docker, Node.js)
- Managing system services
- Creating system directories
- Binding to privileged ports (80, 443)

### Why Sudo/Root is Needed:
```bash
# These operations require root:
systemctl start docker          # Start system services
apt-get install nodejs         # Install system packages  
usermod -aG docker $USER       # Modify user groups
chmod +x /usr/local/bin/*       # Set system executable permissions
```

## 🧪 Test Your Installation

After running the auto-installer, verify everything works:

```bash
# Check installed versions
docker --version
docker compose version
node --version
pnpm --version

# Check services are running
docker ps
curl http://localhost:3000

# Check Docker permissions (if not root)
docker run hello-world
```

## 🚨 Troubleshooting Auto-Install

### Docker Installation Issues
```bash
# If Docker fails to install
sudo systemctl status docker
sudo journalctl -u docker

# Manual Docker install fallback
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### Node.js Installation Issues
```bash
# Check if NodeSource repo was added
ls /etc/apt/sources.list.d/ | grep nodesource

# Manual Node.js install fallback
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20.16.0
nvm use 20.16.0
```

### Permission Issues
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker

# Fix file ownership (if using sudo)
sudo chown -R $USER:$USER .
```

## 🎉 Success Indicators

You'll know the auto-installation worked when you see:

```
✅ Docker installed successfully
✅ Docker Compose installed successfully  
✅ Node.js installed successfully
✅ pnpm installed successfully
✅ All system requirements are satisfied!

🌐 Application will be available at:
   - Main App: http://localhost:3000
   - Traefik Dashboard: http://localhost:8080
```

## ⚡ Quick Commands Reference

| Command | What it does |
|---------|--------------|
| `sudo make dev` | Auto-install everything & start dev mode |
| `sudo ./start.sh --prod` | Auto-install everything & start prod mode |
| `sudo ./start.sh --setup` | Auto-install dependencies only |
| `./health-check.sh` | Verify all services are working |

## 🔄 Updates & Maintenance

To update your installation:
```bash
git pull origin main
sudo make clean
sudo make dev
```

Your OthCloud now handles **everything automatically** - from a fresh server to a running application in minutes! 🚀
