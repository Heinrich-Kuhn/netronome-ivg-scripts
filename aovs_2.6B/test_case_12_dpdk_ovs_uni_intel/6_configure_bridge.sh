#!/bin/bash

echo "1 - Configure br0"
#oet Interface dpdk0 s-vsctl del-br br0
ovs-vsctl add-br br0 -- set bridge br0 datapath_type=netdev
ovs-vsctl add-port br0 dpdk0 -- set Interface dpdk0 type=dpdk ofport_request=1 -- set Interface dpdk0 options:n_rxq=1
#ovs-vsctl add-port br0 dpdk1 -- set Interface dpdk1 type=dpdk ofport_request=2 -- set Interface dpdk1 options:n_rxq=1

#echo "2 - Add dpdkvhostuser0"
ovs-vsctl add-port br0 dpdkvhostuser0 -- set Interface dpdkvhostuser0 type=dpdkvhostuser ofport_request=10 -- set Interface dpdkvhostuser0 options:n_rxq=1
#ovs-vsctl add-port br0 dpdkvhostuser1 -- set Interface dpdkvhostuser1 type=dpdkvhostuser ofport_request=11 -- set Interface dpdkvhostuser1 options:n_rxq=1

echo "2 - Add echo rule"
ovs-ofctl del-flows br0
ovs-ofctl dump-flows br0

chmod 777 /usr/local/var/run/openvswitch/*
