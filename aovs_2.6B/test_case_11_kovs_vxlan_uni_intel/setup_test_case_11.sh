#!/bin/bash

VM_NAME=$1
BONDBR_DEST_IP=$2
BONDBR_SRC_IP=$3

script_dir="$(dirname $(readlink -f $0))"

$script_dir/0_uninstall_aovs.sh
$script_dir/1_install_prerequisitions.sh
$script_dir/2_install_kovs.sh

if [ $? == 1 ]; then 
echo "Could not install KOVS"
exit -1
fi

$script_dir/3_install_intel.sh

if [ $? == 1 ]; then 
echo "Could not install Intel driver"
exit -1
fi

$script_dir/4_configure_bridge.sh $BONDBR_DEST_IP $BONDBR_SRC_IP
$script_dir/5_add_bridge_interface.sh $VM_NAME
$script_dir/6_fix_apparmor.sh

echo "DONE(setup_test_case_11.sh)"

exit 0

