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
    # Comprehensive list of all Minecraft death messages
    if echo "$line" | grep -qE "(was shot by|was pricked to death|went up in flames|walked into fire|was squished|was roasted in dragon|drowned|died from dehydration|hit the ground too hard|blew up|was squashed by|was skewered by|was fireballed by|went off with a bang|experienced kinetic energy|froze to death|died|was killed|discovered the floor was lava|walked into the danger zone|suffocated in a wall|was killed by.*magic|tried to swim in lava|was struck by lightning|was smashed by|was slain by|burned to death|fell out of the world|left the confines|was obliterated by|was speared by|was impaled on|starved to death|was stung to death|was poked to death|was pummeled by|withered away)"; then
        # Extract player name
        PLAYER=$(echo "$line" | grep -oP '(?<=INFO\]: )[A-Za-z0-9_]+(?= (was|drowned|experienced|blew|went|burned|tried|hit|discovered|suffocated|died|fell|left|starved|withered|walked|froze))')
        
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