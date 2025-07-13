#!/bin/bash

SLURM_VERSION="23.02.5"
JSON_FILE="hostnodelist.json"
SLURM_CONF_FILE="/etc/slurm/slurm.conf"
MUNGE_KEY_FILE="/etc/munge/munge.key"

if [ ! -f "$JSON_FILE" ]; then exit 1; fi
if ! command -v jq &> /dev/null; then exit 1; fi
if ! command -v clush &> /dev/null; then exit 1; fi

CONTROLLER_HOSTNAME=$(jq -r '.host.name' "$JSON_FILE")
ALL_NODES=$(jq -r '.nodes[].name' "$JSON_FILE" | tr '\n' ' ' | sed 's/ $//')
COMPUTE_NODES=$(jq -r --arg ctrl "$CONTROLLER_HOSTNAME" '.nodes[] | select(.name != $ctrl) | .name' "$JSON_FILE" | tr '\n' ',' | sed 's/,$//')

wget -q --show-progress https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2
mv slurm-${SLURM_VERSION}.tar.bz2 /root/
cd /root/
rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2 &>/dev/null
rm -f rpmbuild/RPMS/x86_64/slurm-torque-*
rm -f rpmbuild/RPMS/x86_64/slurm-pam-*

if [ -n "$COMPUTE_NODES" ]; then
    clush -w $COMPUTE_NODES --copy /root/rpmbuild/RPMS/x86_64/ --dest /root/slurm_rpms &>/dev/null
fi

clush -w "$ALL_NODES" "bash -c '
rpm --install --nodeps /root/slurm_rpms/*.rpm &>/dev/null
export SLURMUSER=1001
groupadd -g \$SLURMUSER slurm &>/dev/null
useradd -m -c \"Slurm workload manager\" -d /var/lib/slurm -u \$SLURMUSER -g slurm -s /bin/bash slurm &>/dev/null
mkdir -p /var/spool/slurmd /var/log/slurm
chown slurm: /var/spool/slurmd /var/log/slurm
chmod 755 /var/spool/slurmd /var/log/slurm
touch /var/log/slurm/slurmd.log
chown slurm: /var/log/slurm/slurmd.log
'"

dd if=/dev/urandom of=$MUNGE_KEY_FILE bs=1 count=1024 &>/dev/null
chown munge: $MUNGE_KEY_FILE
chmod 400 $MUNGE_KEY_FILE
clush -w $ALL_NODES --copy $MUNGE_KEY_FILE --dest $MUNGE_KEY_FILE &>/dev/null
clush -w $ALL_NODES "chown munge: $MUNGE_KEY_FILE && chmod 400 $MUNGE_KEY_FILE && systemctl restart munge" &>/dev/null

NODE_INFO_FILE=$(mktemp)
clush -w $ALL_NODES "slurmd -C" > $NODE_INFO_FILE

jq -r '.host.name' "$JSON_FILE" > /dev/null
while IFS= read -r line; do
    if [[ $line =~ NodeName=([^[:space:]]+) ]]; then
        NODE_NAME=${BASH_REMATCH[1]}
        NODE_IP=$(getent ahosts "$NODE_NAME" | awk 'NR==1{print $1}')
        HW_INFO=$(echo "$line" | sed 's/NodeName=[^ ]* //')
        jq --arg name "$NODE_NAME" --arg ip "$NODE_IP" --arg config "$HW_INFO" \
           '(.nodes[] | select(.name == $name) | .ip = $ip | .config = $config)' \
           "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"
    fi
done < "$NODE_INFO_FILE"
rm $NODE_INFO_FILE

CONTROLLER_IP=$(jq -r --arg name "$CONTROLLER_HOSTNAME" '.nodes[] | select(.name == $name) | .ip' "$JSON_FILE")
jq --arg name "$CONTROLLER_HOSTNAME" --arg ip "$CONTROLLER_IP" \
   '(.host.name = $name) | (.host.ip = $ip)' "$JSON_FILE" > "${JSON_FILE}.tmp" && mv "${JSON_FILE}.tmp" "$JSON_FILE"

CONTROLLER_NAME=$(jq -r '.host.name' "$JSON_FILE")
sed -i "s/^SlurmctldHost=.*/SlurmctldHost=${CONTROLLER_NAME}(${CONTROLLER_IP})/" "$SLURM_CONF_FILE"
sed -i '/^NodeName=/d' "$SLURM_CONF_FILE"

jq -r '.nodes[] | .name + "|" + .ip + "|" + .config' "$JSON_FILE" | while IFS="|" read -r name ip config; do
  if [ -n "$name" ] && [ -n "$ip" ]; then
    NODE_CONFIG_LINE="NodeName=${name} NodeAddr=${ip} ${config} State=UNKNOWN"
    echo "$NODE_CONFIG_LINE" >> "$SLURM_CONF_FILE"
  fi
done

clush -w $ALL_NODES --copy $SLURM_CONF_FILE --dest $SLURM_CONF_FILE &>/dev/null

systemctl restart slurmctld
systemctl status
clush -w $ALL_NODES "systemctl enable --now slurmd" &>/dev/null
