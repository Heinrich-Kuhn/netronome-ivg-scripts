#!/bin/bash
#package_install.sh

script_dir="$(dirname $(readlink -f $0))"

#Checking AOVS version
DATA_DIR=/opt/netronome/etc
for SCRIPT in ns_sdn_revision.sh ns_sdn_version.sh ns_sdn_install_type.sh; do
  if [ -f $DATA_DIR/$SCRIPT ]; then
    . $DATA_DIR/$SCRIPT
  fi
done

#Check if AOVS is installed, uninstall if present
if [ -z ${NS_SDN_REVISION+x} ]; then
   echo "Agilio-OVS is not installed"

else
   NS_SDN_REVISION=$(echo $NS_SDN_REVISION | cut -f1 -d":")
   #echo "Agilio-OVS $NS_SDN_VERSION Revision $NS_SDN_REVISION is installed"
   #echo "Uninstalling Agilio-OVS"
   $script_dir/vm_shutdown_all.sh
   rmmod vfio-pci
   /opt/netronome/bin/agilio-ovs-uninstall.sh -y

   #Check if uninstall script exited cleanly
   if [ $? == 1 ]; then
      exit 1
   fi
fi

# Ubuntu
grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
  # Agilio OVS requirement
  apt-get -y install make autoconf automake libtool \
  gcc g++ bison flex hwloc-nox libreadline-dev libpcap-dev dkms libftdi1 libjansson4 \
  libjansson-dev guilt pkg-config libevent-dev ethtool libssl-dev \
  libnl-3-200 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev psmisc gawk \
  libzmq3-dev protobuf-c-compiler protobuf-compiler python-protobuf \
  libnuma1 libnuma-dev python-six python-ethtool install qemu-kvm libvirt-bin \
  virtinst bridge-utils cpu-checker cloud-image-utils
  # Clean-up
  apt -y autoremove
  # Fix dependencies
  apt -f install
  # guestfish
  apt-get -y install libguestfs-tools

#Get Ubuntu Version
UBUNTU_VERSION=$(lsb_release -a 2>/dev/null | grep Codename: | awk '{print $2}')

#Check if any agilio .tar files are in the folder
cd script_dir="$(dirname $(readlink -f $0))"
ls agilio-ovs-2.6.B-r* 2>/dev/null

if [ $? == 2 ]; then
   echo "Could not find Agilio-OVS .tar.gz file in folder"
   echo "Please copy the Agilio-OVS .tar.gz file into the same folder as this script"
   exit 1
else

   LATEST_AOVS=$(ls agilio-ovs-2.6.B-r* 2>/dev/null | grep .tar.gz | tail -n1)
   tar xf $LATEST_AOVS
   INSTALL_DIR=$(basename $LATEST_AOVS .tar.gz)
   cd $INSTALL_DIR

   #Check ubuntu version
   if [ $UBUNTU_VERSION == "trusty" ]; then
      cd trusty
   else
      cd xenial
   fi
   dpkg -i *.deb || exit -1
   echo
   echo
   echo "Checking if NIC flash is required..."
   sleep 5
   /opt/netronome/bin/nfp-update-flash.sh
fi
fi

# CentOS
grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
  # Agilio OVS requirement
  yum -y install epel-release
  yum -y install make autoconf automake libtool gcc gcc-c++ libpcap-devel \
  readline-devel jansson-devel libevent libevent-devel libtool openssl-devel \
  bison flex gawk hwloc gettext texinfo rpm-build \
  redhat-rpm-config graphviz python-devel python python-devel tcl-devel \
  tk-devel texinfo dkms zip unzip pkgconfig wget patch minicom libusb \
  libusb-devel psmisc libnl3-devel libftdi pciutils \
  zeromq3 zeromq3-devel protobuf-c-compiler protobuf-compiler protobuf-python \
  protobuf-c-devel python-six numactl-libs python-ethtool kvm qemu-kvm \
  python-virtinst libvirt libvirt-python virt-manager libguestfs-tools \
  cloud-utils virt-install lvm2 wget git net-tools centos-release-qemu-ev.noarch \
  qemu-kvm-ev libvirt libvirt-python libguestfs-tools virt-install tmux sysstat aha
  
  #Disable firewall for vxlan tunnels  
  systemctl disable firewalld.service
  systemctl stop firewalld.service

  #Disable NetworkManager
  systemctl disable NetworkManager.service
  systemctl stop NetworkManager.service

  #SELINUX config
  setenforce 0
  sed -E 's/(SELINUX=).*/\1disabled/g' -i /etc/selinux/config

ls /root/agilio-ovs-2.6.B-r* 2>/dev/null
if [ $? == 2 ]; then
   echo "Could not find Agilio-OVS .tar.gz file in root directory"
   echo "Please copy the Agilio-OVS .tar.gz file into /root/"
   exit -1
else

   LATEST_AOVS=$(ls /root/agilio-ovs-2.6.B-r* 2>/dev/null | grep .tar.gz | tail -n1)
   cd /root/
   tar xf $LATEST_AOVS
   INSTALL_DIR=$(basename $LATEST_AOVS .tar.gz)
   cd $INSTALL_DIR
   rpm -ivh *.rpm || exit -1
   echo
   echo
   echo "Checking if NIC flash is required..."
   sleep 5
   /opt/netronome/bin/nfp-update-flash.sh
fi

fi

exit 0

