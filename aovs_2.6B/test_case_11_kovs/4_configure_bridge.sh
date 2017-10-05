#!/bin/bash

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

#Add PF to br0
ovs-vsctl add-port $BRIDGE $INTERFACE -- set interface $INTERFACE ofport_request=1
#ovs-vsctl add-port $BRIDGE_BOND patch-bond-to-br -- set interface patch-bond-to-br type=patch options:peer=patch-br-to-bond
#ovs-vsctl add-port $BRIDGE patch-br-to-bond -- set interface patch-br-to-bond type=patch options:peer=patch-bond-to-br

ovs-vsctl show
ovs-ofctl show $BRIDGE

ovs-ofctl dump-flows $BRIDGE

ovs-vsctl set Open_vSwitch . other_config:max-idle=300000
ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
ovs-appctl upcall/set-flow-limit 1000000

ifconfig $INTERFACE up

killall irqbalance
script_dir="$(dirname $(readlink -f $0))"

cd $script_dir
tar xf i40e-2.1.26.tar.gz
cd i40e-2.1.26/scripts
./set_irq_affinity $INTERFACE local
exit 0

