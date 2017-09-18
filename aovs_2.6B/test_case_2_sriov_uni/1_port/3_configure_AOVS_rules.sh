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

# Add VF ports
ovs-vsctl add-port $BRIDGE nfp_v0.41 -- set interface nfp_v0.41 ofport_request=41
ovs-vsctl add-port $BRIDGE nfp_v0.42 -- set interface nfp_v0.42 ofport_request=42

#Add NORMAL RULE
ovs-ofctl del-flows br0
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE actions=NORMAL


ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
