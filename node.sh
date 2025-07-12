#---------------------------------------------------------------
# download slurm, rpmbuild slurm, configure slurm.conf
#---------------------------------------------------------------
wget https://download.schedmd.com/slurm/slurm-23.02.5.tar.bz2
mv slurm-23.02.5.tar.bz2 /root
cd /root 
rpmbuild -ta slurm-23.02.5.tar.bz2
echo "FIX *.RPM"
read varname
rpm --install rpmbuild/RPMS/x86_64/*.rpm
echo "FIX slurm.conf"


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
systemctl status slurmd.service

