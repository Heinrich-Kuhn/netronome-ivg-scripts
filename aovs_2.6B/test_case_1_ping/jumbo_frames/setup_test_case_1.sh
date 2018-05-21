#!/bin/bash

script_dir="$(dirname $(readlink -f $0))"
IVG_dir="$(echo $script_dir | sed 's/\(IVG\).*/\1/g')"

$script_dir/1_bind_netronome_nfp_netvf_driver.sh $1
$script_dir/2_configure_AOVS.sh
$script_dir/3_configure_bridge.sh
$script_dir/4_configure_ovs_rules.sh

echo "DONE($(basename $0))"
exit 0
