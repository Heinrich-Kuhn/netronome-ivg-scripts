#!/bin/bash

grep -q 'export LC_ALL=en_US.UTF-8' ~/.bashrc || echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
grep -q 'export LANG=en_US.UTF-8' ~/.bashrc || echo 'export LANG=en_US.UTF-8' >> ~/.bashrc

# Ubuntu
grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
  # Agilio OVS requirement
  apt-get -y install make autoconf automake libtool \
  gcc g++ bison flex hwloc-nox libreadline-dev libpcap-dev dkms libftdi1 libjansson4 \
  libjansson-dev guilt pkg-config libevent-dev ethtool libssl-dev \
  libnl-3-200 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev psmisc gawk \
  libzmq3-dev protobuf-c-compiler protobuf-compiler python-protobuf \
  libnuma1 libnuma-dev python-six python-ethtool
  # MoonGen
  apt-get -y install cmake
  # Clean-up
  apt -y autoremove
  # Fix dependencies
  apt -f install
  # Framework tools
  apt-get -y install python python-dev python-pip bc sysstat htop
  # guestfish
  apt-get -y install libguestfs-tools
  # ovs
  apt-get -y install libssl-dev iproute tcpdump linux-headers-$(uname -r)
  # Cloud config
  apt-get -y cloud-image-utils
fi

# CentOS
grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
  # Agilio OVS requirement
  yum -y install epel-release
  yum -y install make autoconf automake libtool gcc gcc-c++ libpcap-devel \
  readline-devel jansson-devel libevent libevent-devel libtool openssl-devel \
  bison flex gawk hwloc gettext texinfo kernel-devel-$(uname -r)  kernel-headers-$(uname -r) rpm-build \
  redhat-rpm-config graphviz python-devel python python-devel tcl-devel \
  tk-devel texinfo dkms zip unzip pkgconfig wget patch minicom libusb \
  libusb-devel psmisc libnl3-devel libftdi pciutils \
  zeromq3 zeromq3-devel protobuf-c-compiler protobuf-compiler protobuf-python \
  protobuf-c-devel python-six numactl-libs python-ethtool 
  # MoonGen
  yum -y install cmake
  # Framework tools
  yum -y install python python-dev python-pip bc sysstat htop
  # guestfish
  yum -y install libguestfs-tools
  # ovs
  yum -y install libssl-dev iproute tcpdump linux-headers-$(uname -r)
  # Cloud config
  yum -y cloud-image-utils
fi


# Both
pip install --upgrade pip
pip install --upgrade setuptools --user python
pip install requests[security] --user python
pip install urllib3[secure] --user python
pip install numpy --user python
pip install pexpect --user python

