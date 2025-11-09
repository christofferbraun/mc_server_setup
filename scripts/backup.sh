#!/bin/bash
# Minecraft Server Automated Backup Script
# Creates compressed backups of world files and plugins

# ============================================
# CONFIGURATION
# ============================================
MINECRAFT_DIR="/opt/minecraft"
BACKUP_DIR="/opt/minecraft/backups"
RETENTION_DAYS=7  # Keep backups for 7 days

# ============================================
# Script Logic
# ============================================
DATE=$(date +%Y%m%d-%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "Starting backup at $(date)"

# Backup worlds and plugins
tar -czf "$BACKUP_DIR/backup-$DATE.tar.gz" \
  -C "$MINECRAFT_DIR" \
  world \
  world_nether \
  world_the_end \
  plugins \
  server.properties \
  2>/dev/null

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/backup-$DATE.tar.gz" | cut -f1)
    echo "✓ Backup completed: backup-$DATE.tar.gz ($BACKUP_SIZE)"
else
    echo "✗ Backup failed!"
    exit 1
fi

# Keep only backups newer than RETENTION_DAYS
echo "Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete

# List current backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | wc -l)
echo "Total backups: $BACKUP_COUNT"
echo "Backup completed at $(date)"