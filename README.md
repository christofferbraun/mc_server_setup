# Minecraft Server Setup Guide

Complete guide for setting up a Minecraft Paper server on Ubuntu with plugin support, Cloudflare DDNS, and remote access.

## Table of Contents
- [Initial Server Setup](#initial-server-setup)
- [Server Management](#server-management)
- [Network Configuration](#network-configuration)
- [Cloudflare DDNS](#cloudflare-ddns)
- [World Reset Script](#world-reset-script)
- [Essential Commands](#essential-commands)
- [Plugin Management](#plugin-management)
- [Troubleshooting](#troubleshooting)
- [Backup Strategy](#backup-strategy)

---

## Initial Server Setup

### 1. Install Java 21

Paper requires Java 21 for recent Minecraft versions.

```bash
sudo apt update
sudo apt install openjdk-21-jre-headless -y
java -version
```

### 2. Create Minecraft User and Directory

```bash
sudo mkdir -p /opt/minecraft
sudo useradd -r -m -U -d /opt/minecraft -s /bin/bash minecraft
sudo chown -R minecraft:minecraft /opt/minecraft
```

### 3. Download Paper Server

```bash
cd /opt/minecraft
sudo -u minecraft wget https://api.papermc.io/v2/projects/paper/versions/1.21.3/builds/latest/downloads/paper-1.21.3-latest.jar -O paper.jar
```

### 4. Create Start Script

```bash
sudo -u minecraft nano /opt/minecraft/start.sh
```

Add (adjust RAM as needed):

```bash
#!/bin/bash
java -Xms4G -Xmx6G -jar paper.jar --nogui
```

Make executable:

```bash
sudo chmod +x /opt/minecraft/start.sh
```

### 5. Initial Server Configuration

First run to generate files:

```bash
cd /opt/minecraft
sudo -u minecraft ./start.sh
```

Accept EULA:

```bash
sudo -u minecraft nano /opt/minecraft/eula.txt
# Change eula=false to eula=true
```

Configure server properties:

```bash
sudo -u minecraft nano /opt/minecraft/server.properties
```

**Key Settings:**

```properties
hardcore=true
difficulty=hard
max-players=10
online-mode=true
server-port=1064
motd=My Hardcore Server
white-list=true
```

### 6. Create Systemd Service

Download the service file:

```bash
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/configs/minecraft.service -O /etc/systemd/system/minecraft.service
```

Or create it manually - see [configs/minecraft.service](configs/minecraft.service)

Install screen (required for console access):

```bash
sudo apt install screen -y
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl start minecraft
sudo systemctl status minecraft
```

---

## Server Management

### Essential Commands

```bash
# Server control (swap start|stop|restart|status)
sudo systemctl {start|stop|restart|status} minecraft

# View logs
sudo journalctl -u minecraft -f              # Follow live
sudo journalctl -u minecraft -n 50           # Last 50 lines

# Access console (Ctrl+A then D to detach)
sudo -u minecraft screen -r minecraft

# Check if port is open
sudo netstat -tlnp | grep 1064
```

### Quick Status Script

Download and install:

```bash
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/mcstatus.sh -O /usr/local/bin/mcstatus
sudo chmod +x /usr/local/bin/mcstatus
```

Usage: `mcstatus`

See [scripts/mcstatus.sh](scripts/mcstatus.sh) for details.

### Updating Paper Server

Download the update script:

```bash
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/update-paper.sh -O /usr/local/bin/update-paper
sudo chmod +x /usr/local/bin/update-paper
```

Usage: `sudo update-paper`

See [scripts/update-paper.sh](scripts/update-paper.sh) for details.

---

## Network Configuration

### Firewall Setup

```bash
sudo ufw allow 1064/tcp
sudo ufw allow 1064/udp
sudo ufw status
```

### UniFi Port Forwarding

1. Log into UniFi Controller
2. Navigate to **Settings → Routing → Port Forwarding**
3. Create new rule:
   - **Name:** Minecraft Server
   - **Port:** 1064
   - **Forward IP:** [Ubuntu server local IP]
   - **Forward Port:** 1064
   - **Protocol:** TCP/UDP

Find server IP: `ip addr show | grep inet`

---

## Cloudflare DDNS

### Prerequisites

1. Cloudflare Zone ID (from domain dashboard)
2. API Token with DNS Edit permissions
3. Domain name

### Installation

```bash
# Install dependencies
sudo apt install curl jq -y

# Download script
sudo mkdir -p /opt/cloudflare-ddns
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/update-dns.sh -O /opt/cloudflare-ddns/update-dns.sh
sudo chmod +x /opt/cloudflare-ddns/update-dns.sh
```

### Configuration

Edit the script and update these values:

```bash
sudo nano /opt/cloudflare-ddns/update-dns.sh
```

```bash
ZONE_ID="your_zone_id_here"
API_TOKEN="your_api_token_here"
RECORD_NAME="mc.yourdomain.com"
```

See [scripts/update-dns.sh](scripts/update-dns.sh) for the full script.

### Test the Script

```bash
sudo touch /var/log/cloudflare-ddns.log
sudo /opt/cloudflare-ddns/update-dns.sh
cat /var/log/cloudflare-ddns.log
```

### Automate with Cron

```bash
sudo crontab -e
```

Add:

```bash
*/5 * * * * /opt/cloudflare-ddns/update-dns.sh
```

### Cloudflare DNS Settings

**Important:** Disable Cloudflare proxy (orange cloud → gray cloud) for game servers!

---

## World Reset Script

### Manual Reset

Quick script to manually reset hardcore world.

```bash
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/reset-world.sh -O /usr/local/bin/reset-mc-world
sudo chmod +x /usr/local/bin/reset-mc-world
```

Usage: `reset-mc-world`

See [scripts/reset-world.sh](scripts/reset-world.sh) for details.

### Automatic Reset on Death (Recommended for Hardcore)

Automatically monitors server logs and resets the world when any player dies.

**Installation:**

```bash
# Download death monitor script
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/death-monitor.sh -O /opt/minecraft/death-monitor.sh
sudo chmod +x /opt/minecraft/death-monitor.sh
sudo touch /var/log/minecraft-death-monitor.log

# Download and install service
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/configs/minecraft-death-monitor.service -O /etc/systemd/system/minecraft-death-monitor.service

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable minecraft-death-monitor
sudo systemctl start minecraft-death-monitor

# Verify it's running
sudo systemctl status minecraft-death-monitor
```

**How it works:**
1. Monitors logs in real-time for death messages
2. Broadcasts countdown warnings (15, 10, 5 seconds)
3. Automatically backs up and deletes world
4. Restarts server with fresh world

**Monitor the death monitor:**
```bash
tail -f /var/log/minecraft-death-monitor.log
sudo journalctl -u minecraft-death-monitor -f
```

**Disable auto-reset:**
```bash
sudo systemctl stop minecraft-death-monitor
sudo systemctl disable minecraft-death-monitor
```

See [scripts/death-monitor.sh](scripts/death-monitor.sh) and [configs/minecraft-death-monitor.service](configs/minecraft-death-monitor.service) for details.

### Restore a Backup

```bash
sudo systemctl stop minecraft
cd /opt/minecraft
sudo rm -rf world world_nether world_the_end
sudo -u minecraft tar -xzf /opt/minecraft/world-backups/world_backup_TIMESTAMP.tar.gz
sudo systemctl start minecraft
```

---

## Essential Commands

See [docs/QUICK_REFERENCE.txt](docs/QUICK_REFERENCE.txt) for a handy command reference.

### Quick Aliases

Add to `~/.bashrc`:

```bash
alias mcstatus='sudo systemctl status minecraft'
alias mclogs='sudo journalctl -u minecraft -f'
alias mcrestart='sudo systemctl restart minecraft'
alias mcstop='sudo systemctl stop minecraft'
alias mcstart='sudo systemctl start minecraft'
alias resetworld='sudo reset-mc-world'
alias mc='cat ~/mc-commands.txt'
```

Then: `source ~/.bashrc`

### OP Players

```bash
# Add OP
echo "PlayerName" | sudo -u minecraft tee -a /opt/minecraft/ops.txt
sudo systemctl restart minecraft

# Or via console
sudo -u minecraft screen -r minecraft
# Type: op PlayerName
# Press Ctrl+A then D to detach
```

### Whitelist Management

```bash
# Edit whitelist
sudo -u minecraft nano /opt/minecraft/whitelist.json

# Format:
[
  {
    "uuid": "player-uuid-here",
    "name": "PlayerName"
  }
]

# Get UUIDs from: https://mcuuid.net/
```

---

## Plugin Management

### Installing Plugins

Sources:
- [SpigotMC](https://www.spigotmc.org/resources/)
- [Hangar (Paper)](https://hangar.papermc.io/)

```bash
cd /opt/minecraft/plugins
sudo -u minecraft wget [plugin-url]
sudo systemctl restart minecraft
```

### Recommended Plugins

1. **EssentialsX** - Essential commands
2. **CoreProtect** - Anti-grief/rollback
3. **LuckPerms** - Permissions
4. **Vault** - Economy API

---

## Troubleshooting

### Server Won't Start

```bash
# Check logs
sudo journalctl -u minecraft -n 100

# Check port availability
sudo netstat -tlnp | grep 1064

# Check permissions
sudo chown -R minecraft:minecraft /opt/minecraft
```

### Can't Connect

```bash
# Verify server is running
sudo systemctl status minecraft

# Check firewall
sudo ufw status

# Test DNS
dig mc.yourdomain.com +short

# Check public IP
curl ifconfig.me
```

### DDNS Not Updating

```bash
# Check logs
cat /var/log/cloudflare-ddns.log

# Test manually
sudo /opt/cloudflare-ddns/update-dns.sh

# Verify cron
sudo crontab -l
```

---

## Backup Strategy

### Automated Backups

Download backup script:

```bash
sudo wget https://raw.githubusercontent.com/christofferbraun/mc_server_setup/main/scripts/backup.sh -O /opt/minecraft/backup.sh
sudo chmod +x /opt/minecraft/backup.sh
```

Schedule daily backups at 3 AM:

```bash
sudo crontab -e
```

Add:

```bash
0 3 * * * /opt/minecraft/backup.sh >> /var/log/minecraft-backup.log 2>&1
```

See [scripts/backup.sh](scripts/backup.sh) for details.

### Manual Backup

```bash
sudo systemctl stop minecraft
sudo -u minecraft tar -czf /opt/minecraft/backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz \
  /opt/minecraft/world /opt/minecraft/world_nether /opt/minecraft/world_the_end /opt/minecraft/plugins
sudo systemctl start minecraft
```

---

## Quick Reference

### File Locations

```
/opt/minecraft/                              # Server root
/opt/minecraft/paper.jar                    # Server jar
/opt/minecraft/server.properties            # Main config
/opt/minecraft/plugins/                     # Plugins
/opt/minecraft/world/                       # World saves
/opt/minecraft/world-backups/               # Reset backups
/opt/minecraft/backups/                     # Manual backups
/opt/minecraft/death-monitor.sh             # Death monitor script
/etc/systemd/system/minecraft.service       # Minecraft service
/etc/systemd/system/minecraft-death-monitor.service  # Death monitor service
/opt/cloudflare-ddns/update-dns.sh         # DDNS script
/var/log/cloudflare-ddns.log               # DDNS logs
/var/log/minecraft-death-monitor.log       # Death monitor logs
```

### Ports

- **1064** - Minecraft server (TCP/UDP)

### Resources

- Paper Downloads: https://papermc.io/downloads/paper
- Spigot Plugins: https://www.spigotmc.org/resources/
- Server Status: https://mcsrvstat.us/

---

**Last Updated:** November 9, 2025