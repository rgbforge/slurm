#!/bin/bash
set -e
#---------------------------------------------------------------
# create munge key, start munge, test munge
#---------------------------------------------------------------
sudo cp /tmp/munge.key /etc/munge/munge.key
sudo chown munge: /etc/munge/munge.key
sudo chmod 400 /etc/munge/munge.key
sudo chown -R munge: /etc/munge/ /var/log/munge/
sudo chmod 0700 /etc/munge/ /var/log/munge/
systemctl enable munge
systemctl restart munge
