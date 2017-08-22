#!/bin/bash
#install_dependencies.sh

apt-get install \
 autoconf automake bison dkms ethtool flex g++ gawk gcc hwloc-nox \
 libcap-ng0 libevent-dev libftdi1 libjansson4 libjansson-dev libnl-3-200 \
 libnl-3-dev libnl-genl-3-200 libnl-genl-3-dev libnuma1 libnuma-dev \
 libpcap-dev libreadline-dev libssl-dev libtool libzmq3-dev make \
 pkg-config protobuf-c-compiler protobuf-compiler psmisc \
 python-ethtool python-protobuf python-six uuid-runtime \
 || exit -1

exit 0
