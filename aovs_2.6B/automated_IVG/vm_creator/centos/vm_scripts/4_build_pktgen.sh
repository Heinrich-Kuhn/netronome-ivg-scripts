#!/bin/bash

export DPDK_BASE_DIR=/root
export DPDK_VERSION=dpdk-stable-16.11.2
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_BUILD=$DPDK_BASE_DIR/$DPDK_VERSION/$DPDK_TARGET
export PKTGEN=pktgen-3.3.2

echo "Cleaning.."
if [ -d "$DPDK_BASE_DIR/$PKTGEN" ]; then
  rm -rf $DPDK_BASE_DIR/$PKTGEN
fi

if [ ! -e "$DPDK_BASE_DIR/$PKTGEN.tar.gz" ]; then
  echo "Downloading.."
  wget http://dpdk.org/browse/apps/pktgen-dpdk/snapshot/$PKTGEN.tar.gz --directory-prefix=$DPDK_BASE_DIR
fi

echo "Extracting.."
tar xf $DPDK_BASE_DIR/$PKTGEN.tar.gz -C $DPDK_BASE_DIR
cd $DPDK_BASE_DIR/$PKTGEN
make RTE_SDK=$DPDK_BASE_DIR/$DPDK_VERSION RTE_TARGET=$DPDK_TARGET

rm -f /root/dpdk-pktgen
ln -s $DPDK_BASE_DIR/$PKTGEN/app/app/x86_64-native-linuxapp-gcc/pktgen /root/dpdk-pktgen
