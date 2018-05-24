#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

path_ovs=$(find / -name "ovs-ctl" \
    | sed 's=/ovs-ctl==g' \
    | grep ovs \
    | sed -n 1p)

test=$(echo $PATH | grep $path_ovs)

if [[ -z "$test" ]];then
    export PATH="$PATH:$path_ovs"
    echo $PATH
    echo "PATH=\"$PATH\"" > /etc/environment
fi

NR_VFS=50

$script_dir/clean.sh

sleep 1

lsmod | grep -E '^nfp\s' > /dev/null
if [ $? -eq 0 ]; then
    rmmod nfp \
        || exit -1
fi

sleep 1

echo " - Load NFP kernel module"
modprobe nfp nfp_dev_cpp=1
if [ $? -ne 0 ]; then
    echo "ERROR($0): failed to load NFP kernel module"
    exit -1
fi

nfppci="$(lspci -d 19ee:4000 | cut -d ' ' -f 1)"
if [ "$nfppci" == "" ]; then
    echo "ERROR($0): can not locate NFP device"
    exit -1
elif [[ "$nfppci" == *":"*":"*"."* ]]; then
    :
elif [[ "$nfppci" == *":"*"."* ]]; then
    nfppci="0000:$nfppci"
fi

echo "NFP PCI: $nfppci"

numvfs="/sys/bus/pci/devices/$nfppci/sriov_numvfs"
if [ ! -f "$numvfs" ]; then
    echo "ERROR($0): system file $numvfs does not exist"
    exit -1
fi

echo 0 > $numvfs
if [ $? -ne 0 ]; then
    echo "ERROR($0): failed to set sriov_numvfs to zero"
    exit -1
fi

sleep 1

echo "$NR_VFS" > $numvfs
if [ $? -ne 0 ]; then
    echo "ERROR($0): failed to set sriov_numvfs to $NR_VFS"
    exit -1
fi

# Virtual Function Device Directory
vfddir="/sys/bus/pci/devices/$nfppci/net"

if [ ! -d "$vfddir" ]; then
    echo "ERROR($0): missing directory $vfddir"
    exit -1
fi

iflist="$(ls $vfddir)"

for ifname in $iflist ; do
    echo "Configure $ifname"
    ifconfig $ifname up
    ethtool -K $ifname hw-tc-offload on
done

echo " - Start OVS"

/root/ovs/utilities/ovs-ctl start \
    || exit -1

echo "DONE($(basename $0))"

exit 0
