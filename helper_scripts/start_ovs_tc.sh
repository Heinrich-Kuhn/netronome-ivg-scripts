#!/bin/bash

path_ovs=$(find / -name "ovs-ctl" | sed -n 1p | sed 's=/ovs-ctl==g')

test=$(ls /etc/environment | grep $path_ovs)

if [[ -z "$test" ]];then
    export PATH=$PATH:$path_ovs
    echo $PATH
    echo "PATH=\"$PATH\"" > /etc/environment
fi

NR_VFS=50

echo "Reloading nfp module"
rmmod nfp
modprobe nfp nfp_dev_cpp=1
echo "nfp module loaded"

echo "Creating VF's ..."
##TODO: Add check for sf and/or multiple cards later on
dev="0000:"$(lspci -d 19ee:4000 | cut -d ' ' -f 1)
echo "$NR_VFS" > /sys/bus/pci/devices/$dev/sriov_numvfs
echo "Creating VF's done"

pci=$(lspci -d 19ee:4000 | cut -d ' ' -f 1)
pci="0000:$pci"
echo $pci
for ndev in $(ls /sys/bus/pci/devices/$pci/net); do
    echo $ndev
    ifconfig $ndev up
    ethtool -K $ndev hw-tc-offload on
done

ovs-ctl start
echo "AOVS-TC started"

