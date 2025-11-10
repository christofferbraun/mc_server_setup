#!/bin/bash
# Minecraft Death Monitor Script
# Watches logs for player deaths and triggers automatic world reset

# ============================================
# CONFIGURATION
# ============================================
LOG_FILE="/var/log/minecraft-death-monitor.log"
RESET_SCRIPT="/opt/minecraft/reset-world-auto.sh"

# ============================================
# Main Loop
# ============================================

echo "$(date): Death monitor started" >> "$LOG_FILE"

# Follow the journalctl logs in real-time
journalctl -u minecraft -f -n 0 | while read -r line; do
    # Check if line contains death message
    if echo "$line" | grep -qE "(fell from a high place|was slain by|was shot by|drowned|experienced kinetic energy|blew up|was killed|burned to death|tried to swim in lava|was squashed|went off with a bang|was impaled|starved to death|suffocated|was poked to death|was pricked to death|walked into a cactus|was roasted|was struck by lightning|was frozen|was skewered|death\.attack\.|died)"; then
        # Extract player name
        PLAYER=$(echo "$line" | grep -oP '(?<=INFO\]: )[A-Za-z0-9_]+(?= (fell|was|drowned|experienced|blew|burned|tried|went|walked|death|died))')
        
        if [ ! -z "$PLAYER" ]; then
            echo "$(date): ===========================================" >> "$LOG_FILE"
            echo "$(date): DEATH DETECTED - Player: $PLAYER" >> "$LOG_FILE"
            echo "$(date): Death message: $line" >> "$LOG_FILE"
            echo "$(date): ===========================================" >> "$LOG_FILE"
            
            # Trigger world reset using the auto-reset script
            if [ -f "$RESET_SCRIPT" ]; then
                echo "$(date): Executing reset script..." >> "$LOG_FILE"
                bash "$RESET_SCRIPT" 2>&1 | tee -a "$LOG_FILE"
            else
                echo "$(date): ERROR: Reset script not found at $RESET_SCRIPT" >> "$LOG_FILE"
                exit 1
            fi
            
            echo "$(date): Reset complete, exiting death monitor (will restart automatically)" >> "$LOG_FILE"
            
            # Exit after reset (systemd will restart this service)
            exit 0
        fi
    fi
done