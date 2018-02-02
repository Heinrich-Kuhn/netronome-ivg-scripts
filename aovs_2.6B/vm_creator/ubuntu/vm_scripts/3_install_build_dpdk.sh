#!/bin/bash
export DPDK_BASE_DIR=/root/
export DPDK_TARGET=x86_64-native-linuxapp-gcc
export DPDK_VERSION=dpdk-17.05
export DPDK_EXTRACTED_NAME=dpdk-17.05
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
# disable shared libraries
sed 's/CONFIG_RTE_BUILD_SHARED_LIB=y/CONFIG_RTE_BUILD_SHARED_LIB=n/' -i config/common_base
# disable all PMD
#sed -E "s/(CONFIG.*PMD=)(.)/\1n/g" -i config/common_base
# enable only NFP and VIRTIO PMD
sed 's/CONFIG_RTE_LIBRTE_NFP_PMD=n/CONFIG_RTE_LIBRTE_NFP_PMD=y/' -i config/common_base
sed 's/CONFIG_RTE_LIBRTE_VIRTIO_PMD=n/CONFIG_RTE_LIBRTE_VIRTIO_PMD=y/' -i config/common_base
# Modidy VIRTIO default virtual speed
sed 's/ETH_LINK_SPEED_10G/ETH_SPEED_NUM_100G/g' -i drivers/net/virtio/virtio_ethdev.c
sed 's/SPEED_10G/SPEED_100G/g' -i drivers/net/virtio/virtio_ethdev.c
sed '/SPEED_10G/a#define SPEED_100G       100000' -i drivers/net/virtio/virtio_ethdev.h
# Modify SRIOV default virtual speed
sed "s/link.link_speed = ETH_SPEED_NUM_NONE/link.link_speed = ETH_SPEED_NUM_100G/g" -i drivers/net/nfp/nfp_net.c

# Remove KNI (DPDK v16.11.3 does not build on CentOS 7.4)
sed 's/CONFIG_RTE_KNI_KMOD=y/CONFIG_RTE_KNI_KMOD=n/' -i config/common_linuxapp
sed 's/CONFIG_RTE_LIBRTE_KNI=y/CONFIG_RTE_LIBRTE_KNI=n/' -i config/common_linuxapp
sed 's/CONFIG_RTE_LIBRTE_PMD_KNI=y/CONFIG_RTE_LIBRTE_PMD_KNI=n/' -i config/common_linuxapp

make config T=x86_64-native-linuxapp-gcc
make -j $NUM_CPUS install DESTDIR=dpdk-install T=$DPDK_TARGET

lsmod | grep -q igb_uio && modprobe -r igb_uio
igb_ko=$(readlink -f $(find . -name "igb_uio.ko" | head -1))
cp $igb_ko  /lib/modules/$(uname -r)/extra/
depmod -a
modprobe igb_uio

# Save DPDK settings to file
cat <<EOF > /etc/dpdk.conf
export RTE_SDK="$DPDK_BASE_DIR/$DPDK_VERSION"
export RTE_TARGET="$DPDK_TARGET"
EOF

exit 0
