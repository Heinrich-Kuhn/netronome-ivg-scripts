#!/bin/bash

cur_kernel_1=$(uname -r | cut -d '-' -f1 | cut -d '.' -f1 )
cur_kernel_2=$(uname -r | cut -d '-' -f1 | cut -d '.' -f2 )
cur_kernel_3=$(uname -r | cut -d '-' -f1 | cut -d '.' -f3 )

echo "KERNEL VERSION: $cur_kernel_1.$cur_kernel_2.$cur_kernel_3"

if [[ $cur_kernel_1 -gt 3 ]] && [[ $cur_kernel_2 -gt 12 ]] && [[ $cur_kernel_3 -gt 11 ]]; then
    echo "Kernel up to date"
    kernel_pass=1
else
    echo "Old Kernel"
    echo "Please update kernel with the appropriate script:"
    echo "/root/IVG-folder/helper_scripts/kernel_install-4.13.12-ubuntu.sh"
    echo "/root/IVG-folder/helper_scripts/kernel_install-4.14.13-ubuntu.sh"
    sleep 3
    kernel_pass=0
fi


if [[ $kernel_pass -eq 1 ]]; then

    #INSTALL pre-req
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
    fi

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
    fi

    #CONFIGURE GRUB
    /root/IVG_folder/helper_scripts/configure_grub.sh

    #KERNEL OVS INSTALL
    cd /root
    git clone https://github.com/openvswitch/ovs.git
    cd ovs
    git checkout branch-2.8
    ./boot.sh
    ./configure
    make -j 8
    make -j 8 install

    #DISA INSTALL
    cd /tmp
    wget --timestamp http://pahome.netronome.com/releases-intern/disa/firmware/disa-2.8.A-r5625-2017-10-25_firmware.tar.gz
    tar xvf disa-2.8.A-r5625-2017-10-25_firmware.tar.gz
    /tmp/disa-2.8.A-r5625-2017-10-25_firmware/install.sh


    echo "OVS_TC installation complete"
fi

exit 0
