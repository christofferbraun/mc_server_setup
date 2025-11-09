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

Create a dedicated user for security and organization:

```bash
sudo mkdir -p /opt/minecraft
sudo useradd -r -m -U -d /opt/minecraft -s /bin/bash minecraft
sudo chown -R minecraft:minecraft /opt/minecraft
```

### 3. Download Paper Server

Paper is a high-performance Spigot fork with plugin support:

```bash
cd /opt/minecraft
sudo -u minecraft wget https://api.papermc.io/v2/projects/paper/versions/1.21.3/builds/latest/downloads/paper-1.21.3-latest.jar -O paper.jar
```

### 4. Create Start Script

```bash
sudo -u minecraft nano /opt/minecraft/start.sh
```

Add the following (adjust RAM as needed):

```bash
#!/bin/bash
java -Xms4G -Xmx6G -jar paper.jar --nogui
```

Make it executable:

```bash
sudo chmod +x /opt/minecraft/start.sh
```

**RAM Guidelines:**
- `-Xms`: Minimum RAM (starting allocation)
- `-Xmx`: Maximum RAM (upper limit)
- Recommended: 2-4GB for 5-10 players, 4-8GB for 10-20 players

### 5. Initial Server Configuration

First run to generate files:

```bash
cd /opt/minecraft
sudo -u minecraft ./start.sh
```

Accept EULA:

```bash
sudo -u minecraft nano /opt/minecraft/eula.txt
```

Change `eula=false` to `eula=true`

Configure server properties:

```bash
sudo -u minecraft nano /opt/minecraft/server.properties
```

**Key Settings for Hardcore Server:**

```properties
hardcore=true
difficulty=hard
max-players=20
online-mode=true
server-port=1064
motd=My Hardcore Server
gamemode=survival
pvp=true
spawn-protection=16
view-distance=10
simulation-distance=10
```

### 6. Create Systemd Service

This makes the server start automatically on boot and enables easy management:

```bash
sudo nano /etc/systemd/system/minecraft.service
```

Add:

```ini
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
User=minecraft
WorkingDirectory=/opt/minecraft
ExecStart=/opt/minecraft/start.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable minecraft
sudo systemctl start minecraft
sudo systemctl status minecraft
```

---

## Server Management

### Essential Service Commands

```bash
# Start server
sudo systemctl start minecraft

# Stop server
sudo systemctl stop minecraft

# Restart server
sudo systemctl restart minecraft

# Check status
sudo systemctl status minecraft

# Check if enabled for auto-start
sudo systemctl is-enabled minecraft

# Enable auto-start on boot
sudo systemctl enable minecraft

# Disable auto-start
sudo systemctl disable minecraft
```

### View Server Logs

```bash
# View recent logs (last 50 lines)
sudo journalctl -u minecraft -n 50

# Follow logs in real-time
sudo journalctl -u minecraft -f

# View logs from today
sudo journalctl -u minecraft --since today

# View logs from last hour
sudo journalctl -u minecraft --since "1 hour ago"

# View all logs without pager
sudo journalctl -u minecraft --no-pager

# Search logs for specific text
sudo journalctl -u minecraft | grep "player"
```

### Server Files and Directories

```bash
# Main server directory
/opt/minecraft/

# Key files:
/opt/minecraft/paper.jar           # Server executable
/opt/minecraft/server.properties   # Main configuration
/opt/minecraft/eula.txt           # EULA acceptance
/opt/minecraft/start.sh           # Start script

# Directories:
/opt/minecraft/world/             # Overworld save
/opt/minecraft/world_nether/      # Nether save
/opt/minecraft/world_the_end/     # End save
/opt/minecraft/plugins/           # Plugin directory
/opt/minecraft/logs/              # Server logs
```

### Updating Paper Server

When Paper shows an update warning:

```bash
# Stop the server
sudo systemctl stop minecraft

# Backup current jar (optional)
sudo -u minecraft cp /opt/minecraft/paper.jar /opt/minecraft/paper.jar.old

# Download latest version
cd /opt/minecraft
sudo -u minecraft wget https://api.papermc.io/v2/projects/paper/versions/1.21.3/builds/latest/downloads/paper-1.21.3-latest.jar -O paper.jar

# Start server
sudo systemctl start minecraft

# Verify in logs
sudo journalctl -u minecraft -f
```

---

## Network Configuration

### Firewall Setup

Open Minecraft port on Ubuntu:

