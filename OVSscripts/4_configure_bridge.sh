#!/bin/bash

BRIDGE=br-fo
NETDEV=nfp_p0

# Delete all existing bridges 
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE

# Add physical ports
ovs-vsctl add-port $BRIDGE $NETDEV -- set interface $NETDEV ofport_request=1

# Add VF ports
#ovs-vsctl add-port $BRIDGE nfp_v0.1 -- set interface nfp_v0.1 ofport_request=1

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
