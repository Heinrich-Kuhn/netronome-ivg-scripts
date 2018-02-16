#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

sleep 2

DPDK_DEVBIND=$(find /opt/ -iname dpdk-devbind.py | head -1)

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

for item in $pci_list
do
    echo "PCI: $item"
    $DPDK_DEVBIND -u $item
done

sed "s#^VIRTIOFWD_STATIC_VFS=.*#VIRTIOFWD_STATIC_VFS=#g" -i /etc/default/virtioforwarder

systemctl stop virtioforwarder

rmmod nfp














