#!/bin/bash

pkgs=()
pkgs+=( "git" )
pkgs+=( "build-essential" )
pkgs+=( "cmake" )
pkgs+=( "libpcap-dev" )
pkgs+=( "python" )
pkgs+=( "unzip" )
pkgs+=( "python-scapy" "python-pip" "python-numpy" )
pkgs+=( "numactl" "libnuma-dev" )

apt-get update \
    || exit -1
apt-get -y install -y ${pkgs[@]} \
    || exit -1

pip install numpy
pip install plotly

exit 0
