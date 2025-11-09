#!/bin/bash
# Cloudflare DDNS Update Script
# Automatically updates Cloudflare DNS A record with current public IP

# ============================================
# CONFIGURATION - Edit these values
# ============================================
ZONE_ID="your_zone_id_here"
API_TOKEN="your_api_token_here"
RECORD_NAME="mc.yourdomain.com"
RECORD_TYPE="A"

# ============================================
# Script Logic - Don't edit below this line
# ============================================
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