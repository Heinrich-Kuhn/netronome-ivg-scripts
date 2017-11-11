#!/bin/bash
#configure_ovs_rules.sh

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE \
  || exit -1

#Add VF's
ovs-vsctl \
  -- add-port $BRIDGE nfp_v0.39 \
  -- set interface nfp_v0.39 ofport_request=39 external_ids:virtio_relay=39 \
  -- add-port $BRIDGE nfp_v0.40 \
  -- set interface nfp_v0.40 ofport_request=40 external_ids:virtio_relay=40 \
  || exit -1

# Add physical ports
$HOME/IVG_folder/helper_scripts/attach-physical-ports.sh $BRIDGE \
  || exit -1

ovs-ofctl del-flows $BRIDGE

ovs-ofctl -O OpenFlow13 add-flow $BRIDGE actions=NORMAL

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE

exit 0
