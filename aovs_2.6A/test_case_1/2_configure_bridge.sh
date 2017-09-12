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
ovs-vsctl add-port $BRIDGE sdn_p0 -- set interface sdn_p0 ofport_request=1

# Add VF ports
ovs-vsctl add-port $BRIDGE sdn_v0.40 -- set interface sdn_v0.40 ofport_request=40

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE