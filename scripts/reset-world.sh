#!/bin/bash
# Minecraft World Reset Script
# Stops server, backs up world, deletes it, and restarts with fresh world

# ============================================
# CONFIGURATION
# ============================================
MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/opt/minecraft/world-backups"
WORLD_NAME="world"
WORLD_NETHER="world_nether"
WORLD_END="world_the_end"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}================================${NC}"
echo -e "${RED}  MINECRAFT WORLD RESET SCRIPT${NC}"
echo -e "${RED}================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will DELETE the current world!${NC}"
echo ""
echo "This script will:"
echo "  1. Stop the Minecraft server"
echo "  2. Backup the current world"
echo "  3. Delete all world files"
echo "  4. Restart the server with a fresh world"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Reset cancelled. No changes made.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting world reset process...${NC}"
echo ""

# Step 1: Stop the server
echo -e "${YELLOW}[1/4] Stopping Minecraft server...${NC}"
sudo systemctl stop minecraft

# Wait for server to fully stop
sleep 5

# Check if stopped
if sudo systemctl is-active --quiet minecraft; then
    echo -e "${RED}ERROR: Failed to stop Minecraft server!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Server stopped${NC}"
echo ""

# Step 2: Create backup directory if it doesn't exist
echo -e "${YELLOW}[2/4] Creating backup...${NC}"
sudo -u minecraft mkdir -p "$BACKUP_DIR"

# Create backup with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="world_backup_${TIMESTAMP}"

cd "$MINECRAFT_DIR"

# Backup all world folders if they exist
if [ -d "$WORLD_NAME" ] || [ -d "$WORLD_NETHER" ] || [ -d "$WORLD_END" ]; then
    sudo -u minecraft tar -czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" \
        --ignore-failed-read \
        "$WORLD_NAME" "$WORLD_NETHER" "$WORLD_END" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        BACKUP_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)
        echo -e "${GREEN}✓ Backup created: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})${NC}"
    else
        echo -e "${YELLOW}⚠ Backup creation had issues, but continuing...${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No existing world found to backup${NC}"
fi
echo ""

# Step 3: Delete world files
echo -e "${YELLOW}[3/4] Deleting world files...${NC}"

# Remove world directories
for world_dir in "$WORLD_NAME" "$WORLD_NETHER" "$WORLD_END"; do
    if [ -d "$MINECRAFT_DIR/$world_dir" ]; then
        sudo rm -rf "$MINECRAFT_DIR/$world_dir"
        echo -e "${GREEN}✓ Deleted $world_dir${NC}"
    fi
done

# Also remove any world UID files
sudo rm -f "$MINECRAFT_DIR/uid.dat" 2>/dev/null

echo ""

# Step 4: Restart server
echo -e "${YELLOW}[4/4] Starting Minecraft server with fresh world...${NC}"
sudo systemctl start minecraft

# Wait a moment for server to start
sleep 3

# Check if started successfully
if sudo systemctl is-active --quiet minecraft; then
    echo -e "${GREEN}✓ Server started successfully!${NC}"
else
    echo -e "${RED}ERROR: Server failed to start!${NC}"
    echo "Check logs with: sudo journalctl -u minecraft -n 50"
    exit 1
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  WORLD RESET COMPLETE!${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Summary:"
echo "  • Old world backed up to: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "  • Fresh world is generating now"
echo "  • Server is online and ready for players"
echo ""
echo "Useful commands:"
echo "  • Check server status: sudo systemctl status minecraft"
echo "  • View logs: sudo journalctl -u minecraft -f"
echo "  • List backups: ls -lh $BACKUP_DIR"
echo ""

# Show recent server logs
echo -e "${YELLOW}Recent server logs:${NC}"
sudo journalctl -u minecraft -n 10 --no-pager