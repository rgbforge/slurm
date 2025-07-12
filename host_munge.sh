#!/bin/bash

USAGE="Usage: $0 -u <user> -n <hostname_or_ip>"
JSON_FILE="hostnodelist.json"

while getopts ":u:n:h" opt; do
  case ${opt} in
    u )
      REMOTE_USER=$OPTARG
      ;;
    n )
      REMOTE_HOST=$OPTARG
      ;;
    h )
      echo "$USAGE"
      exit 0
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      echo "$USAGE" >&2
      exit 1
      ;;
    : )
      echo "Invalid option: -$OPTARG requires an argument" >&2
      echo "$USAGE" >&2
      exit 1
      ;;
  esac
done


if ! command -v jq &> /dev/null; then
    echo 'jq is not installed' >&2
    exit 1
fi

dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key

scp -p /etc/munge/munge.key ${REMOTE_USER}@${REMOTE_HOST}:/tmp/munge.key

LOCAL_HOSTNAME=$(hostname -s)
LOCAL_IP=$(hostname -I | awk '{print $1}')

REMOTE_SHORT_HOSTNAME=$(ssh ${REMOTE_USER}@${REMOTE_HOST} 'hostname -s')
REMOTE_IP=$(getent ahosts "$REMOTE_HOST" | awk 'NR==1{print $1}')

jq \
  --arg l_name "$LOCAL_HOSTNAME" \
  --arg l_ip "$LOCAL_IP" \
  --arg r_name "$REMOTE_SHORT_HOSTNAME" \
  --arg r_ip "$REMOTE_IP" \
  '(.host.name = $l_name) | (.host.ip = $l_ip) | (.nodes[0].name = $l_name) | (.nodes[0].ip = $l_ip) | (.nodes[1].name = $r_name) | (.nodes[1].ip = $r_ip)' \
  "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

systemctl restart munge

munge -n | unmunge
munge -n | ssh ${REMOTE_USER}@${REMOTE_HOST} unmunge
