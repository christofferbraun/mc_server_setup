#!/bin/bash
# Automatic World Reset Script (No confirmation required)
# Used by death monitor for automatic resets

# ============================================
# CONFIGURATION
# ============================================
MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/opt/minecraft/world-backups"
WORLD_NAME="world"
WORLD_NETHER="world_nether"
WORLD_END="world_the_end"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

LOG_FILE="/var/log/minecraft-death-monitor.log"

echo -e "${YELLOW}Starting automatic world reset...${NC}" | tee -a "$LOG_FILE"

# Step 1: Stop the server by killing the process
echo -e "${YELLOW}[1/4] Stopping Minecraft server...${NC}" | tee -a "$LOG_FILE"

# Kill minecraft process
pkill -9 -f "paper.jar"
pkill -9 -f "SCREEN.*minecraft"

sleep 5

# Check if stopped
if pgrep -f "paper.jar" > /dev/null; then
    echo -e "${RED}ERROR: Failed to stop Minecraft server!${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
echo -e "${GREEN}✓ Server stopped${NC}" | tee -a "$LOG_FILE"

# Step 2: Create backup
echo -e "${YELLOW}[2/4] Creating backup...${NC}" | tee -a "$LOG_FILE"
sudo -u minecraft mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="world_backup_${TIMESTAMP}"

cd "$MINECRAFT_DIR"

if [ -d "$WORLD_NAME" ] || [ -d "$WORLD_NETHER" ] || [ -d "$WORLD_END" ]; then
    sudo -u minecraft tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" \
        --ignore-failed-read \
        "$WORLD_NAME" "$WORLD_NETHER" "$WORLD_END" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
        echo -e "${GREEN}✓ Backup created: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}⚠ Backup creation had issues, but continuing...${NC}" | tee -a "$LOG_FILE"
    fi
else
    echo -e "${YELLOW}⚠ No existing world found to backup${NC}" | tee -a "$LOG_FILE"
fi

# Step 3: Delete world files
echo -e "${YELLOW}[3/4] Deleting world files...${NC}" | tee -a "$LOG_FILE"

for world_dir in "$WORLD_NAME" "$WORLD_NETHER" "$WORLD_END"; do
    if [ -d "$MINECRAFT_DIR/$world_dir" ]; then
        rm -rf "$MINECRAFT_DIR/$world_dir"
        echo -e "${GREEN}✓ Deleted $world_dir${NC}" | tee -a "$LOG_FILE"
    fi
done

rm -f "$MINECRAFT_DIR/uid.dat" 2>/dev/null

# Verify deletion
if [ -d "$MINECRAFT_DIR/world" ]; then
    echo -e "${RED}ERROR: World directory still exists!${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# Step 4: Restart server
echo -e "${YELLOW}[4/4] Starting Minecraft server with fresh world...${NC}" | tee -a "$LOG_FILE"
systemctl start minecraft

sleep 5

if systemctl is-active --quiet minecraft; then
    echo -e "${GREEN}✓ Server started successfully!${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}ERROR: Server failed to start!${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "${GREEN}================================${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}  WORLD RESET COMPLETE!${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}================================${NC}" | tee -a "$LOG_FILE"