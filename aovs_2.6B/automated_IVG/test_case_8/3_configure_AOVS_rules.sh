#!/bin/bash

VM_NAME="$1"
BRIDGE="br0"

# Delete all bridges
for br in $(ovs-vsctl list-br); do
  ovs-vsctl --if-exists del-br $br
done

# Create a new bridge
ovs-vsctl add-br $BRIDGE || exit -1

# List of all physical interfaces (nfp_p)
nfp_p_list=( $( cat /proc/net/dev \
    | sed -rn 's/^\s*(nfp_p[0-9]):.*$/\1/p' \
    ) )

# Create list of interfaces that are 'UP'
iflist=()
for ifname in ${nfp_p_list[@]} ; do
    ip link show $ifname | grep "state UP" > /dev/null
    if [ "$?" == "0" ]; then
        iflist+=( "$ifname" )
    fi
done

if [ ${#iflist[@]} -eq 1 ]; then
    ovs-vsctl add-port $BRIDGE ${iflist[0]} || exit -1
else
    ovs-vsctl add-bond br0 bond0 ${iflist[@]} || exit -1
    ovs-vsctl set port bond0 bond_mode=balance-tcp
    ovs-vsctl set port bond0 lacp=active
fi

# Add VF ports
ovs-vsctl add-port $BRIDGE nfp_v0.44 || exit -1
ovs-vsctl add-port $BRIDGE nfp_v0.45 || exit -1

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

exit 0
