#!/bin/bash

if [ ! -f "/etc/dpdk.conf" ]; then
    echo "ERROR($0): missing DPDK settings file /etc/dpdk.conf"
    exit -1
fi

. /etc/dpdk.conf

if [ ! -d "$RTE_SDK" ]; then
    echo "ERROR($0): missing DPDK directory $RTE_SDK"
    exit -1
fi

if [ -d /opt/src/virtio-forwarder ]; then
    rm -rf /opt/src/virtio-forwarder
fi

if systemctl is-active -q virtio-forwarder ; then
    echo " - Stop virtio-forwarder"
    systemctl stop virtio-forwarder
fi

if systemctl is-enabled -q virtio-forwarder ; then
    echo " - Disable virtio-forwarder"
    systemctl disable virtio-forwarder
fi

find /etc/systemd/system -name 'virtio-forwarder.*' -delete
find /etc/default -name 'virtioforwarder' -delete

systemctl daemon-reload
systemctl reset-failed

grep ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then

    yum install policycoreutils-python \
        || exit -1
    semanage permissive -a svirt_t \
        || exit -1
fi

sed -r 's#^(CONFIG_RTE_MAX_ETHPORTS)=.*#\1=64#' \
    -i $RTE_SDK/config/common_base
sed -r 's#^(CONFIG_RTE_LIBRTE_VHOST_NUMA)=.*#\1=y#' \
    -i $RTE_SDK/config/common_base
sed -r 's#^(CONFIG_RTE_LIBRTE_NFP_PMD)=.*#\1=y#' \
    -i $RTE_SDK/config/common_base

echo " - Rebuilding DPDK $DPDK_VERSION with NFP_PMD enabled"
make -C $RTE_SDK config T="$RTE_TARGET" \
    || exit -1
make -C $RTE_SDK -j8 \
    || exit -1

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
    yum -y install python-sphinx \
        || exit -1
    yum remove virtio-forwarder \
        > /dev/null 2>&1
fi

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    apt-get -y install python-sphinx \
        || exit -1
    dpkg --purge virtio-forwarder \
        > /dev/null 2>&1
fi

mkdir -p /opt/src
cd /opt/src

echo " - Clone Netronome's VirtIO Forwarder"
git clone https://github.com/Netronome/virtio-forwarder \
    || exit -1
cd /opt/src/virtio-forwarder \
    || exit -1

echo " - Build Netronome's VirtIO Forwarder"
make \
    || exit -1
make install \
    || exit -1

# Start virtio-forwarder

echo " - Start Netronome's VirtIO Forwarder"
systemctl start virtio-forwarder \
    || exit -1

echo "DONE($(basename $0))"

exit 0
