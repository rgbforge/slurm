#---------------------------------------------------------------
# repo and package install
#---------------------------------------------------------------
dnf config-manager --set-enabled crb
dnf install munge munge-devel pam-devel perl readline-devel dbus-devel mariadb-server mariadb-devel rpm-build


#---------------------------------------------------------------
# create munge key, start munge, test munge
#---------------------------------------------------------------
dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
chown munge: /etc/munge/munge.key
chmod 400 /etc/munge/munge.key
scp -p /etc/munge/munge.key zephyrus:/etc/munge/munge.key
chown -R munge: /etc/munge/ /var/log/munge/
chmod 0700 /etc/munge/ /var/log/munge/
systemctl enable munge
systemctl start munge
munge -n | unmunge
munge -n | ssh zephyrus unmunge


#---------------------------------------------------------------
# download slurm, rpmbuild slurm, configure slurm.conf
#---------------------------------------------------------------
wget https://download.schedmd.com/slurm/slurm-23.02.5.tar.bz2
mv slurm-23.02.5.tar.bz2 /root
cd /root 
rpmbuild -ta slurm-23.02.5.tar.bz2
echo "FIX *.RPM"
read varname
#rm ctld for node
rpm --install rpmbuild/RPMS/x86_64/*.rpm
echo "FIX slurm.conf"
read varname
nano /etc/slurm/slurm.conf.example
echo "FIX slurm.conf2"
read varname


#---------------------------------------------------------------
# create linux slurm user and group
#---------------------------------------------------------------
export SlurmUSER=1001
groupadd -g $SlurmUSER slurm
useradd  -m -c "Slurm workload manager" -d /var/lib/slurm -u $SlurmUSER -g slurm  -s /bin/bash slurm

---------------------------------------------------------------
# create and modify slurmd log files, start slurmd
#---------------------------------------------------------------
#clush -bw <node-list> --copy /etc/slurm/slurm.conf --dest /etc/slurm/slurm.conf
mkdir /var/spool/slurmd /var/log/slurm
chown slurm: /var/spool/slurmd  /var/log/slurm
chmod 755 /var/spool/slurmd  /var/log/slurm
touch /var/log/slurm/slurmd.log
chown slurm: /var/log/slurm/slurmd.log
slurmd -C
echo "FIX slurm.conf part3"
read varname
#NodeName=test001 Boards=1 SocketsPerBoard=2 CoresPerSocket=2 ThreadsPerCore=1 RealMemory=8010 TmpDisk=32752 Feature=xeon
#TmpFS=/scratch
systemctl enable slurmd.service
systemctl start slurmd.service
#systemctl status slurmd.service


#---------------------------------------------------------------
# create and modify slurmctld log files, start slurmctld
#---------------------------------------------------------------
mkdir /var/spool/slurmctld 
chown slurm: /var/spool/slurmctld 
chmod -R 755 /var/spool/slurmctld 
touch /var/log/slurm/slurmctld.log
chown slurm: /var/log/slurm/slurmctld.log
touch /var/log/slurm/slurm_jobacct.log /var/spool/slurmctld/job_state /var/log/slurm/slurm_jobcomp.log /var/spool/slurmctld/trigger_state
chown slurm: /var/log/slurm/slurm_jobacct.log /var/log/slurm/slurm_jobcomp.log /var/spool/slurmctld/trigger_state /var/spool/slurmctld/job_state
systemctl enable slurmctld.service
systemctl start slurmctld.service
#systemctl status slurmctld.service


systemctl restart slurmd.service
systemctl restart slurmdctld.service



