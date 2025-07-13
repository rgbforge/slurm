#!/bin/bash
set -e

dnf config-manager --set-enabled crb
dnf -y install epel-release
dnf -y install munge munge-devel pam-devel perl readline-devel dbus-devel mariadb-server mariadb-devel rpm-build jq clustershell

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

sudo wget --no-verbose --show-progress https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 -O /root/slurm-${SLURM_VERSION}.tar.bz2
cd /root/
sudo rpmbuild -ta slurm-${SLURM_VERSION}.tar.bz2
sudo rm -f rpmbuild/RPMS/x86_64/slurm-torque-*
sudo rm -f rpmbuild/RPMS/x86_64/slurm-pam-*
sudo rpm --install --nodeps rpmbuild/RPMS/x86_64/*.rpm

clush -w "$COMPUTE_NODES" "bash -c '
sudo groupadd -g 1001 slurm
sudo useradd -m -c \"Slurm workload manager\" -d /var/lib/slurm -u 1001 -g slurm -s /bin/bash slurm
sudo mkdir -p /var/spool/slurmd /var/log/slurm
sudo chown slurm: /var/spool/slurmd /var/log/slurm
sudo chmod 755 /var/spool/slurmd /var/log/slurm
sudo touch /var/log/slurm/slurmd.log
sudo chown slurm: /var/log/slurm/slurmd.log
'"

sudo dd if=/dev/urandom of=$MUNGE_KEY_FILE bs=1 count=1024
sudo chown munge:munge $MUNGE_KEY_FILE
sudo chmod 400 $MUNGE_KEY_FILE

cat $MUNGE_KEY_FILE | clush -w $ALL_NODES "sudo /usr/local/sbin/update-munge-key.sh"
clush -w $ALL_NODES "sudo systemctl restart munge"

NODE_INFO_FILE=$(mktemp)
clush -w $ALL_NODES "sudo slurmd -C" > $NODE_INFO_FILE

while IFS= read -r line; do
  if [[ $line =~ NodeName=([^[:space:]]+) ]]; then
    NODE_NAME=${BASH_REMATCH[1]}
    NODE_IP=$(getent ahosts "$NODE_NAME" | awk 'NR==1{print $1}')
    HW_INFO=$(echo "$line" | sed 's/NodeName=[^ ]* //')
    jq --arg name "$NODE_NAME" --arg ip "$NODE_IP" --arg config "$HW_INFO" \
       '(.nodes[] | select(.name == $name) | .ip = $ip | .config = $config)' \
       "$JSON_FILE" > "${JSON_FILE}.tmp" && sudo mv "${JSON_FILE}.tmp" "$JSON_FILE"
  fi
done < "$NODE_INFO_FILE"
rm $NODE_INFO_FILE

CONTROLLER_IP=$(jq -r --arg name "$CONTROLLER_HOSTNAME" '.nodes[] | select(.name == $name) | .ip' "$JSON_FILE")
jq --arg name "$CONTROLLER_HOSTNAME" --arg ip "$CONTROLLER_IP" \
   '(.host.name = $name) | (.host.ip = $ip)' "$JSON_FILE" > "${JSON_FILE}.tmp" && sudo mv "${JSON_FILE}.tmp" "$JSON_FILE"

TEMP_SLURM_CONF=$(mktemp)
cp "$SLURM_CONF_FILE" "$TEMP_SLURM_CONF"

CONTROLLER_NAME=$(jq -r '.host.name' "$JSON_FILE")
sed -i "s/^SlurmctldHost=.*/SlurmctldHost=${CONTROLLER_NAME}(${CONTROLLER_IP})/" "$TEMP_SLURM_CONF"
sed -i '/^NodeName=/d' "$TEMP_SLURM_CONF"
sed -i '/^PartitionName=/d' "$TEMP_SLURM_CONF"

jq -r '.nodes[] | .name + "|" + .ip + "|" + .config' "$JSON_FILE" | while IFS="|" read -r name ip config; do
  if [ -n "$name" ] && [ -n "$ip" ]; then
    echo "NodeName=${name} NodeAddr=${ip} ${config} State=UNKNOWN" >> "$TEMP_SLURM_CONF"
  fi
done
echo "" >> "$TEMP_SLURM_CONF"
echo "PartitionName=compute Nodes=${COMPUTE_NODES} Default=YES MaxTime=INFINITE State=UP" >> "$TEMP_SLURM_CONF"

sudo mv "$TEMP_SLURM_CONF" "$SLURM_CONF_FILE"

cat $SLURM_CONF_FILE | clush -w $ALL_NODES "sudo /usr/local/sbin/update-slurm-conf.sh"

sudo systemctl restart slurmctld
sudo systemctl status slurmctld
clush -w $ALL_NODES "sudo systemctl enable --now slurmd"
