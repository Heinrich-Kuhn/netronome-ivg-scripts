#!/bin/bash

export DPDK_BASE_DIR=/root/
export DPDK_VERSION=dpdk-16.11.3
export DPDK_EXP=dpdk-stable-16.11.3
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_BUILD=$DPDK_BASE_DIR/$DPDK_VERSION/$DPDK_TARGET

NUM_CPUS=$(cat /proc/cpuinfo | grep "processor\\s: " | wc -l)

echo "Changing directory.."
cd $DPDK_BASE_DIR

echo "Cleaning.."
if [ -d "./$DPDK_VERSION" ]; then rm -rf $DPDK_VERSION; fi

if [ ! -e "./$DPDK_VERSION.tar.gz" ]; then
  echo "Downloading.."
  wget http://fast.dpdk.org/rel/$DPDK_VERSION.tar.xz
fi

echo "Extracting.."
tar xf $DPDK_VERSION.tar.xz
cd $DPDK_EXP

echo "pwd: " $(pwd)
export DPDK_DIR=$(pwd)

make install DESTDIR=dpdk-install T=$DPDK_TARGET

sed -i 's/\(CONFIG_RTE_BUILD_COMBINE_LIBS=\)n/\1y/g' config/common_base
sed -i 's/\(CONFIG_RTE_LIBRTE_PMD_VHOST=\)n/\1y/g' config/common_base 
sed -i 's/\(CONFIG_RTE_LIBRTE_VHOST=\)n/\1y/g' config/common_base
sed -i 's/\(CONFIG_RTE_LIBRTE_VHOST_NUMA=\)n/\1y/g' config/common_base
sed -i 's/\(CONFIG_RTE_LIBRTE_VHOST_DEBUG=\)n/\1y/g' config/common_base

#sed  's/CONFIG_RTE_BUILD_SHARED_LIB=n/CONFIG_RTE_BUILD_SHARED_LIB=y/' -i config/common_base
#sed 's@SRCS-y += ethtool/igb/igb_main.c@#SRCS-y += ethtool/igb/igb_main.c@g' -i lib/librte_eal/linuxapp/kni/Makefile

make config DESTDIR=dpdk-install T=$DPDK_TARGET 'CFLAGS=-Ofast -g'


