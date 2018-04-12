#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

path_ovs=$(find / -name "ovs-ctl" | sed 's=/ovs-ctl==g' | grep ovs | sed -n 1p)

test=$(echo $PATH | grep $path_ovs)

if [[ -z "$test" ]];then
    export PATH="$PATH:$path_ovs"
    echo $PATH
    echo "PATH=\"$PATH\"" > /etc/environment
fi

NR_VFS=50

$script_dir/clean.sh

sleep 3

echo "Reloading nfp module"
rmmod nfp

sleep 3

modprobe nfp nfp_dev_cpp=1
echo "nfp module loaded"

echo "Creating VF's ..."
##TODO: Add check for sf and/or multiple cards later on
dev="0000:"$(lspci -d 19ee:4000 | cut -d ' ' -f 1)
echo 0 > /sys/bus/pci/devices/$dev/sriov_numvfs

sleep 3

echo "$NR_VFS" > /sys/bus/pci/devices/$dev/sriov_numvfs
echo "Creating VF's done"

pci=$(lspci -d 19ee: | grep 4000 | cut -d ' ' -f1)

if [[ "$pci" == *":"*":"*"."* ]]; then
    echo "PCI correct format"
elif [[ "$pci" == *":"*"."* ]]; then
    echo "PCI corrected"
    pci="0000:$pci"
fi

echo $pci
for ndev in $(ls /sys/bus/pci/devices/$pci/net); do
    echo $ndev
    ifconfig $ndev up
    ethtool -K $ndev hw-tc-offload on
done
echo "Start OVS"
/root/ovs/utilities/ovs-ctl start
echo "OVS-TC started"

