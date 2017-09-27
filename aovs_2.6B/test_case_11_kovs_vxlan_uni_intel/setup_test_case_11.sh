#!/bin/bash

VM_NAME=$1
INTERFACE1=$2
INTERFACE2=$3
BONDBR_DEST_IP=$4
BONDBR_SRC_IP=$5

script_dir="$(dirname $(readlink -f $0))"

$script_dir/0_uninstall_aovs.sh
$script_dir/1_install_prerequisitions.sh
$script_dir/2_install_kovs.sh
$script_dir/3_install_intel.sh

if [ $? == 1 ]; then 
echo "Could not install CoreNIC"
exit -1
fi

$script_dir/4_configure_bridge.sh $BONDBR_DEST_IP $BONDBR_SRC_IP
$script_dir/5_add_bridge_interface.sh $VM_NAME $INTERFACE1
$script_dir/5_add_bridge_interface.sh $VM_NAME $INTERFACE2
$script_dir/6_fix_apparmor.sh

exit 0

