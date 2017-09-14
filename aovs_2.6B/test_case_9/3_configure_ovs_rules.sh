#!/bin/bash
#configure_ovs_rules.sh

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

ovs-vsctl add-port $BRIDGE nfp_p0 -- set interface nfp_p0 ofport_request=1
ovs-vsctl add-port $BRIDGE nfp_p1 -- set interface nfp_p1 ofport_request=2


#Add VF's
ovs-vsctl add-port $BRIDGE nfp_v0.23 -- set interface nfp_v0.23 ofport_request=23 external_ids:virtio_relay=23
ovs-vsctl add-port $BRIDGE nfp_v0.24 -- set interface nfp_v0.24 ofport_request=24 external_ids:virtio_relay=24

ovs-ofctl del-flows $BRIDGE

ovs-ofctl -O OpenFlow13 add-flow in_port=1,actions=output:23
ovs-ofctl -O OpenFlow13 add-flow in_port=23,actions=output:1

ovs-ofctl -O OpenFlow13 add-flow in_port=2,actions=output:24
ovs-ofctl -O OpenFlow13 add-flow in_port=24,actions=output:2

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
