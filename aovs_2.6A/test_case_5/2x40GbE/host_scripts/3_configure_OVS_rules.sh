#!/bin/bash

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE

# Add physical ports
for i in $(seq 0 1);
do
  ovs-vsctl add-port $BRIDGE sdn_p${i} -- set interface sdn_p${i} ofport_request=$((i+1))
done

# Add VF ports
for i in 42 44;
do
  ovs-vsctl add-port $BRIDGE sdn_v0.${i} -- set interface sdn_v0.${i} ofport_request=$((i)) external_ids:virtio_relay=$((i))
done

#d=$(locate dpdk-devbind.py | head -1)
#echo "Using $d"
#modprobe igb_uio
#for i in 42 44;
#do
#  echo "sdn_v0.${i} -> $(ethtool -i sdn_v0.${i} | grep bus-info | awk '{print $5}')"
#  $d --bind igb_uio $(ethtool -i sdn_v0.${i} | grep bus-info | awk '{print $5}')
#done


ovs-ofctl del-flows $BRIDGE
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=1,actions=output:42
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=42,actions=output:1
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=2,actions=output:44
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=44,actions=output:2
ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
