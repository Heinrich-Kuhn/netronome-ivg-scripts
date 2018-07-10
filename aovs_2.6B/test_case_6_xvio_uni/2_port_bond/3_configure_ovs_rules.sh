#!/bin/bash
#configure_ovs_rules.sh

BRIDGE=br0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE

#check phy ports connected
ip link | grep nfp_p0 | grep DOWN #Is link up
if [ $? -eq 1 ]; then
	ip link | grep nfp_p1 | grep DOWN #Is link up?
	if [ $? -eq 1 ]; then
		# Both links are up, use bond
		ovs-vsctl add-bond br0 bond0 nfp_p0 nfp_p1
		ovs-vsctl set port bond0 bond_mode=balance-tcp
		ovs-vsctl set port bond0 lacp=active
		ovs-ofctl -OOpenflow13 mod-port br0 br0 no-forward
	else
		#Only nfp_p0 is up, add it to bridge
		ovs-vsctl add-port $BRIDGE nfp_p0 -- set interface nfp_p0 ofport_request=1
	fi
else
	ip link | grep nfp_p1 | grep DOWN #Is link up?
	if [ $? -eq 1 ]; then
		#Only nfp_p1 is up, add it to bridge
		ovs-vsctl add-port $BRIDGE nfp_p1 -- set interface nfp_p1 ofport_request=1
	fi
fi

#Add VF's
ovs-vsctl add-port $BRIDGE nfp_v0.39 -- set interface nfp_v0.39 ofport_request=39 external_ids:virtio_relay=39
ovs-vsctl add-port $BRIDGE nfp_v0.40 -- set interface nfp_v0.40 ofport_request=40 external_ids:virtio_relay=40

ovs-ofctl del-flows $BRIDGE

ovs-ofctl -O OpenFlow13 add-flow $BRIDGE actions=NORMAL

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ovs-vsctl show
ovs-ofctl show $BRIDGE
ovs-ofctl dump-flows $BRIDGE
