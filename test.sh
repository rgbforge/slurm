scp -p /etc/munge/munge.key zephyrus:/etc/munge/munge.key
chown -R munge: /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/
systemctl enable munge
systemctl start munge
munge -n | unmunge
munge -n | ssh zephyrus unmunge
