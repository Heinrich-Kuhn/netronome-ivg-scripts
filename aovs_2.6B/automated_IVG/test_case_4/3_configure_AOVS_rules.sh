#!/bin/bash

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE
ovs-vsctl add-port $BRIDGE nfp_p0 -- set interface nfp_p0 ofport_request=1
ovs-vsctl add-port $BRIDGE nfp_p1 -- set interface nfp_p1 ofport_request=2

# Add VF ports
ovs-vsctl add-port $BRIDGE nfp_v0.30 -- set interface nfp_v0.30 ofport_request=30
ovs-vsctl add-port $BRIDGE nfp_v0.31 -- set interface nfp_v0.31 ofport_request=31

#Add NORMAL RULE
ovs-ofctl del-flows br0
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=1,actions=output:30
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=30,actions=output:1

ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=2,actions=output:31
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE in_port=31,actions=output:2


ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
