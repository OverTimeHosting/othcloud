# OTHcloud Installation

## One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/OverTimeHosting/othcloud/main/install.sh | bash
```

## Manual Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/OverTimeHosting/othcloud/main/install.sh

# Make it executable
chmod +x install.sh

# Run installation
sudo ./install.sh
```

## Management Commands

```bash
# Update to latest version
sudo ./install.sh update

# Check status
./install.sh status

# View logs
./install.sh logs [app|postgres|redis]

# Restart services
sudo ./install.sh restart-services

# Uninstall (preserves data)
sudo ./install.sh uninstall
```

## Requirements

- **OS**: Ubuntu 20.04+ or Debian 11+
- **RAM**: Minimum 2GB (4GB+ recommended)
- **CPU**: 2+ cores recommended
- **Disk**: 10GB+ free space
- **Ports**: 80, 443, 3000 must be available
- **Root Access**: Required for installation

## What Gets Installed

- **Docker & Docker Swarm**: Container orchestration
- **PostgreSQL**: Database (in container)
- **Redis**: Cache and session storage
- **Traefik**: Reverse proxy and SSL termination
- **OTHcloud**: Main application

## Post-Installation

1. **Access the application**: `http://YOUR_SERVER_IP:3000`
2. **Default login**: 
   - Email: `damo@damo.com`
   - Password: `admin`
3. **Change credentials immediately** after first login
4. **Configure Cloudflare** (optional):
   - Add your Cloudflare API token
   - Add your Zone ID
   - Set your base domain

## Architecture

```
Internet → Traefik (80/443) → OTHcloud App (3000)
                            ↓
                      PostgreSQL (5432)
                            ↓
                        Redis (6379)
```

## File Locations

- **Application**: `/opt/othcloud/`
- **Configuration**: `/etc/othcloud/`
- **Logs**: `docker service logs othcloud-app`
- **Data**: Docker volumes (persistent)

## Troubleshooting

### Check Service Status
```bash
docker service ls
docker ps
systemctl status othcloud
```

### View Logs
```bash
# Application logs
docker service logs -f othcloud-app

# Database logs
docker service logs -f othcloud-postgres

# All container logs
docker logs $(docker ps -q)
```

### Reset Services
```bash
sudo ./install.sh restart-services
```

### Complete Reinstall
```bash
sudo ./install.sh uninstall
curl -sSL https://raw.githubusercontent.com/YourUsername/othcloud/main/install.sh | bash
```

### Free Up Ports
```bash
# Check what's using ports
sudo ss -tulnp | grep -E ":80|:443|:3000"

# Stop conflicting services
sudo systemctl stop nginx apache2
```

## Security Notes

- Change default credentials immediately
- Configure firewall to restrict access
- Use SSL certificates in production
- Regularly update the system
- Monitor logs for suspicious activity

## Support

- **Documentation**: Check the `/docs` directory
- **Issues**: Create GitHub issues for bugs
- **Logs**: Always include logs when reporting issues