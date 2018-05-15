#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

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

# Delete all bridges
for br in $(ovs-vsctl list-br);
do
  /root/ovs/utilities/ovs-vsctl --if-exists del-br $br
done

echo "Stop openvswitch ..."
/root/ovs/utilities/ovs-ctl stop

dev="0000:"$(lspci -d 19ee:4000 | cut -d ' ' -f 1)
echo 0 > /sys/bus/pci/devices/$dev/sriov_numvfs

sleep 2

repr_pf0=$(find_repr pf0 | rev | cut -d "/" -f 1 | rev)
repr_p0=$(find_repr p0 | rev | cut -d "/" -f 1 | rev)
ip link set $repr_p0 down
ip link set $repr_pf0 down

DPDK_DEVBIND=$(find / -iname dpdk-devbind.py | head -1)

PCI=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$PCI" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$PCI" == *":"*"."* ]]; then
    echo "PCI corrected"
    PCI="0000:$PCI"
fi

pci2=$(echo $PCI | cut -d ':' -f2)
pci1=$(echo $PCI | cut -d ':' -f1)

PCI="$pci1:$pci2"
echo $PCI

pci_list=$($DPDK_DEVBIND -s | grep $PCI | cut -d ' ' -f1 )

echo "Unbinding VFs"
for item in $pci_list
do
    $DPDK_DEVBIND -u $item 2>/dev/null
done

sed "s#^VIRTIOFWD_STATIC_VFS=.*#VIRTIOFWD_STATIC_VFS=#g" -i /etc/default/virtioforwarder

echo "Stop Virtioforwarder ..."

systemctl stop virtioforwarder

echo "rmmod nfp"
rmmod nfp

echo "CLEANED"













