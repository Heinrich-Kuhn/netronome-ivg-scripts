#!/bin/bash
#package_install.sh

#check kernel

kernel_test=$(setpci -d 19ee:4000 0xFFC.L | sed '2,$d' )

if [ $kernel_test == "ffffffff" ]; then
    echo "Kernel is valid"
else
    echo "The installed kernel is missing a required patch"
    echo "Locating kernel installation files.."
    cd /root
    ls AOVS_kernel*.tar.gz 2>/dev/null

    if [ $? == 2 ]; then
        echo "Unable to find AOVS_kernel archive in /root/"
        echo "Please do the following"
        echo " 1) Download the required kernel archive from support.netronome.com"
        echo " 2) Place archive in /root/"
        echo " 3) Rerun this script"
        exit -1
    else
        echo "Installing new kernel.."
        tar zxvf AOVS_kernel*.tar.gz \
            || exit -1
        cd AOVS_ker* \
            || exit -1
        rpm -i *.rpm

        echo "New kernel has been installed - Please reboot machine"
        exit 0
    fi 
fi

script_dir="$(dirname $(readlink -f $0))"

kovs_dir="/usr/local/src/kovs/ovs"
if [ -d $kovs_dir ]; then
    echo "Uninstall Kernel-OVS"
    make -C $kovs_dir uninstall \
        || exit -1
fi

cd
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
  libjansson-dev guilt pkg-config libevent-dev ethtool build-essential libssl-dev \
  libnl-3-200 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev psmisc gawk \
  libzmq3-dev protobuf-c-compiler protobuf-compiler python-protobuf \
  libnuma1 libnuma-dev python-ethtool python-six python-ethtool \
  virtinst bridge-utils cpu-checker libjansson-dev dkms
  
  # CPU-meas pre-req
  apt-get -y install aha htop sysstat
  
  # Clean-up
  apt -y autoremove
  
  # Fix dependencies
  apt -f install
  
  #VM pre-req
  apt-get -y install libguestfs-tools qemu-kvm libvirt-bin qemu-kvm libvirt-bin

#Get Ubuntu Version
UBUNTU_VERSION=$(lsb_release -a 2>/dev/null | grep Codename: | awk '{print $2}')

#Check if any agilio .tar files are in the folder
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
    protobuf-c-devel python-six numactl-libs python-ethtool \
    python-virtinst virt-manager libguestfs-tools \
    cloud-utils lvm2 wget git net-tools centos-release-qemu-ev.noarch \
    qemu-kvm-ev libvirt libvirt-python virt-install \
    numactl-devel numactl-devel pearl

    #CPU-meas pre-req
    yum -y install sysstat aha htop

    #Disable firewall for vxlan tunnels  
    systemctl disable firewalld.service
    systemctl stop firewalld.service

    #Disable NetworkManager
    systemctl disable NetworkManager.service
    systemctl stop NetworkManager.service
    service libvirtd restart

    #SELINUX config
    setenforce 0
    sed -E 's/(SELINUX=).*/\1disabled/g' -i /etc/selinux/config

    yum -y install centos-release-qemu-ev.noarch qemu-kvm-ev libvirt libvirt-python virt-install

    [ -d $HOME/aha ] && rm -rf $HOME/aha
    git clone https://github.com/theZiz/aha \
        || exit -1
    make -C aha install \
        || exit -1

    # Locate latest Agilio-OVS RPM package in root home directory
    filter="agilio-ovs-2.6.B-r*_rpm.tar.gz"
    pkgfile=$(find /root -maxdepth 1 -type f -name "$filter" \
        | sort \
        | tail -n 1)

    if [ "$pkgfile" == "" ]; then
        echo "ERRORL Could not find Agilio-OVS .tar.gz file in root directory"
        echo "Please copy the Agilio-OVS .tar.gz file into /root/"
        exit -1
    fi

    tar x -C $HOME -f $pkgfile \
        || exit -1
    INSTALL_DIR=$(basename $pkgfile .tar.gz)
    cd $INSTALL_DIR \
        || exit -1
    rpm -ivh *.rpm \
        || exit -1

    echo
    echo "Checking if NIC flash is required..."
    sleep 1

    /opt/netronome/bin/nfp-update-flash.sh \
        || exit -1

fi

echo "DONE(package_install.sh)"

exit 0

