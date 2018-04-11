#!/bin/bash

dpdk_version="$1"

# REMOVE VIRTIO-FORWARDER
rm -rf /opt/src/virtio-forwarder
systemctl stop virtio-forwarder
systemctl disable virtio-forwarder
rm /etc/systemd/system/virtio-forwarder.service
rm /etc/systemd/system/virtio-forwarder.*
rm /etc/default/virtioforwarder
systemctl daemon-reload
systemctl reset-failed


grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then

    yum install policycoreutils-python
    semanage permissive -a svirt_t

    cd /opt/src/$dpdk_version/
    sed -i 's#^CONFIG_RTE_MAX_ETHPORTS=.*#CONFIG_RTE_MAX_ETHPORTS=64#g' /opt/src/$dpdk_version/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_VHOST_NUMA=.*#CONFIG_RTE_LIBRTE_VHOST_NUMA=y#g' /opt/src/$dpdk_version/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_NFP_PMD=.*#CONFIG_RTE_LIBRTE_NFP_PMD=y#g' /opt/src/$dpdk_version/config/common_base
    echo "Rebuilding DPDK with NFP_PMD enabled"
    make config T=x86_64-native-linuxapp-gcc
    make -j8

    yum -y install python-sphinx
    yum remove virtio-forwarder

    cd /opt/src/
    git clone https://github.com/Netronome/virtio-forwarder
    cd /opt/src/virtio-forwarder
    export RTE_SDK=/opt/src/$dpdk_version
    export RTE_TARGET=x86_64-native-linuxapp-gcc

    make 
    make install
    
fi

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    # debs
    #add-apt-repository -y ppa:netronome/virtio-forwarder
    #apt-get -y update
    #apt-get -y install virtio-forwarder
    cd /opt/src/$dpdk_version/
    sed -i 's#^CONFIG_RTE_MAX_ETHPORTS=.*#CONFIG_RTE_MAX_ETHPORTS=64#g' /opt/src/$dpdk_version/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_VHOST_NUMA=.*#CONFIG_RTE_LIBRTE_VHOST_NUMA=y#g' /opt/src/$dpdk_version/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_NFP_PMD=.*#CONFIG_RTE_LIBRTE_NFP_PMD=y#g' /opt/src/$dpdk_version/config/common_base
    echo "Rebuilding DPDK with NFP_PMD enabled"
    make config T=x86_64-native-linuxapp-gcc
    make -j8

    apt-get -y install python-sphinx
    dpkg --purge virtio-forwarder

    cd /opt/src/
    git clone https://github.com/Netronome/virtio-forwarder
    cd /opt/src/virtio-forwarder
    export RTE_SDK=/opt/src/$dpdk_version
    export RTE_TARGET=x86_64-native-linuxapp-gcc

    make 
    make install


fi

# Start virtio-forwarder

systemctl start virtio-forwarder # systemd




