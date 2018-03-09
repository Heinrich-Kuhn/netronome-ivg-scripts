#!/bin/bash

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE \
  || exit -1

# Add VF ports
ovs-vsctl \
  -- add-port $BRIDGE nfp_v0.41 \
  -- set interface nfp_v0.41 ofport_request=41 \
  -- add-port $BRIDGE nfp_v0.42 \
  -- set interface nfp_v0.42 ofport_request=42 \
  || exit -1

# Add physical ports
$HOME/IVG_folder/helper_scripts/attach-physical-ports.sh $BRIDGE \
  || exit -1

#Add NORMAL RULE
#ovs-ofctl del-flows br0
#ovs-ofctl -O OpenFlow13 add-flow $BRIDGE actions=NORMAL

script=$(find / -name of_rules.sh | grep IVG_folder)
num_flows=$(cat /root/IVG_folder/aovs_2.6B/flow_setting.txt)

sleep 1

$script $num_flows 41 42 $BRIDGE

sleep 1

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE

exit 0
