#!/bin/bash

USAGE="Usage: $0 -u <user> -n <hostname>"

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
      echo "$USAGE"
      exit 1
      ;;
  esac
done

if [ -z "${REMOTE_USER}" ] || [ -z "${REMOTE_HOST}" ]; then
    echo "$USAGE"
    exit 1
fi

dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
scp -p /etc/munge/munge.key ${REMOTE_USER}@${REMOTE_HOST}:/tmp/munge.key
systemctl restart munge

echo "munge on target"
read
munge -n | unmunge
munge -n | ssh ${REMOTE_USER}@${REMOTE_HOST} unmunge
