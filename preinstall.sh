#---------------------------------------------------------------
# repo and package install
#---------------------------------------------------------------
dnf config-manager --set-enabled crb
dnf install munge munge-devel pam-devel perl readline-devel dbus-devel mariadb-server mariadb-devel rpm-build jq
