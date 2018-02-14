#!/bin/bash

IP=$1

VF_NAME_1="virtfn1"

VF1="pf0vf1"

BRIDGE_NAME="br0"

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


function bind_nfp_netvf()
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
bind_nfp_netvf ${VF1_PCI_ADDRESS}

ip a add $IP/24 dev $repr_vf1

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
ovs-ofctl add-flow $BRIDGE_NAME actions=NORMAL

ovs-vsctl show
ovs-ofctl show $BRIDGE_NAME
ovs-ofctl dump-flows $BRIDGE_NAME























PCIA="$(ethtool -i nfp_v0.1 | grep bus | cut -d ' ' -f 5)"

# Bind VF using nfp
IP=$1


DPDK_DEVBIND=$(find /opt/netronome -iname dpdk-devbind.py | head -1)
if [ "$DPDK_DEVBIND" == "" ]; then
  echo "ERROR: could not find dpdk-devbind.py tool"
  exit -1
fi

echo "loading driver"
modprobe $driver
echo "DPDK_DEVBIND: $DPDK_DEVBIND"
echo $DPDK_DEVBIND --bind $driver $PCIA
$DPDK_DEVBIND --bind $driver $PCIA

echo $DPDK_DEVBIND --bind $driver $PCIB
$DPDK_DEVBIND --bind $driver $PCIB

echo $DPDK_DEVBIND --status
$DPDK_DEVBIND --status

#Get netdev name
ETH=$($DPDK_DEVBIND --status | grep $PCIA | cut -d ' ' -f 4 | cut -d '=' -f 2)

#Assign IP to netdev and up the interface
ip a add $IP/24 dev $ETH
ip link set dev $ETH up

#Change default Coalesce setting
ethtool -C $ETH rx-usecs 1

exit 0
