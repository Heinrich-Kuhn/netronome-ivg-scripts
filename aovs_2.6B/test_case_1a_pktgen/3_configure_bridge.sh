#!/bin/bash

BRIDGE=br0

# Delete all existing bridges 
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE \
  || exit -1

# Add VF ports
ovs-vsctl add-port $BRIDGE nfp_v0.1 \
  -- set interface nfp_v0.1 ofport_request=1 \
  || exit -1

# Add physical ports
$HOME/IVG_folder/helper_scripts/attach-physical-ports.sh $BRIDGE \
  || exit -1

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE

exit 0
