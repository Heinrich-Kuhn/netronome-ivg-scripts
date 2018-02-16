#!/bin/bash

VM_NAME=$1
VM_CPU_COUNT=$2

VF_NAME_1="virtfn21"
VF_NAME_2="virtfn22"

VF1="pf0vf21"
VF2="pf0vf22"

BRIDGE_NAME=br0

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


##############################################################################################################

/root/IVG_folder/helper_scripts/start_ovs_tc.sh

PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi

#------------------------------------------------------------------------------------------------------

repr_vf1=$(find_repr $VF1 | rev | cut -d '/' -f 1 | rev)
VF1_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_1} | rev | cut -d '/' -f1 | rev)
echo "VF1_PCI_ADDRESS: $VF1_PCI_ADDRESS"

#------------------------------------------------------------------------------------------------------

repr_vf2=$(find_repr $VF2 | rev | cut -d '/' -f 1 | rev)
VF2_PCI_ADDRESS=$(readlink -f /sys/bus/pci/devices/${PCI}/${VF_NAME_2} | rev | cut -d '/' -f1 | rev)
echo "VF2_PCI_ADDRESS: $VF2_PCI_ADDRESS"

#------------------------------------------------------------------------------------------------------

sed "s#^VIRTIOFWD_STATIC_VFS=.*#VIRTIOFWD_STATIC_VFS=($VF1_PCI_ADDRESS=21 $VF2_PCI_ADDRESS=22)#g" -i /etc/default/virtioforwarder

## BIND IGB_UIO DRIVER
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

