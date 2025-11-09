#!/bin/bash
# Paper Server Update Script
# Downloads and installs the latest Paper build

# ============================================
# CONFIGURATION
# ============================================
MINECRAFT_DIR="/opt/minecraft"
VERSION="1.21.3"  # Update this to your Minecraft version

# ============================================
# Script Logic
# ============================================

echo "Stopping Minecraft server..."
sudo systemctl stop minecraft

echo "Backing up current jar..."
if [ -f "$MINECRAFT_DIR/paper.jar" ]; then
    cp "$MINECRAFT_DIR/paper.jar" "$MINECRAFT_DIR/paper.jar.backup"
    echo "✓ Backup created: paper.jar.backup"
fi

echo "Downloading latest Paper build for version $VERSION..."
cd "$MINECRAFT_DIR"
sudo -u minecraft wget -q --show-progress \
    "https://api.papermc.io/v2/projects/paper/versions/$VERSION/builds/latest/downloads/paper-$VERSION-latest.jar" \
    -O paper.jar

if [ $? -eq 0 ]; then
    echo "✓ Download complete"
else
    echo "✗ Download failed! Restoring backup..."
    if [ -f "$MINECRAFT_DIR/paper.jar.backup" ]; then
        mv "$MINECRAFT_DIR/paper.jar.backup" "$MINECRAFT_DIR/paper.jar"
    fi
    exit 1
fi

echo "Starting Minecraft server..."
sudo systemctl start minecraft

echo "Update complete! Checking status..."
sleep 3
sudo systemctl status minecraft --no-pager

echo ""
echo "View logs with: sudo journalctl -u minecraft -f"