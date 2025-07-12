#!/bin/bash

OLD_CONTROLLER_HOSTNAME="freya"

if [ -z "$1" ]; then
  exit 1
fi

SLURM_CONF_FILE=$1

if [ ! -f "$SLURM_CONF_FILE" ]; then
    exit 1
fi

NEW_HOSTNAME=$(hostname -s)
NEW_IP=$(hostname -I | awk '{print $1}')

if [ -z "$NEW_HOSTNAME" ] || [ -z "$NEW_IP" ]; then
    exit 1
fi

sed -i "s/^SlurmctldHost=.*/SlurmctldHost=${NEW_HOSTNAME}(${NEW_IP})/" "$SLURM_CONF_FILE"
sed -i "/NodeName=${OLD_CONTROLLER_HOSTNAME}/s/NodeName=${OLD_CONTROLLER_HOSTNAME}.*NodeAddr=[^ ]*/NodeName=${NEW_HOSTNAME} NodeAddr=${NEW_IP}/" "$SLURM_CONF_FILE"
