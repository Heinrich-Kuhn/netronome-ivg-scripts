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

BRIDGE=br-fo
BRIDGE_BOND=bondbr0

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  ovs-vsctl --if-exists del-br $br
done

ovs-vsctl add-br $BRIDGE
ovs-vsctl add-br $BRIDGE_BOND

#Add PF to br0
ovs-vsctl add-port $BRIDGE_BOND nfp_p0 -- set interface nfp_p0 ofport_request=1
ovs-vsctl add-port $BRIDGE_BOND patch-bond-to-br -- set interface patch-bond-to-br type=patch options:peer=patch-br-to-bond
ovs-vsctl add-port $BRIDGE patch-br-to-bond -- set interface patch-br-to-bond type=patch options:peer=patch-bond-to-br

ovs-vsctl show
ovs-ofctl show $BRIDGE

ovs-ofctl dump-flows $BRIDGE
ovs-ofctl dump-flows $BRIDGE_BOND

#Delete patch
ovs-vsctl del-port patch-bond-to-br

