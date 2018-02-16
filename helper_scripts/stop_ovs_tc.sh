#!/bin/bash
script_dir="$(dirname $(readlink -f $0))"

$script_dir/clean.sh

ovs-ctl stop
for dp in $(ovs-dpctl dump-dps)
do
    ovs-dpctl del-dp $dp
done
rmmod openvswitch 2>/dev/null
rmmod nfp 2>/dev/null
echo "AOVS-TC stopped"

