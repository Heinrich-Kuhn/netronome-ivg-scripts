#!/bin/bash

VF_NAME_1="virtfn5"
VF_NAME_2="virtfn6"

VF1="pf0vf5"
VF2="pf0vf6"

BRIDGE_NAME="br0"

#DRIVER="vfio-pci"

grep ID_LIKE /etc/os-release | grep -q debian
if [[ $? -eq 0 ]]; then
  DRIVER=nfp_netvf
fi

grep  ID_LIKE /etc/os-release | grep -q fedora
if [[ $? -eq 0 ]]; then
  DRIVER=nfp
fi

##############################################################################################################

function find_repr()
{
  local REPR=$1
  for i in /sys/class/net/*;
  do
    phys_port_name=$(cat $i/phys_port_name 2>&1 /dev/null)
    #echo "test: ${phys_port_name}"
    #echo "REPR: $REPR"
    if [ "$phys_port_name" == "$REPR" ];
    then
      echo "$i"
    fi
  done
}

function clean-ovs-bridges()
{
  ovs-vsctl list-br | while read BRIDGE;
  do
    echo "Deleting: $BRIDGE"
    ovs-vsctl del-br $BRIDGE
  done
}

function general-ovs-config()
{
  ovs-vsctl --no-wait set Open_vSwitch . other_config:hw-offload=true
  ovs-vsctl --no-wait set Open_vSwitch . other_config:tc-policy=none
  ovs-vsctl --no-wait set Open_vSwitch . other_config:max-idle=60000
  ovs-vsctl set Open_vSwitch . other_config:flow-limit=1000000
}


/root/IVG_folder/helper_scripts/start_ovs_tc.sh

general-ovs-config
clean-ovs-bridges

ovs-vsctl add-br $BRIDGE_NAME

PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi
echo $PCI

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
echo "repr_vf1 = $repr_vf1"
ip l set $repr_vf1 up

repr_vf2=$(find_repr $VF2 | rev | cut -d '/' -f 1 | rev)
echo "repr_vf2 = $repr_vf2"
ip l set $repr_vf2 up


VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
sleep 1
echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"
sleep 1

VF2_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_2} | rev | cut -d '/' -f1 | rev)
sleep 1
echo "VF2_PCI_ADDRESS: $VF2_PCI_ADDRESS"
sleep 1


interface_list=(${VF1_PCI_ADDRESS} ${VF2_PCI_ADDRESS})
driver=igb_uio
mp=uio
# updatedb
DPDK_DEVBIND=$(find /opt/ -iname dpdk-devbind.py | head -1)
DRKO=$(find /opt/ -iname 'igb_uio.ko' | head -1 )
echo "loading driver"
modprobe $mp 
insmod $DRKO
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
for interface in ${interface_list[@]};
do
  echo $DPDK_DEVBIND --bind $driver $interface
  $DPDK_DEVBIND --bind $driver $interface
done
echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status


###################################################################################################
###################################################################################################

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up

#Change default Coalesce setting
ethtool -C $ETH rx-usecs 1

ovs-vsctl add-port $BRIDGE_NAME $repr_p0 -- set interface $repr_p0 ofport_request=1
ovs-vsctl add-port $BRIDGE_NAME $repr_vf1 -- set interface $repr_vf1 ofport_request=5
ovs-vsctl add-port $BRIDGE_NAME $repr_vf2 -- set interface $repr_vf2 ofport_request=6


#Add NORMAL RULE
ovs-ofctl del-flows $BRIDGE_NAME


#ADD IN OUT RULES
################################################
ovs-ofctl add-flow $BRIDGE_NAME in_port=5,actions=1
ovs-ofctl add-flow $BRIDGE_NAME in_port=6,actions=1

ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.10.1,actions=5
ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0800,nw_dst=10.10.10.2,actions=6

ovs-ofctl add-flow $BRIDGE_NAME in_port=1,dl_type=0x0806,actions=5,6
################################################

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME

