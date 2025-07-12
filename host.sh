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
systemctl restart slurmd.service
systemctl status slurmd.service


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
systemctl enable --now slurmctld.service
systemctl status slurmctld.service


systemctl restart slurmd.service
systemctl restart slurmdctld.service
systemctl status slurmd.service
systemctl status slurmctld.service
