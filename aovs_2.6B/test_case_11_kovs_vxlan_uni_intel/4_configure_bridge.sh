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

#echo "Creating VF"
intel_bus=$(lspci -d 8086:1583 | awk 'NR==1 {print $1}')
#echo 1 > /sys/bus/pci/devices/0000\:$intel_bus/sriov_numvfs

INTERFACE=$(ls /sys/bus/pci/devices/0000\:$intel_bus/net)
echo "Intel interface: $INTERFACE"

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
ovs-vsctl add-port $BRIDGE_BOND $INTERFACE -- set interface $INTERFACE ofport_request=1
#ovs-vsctl add-port $BRIDGE_BOND patch-bond-to-br -- set interface patch-bond-to-br type=patch options:peer=patch-br-to-bond
#ovs-vsctl add-port $BRIDGE patch-br-to-bond -- set interface patch-br-to-bond type=patch options:peer=patch-bond-to-br

ovs-vsctl show
ovs-ofctl show $BRIDGE

ovs-ofctl dump-flows $BRIDGE
ovs-ofctl dump-flows $BRIDGE_BOND

#Delete patch
#ovs-vsctl del-port patch-bond-to-br

ifconfig $BRIDGE_BOND $BONDBR_SRC_IP

ovs-vsctl add-port $BRIDGE vxlan01 -- set interface vxlan01 type=vxlan options:remote_ip=$BONDBR_DEST_IP  options:local_ip=$BONDBR_SRC_IP


ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ifconfig $INTERFACE up

exit 0

