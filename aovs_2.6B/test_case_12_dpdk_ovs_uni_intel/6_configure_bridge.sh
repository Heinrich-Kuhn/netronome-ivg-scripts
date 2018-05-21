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


echo "1 - Configure br0"
#oet Interface dpdk0 s-vsctl del-br br0
br=$(ovs-vsctl list-br | grep -o br0)
if [[ "$br" == "br0" ]]; then
    ovs-vsctl --no-wait del-br br0
fi
ovs-vsctl --no-wait add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl --no-wait add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk ofport_request=1 -- set Interface dpdk0 options:dpdk-devargs=$PCI
#ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk ofport_request=2 -- set Interface dpdk1 options:n_rxq=1


#echo "2 - Add dpdkvhostuser0"
ovs-vsctl --no-wait add-port br0 dpdkvhostuser0 -- set Interface dpdkvhostuser0 type=dpdkvhostuser ofport_request=10 -- set Interface dpdkvhostuser0 options:n_rxq=1
#ovs-vsctl add-port br0 dpdkvhostuser1 -- set Interface dpdkvhostuser1 type=dpdkvhostuser ofport_request=11 -- set Interface dpdkvhostuser1 options:n_rxq=1
sleep 5
echo "2 - Add echo rule"
#ovs-ofctl del-flows br0
ovs-ofctl dump-flows br0

chmod 777 /usr/local/var/run/openvswitch/*
