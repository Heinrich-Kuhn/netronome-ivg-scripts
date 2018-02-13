#!/bin/bash



grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
    # rpms
    yum install yum-plugin-copr
    yum copr enable netronome/virtio-forwarder
    yum install virtio-forwarder
fi

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
    # debs
    #add-apt-repository -y ppa:netronome/virtio-forwarder
    #apt-get -y update
    #apt-get -y install virtio-forwarder
    cd /opt/src/dpdk-17.05/
    sed -i 's#^CONFIG_RTE_MAX_ETHPORTS=.*#CONFIG_RTE_MAX_ETHPORTS=64#g' /opt/src/dpdk-17.05/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_VHOST_NUMA=.*#CONFIG_RTE_LIBRTE_VHOST_NUMA=y#g' /opt/src/dpdk-17.05/config/common_base
    sed -i 's#^CONFIG_RTE_LIBRTE_NFP_PMD=.*#CONFIG_RTE_LIBRTE_NFP_PMD=y#g' /opt/src/dpdk-17.05/config/common_base
    echo "Rebuilding DPDK with NFP_PMD enabled"
    make config T=x86_64-native-linuxapp-gcc
    make -j8

    cd /opt/src/
    git clone https://github.com/Netronome/virtio-forwarder
    export RTE_SDK=/opt/src/dpdk-17.05
    cd /opt/src/virtio-forwarder
    apt-get install python-sphinx
    dpkg --purge virtio-forwarder
    make
    make install


fi

# Start virtio-forwarder

systemctl start virtio-forwarder # systemd




