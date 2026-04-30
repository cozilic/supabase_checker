#!/usr/bin/env bash

set -e

# Load config
source /app/config.env

mkdir -p /app/state

# 🔴 Viktig fix: logga till stderr
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

check_once() {
    local url="$1"
    local api_key="$2"

    curl -s -o /dev/null -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        -H "apikey: $api_key" \
        "$url"
}

check_with_retries() {
    local url="$1"
    local api_key="$2"

    for ((i=1; i<=RETRIES; i++)); do
        HTTP_CODE=$(check_once "$url" "$api_key")

        if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 400 ]]; then
            echo "UP"
            return
        fi

        log "[$url] Attempt $i failed (HTTP $HTTP_CODE)"

        if [[ $i -lt $RETRIES ]]; then
            sleep "$RETRY_DELAY"
        fi
    done

    echo "DOWN"
}

send_notification() {
    local name="$1"
    local url="$2"

    JSON=$(jq -n \
        --arg title "Supabase Alert: $name" \
        --arg message "🚨 Supabase project DOWN: $name\n$url" \
        --argjson priority 5 \
        '{title: $title, message: $message, priority: $priority}')

    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/gotify_body \
        -X POST "$GOTIFY_URL?token=$GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$JSON")

    log "[$name] Gotify HTTP: $RESPONSE"
    log "[$name] Gotify response: $(cat /tmp/gotify_body)"

    if [[ "$RESPONSE" == "200" ]]; then
        log "[$name] Notification OK"
    else
        log "[$name] Notification FAILED"
    fi
}

send_up_notification() {
    local name="$1"
    local url="$2"

    MESSAGE="✅ Supabase project UP again: $name - $url"

    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/gotify_body \
        -X POST "$GOTIFY_URL?token=$GOTIFY_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"title\": \"Supabase Recovery: $name\",
            \"message\": \"$MESSAGE\",
            \"priority\": 2
        }")

    log "[$name] UP Gotify HTTP: $RESPONSE"
    log "[$name] Gotify response: $(cat /tmp/gotify_body)"
}

# =========================
# MAIN LOOP
# =========================

IFS=';' read -ra PROJECT_ARRAY <<< "$PROJECTS"

for entry in "${PROJECT_ARRAY[@]}"; do
    # Format: name|url|apikey
    IFS='|' read -r NAME URL API_KEY <<< "$entry"

    STATE_FILE="/app/state/${NAME}.state"

    CURRENT_STATUS=$(check_with_retries "$URL" "$API_KEY")
    PREVIOUS_STATUS="UNKNOWN"

    if [[ -f "$STATE_FILE" ]]; then
        PREVIOUS_STATUS=$(cat "$STATE_FILE")
    fi

    log "[$NAME] Current: $CURRENT_STATUS | Previous: $PREVIOUS_STATUS"

 #   if [[ "$CURRENT_STATUS" == "UP" ]]; then
 #       echo "UP" > "$STATE_FILE"
 #       continue
 #   fi

if [[ "$CURRENT_STATUS" == "UP" ]]; then
    if [[ "$PREVIOUS_STATUS" == "DOWN" ]]; then
        send_up_notification "$NAME" "$URL"
    fi

    echo "UP" > "$STATE_FILE"
    continue
fi


    if [[ "$CURRENT_STATUS" == "DOWN" ]]; then
        if [[ "$PREVIOUS_STATUS" != "DOWN" ]]; then
            send_notification "$NAME" "$URL"
        else
            log "[$NAME] Already DOWN, skipping notification"
        fi

        echo "DOWN" > "$STATE_FILE"
    fi
done
