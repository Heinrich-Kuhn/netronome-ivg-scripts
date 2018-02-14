#!/bin/bash

DEFAULT_IP="10.10.10.1"

VF_NAME_1="virtfn01"

VF1="pf0vf01"

BRIDGE="br0"

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

PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
ip l set $repr_vf1 up
echo "Add $repr_vf1 to $BRIDGE_NAME"
echo "ovs-vsctl add-port $BRIDGE_NAME $repr_vf1 -- set interface $repr_vf1 ofport_request=2"

VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"
bind_vfio ${VF1_PCI_ADDRESS}


repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
echo "pf0 = $repr_pf0"
ip link set $repr_pf0 up

repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
echo "p0 = $repr_p0"
ip link set $repr_p0 up


ovs-vsctl add-port $BRIDGE_NAME $repr_p0 -- set interface $repr_p0 ofport_request=1


#Add NORMAL RULE
ovs-ofctl del-flows $BRIDGE_NAME
ovs-ofctl -O OpenFlow13 add-flow $BRIDGE_NAME actions=NORMAL

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
