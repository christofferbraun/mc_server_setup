#!/bin/bash
# Minecraft Death Monitor Script
# Watches logs for player deaths and triggers automatic world reset

# ============================================
# CONFIGURATION
# ============================================
MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/opt/minecraft/world-backups"
LOG_FILE="/var/log/minecraft-death-monitor.log"

# ============================================
# Functions
# ============================================

send_server_command() {
    local command=$1
    sudo -u minecraft screen -S minecraft -X stuff "${command}\n"
}

broadcast_message() {
    local message=$1
    send_server_command "say ${message}"
}

reset_world_auto() {
    echo "$(date): Starting automatic world reset..." >> "$LOG_FILE"
    
    # Countdown warnings
    broadcast_message "§c[HARDCORE] A player has died! Server resetting in 15 seconds..."
    sleep 5
    broadcast_message "§c[HARDCORE] World reset in 10 seconds..."
    sleep 5
    broadcast_message "§c[HARDCORE] World reset in 5 seconds..."
    sleep 5
    
    # Stop server gracefully
    send_server_command "stop"
    echo "$(date): Sent stop command to server" >> "$LOG_FILE"
    
    # Wait for server to stop
    sleep 10
    
    # Create backup
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_NAME="world_backup_${TIMESTAMP}"
    sudo -u minecraft mkdir -p "$BACKUP_DIR"
    
    cd "$MINECRAFT_DIR"
    sudo -u minecraft tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" \
        --ignore-failed-read \
        world world_nether world_the_end 2>/dev/null
    
    echo "$(date): Backup created: ${BACKUP_NAME}.tar.gz" >> "$LOG_FILE"
    
    # Delete world files
    sudo rm -rf "$MINECRAFT_DIR/world" "$MINECRAFT_DIR/world_nether" "$MINECRAFT_DIR/world_the_end"
    sudo rm -f "$MINECRAFT_DIR/uid.dat" 2>/dev/null
    
    echo "$(date): World files deleted" >> "$LOG_FILE"
    
    # Restart server
    sudo systemctl start minecraft
    echo "$(date): Server restarted with fresh world" >> "$LOG_FILE"
}

# ============================================
# Main Loop
# ============================================

echo "$(date): Death monitor started" >> "$LOG_FILE"

# Follow the journalctl logs in real-time
sudo journalctl -u minecraft -f -n 0 | while read -r line; do
    # Check if line contains death message
    # Minecraft death messages contain "died" or specific death causes
    if echo "$line" | grep -qE "(fell from a high place|was slain by|was shot by|drowned|experienced kinetic energy|blew up|was killed|burned to death|tried to swim in lava|was squashed|went off with a bang|was impaled|starved to death|suffocated|was poked to death|was pricked to death|walked into a cactus|was roasted|was struck by lightning|was frozen|was skewered|death\.attack\.|died)"; then
        # Extract player name (appears before the death message)
        PLAYER=$(echo "$line" | grep -oP '(?<=INFO\]: )[A-Za-z0-9_]+(?= (fell|was|drowned|experienced|blew|burned|tried|went|walked|death|died))')
        
        if [ ! -z "$PLAYER" ]; then
            echo "$(date): DEATH DETECTED - Player: $PLAYER" >> "$LOG_FILE"
            echo "$(date): Death message: $line" >> "$LOG_FILE"
            
            # Trigger world reset
            reset_world_auto
            
            # Exit after reset (systemd will restart this service)
            exit 0
        fi
    fi
done