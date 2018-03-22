#!/bin/bash

PCI=$(lspci -d 8086:1583 | awk 'NR==1 {print $1}')
if [ -z "$PCI" ]
then
    PCI=$(lspci -d 8086:1584 | awk 'NR==1 {print $1}')
fi
if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi
echo $PCI


BONDBR_DEST_IP=$1
BONDBR_SRC_IP=$2

if [ -z "$1" ] && [ -z "$2" ]; then
    echo "ERROR: Not enough parameters where passed to this script"
    echo "Example: ./3_configure_AOVS_rules.sh 10.10.10.1 10.10.10.2"
    exit -1
else
    BONDBR_DEST_IP=$1
    BONDBR_SRC_IP=$2
fi

#Intel Interface
INTERFACE=$(ls /sys/bus/pci/devices/0000\:$intel_bus/net)
echo "Intel interface: $INTERFACE"

echo "1 - Configure br0"
ovs-vsctl del-br br0
ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
#ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk ofport_request=1 -- set Interface dpdk0 options:n_rxq=1
#ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk ofport_request=2 -- set Interface dpdk1 options:n_rxq=1

#echo "2 - Add dpdkvhostuser0"
ovs-vsctl add-port br0 dpdkvhostuser0 -- set Interface dpdkvhostuser0 type=dpdkvhostuser ofport_request=10 -- set Interface dpdkvhostuser0 options:n_rxq=1

ifconfig $INTERFACE $BONDBR_SRC_IP
ifconfig $INTERFACE up

ovs-vsctl add-port br0 vxlan01 -- set interface vxlan01 type=vxlan options:remote_ip=$BONDBR_DEST_IP  options:local_ip=$BONDBR_SRC_IP

echo "2 - Add echo rule"
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 in_port=10,actions=output:1
ovs-ofctl add-flow br0 in_port=1,actions=output:10
ovs-ofctl dump-flows br0

chmod 777 /usr/local/var/run/openvswitch/*

killall irqbalance

exit 0
