#!/bin/bash

# OVH DynDNS Update Script using curl
# Updates both apex (corsair.tf) and wildcard (*.corsair.tf) A records via OVH API

# Load environment variables from .env file if it exists
if [ -f "$(dirname "$0")/.env" ]; then
    export $(cat "$(dirname "$0")/.env" | grep -v '^#' | xargs)
fi

# Configuration
OVH_ENDPOINT="${OVH_ENDPOINT:-https://eu.api.ovh.com/1.0}"
OVH_APP_KEY="${OVH_APPLICATION_KEY:-your_app_key}"
OVH_APP_SECRET="${OVH_APPLICATION_SECRET:-your_app_secret}"
OVH_CONSUMER_KEY="${OVH_CONSUMER_KEY:-your_consumer_key}"
ZONE="${OVH_ZONE:-corsair.tf}"
TARGET_IP=$(curl -s https://api.ipify.org)

# Function to make API calls
call_api() {
    local method=$1
    local path=$2
    local body=$3
    
    local http_query="$OVH_ENDPOINT$path"
    local http_body="$body"
    local timestamp=$(curl -s "$OVH_ENDPOINT/auth/time")
    
    # Build signature string
    local clear_sign="$OVH_APP_SECRET+$OVH_CONSUMER_KEY+$method+$http_query+$http_body+$timestamp"
    local sig="\$1\$$(echo -n "$clear_sign" | openssl dgst -sha1 | sed -e 's/^.* //')"
    
    if [ -z "$body" ]; then
        curl -s -X "$method" \
            -H "Content-Type:application/json;charset=utf-8" \
            -H "X-Ovh-Application:$OVH_APP_KEY" \
            -H "X-Ovh-Timestamp:$timestamp" \
            -H "X-Ovh-Signature:$sig" \
            -H "X-Ovh-Consumer:$OVH_CONSUMER_KEY" \
            "$http_query"
    else
        curl -s -X "$method" \
            -H "Content-Type:application/json;charset=utf-8" \
            -H "X-Ovh-Application:$OVH_APP_KEY" \
            -H "X-Ovh-Timestamp:$timestamp" \
            -H "X-Ovh-Signature:$sig" \
            -H "X-Ovh-Consumer:$OVH_CONSUMER_KEY" \
            --data "$body" \
            "$http_query"
    fi
}

# Function to update a DNS record
update_record() {
    local subdomain=$1
    local display_name=$2
    
    echo "Processing $display_name..."
    
    # Get current record IDs matching this subdomain
    if [ -z "$subdomain" ]; then
        response=$(call_api "GET" "/domain/zone/$ZONE/record?fieldType=A")
    else
        response=$(call_api "GET" "/domain/zone/$ZONE/record?fieldType=A&subDomain=$subdomain")
    fi
    
    echo "  API Response: $response"
    
    # Extract first record ID
    record_id=$(echo "$response" | grep -oP '[0-9]+' | head -1)
    
    if [ -z "$record_id" ]; then
        echo "  Error: Could not find A record for $display_name"
        return 1
    fi
    
    echo "  Record ID: $record_id"
    
    # Get the actual record details
    response=$(call_api "GET" "/domain/zone/$ZONE/record/$record_id")
    current_ip=$(echo "$response" | grep -oP '"target":"?\K[0-9.]+')
    
    echo "  Current IP: $current_ip"
    echo "  Target IP: $TARGET_IP"
    
    # Update if different
    if [ "$current_ip" != "$TARGET_IP" ]; then
        echo "  IP changed, updating $display_name..."
        
        body="{\"target\":\"$TARGET_IP\"}"
        update_response=$(call_api "PUT" "/domain/zone/$ZONE/record/$record_id" "$body")
        
        echo "  Update response: $update_response"
        return 0
    else
        echo "  IP hasn't changed, skipping update"
        return 1
    fi
}

echo "=== OVH DynDNS Update ==="
echo "Current IP: $TARGET_IP"
echo ""

# Track if any updates were made
updates_made=0

# Update apex record (corsair.tf)
if update_record "" "apex (corsair.tf)"; then
    updates_made=1
fi

echo ""

# Update wildcard record (*.corsair.tf)
if update_record "*" "wildcard (*.corsair.tf)"; then
    updates_made=1
fi

echo ""

# Refresh zone if any updates were made
if [ $updates_made -eq 1 ]; then
    echo "Refreshing DNS zone..."
    refresh_response=$(call_api "POST" "/domain/zone/$ZONE/refresh" "")
    echo "Refresh response: $refresh_response"
    echo "DNS records updated successfully!"
else
    echo "No updates needed"
fi