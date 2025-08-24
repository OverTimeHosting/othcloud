# 🚀 OthCloud - Streamlined Dokploy Build

A simplified, one-command deployment version of Dokploy - a free, self-hostable Platform as a Service (PaaS).

## ⚡ Quick Start

**One-command setup:**
```bash
git clone <your-repo-url> && cd othcloud && make dev
```

**Or using the installer:**
```bash
curl -sSL https://raw.githubusercontent.com/your-username/othcloud/main/install.sh | bash
```

Your application will be running at `http://localhost:3000` 🎉

## 🎯 Available Commands

| Command | Description |
|---------|-------------|
| `make dev` | Start in development mode |
| `make prod` | Start in production mode |
| `make stop` | Stop all services |
| `make clean` | Clean up everything |
| `make logs` | Show service logs |
| `make status` | Show service status |
| `make restart` | Restart services |
| `make help` | Show all commands |

## 🔧 Manual Commands

```bash
./start.sh --dev     # Development mode
./start.sh --prod    # Production mode
./start.sh --stop    # Stop services
./start.sh --clean   # Clean everything
./start.sh --setup   # Install dependencies only
```

## 🌐 Access Points

- **Main Application**: http://localhost:3000
- **Traefik Dashboard**: http://localhost:8080
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

---

<div align="center">
  <a href="https://dokploy.com">
    <img src=".github/sponsors/logo.png" alt="Dokploy - Open Source Alternative to Vercel, Heroku and Netlify." width="100%"  />
  </a>
  </br>
  </br>
  <p>Join us on Discord for help, feedback, and discussions!</p>
  <a href="https://discord.gg/2tBnJ3jDJc">
    <img src="https://discordapp.com/api/guilds/1234073262418563112/widget.png?style=banner2" alt="Discord Shield"/>
  </a>
</div>
<br />

## About Dokploy

Dokploy is a free, self-hostable Platform as a Service (PaaS) that simplifies the deployment and management of applications and databases.

## ✨ Features

Dokploy includes multiple features to make your life easier.

- **Applications**: Deploy any type of application (Node.js, PHP, Python, Go, Ruby, etc.).
- **Databases**: Create and manage databases with support for MySQL, PostgreSQL, MongoDB, MariaDB, and Redis.
- **Backups**: Automate backups for databases to an external storage destination.
- **Docker Compose**: Native support for Docker Compose to manage complex applications.
- **Multi Node**: Scale applications to multiple nodes using Docker Swarm to manage the cluster.
- **Templates**: Deploy open-source templates (Plausible, Pocketbase, Calcom, etc.) with a single click.
- **Traefik Integration**: Automatically integrates with Traefik for routing and load balancing.
- **Real-time Monitoring**: Monitor CPU, memory, storage, and network usage for every resource.
- **Docker Management**: Easily deploy and manage Docker containers.
- **CLI/API**: Manage your applications and databases using the command line or through the API.
- **Notifications**: Get notified when your deployments succeed or fail (via Slack, Discord, Telegram, Email, etc.).
- **Multi Server**: Deploy and manage your applications remotely to external servers.
- **Self-Hosted**: Self-host Dokploy on your VPS.

## 🔍 What's Different in OthCloud

This streamlined version provides:

- ✅ **One-command setup** - No manual configuration needed
- ✅ **Simplified Docker setup** - Uses Docker Compose instead of Swarm
- ✅ **Auto dependency management** - Installs everything automatically
- ✅ **Development optimized** - Fast startup and hot reload
- ✅ **Easy cleanup** - One command to reset everything
- ✅ **Better error handling** - Clear error messages and recovery

## 📋 System Requirements

- **Docker** (automatically installed if missing)
- **Docker Compose** 
- **Node.js 20.16.0** (automatically prompted if missing)
- **pnpm** (automatically installed if missing)
- **Git**

## 🔧 Troubleshooting

### Port Conflicts
```bash
make ports          # Check port usage
sudo systemctl stop nginx apache2  # Stop web servers if needed
```

### Docker Issues
```bash
make clean          # Clean everything
docker system prune -af  # Reset Docker
```

### Service Issues
```bash
make logs           # Check logs
make status         # Check service status
make restart        # Restart everything
```

## 🚀 Original Dokploy Installation

For the full production Dokploy experience:

```bash
curl -sSL https://dokploy.com/install.sh | sh
```

For detailed documentation, visit [docs.dokploy.com](https://docs.dokploy.com).

## ♥️ Sponsors

🙏 We're deeply grateful to all our sponsors who make Dokploy possible! Your support helps cover the costs of hosting, testing, and developing new features.

[Dokploy Open Collective](https://opencollective.com/dokploy)

[Github Sponsors](https://github.com/sponsors/Siumauricio)

### Hero Sponsors 🎖

<div>
  <a href="https://www.hostinger.com/vps-hosting?ref=dokploy"><img src=".github/sponsors/hostinger.jpg" alt="Hostinger" width="300"/></a>
  <a href="https://www.lxaer.com/?ref=dokploy"><img src=".github/sponsors/lxaer.png" alt="LX Aer" width="100"/></a>
</div>

### Premium Supporters 🥇

<div>
  <a href="https://supafort.com/?ref=dokploy"><img src="https://supafort.com/build/q-4Ht4rBZR.webp" alt="Supafort.com" width="300"/></a>
  <a href="https://agentdock.ai/?ref=dokploy"><img src=".github/sponsors/agentdock.png" alt="agentdock.ai" width="100"/></a>
</div>

### Elite Contributors 🥈

<div>
  <a href="https://americancloud.com/?ref=dokploy"><img src=".github/sponsors/american-cloud.png" alt="AmericanCloud" width="300"/></a>
  <a href="https://tolgee.io/?utm_source=github_dokploy&utm_medium=banner&utm_campaign=dokploy"><img src="https://dokploy.com/tolgee-logo.png" alt="Tolgee" width="100"/></a>
</div>

### Supporting Members 🥉

<div>
  <a href="https://cloudblast.io/?ref=dokploy"><img src="https://cloudblast.io/img/logo-icon.193cf13e.svg" width="250px" alt="Cloudblast.io"/></a>
  <a href="https://synexa.ai/?ref=dokploy"><img src=".github/sponsors/synexa.png" width="65px" alt="Synexa"/></a>
</div>

### Community Backers 🤝

#### Organizations:

[Sponsors on Open Collective](https://opencollective.com/dokploy)

#### Individuals:

[![Individual Contributors on Open Collective](https://opencollective.com/dokploy/individuals.svg?width=890)](https://opencollective.com/dokploy)

### Contributors 🤝

<a href="https://github.com/dokploy/dokploy/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=dokploy/dokploy" alt="Contributors" />
</a>

## 📺 Video Tutorial

<a href="https://youtu.be/mznYKPvhcfw">
  <img src="https://dokploy.com/banner.png" alt="Watch the video" width="400"/>
</a>

## 🤝 Contributing

Check out the [Contributing Guide](CONTRIBUTING.md) for more information.
