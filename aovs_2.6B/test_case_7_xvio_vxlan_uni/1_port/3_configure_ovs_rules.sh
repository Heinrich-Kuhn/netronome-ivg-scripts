#!/bin/bash

BONDBR_DEST_IP=$1 
BONDBR_SRC_IP=$2

if [ -z "$1" ] && [ -z "$2" ]; then
    echo "ERROR: Not enough parameters where passed to this script"
    echo "Example: ./3_configure_AOVS_rules.sh 10.10.10.1 10.10.10.2"
    exit -1
else
    BONDBR_DEST_IP=$1 
    BONDBR_SRC_IP=$2
fi    

BRIDGE=br0
BRIDGE_BOND=bondbr0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

ovs-vsctl add-br $BRIDGE
#ovs-vsctl add-br $BRIDGE_BOND

#Add PF to br0
#ovs-vsctl add-port $BRIDGE_BOND nfp_p0 -- set interface nfp_p0 ofport_request=1
#ovs-vsctl add-port $BRIDGE_BOND patch-bond-to-br -- set interface patch-bond-to-br type=patch options:peer=patch-br-to-bond
#ovs-vsctl add-port $BRIDGE patch-br-to-bond -- set interface patch-br-to-bond type=patch options:peer=patch-bond-to-br

#Add VF's to br0 
ovs-vsctl add-port $BRIDGE nfp_v0.25 -- set interface nfp_v0.25 ofport_request=25 external_ids:virtio_relay=25
ovs-vsctl add-port $BRIDGE nfp_v0.26 -- set interface nfp_v0.26 ofport_request=26 external_ids:virtio_relay=26

ovs-vsctl show
ovs-ofctl show $BRIDGE

ovs-ofctl dump-flows $BRIDGE
#ovs-ofctl dump-flows $BRIDGE_BOND

#Delete patch
#ovs-vsctl del-port patch-bond-to-br

ip link set nfp_p0 down
ip addr add $BONDBR_SRC_IP/24 dev nfp_p0
ip link set nfp_p0 up

ovs-vsctl add-port br0 vxlan01 -- set interface vxlan01 type=vxlan options:remote_ip=$BONDBR_DEST_IP  options:local_ip=$BONDBR_SRC_IP

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

exit 0


