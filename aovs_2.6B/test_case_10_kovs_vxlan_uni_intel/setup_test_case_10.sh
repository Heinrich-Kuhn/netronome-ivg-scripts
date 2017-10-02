#!/bin/bash

VM_NAME=$1
BONDBR_DEST_IP=$2
BONDBR_SRC_IP=$3

script_dir="$(dirname $(readlink -f $0))"

ovs-ctl start

$script_dir/4_configure_bridge.sh $BONDBR_DEST_IP $BONDBR_SRC_IP
$script_dir/5_add_bridge_interface.sh $VM_NAME
$script_dir/6_fix_apparmor.sh

echo "DONE(setup_test_case_10.sh)"

exit 0

