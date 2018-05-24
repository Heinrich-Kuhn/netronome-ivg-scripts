#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"

$script_dir/vm_shutdown_all.sh

$script_dir/clean.sh

/root/ovs/utilities/ovs-ctl stop

for dp in $(ovs-dpctl dump-dps) ; do
    /root/ovs/utilities/ovs-dpctl del-dp $dp
done

lsmod | grep -E '^openvswitch\s' > /dev/null
if [ $? -eq 0 ]; then
    echo "Remove kernel module 'openvswitch'"
    rmmod openvswitch \
        || exit -1
fi

lsmod | grep -E '^nfp\s' > /dev/null
if [ $? -eq 0 ]; then
    echo "Remove kernel module 'nfp'"
    rmmod nfp \
        || exit -1
fi

echo "OVS-TC stopped"
exit 0
