#!/bin/bash

# Synchronize package index files
#yum -y update --exclude=kernel*
yum clean all

# Install and enable Multicast DNS
yum -y install epel-release
yum -y install nss-mdns
systemctl enable avahi-daemon
systemctl start avahi-daemon

# Install required packages
yum -y install ftp://fr2.rpmfind.net/linux/centos/7.3.1611/updates/x86_64/Packages/kernel-devel-3.10.0-514.26.1.el7.x86_64.rpm
yum -y install make gcc gcc-c++ libxml2 glibc libpcap-devel python wget pciutils

# Disable SElinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
