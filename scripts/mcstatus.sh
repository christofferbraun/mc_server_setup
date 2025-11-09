#!/bin/bash
# Minecraft Server Status Check Script
# Displays comprehensive server status information

echo "=== Minecraft Server Status ==="
sudo systemctl status minecraft --no-pager -l

echo ""
echo "=== Port Status ==="
sudo netstat -tlnp | grep 25565 || echo "Port 25565 not listening"

echo ""
echo "=== Recent Logs (Last 20 lines) ==="
sudo journalctl -u minecraft -n 20 --no-pager

echo ""
echo "=== Disk Usage ==="
du -sh /opt/minecraft

echo ""
echo "=== System Resources ==="
echo "Memory:"
free -h | grep -E "Mem:|Swap:"
echo ""
echo "CPU Load:"
uptime

echo ""
echo "=== Network ==="
echo "Public IP: $(curl -s ifconfig.me)"
echo "DNS Resolution: $(dig +short mc.christofferbraun.com 2>/dev/null || echo 'DNS query failed')"