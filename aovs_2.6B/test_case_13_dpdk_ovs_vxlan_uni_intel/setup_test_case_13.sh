#!/bin/bash

VM_NAME=$1
script_dir="$(dirname $(readlink -f $0))"

ovs-ctl start

$script_dir/4_bind_intel_vfio_pci.sh
$script_dir/5_start_dpdk_ovs.sh
$script_dir/6_configure_bridge.sh
$script_dir/7_add_bridge_interface.sh $VM_NAME
$script_dir/8_fix_apparmor.sh


echo "DONE(setup_test_case_13.sh)"

exit 0

