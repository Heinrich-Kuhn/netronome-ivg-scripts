#!/bin/bash
export DPDK_BASE_DIR=/root/
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_VERSION=dpdk-16.11.2
export DPDK_EXTRACTED_NAME=dpdk-stable-16.11.2
export DPDK_BUILD=$DPDK_BASE_DIR/$DPDK_VERSION/$DPDK_TARGET

NUM_CPUS=$(cat /proc/cpuinfo | grep "processor\\s: " | wc -l)

echo "Cleaning.."
if [ -d "$DPDK_BASE_DIR/$DPDK_EXTRACTED_NAME" ]; then
  rm -rf $DPDK_BASE_DIR/$DPDK_EXTRACTED_NAME
fi

if [ ! -e "$DPDK_BASE_DIR/$DPDK_VERSION.tar.gz" ]; then
  echo "Downloading.."
  wget http://fast.dpdk.org/rel/$DPDK_VERSION.tar.gz --directory-prefix=$DPDK_BASE_DIR
fi

echo "Extracting.."
tar xf $DPDK_BASE_DIR/$DPDK_VERSION.tar.gz -C $DPDK_BASE_DIR
cd $DPDK_BASE_DIR/$DPDK_EXTRACTED_NAME
sed 's/CONFIG_RTE_BUILD_SHARED_LIB=y/CONFIG_RTE_BUILD_SHARED_LIB=n/' -i config/common_base
sed 's/CONFIG_RTE_LIBRTE_NFP_PMD=n/CONFIG_RTE_LIBRTE_NFP_PMD=y/' -i config/common_base

make config T=x86_64-native-linuxapp-gcc
make -j $NUM_CPUS install DESTDIR=dpdk-install T=$DPDK_TARGET

igb_ko=$(readlink -f $(find . -name "igb_uio.ko" | head -1))
cp $igb_ko  /lib/modules/$(uname -r)/extra/
depmod -a

