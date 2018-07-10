#!/bin/bash

export OVS_BASE_DIR=/root/
export DPDK_BASE_DIR=/opt/src/
export DPDK_VERSION=dpdk-stable-$1
export OVS_VERSION=$2
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_BUILD=$DPDK_BASE_DIR/$DPDK_VERSION/$DPDK_TARGET

NUM_CPUS=$(cat /proc/cpuinfo | grep "processor\\s: " | wc -l)

cd $OVS_BASE_DIR
rm -rf $DIR_BASE/$OVS_VERSION

if [ ! -e "./$OVS_VERSION.tar.gz" ]; then
  echo "Downloading.."
  wget http://openvswitch.org/releases/$OVS_VERSION.tar.gz
fi

tar xf $OVS_VERSION.tar.gz
cd $OVS_VERSION
./boot.sh
./configure --with-dpdk="$DPDK_BUILD" CFLAGS="-Ofast -g -O3 -march=native"

#make - LDFLAGS=-libverbs
#make install 'CFLAGS=-g -O3 -march=native' -j22
make install 'CFLAGS=-Ofast -g -O3 -march=native' -j $NUM_CPUS


