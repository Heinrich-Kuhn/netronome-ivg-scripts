#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

$script_dir/vm_shutdown_all.sh

$script_dir/clean.sh

/root/ovs/utilities/ovs-ctl stop
for dp in $(ovs-dpctl dump-dps)
do
    /root/ovs/utilities/ovs-dpctl del-dp $dp
done
rmmod openvswitch 2>/dev/null
rmmod nfp 2>/dev/null
echo "OVS-TC stopped"

