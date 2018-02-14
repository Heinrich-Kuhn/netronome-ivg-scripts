#!/bin/bash

IP=$1

VF_NAME_1="virtfn4"

VF1="pf0vf4"

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


function bind_driver()
{
  lsmod | grep --silent $DRIVER || modprobe $DRIVER
  INTERFACE_PCI=$1
  current=$(lspci -ks ${INTERFACE_PCI} | awk '/in use:/ {print $5}')
  echo "INTERFACE_PCI: $INTERFACE_PCI"
  echo "current driver: $current"
  echo "expected driver: $DRIVER"
  if [ "$current" != "$DRIVER" ]; then
    #DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
    #echo "DPDK_DEVBIND: $DPDK_DEVBIND"
    #$DPDK_DEVBIND --bind $DRIVER $INTERFACE_PCI
    if [ "$current" != "" ]; then
      echo "testing: unbind $current on ${INTERFACE_PCI}"
      echo ${INTERFACE_PCI} > /sys/bus/pci/devices/${INTERFACE_PCI}/driver/unbind
      echo ${DRIVER} > /sys/bus/pci/devices/${INTERFACE_PCI}/driver_override
      echo ${INTERFACE_PCI} > /sys/bus/pci/drivers/vfio-pci/bind
    fi
  fi
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


VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
sleep 1
echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"
sleep 1
bind_driver ${VF1_PCI_ADDRESS}


###################################################################################################


DPDK_DEVBIND=$(find /opt -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

ETH=$($DPDK_DEVBIND --status | grep $VF1_PCI_ADDRESS | cut -d ' ' -f 4 | cut -d '=' -f 2)

ip l set $ETH up
ip a add $IP/24 dev $ETH

###################################################################################################




repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up

#Change default Coalesce setting
ethtool -C $repr_vf1 rx-usecs 1

ovs-vsctl add-port $BRIDGE_NAME $repr_p0 -- set interface $repr_p0 ofport_request=1
ovs-vsctl add-port $BRIDGE_NAME $repr_vf1 -- set interface $repr_vf1 ofport_request=2


#Add NORMAL RULE
ovs-ofctl del-flows $BRIDGE_NAME
#ovs-ofctl -O OpenFlow13 add-flow $BRIDGE_NAME actions=NORMAL

ovs-ofctl add-flow $BRIDGE_NAME in_port=1,actions=2
ovs-ofctl add-flow $BRIDGE_NAME in_port=2,actions=1

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME

