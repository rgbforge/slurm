#!/bin/bash

JSON_FILE=${1:-hostnodelist.json}

if [ ! -f "$JSON_FILE" ]; then
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq not installed"
    exit 1
fi

NEW_HOSTNAME=$(hostname -s)
NEW_IP=$(hostname -I | awk '{print $1}')

if [ -z "$NEW_HOSTNAME" ] || [ -z "$NEW_IP" ]; then
    exit 1
fi

jq \
  --arg name "$NEW_HOSTNAME" \
  --arg ip "$NEW_IP" \
  '(.host.name = $name) | (.host.ip = $ip) | (.nodes[0].name = $name) | (.nodes[0].ip = $ip)' \
  "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