```bash
sudo ufw allow 1064/tcp
sudo ufw allow 1064/udp
sudo ufw status
```

### UniFi Port Forwarding

1. Log into UniFi Controller (https://unifi.ui.com or local)
2. Navigate to **Settings → Routing → Port Forwarding**
3. Create new rule:
   - **Name:** Minecraft Server
   - **Enabled:** ✓
   - **From:** Any / WAN
   - **Port:** 1064
   - **Forward IP:** [Ubuntu server local IP, e.g., 192.168.1.100]
   - **Forward Port:** 1064
   - **Protocol:** TCP/UDP

Find your server's local IP:

```bash
ip addr show | grep inet
```

Find your public IP:

```bash
curl ifconfig.me
```

### Verify Port is Open

```bash
# Check if Minecraft is listening
sudo netstat -tlnp | grep 1064

# Alternative with ss
sudo ss -tlnp | grep 1064

# Test from external tool
# Visit: https://mcsrvstat.us/
```

---

## Cloudflare DDNS

Automatically update Cloudflare DNS when your public IP changes.

### Prerequisites

1. Domain registered with Cloudflare
2. Cloudflare API Token with DNS Edit permissions
3. Zone ID from Cloudflare dashboard

### Get Cloudflare Credentials

**Zone ID:**
1. Log into Cloudflare
2. Select your domain
3. Scroll down on Overview page
4. Copy **Zone ID** from right sidebar

**API Token:**
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use **Edit zone DNS** template
4. Permissions: Zone → DNS → Edit
5. Zone Resources: Include → Specific zone → yourdomain.com
6. Create and copy the token

### Install DDNS Script

```bash
# Install dependencies
sudo apt install curl jq -y

# Create directory
sudo mkdir -p /opt/cloudflare-ddns
cd /opt/cloudflare-ddns

# Create script
sudo nano /opt/cloudflare-ddns/update-dns.sh
```

**Script Content:**

```bash
#!/bin/bash

# Cloudflare Configuration
ZONE_ID="your_zone_id_here"
API_TOKEN="your_api_token_here"
RECORD_NAME="mc.yourdomain.com"
RECORD_TYPE="A"

# Log file
LOG_FILE="/var/log/cloudflare-ddns.log"

# Get current public IP
CURRENT_IP=$(curl -s -4 ifconfig.me)

if [ -z "$CURRENT_IP" ]; then
    echo "$(date): Failed to get current IP" >> "$LOG_FILE"
    exit 1
fi

# Get the record from Cloudflare
RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$RECORD_TYPE&name=$RECORD_NAME" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Content-Type: application/json")

# Check if API call was successful
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" != "true" ]; then
    echo "$(date): API call failed. Response: $RESPONSE" >> "$LOG_FILE"
    exit 1
fi

# Get record ID
RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')

if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" = "null" ]; then
    echo "$(date): Record not found for $RECORD_NAME. Creating it..." >> "$LOG_FILE"
    
    # Create the record
    CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}")
    
    CREATE_SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success')
    if [ "$CREATE_SUCCESS" = "true" ]; then
        echo "$(date): Successfully created DNS record with IP $CURRENT_IP" >> "$LOG_FILE"
        exit 0
    else
        echo "$(date): Failed to create DNS record. Error: $(echo $CREATE_RESPONSE | jq -r '.errors')" >> "$LOG_FILE"
        exit 1
    fi
fi

# Get current DNS IP
DNS_IP=$(echo "$RESPONSE" | jq -r '.result[0].content')

# Compare and update if different
if [ "$CURRENT_IP" != "$DNS_IP" ]; then
    echo "$(date): IP changed from $DNS_IP to $CURRENT_IP. Updating..." >> "$LOG_FILE"
    
    UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"ttl\":120,\"proxied\":false}")
    
    SUCCESS=$(echo "$UPDATE_RESULT" | jq -r '.success')
    
    if [ "$SUCCESS" = "true" ]; then
        echo "$(date): Successfully updated DNS to $CURRENT_IP" >> "$LOG_FILE"
    else
        echo "$(date): Failed to update DNS. Error: $(echo $UPDATE_RESULT | jq -r '.errors')" >> "$LOG_FILE"
    fi
else
    echo "$(date): IP unchanged ($CURRENT_IP)" >> "$LOG_FILE"
fi
```

**Setup:**

```bash
# Make executable
sudo chmod +x /opt/cloudflare-ddns/update-dns.sh

# Create log file
sudo touch /var/log/cloudflare-ddns.log

# Test the script
sudo /opt/cloudflare-ddns/update-dns.sh

# Check results
cat /var/log/cloudflare-ddns.log
```

### Automate with Cron

Run the script every 5 minutes:

```bash
sudo crontab -e
```

Add:

```bash
*/5 * * * * /opt/cloudflare-ddns/update-dns.sh
```

**Verify cron job:**

```bash
sudo crontab -l
```

**Monitor updates:**

```bash
tail -f /var/log/cloudflare-ddns.log
```

### Cloudflare DNS Settings

**Important:** Disable Cloudflare proxy for Minecraft!

1. Go to Cloudflare DNS settings
2. Find your `mc.yourdomain.com` A record
3. Click the **orange cloud** to make it **gray** (DNS only)
4. Cloudflare's proxy doesn't support Minecraft traffic
5. Set TTL to **Auto** or **2 minutes**

### Optional: SRV Record

Allows players to connect without specifying port:

- **Type:** SRV
- **Name:** `_minecraft._tcp.mc` (or `_minecraft._tcp` for root)
- **Priority:** 0
- **Weight:** 5
- **Port:** 25565
- **Target:** `mc.yourdomain.com`

Players can then connect using just: `mc.yourdomain.com`

---

## World Reset Script

Quick script to reset the world after deaths in hardcore mode.

### Installation

```bash
sudo nano /usr/local/bin/reset-mc-world
```

Paste the script from the artifact, then:

```bash
sudo chmod +x /usr/local/bin/reset-mc-world
```

### Usage

```bash
reset-mc-world
```

Or with sudo:

```bash
sudo reset-mc-world
```

### What It Does

1. Asks for confirmation (must type "yes")
2. Stops the server gracefully
3. Creates timestamped backup of current world
4. Deletes all world files (overworld, nether, end)
5. Restarts server with fresh world generation
6. Shows status and recent logs

### Backups Location

```bash
/opt/minecraft/world-backups/
```

View backups:

```bash
ls -lh /opt/minecraft/world-backups/
```

### Restore a Backup

```bash
# Stop server
sudo systemctl stop minecraft

# Go to minecraft directory
cd /opt/minecraft

# Delete current world
sudo rm -rf world world_nether world_the_end

# Restore backup (replace TIMESTAMP with actual backup filename)
sudo -u minecraft tar -xzf /opt/minecraft/world-backups/world_backup_TIMESTAMP.tar.gz

# Start server
sudo systemctl start minecraft
```

### Clean Old Backups

```bash
# Delete backups older than 30 days
find /opt/minecraft/world-backups/ -name "*.tar.gz" -mtime +30 -delete

# Manually delete specific backup
rm /opt/minecraft/world-backups/world_backup_20251108_210506.tar.gz
```

---

## Essential Commands

### Quick Status Script

Create a comprehensive status check:

```bash
sudo nano /usr/local/bin/mcstatus
```

Add:

```bash
#!/bin/bash
echo "=== Minecraft Server Status ==="
sudo systemctl status minecraft --no-pager -l
echo ""
echo "=== Port Status ==="
sudo netstat -tlnp | grep 1064
echo ""
echo "=== Recent Logs ==="
sudo journalctl -u minecraft -n 20 --no-pager
echo ""
echo "=== Disk Usage ==="
du -sh /opt/minecraft
echo ""
echo "=== Public IP ==="
curl -s ifconfig.me
echo ""
echo "=== DNS Resolution ==="
dig mc.yourdomain.com +short
```

Make executable:

```bash
sudo chmod +x /usr/local/bin/mcstatus
```

Usage:

```bash
mcstatus
```

### Useful Aliases

Add to `~/.bashrc`:

```bash
nano ~/.bashrc
```

Add at the end:

```bash
# Minecraft Server Aliases
alias mcstatus='sudo systemctl status minecraft'
alias mclogs='sudo journalctl -u minecraft -f'
alias mcrestart='sudo systemctl restart minecraft'
alias mcstop='sudo systemctl stop minecraft'
alias mcstart='sudo systemctl start minecraft'
alias resetworld='sudo /usr/local/bin/reset-mc-world'
alias ddnslogs='tail -f /var/log/cloudflare-ddns.log'
```

Reload:

```bash
source ~/.bashrc
```

### Server Performance Monitoring

```bash
# CPU and memory usage (interactive)
htop

# Or simpler top
top

# Check memory
free -h

# Check disk space
df -h

# Check disk usage of minecraft directory
du -sh /opt/minecraft/*

# Check network connections
sudo netstat -an | grep 1064
```

### Player Activity

```bash
# See recent player joins/leaves
sudo journalctl -u minecraft | grep -E "joined|left" | tail -20

# See all player activity
sudo journalctl -u minecraft | grep -E "joined|left"

# Search for specific player
sudo journalctl -u minecraft | grep "PlayerName"
```

---

## Plugin Management

### Installing Plugins

Paper server supports Bukkit/Spigot plugins.

**Plugin Sources:**
- [SpigotMC](https://www.spigotmc.org/resources/)
- [Bukkit](https://dev.bukkit.org/bukkit-plugins)
- [Hangar (Paper)](https://hangar.papermc.io/)

**Installation Process:**

```bash
# Navigate to plugins directory
cd /opt/minecraft/plugins

# Download plugin (example: EssentialsX)
sudo -u minecraft wget https://github.com/EssentialsX/Essentials/releases/download/2.20.1/EssentialsX-2.20.1.jar

# Restart server to load plugin
sudo systemctl restart minecraft

# Check if plugin loaded
sudo journalctl -u minecraft | grep -i "essentials"
```

### Recommended Plugins for Hardcore

**Core Plugins:**

1. **EssentialsX** - Essential commands (/home, /tpa, etc.)
   - https://essentialsx.net/

2. **CoreProtect** - Block logging and rollback (anti-grief)
   - https://www.spigotmc.org/resources/coreprotect.8631/

3. **LuckPerms** - Advanced permission management
   - https://luckperms.net/

4. **Vault** - Economy API (required by many plugins)
   - https://www.spigotmc.org/resources/vault.34315/

**Optional Plugins:**

5. **WorldEdit** - World editing tools
   - https://enginehub.org/worldedit

6. **WorldGuard** - Region protection
   - https://enginehub.org/worldguard

7. **Dynmap** - Live web map
   - https://www.spigotmc.org/resources/dynmap.274/

### Managing Plugins

```bash
# List installed plugins
ls -la /opt/minecraft/plugins/

# Remove a plugin (while server is stopped)
sudo systemctl stop minecraft
sudo -u minecraft rm /opt/minecraft/plugins/PluginName.jar
sudo systemctl start minecraft

# Update a plugin
sudo systemctl stop minecraft
sudo -u minecraft rm /opt/minecraft/plugins/OldPlugin.jar
sudo -u minecraft wget [new-plugin-url] -P /opt/minecraft/plugins/
sudo systemctl start minecraft

# View plugin configs
ls -la /opt/minecraft/plugins/PluginName/
```

### Plugin Configuration

Most plugins create a config folder:

```bash
# Navigate to plugin config
cd /opt/minecraft/plugins/PluginName/

# Edit main config
sudo -u minecraft nano config.yml

# Restart server after config changes
sudo systemctl restart minecraft
```

---

## Troubleshooting

### Server Won't Start

**Check logs:**

```bash
sudo journalctl -u minecraft -n 100
```

**Common issues:**

1. **Port already in use:**
   ```bash
   sudo netstat -tlnp | grep 1064
   # Kill process if needed
   sudo kill -9 [PID]
   ```

2. **Insufficient memory:**
   - Edit `/opt/minecraft/start.sh`
   - Reduce `-Xmx` value
   - Check available RAM: `free -h`

3. **Java not found:**
   ```bash
   java -version
   # Reinstall if needed
   sudo apt install openjdk-21-jre-headless -y
   ```

4. **Permission issues:**
   ```bash
   sudo chown -R minecraft:minecraft /opt/minecraft
   sudo chmod +x /opt/minecraft/start.sh
   ```

### Can't Connect to Server

**Check server is running:**

```bash
sudo systemctl status minecraft
```

**Check port is open locally:**

```bash
sudo netstat -tlnp | grep 1064
```

**Check firewall:**

```bash
sudo ufw status
sudo ufw allow 1064/tcp
sudo ufw allow 1064/udp
```

**Check UniFi port forward:**
- Verify rule is enabled
- Confirm local IP is correct
- Ensure it's on the right WAN interface

**Test DNS resolution:**

```bash
dig mc.yourdomain.com +short
nslookup mc.yourdomain.com
```

**Check public IP:**

```bash
curl ifconfig.me
```

**Test from outside network:**
- Use https://mcsrvstat.us/
- Have friend try connecting

### DDNS Not Updating

**Check script errors:**

```bash
cat /var/log/cloudflare-ddns.log
```

**Test script manually:**

```bash
sudo /opt/cloudflare-ddns/update-dns.sh
```

**Verify cron is running:**

```bash
sudo systemctl status cron
sudo crontab -l
```

**Check Cloudflare API:**

```bash
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" | jq
```

### Performance Issues

**Check resource usage:**

```bash
htop
free -h
df -h
```

**Reduce view/simulation distance:**

Edit `server.properties`:
```properties
view-distance=8
simulation-distance=8
```

**Optimize Java flags:**

Edit `/opt/minecraft/start.sh`:
```bash
java -Xms4G -Xmx4G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -jar paper.jar --nogui
```

**Check for lag:**

```bash
# In-game command as OP
/tps
/mspt
```

---

## Backup Strategy

### Manual Backup

```bash
# Stop server
sudo systemctl stop minecraft

# Create backup
sudo -u minecraft tar -czf /opt/minecraft/backups/backup-$(date +%Y%m%d-%H%M%S).tar.gz /opt/minecraft/world /opt/minecraft/world_nether /opt/minecraft/world_the_end /opt/minecraft/plugins

# Start server
sudo systemctl start minecraft
```

### Automated Backup Script

```bash
sudo nano /opt/minecraft/backup.sh
```

Add:

```bash
#!/bin/bash
BACKUP_DIR="/opt/minecraft/backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup worlds and plugins
tar -czf "$BACKUP_DIR/backup-$DATE.tar.gz" \
  /opt/minecraft/world \
  /opt/minecraft/world_nether \
  /opt/minecraft/world_the_end \
  /opt/minecraft/plugins \
  /opt/minecraft/server.properties

# Keep only last 7 backups
ls -t "$BACKUP_DIR"/backup-*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed: backup-$DATE.tar.gz"
```

Make executable:

```bash
sudo chmod +x /opt/minecraft/backup.sh
```

**Schedule with cron (daily at 3 AM):**

```bash
sudo crontab -e
```

Add:

```bash
0 3 * * * /opt/minecraft/backup.sh >> /var/log/minecraft-backup.log 2>&1
```

### Restore from Backup

```bash
# Stop server
sudo systemctl stop minecraft

# Extract backup
sudo -u minecraft tar -xzf /opt/minecraft/backups/backup-TIMESTAMP.tar.gz -C /

# Start server
sudo systemctl start minecraft
```

---

## Quick Reference

### File Locations

```
/opt/minecraft/                        # Server root
/opt/minecraft/paper.jar              # Server jar
/opt/minecraft/server.properties      # Main config
/opt/minecraft/plugins/               # Plugins directory
/opt/minecraft/world/                 # World saves
/opt/minecraft/world-backups/         # Reset script backups
/opt/minecraft/backups/               # Manual backups
/etc/systemd/system/minecraft.service # Service file
/opt/cloudflare-ddns/update-dns.sh   # DDNS script
/usr/local/bin/reset-mc-world        # Reset script
/var/log/cloudflare-ddns.log         # DDNS logs
```

### Port Information

- **25565** - Minecraft server (TCP/UDP)
- **80** - HTTP (if using web panel)
- **443** - HTTPS (if using web panel)

### Important URLs

- Paper Downloads: https://papermc.io/downloads/paper
- Spigot Plugins: https://www.spigotmc.org/resources/
- Server Status Checker: https://mcsrvstat.us/
- Cloudflare Dashboard: https://dash.cloudflare.com/

### Default Credentials

- Minecraft OP: Set in-game with `/op username`
- Server files owner: `minecraft` user

---

## Summary

This guide covers:
- ✅ Paper server installation with plugin support
- ✅ Systemd service for automatic startup
- ✅ UniFi port forwarding configuration
- ✅ Cloudflare DDNS for dynamic IP updates
- ✅ World reset script for hardcore mode
- ✅ Complete command reference
- ✅ Backup and restore procedures
- ✅ Troubleshooting common issues

Your server should now be fully operational and accessible at:
- Direct IP: `your-public-ip:1064`
- Domain: `mc.yourdomain.com:1064`
- With SRV: `mc.yourdomain.com`

For additional help, check:
- Paper Documentation: https://docs.papermc.io/
- Spigot Forums: https://www.spigotmc.org/
- Minecraft Wiki: https://minecraft.wiki/

---

**Last Updated:** November 8, 2025
