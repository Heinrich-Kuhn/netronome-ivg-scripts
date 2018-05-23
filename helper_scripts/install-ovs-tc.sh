#!/bin/bash

disa_pkg_file="$1"
dpdk_version="$2"

if [ "$IVG_dir" == "" ] || [ ! -d $IVG_dir ]; then
    echo "ERROR($0): please set variable \$IVG_dir"
    exit -1
fi

if [ ! -f "$disa_pkg_file" ]; then
    echo "ERROR($0): no OVS-TC (DISA) package file specified"
    exit -1
fi

script_dir="$(dirname $(readlink -f $0))"

cur_kernel_1=$(uname -r | cut -d '-' -f1 | cut -d '.' -f1 )
cur_kernel_2=$(uname -r | cut -d '-' -f1 | cut -d '.' -f2 )
cur_kernel_3=$(uname -r | cut -d '-' -f1 | cut -d '.' -f3 )

kernel_pass=0

if [ $cur_kernel_1 -gt 3 ]; then
    if [ $cur_kernel_1 -eq 4 ] && [ $cur_kernel_2 -gt 14 ]; then
    	kernel_pass=1
    elif [ $cur_kernel_1 -gt 4 ]; then
    	kernel_pass=1
    fi
fi

if [ $kernel_pass -eq 0 ]; then
    echo "The kernel ($(uname -r)) is too old for Agilio OVS-TC"
    echo "Agilio OVS-TC requires at least 4.15"
    echo "Please update kernel with the script:"
    echo "  $IVG_dir/helper_scripts/kernel_install-4.15.18.sh"
    exit -1
fi

echo "The current kernel ($(uname -r)) is up-to-date"

#INSTALL pre-req
grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    # Agilio OVS requirement
    apt-get install -y \
        make autoconf automake libtool gcc g++ bison flex hwloc-nox \
        libreadline-dev libpcap-dev dkms \
        libftdi1 libjansson4 libjansson-dev guilt pkg-config libevent-dev \
        ethtool build-essential libssl-dev \
        libnl-3-200 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev psmisc gawk \
        libzmq3-dev protobuf-c-compiler protobuf-compiler python-protobuf \
        libnuma1 libnuma-dev python-ethtool python-six python-ethtool \
        virtinst bridge-utils cpu-checker libjansson-dev dkms \
        || exit -1

    # CPU-meas pre-req
    apt-get -y install aha htop sysstat \
        || exit -1

    # Clean-up
    apt -y autoremove \
        || exit -1

    # Fix dependencies
    apt -f install \
        || exit -1

    #VM pre-req
    apt-get install -y libguestfs-tools qemu-kvm libvirt-bin qemu-kvm libvirt-bin \
        || exit -1
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
    # Agilio OVS requirement
    yum install -y epel-release \
        || exit -1
    yum install -y \
        make autoconf automake libtool gcc gcc-c++ libpcap-devel \
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
        numactl-devel numactl-devel pearl \
        || exit -1

    #CPU-meas pre-req
    yum -y install sysstat aha htop \
        || exit -1

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
fi

# Un-package DISA package (do this relatively early)
disa_tmp_dir=$(mktemp --directory)
tar x -C $disa_tmp_dir -f $disa_pkg_file
if [ $? -ne 0 ]; then
    echo "ERROR($0): failed to extract $disa_pkg_file"
    exit -1
fi
disa_install=$(find $disa_tmp_dir -name 'install.sh')
if [ ! -x "$disa_install" ]; then
    echo "ERROR($0): missing install script inside $disa_pkg_file"
    exit -1
fi

# CONFIGURE GRUB
$IVG_dir/helper_scripts/configure_grub.sh \
    || exit -1
$IVG_dir/helper_scripts/configure_hugepages.sh \
    || exit -1

$IVG_dir/helper_scripts/install-dpdk.sh $dpdk_version \
    || exit -1

# KERNEL OVS INSTALL
cd $HOME

if [ -e ovs ]; then
    rm -r ovs
fi

echo " - Clone and Install Open vSwitch"
git clone https://github.com/openvswitch/ovs.git \
    || exit -1
cd ovs \
    || exit -1
git checkout branch-2.8 \
    || exit -1
./boot.sh \
    || exit -1
./configure \
    || exit -1
make -j 8 \
    || exit -1
make -j 8 install \
    || exit -1

echo " - Install OVS-TC (DISA) Firmware"
{
    cd $(dirname $disa_install) \
        || exit -1
    $disa_install \
        || exit -1
}

# Clean-up DISA Firmware temporary directory
/bin/rm -rf $disa_tmp_dir

echo " - Install VirtIO Forwarder"
$IVG_dir/helper_scripts/install-virtio-forwarder.sh dpdk-$dpdk_version \
    || exit -1

path_ovs=$(find / -name "ovs-ctl" | sed -n 1p | sed 's=/ovs-ctl==g')

test=$(cat /etc/environment | grep $path_ovs)

if [ -z "$test" ]; then
    export PATH=$PATH:$path_ovs
    echo $PATH
    echo "PATH=\"$PATH\"" > /etc/environment
fi

echo "DONE($(basename $0))"

exit 0
